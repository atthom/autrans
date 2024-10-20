
mse(arr) = @chain arr begin
    extrema(_, dims=2)
    map(x -> x[2] - x[1], _)
    _ .^ 2
    sum
end


function mse(arr, scheduler::Scheduler)
    all_mse = 0
    nb_workers = length(scheduler.workers)
    for day_idx in 1:scheduler.days
        worker_working = [w for w in 1:nb_workers if !in(day_idx-1, scheduler.workers[w].days_off)]
        m1, m2 = extrema(arr[day_idx, worker_working])
        all_mse += (m2 - m1)^2
    end
    return all_mse
end

function task_per_day_loss(scheduler, schedule, nb_worker)
    # equity between worker in type of task assigned
    agg_all_tasks_per_day = zeros(Int, (length(scheduler.all_task_indices_per_day), nb_worker))
    
    for (id_t, (t, indices)) in enumerate(scheduler.all_task_indices_per_day)
        agg_all_tasks_per_day[id_t, :] = sum(schedule[indices, :], dims=1)
    end
    
    return agg_all_tasks_per_day, mse(agg_all_tasks_per_day)
end

function type_task_loss(scheduler, agg_all_tasks_per_day, nb_worker)
    agg_type_task = zeros((length(scheduler.task_type_indices), nb_worker))
    for (id_t, indices) in enumerate(scheduler.task_type_indices)
        agg_type_task[id_t, :] = sum(agg_all_tasks_per_day[indices, :], dims=1)
    end

    agg_worker = sum(agg_type_task, dims=1)
    return mse(agg_type_task) + mse(agg_worker)
end

function workload_loss(scheduler, schedule, nb_workers)
    # equity between worker in daily workload
    agg_all_days = zeros(Int, (scheduler.days, nb_workers))
    for (i, d) in enumerate(scheduler.daily_indices)
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)
    end

    return mse(agg_all_days, scheduler)
end


function fitness(scheduler, schedule, verbose=false)
    #per_worker = sum(schedule, dims=1)
    # equity between worker in number of tasks assigned
    #per_worker_balance = maximum(per_worker) - minimum(per_worker)
    nb_workers = length(scheduler.workers)

    agg_all_tasks_per_day, agg_type_loss = task_per_day_loss(scheduler, schedule, nb_workers)

    agg_type_loss2 = type_task_loss(scheduler, agg_all_tasks_per_day, nb_workers)

    agg_workload_loss = workload_loss(scheduler, schedule, nb_workers)

    if verbose
        println("agg_type_loss=$agg_type_loss, agg_type_loss2=$agg_type_loss2, agg_workload_loss=$agg_workload_loss")
    end

    #return per_worker_balance +agg_type_loss + agg_type_loss2 + agg_time_loss + agg_time_loss2
    return agg_type_loss + agg_workload_loss + agg_type_loss2 #+ agg_shuffle_loss
end


function correct_weigts(wv, slots)
    min_work, max_work = extrema(wv)

    if max_work == min_work
        wv .= 1
    else
        wv = max_work .- wv
        if length(findall(x-> x != 0, wv)) < slots
            wv = wv .+ 1
        end
    end
    return wv
end

get_weights(workload, slots) = @chain workload begin
    getindex.(_, 2)
    correct_weigts(_, slots)
    _ .^ 2
    Weights
end


function permutations_seed(scheduler)

    rebalance = @chain scheduler.all_task_indices_per_day begin
        [t.worker_slots*length(indices) for (t, indices) in _]
        sum
        _ / length(scheduler.workers) / scheduler.days
        [_*length(w.days_off) for w in scheduler.workers]
        reshape(_, 1, length(_))
    end

    nb_workers = length(scheduler.workers)
    slots = zeros(Bool, (scheduler.total_tasks, nb_workers))

    for (day_idx, indices) in enumerate(scheduler.daily_indices)
        for t in indices
            task = get_task(scheduler, t)
            workload = sum(slots, dims=1) 
            if scheduler.balance_daysoff
                workload += rebalance
            end

            workload = [(i, w) for (i, w) in enumerate(workload) if !in(day_idx-1, scheduler.workers[i].days_off)]

            @chain workload begin
                get_weights(_, task.worker_slots)
                StatsBase.sample(workload, _, task.worker_slots, replace=false)
                getindex.(_, 1)
                slots[t, _] .= 1
            end

        end
    end
    slots
end

function Autrans.sequence_swap(best, worker_max, worker_min, task_give, task_take)
    affectation_give = CartesianIndex(task_give, worker_max)
    affectation_take = CartesianIndex(task_give, worker_min)

    affectation_giveback = CartesianIndex(task_take, worker_min)
    affectation_takeback = CartesianIndex(task_take, worker_max)

    if best[affectation_take] || best[affectation_takeback] == 1
        println("affectation_take")
        return best
    end
    if best[affectation_give] && best[affectation_giveback] == 0
        println("affectation_give")
        return best
    end

    best[affectation_give] = 0
    best[affectation_take] = 1

    best[affectation_giveback] = 0
    best[affectation_takeback] = 1

    return best
end

function get_task_off(scheduler, worker_max, worker_min)
    workers = scheduler.workers
    days_off = vcat(workers[worker_max].days_off, workers[worker_min].days_off)
    return [t for i in days_off for t in scheduler.daily_indices[i+1]]
end

function day_available(scheduler, worker_max, worker_min, day1, day2)
    workers = scheduler.workers
    days_off = vcat(workers[worker_max].days_off, workers[worker_min].days_off) .+ 1

    return (day1 ∉ days_off) & (day2 ∉ days_off)
end


function optimize_task_per_day2(scheduler, best, nb_workers)
    cost_matrix, loss = task_per_day_loss(scheduler, best, nb_workers)

    task_affected, nb_workers = size(cost_matrix)
    all_squares = Iterators.product(1:task_affected, 1:task_affected, 1:nb_workers, 1:nb_workers)

    all_squares = Iterators.filter(x -> (x[1] != x[2]) & (x[3] != x[4]), all_squares)
    all_squares = Iterators.filter(x -> cost_matrix[x[1], x[3]] > cost_matrix[x[1], x[4]] +1, all_squares)
    all_squares = Iterators.filter(x -> cost_matrix[x[2], x[4]] > cost_matrix[x[2], x[3]] +1, all_squares)



    for (task_row, (task, task_index)) in enumerate(scheduler.all_task_indices_per_day)
        t, l = task_per_day_loss(scheduler, best, nb_workers)

        m1, m2 = extrema(t[task_row, :])
        if m2 - m1 < 2
            continue
        end

        worker_max, worker_min = argmax(t[task_row, :]), argmin(t[task_row, :])
        task_to_give = argmax(best[task_index, worker_max])
        task_to_give = task_index[task_to_give]

        tasks_off = get_task_off(scheduler, worker_max, worker_min)

        if task_to_give in tasks_off
            continue
        end

        task_to_giveback = @chain t[:, worker_max] begin
            argmin
            scheduler.all_task_indices_per_day[_][2]
            _, argmax(best[_, worker_min])
            _[1][_[2]]
        end

        if task_to_giveback in tasks_off
            continue
        end
        
        best = sequence_swap(best, worker_max, worker_min, task_to_give, task_to_giveback)
    end

    return best
end


function optimize_task_per_day(scheduler, best, nb_workers)

    for (task_row, (task, task_index)) in enumerate(scheduler.all_task_indices_per_day)
        t, l = task_per_day_loss(scheduler, best, nb_workers)

        m1, m2 = extrema(t[task_row, :])
        if m2 - m1 < 2
            continue
        end

        worker_max, worker_min = argmax(t[task_row, :]), argmin(t[task_row, :])
        task_to_give = argmax(best[task_index, worker_max])
        task_to_give = task_index[task_to_give]

        tasks_off = get_task_off(scheduler, worker_max, worker_min)

        if task_to_give in tasks_off
            continue
        end

        task_to_giveback = @chain t[:, worker_max] begin
            argmin
            scheduler.all_task_indices_per_day[_][2]
            _, argmax(best[_, worker_min])
            _[1][_[2]]
        end

        if task_to_giveback in tasks_off
            continue
        end
        
        best = sequence_swap(best, worker_max, worker_min, task_to_give, task_to_giveback)
    end

    return best
end

filter_task(indices, constraints, tasks_off) = @chain constraints begin
    findall
    indices[_]
    filter(x -> !in(x, tasks_off), _)
end

# best2 = square_trick2(scheduler, nothing, best)

function Autrans.square_trick2(scheduler, map_day_task, best)
    daily_indices = [(indices, sum(best[indices, :], dims=1)) for (day, indices) in enumerate(scheduler.daily_indices)]
    daily_indices = filter(x -> maximum(x[2]) - minimum(x[2]) > 1, daily_indices)

    if length(s) == 0
        return best
    end
    #tasks_affected_indices = [id_task for (idx_day, agg) in s for id_task in scheduler.daily_indices[idx_day]]
    #tasks_affected = get_task.(Ref(scheduler), tasks_affected_indices)

    agg_all_day_affected = vcat(getindex.(daily_indices, 2)...)
    day_affected, nb_workers = size(agg_all_day_affected)
    all_squares = Iterators.product(1:day_affected, 1:nb_workers, 1:day_affected, 1:nb_workers)
    all_squares = Iterators.filter(x -> (x[1] != x[3]) & (x[2] != x[4]), all_squares)
    all_squares = Iterators.filter(x -> agg_all_day_affected[x[1], x[2]] > agg_all_day_affected[x[1], x[4]] +1, all_squares)
    all_squares = Iterators.filter(x -> agg_all_day_affected[x[3], x[4]] > agg_all_day_affected[x[3], x[2]] +1, all_squares)
    all_squares = Iterators.filter(x -> day_available(scheduler, x[2], x[4], x[1], x[3]), all_squares)

    all_squares = Iterators.map(x -> (daily_indices[x[1]][1], x[2], daily_indices[x[3]][1], x[4]), all_squares)
    all_squares = Iterators.filter(x -> best[x[1], x[2]] .&& .!best[x[1], x[4]], all_squares)
    all_squares = Iterators.filter(x -> .!best[x[3], x[2]] .&& best[x[3], x[4]], all_squares)

    # day1, worker1, day2, worker2
    # since day1 != day2 and worker1 != worker2 it produce a square shape in the cost matrix
    # exchanging tasks keeps the same number of tasks overall but reduce days with heavy workload
    for (d1, w1, d2, w2) in Iterators.take(all_squares, 5)
        println("$d1, $w1, $d2, $w2")
        #tasks_off = Autrans.get_task_off(scheduler, w1, w2)

        #tasks_d1 = filter(id -> !in(id, tasks_off), s[d1][1])
        tasks_d1 = daily_indices[d1][1]
        constraints_t1 = best[tasks_d1, w1] .&& .!best[tasks_d1, w2]
        possible_t1 = tasks_d1[findall(constraints_t1)]

        #tasks_d2 = filter(id -> !in(id, tasks_off), s[d2][1])
        tasks_d2 = daily_indices[d2][1]
        constraints_t2 = .!best[tasks_d2, w1] .&& best[tasks_d2, w2]
        possible_t2 = tasks_d2[findall(constraints_t2)]
        
        for t1 in possible_t1
            t = Autrans.get_task(scheduler, t1)
            for t2 in possible_t2
                if t == Autrans.get_task(scheduler, t2)
                    println("swap $w1, $w2, $t1, $t2")
                    return Autrans.sequence_swap(best, w1, w2, t1, t2)
                end
            end
        end
    end

    return best
end

function square_trick(scheduler, map_day_task, best)
    nb_tasks, _ = size(best)

    for indices in scheduler.daily_indices
        agg_day = sum(best[indices, :], dims=1)

        m1, m2 = extrema(agg_day)
        if m2 - m1 < 2
            continue
        end

        all_max = getindex.(findall(x-> x == m2, agg_day), 2)
        all_min = getindex.(findall(x-> x == m1, agg_day), 2)

        for (worker_max, worker_min) in Base.product(all_max, all_min)
            tasks_off = get_task_off(scheduler, worker_max, worker_min)

            constraints_t1 = best[indices, worker_max] .&& .!best[indices, worker_min]
            possible_t1 = filter_task(indices, constraints_t1, tasks_off)

            start_idx = indices[end] +1
            indices_t2 = start_idx:nb_tasks
            
            constraints_t2 = .!best[indices_t2, worker_max] .&& best[indices_t2, worker_min]
            possible_t2 = filter_task(indices_t2, constraints_t2, tasks_off)

            possible_task = Iterators.product(possible_t1, possible_t2) #|> collect
            possible_task = Iterators.filter(x -> map_day_task[x[1]] == map_day_task[x[2]], possible_task) #|> collect

            if !isempty(possible_task)
                t1, t2 = first(possible_task)
                best = sequence_swap(best, worker_max, worker_min, t1, t2)
            end
            
        end
    end
    return best
end


function optimize_permutations(scheduler; nb_gen=10)
    all_res = []

    map_day_task = Dict(
        i => idx for i in 1:scheduler.total_tasks 
        for (idx, (t, indices)) in enumerate(scheduler.all_task_indices_per_day) if i in indices
    )

    for i in 1:nb_gen
        println("New seed")
        best = permutations_seed(scheduler)
        current_fit = fitness(scheduler, best, false)
        nb_tasks, nb_workers = size(best)

        fit = 100000000000000
        for i in 1:100
            current_fit = fitness(scheduler, best, true)

            best = optimize_task_per_day(scheduler, best, nb_workers)

            current_fit = fitness(scheduler, best, true)

            #best = square_trick2(scheduler, map_day_task, best)

            current_fit = fitness(scheduler, best, false)

            #if current_fit < fit
            #    fit = current_fit
            #else
            #    break
            #end
        end
        push!(all_res, best)
    end
    
    best = all_res[argmin(fitness.(Ref(scheduler), all_res))]
    println("best fitness: $(fitness(scheduler, best, false))")

    return best
end


function check_days_off(scheduler, s)

    for (w_id, w) in enumerate(scheduler.workers)
        task_off = [t for i in w.days_off for t in scheduler.daily_indices[i+1]]
        if any(s[task_off, w_id])
            println("worker $w_id is working on his day off")
        end
    end
    
end