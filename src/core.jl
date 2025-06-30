
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
    agg_tasks_per_day = zeros(Int, (length(scheduler.tasks_indices_per_day), nb_worker))
    
    for (id_t, (t, indices)) in enumerate(scheduler.tasks_indices_per_day)
        agg_tasks_per_day[id_t, :] = sum(schedule[indices, :], dims=1)
    end
    
    return agg_tasks_per_day, mse(agg_tasks_per_day)
end

function type_task_loss(scheduler, agg_tasks_per_day, nb_worker)
    agg_type_task = zeros((length(scheduler.task_type_indices), nb_worker))
    for (id_t, indices) in enumerate(scheduler.task_type_indices)
        agg_type_task[id_t, :] = sum(agg_tasks_per_day[indices, :], dims=1)
    end

    agg_worker = sum(agg_type_task, dims=1)
    return mse(agg_type_task) + mse(agg_worker)
end

function workload_loss(scheduler, schedule, nb_workers)
    # equity between worker in daily workload
    agg_all_days = zeros(Int, (scheduler.days, nb_workers))
    for (i, d) in enumerate(scheduler.daily_indices)
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)

        for (i_w, w) in enumerate(scheduler.workers)
            if i ∈ w.days_off
                agg_all_days[i, i_w] = div(sum(schedule[d, :]), nb_workers)
            end
        end
    end

    return mse(agg_all_days, scheduler)
end


function fitness(scheduler, schedule, verbose=false)
    nb_workers = length(scheduler.workers)

    # equity in daily workload
    agg_all_tasks_per_day, agg_type_loss = task_per_day_loss(scheduler, schedule, nb_workers)

    # equity in type task
    agg_type_loss2 = type_task_loss(scheduler, agg_all_tasks_per_day, nb_workers)

    # equity in overall workload
    agg_workload_loss = workload_loss(scheduler, schedule, nb_workers)

    if verbose
        println("agg_type_loss=$agg_type_loss, agg_type_loss2=$agg_type_loss2, agg_workload_loss=$agg_workload_loss")
    end

    return agg_type_loss + agg_workload_loss + agg_type_loss2 
end


function correct_weights(wv, slots)
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
    correct_weights(_, slots)
    _ .^ 2
    Weights
end


function sequence_swap(best, worker_max, worker_min, task_give, task_take)
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

function check_days_off(scheduler, s)
    for (w_id, w) in enumerate(scheduler.workers)
        task_off = [t for i in w.days_off for t in scheduler.daily_indices[i+1]]
        if any(s[task_off, w_id])
            println("worker $w_id is working on his day off")
        end
    end
end


function permutations_seed(scheduler)

    workload_ratio = @chain scheduler.tasks_indices_per_day begin
        [t.worker_slots*length(indices) for (t, indices) in _]
        sum
        _ / length(scheduler.workers) / scheduler.days 
    end
    rebalance = @chain workload_ratio begin
        [_ * -length(w.days_off) for w in scheduler.workers]
        reshape(_, 1, length(_))
    end
    if scheduler.balance_daysoff
        rebalance .*= -1
    end

    nb_workers = length(scheduler.workers)
    slots = zeros(Bool, (scheduler.total_tasks, nb_workers))
    task_type_correction = zeros(Int, (length(scheduler.tasks_indices_per_day), nb_workers))
    last_workers = Int[]
    
    task_type_map = Dict{String, Int}(task.name => id_type for (id_type, (task, indices)) in enumerate(scheduler.tasks_indices_per_day))

    for (day_idx, indices) in enumerate(scheduler.daily_indices)
        daily_workload = zeros(Int, (1, nb_workers))
        for t in indices
            task = get_task(scheduler, t)

            type_task = task_type_map[task.name]
            task_type_workload = reshape(task_type_correction[type_task, :], 1, nb_workers)

            workload = sum(slots, dims=1) + daily_workload
            workload = float.(workload)
            workload .+= rebalance
            
            workload = workload + task_type_workload // 2 
            workload[last_workers] .-= 1//10
            workload = [(i, w) for (i, w) in enumerate(workload) if !in(day_idx-1, scheduler.workers[i].days_off)]
            workload = sort(workload, by=x->x[2], rev=false)
            
            selected_workers = getindex.(workload, 1)
            selected_workers = selected_workers[1:task.worker_slots]
            last_workers = selected_workers
            slots[t, selected_workers] .= 1

            task_type_correction[type_task, selected_workers] .+= 1
            daily_workload += reshape(slots[t, :], 1, nb_workers)
        end
        update_balance = reshape([workload_ratio * in(day_idx, w.days_off) for w in scheduler.workers], 1, length(scheduler.workers))
        update_balance .*= -2*scheduler.balance_daysoff + 1
        rebalance .+= update_balance
    end
    slots
end


function optimize_task_per_day2(scheduler, best::Matrix{Bool})
    nb_workers = length(scheduler.workers)
    map_task_day = Dict{Int64, Int64}(id_t => day for (day, task) in enumerate(scheduler.daily_indices) 
                                                  for id_t in task)
    cost_matrix, loss =  task_per_day_loss(scheduler, best, nb_workers)
    task_affected, _ = size(cost_matrix)
    all_squares = Iterators.product(1:task_affected, 1:task_affected, 1:nb_workers, 1:nb_workers)
    all_squares2 = Iterators.filter(x -> (x[1] != x[2]) & (x[3] != x[4]), all_squares)
    all_squares3 = Iterators.filter(x -> cost_matrix[x[1], x[3]] > cost_matrix[x[1], x[4]]+1, all_squares2)
    all_squares4 = Iterators.filter(x -> cost_matrix[x[2], x[4]] > cost_matrix[x[2], x[3]], all_squares3)
    all_squares5 = Iterators.map(x -> (scheduler.tasks_indices_per_day[x[1]][2], 
                                    scheduler.tasks_indices_per_day[x[2]][2],
                                    x[3], x[4], x[1], x[2]), all_squares4)
    all_squares6 = Iterators.flatmap(x -> Iterators.product(x[1], x[2], x[3], x[4], x[5], x[6]), all_squares5)
    all_squares7 = Iterators.filter(x -> map_task_day[x[1]] == map_task_day[x[2]], all_squares6)
    all_squares8 = Iterators.filter(x -> best[x[1], x[3]] & !best[x[1], x[4]], all_squares7)
    all_squares9 = Iterators.filter(x -> !best[x[2], x[3]] & best[x[2], x[4]], all_squares8)
    for (t1, t2, w1, w2, tp1, tp2) in all_squares9
        if (cost_matrix[tp1, w1] == cost_matrix[tp1, w2]) || (cost_matrix[tp2, w1] == cost_matrix[tp2, w2])
            continue
        end
        best = sequence_swap(best, w1, w2, t1, t2)
        cost_matrix[tp1, w1] -= 1
        cost_matrix[tp1, w2] += 1
        cost_matrix[tp2, w1] += 1
        cost_matrix[tp2, w2] -= 1
    end
    return best
end

function optimize_permutations(scheduler)
    best = permutations_seed(scheduler)

    if fitness(scheduler, best) != 0
        best = optimize_task_per_day2(scheduler, best)
    end
    
    return best
end

function workload_by_worker(scheduler, total_work, nb_workers, worker, minimum_offday)
    if scheduler.balance_daysoff
        working_ratio = (scheduler.days - length(worker.days_off) + minimum_offday) / scheduler.days
        corrected_workload, rem = divrem(working_ratio * total_work, nb_workers)
        corrected_workload_int = ceil(Int, corrected_workload)
        rem += corrected_workload - corrected_workload_int
        if rem == 0
            return corrected_workload_int, 0
        else
            return corrected_workload_int, 1
        end
    else
        return divrem(total_work, nb_workers)
    end
end


function daily_workload_by_worker(scheduler, worker::SWorker, day_idx::Int)
    if day_idx ∈ worker.days_off
        return 0, 0
    end
    working_workers = sum(day_idx ∉ w.days_off for w in scheduler.workers)
    daily_indices = scheduler.daily_indices[day_idx]
    workload = sum(scheduler.indice_task[t_idx].worker_slots for t_idx in daily_indices)

    return divrem(workload, working_workers)
end


function daily_workload_by_workerFALSE(scheduler, worker::SWorker, day_idx::Int)
    if day_idx ∈ worker.days_off
        return 0, 0
    end
    
    working_workers = sum(day_idx ∉ w.days_off for w in scheduler.workers)
    daily_indices = scheduler.daily_indices[day_idx]
    workload = sum(scheduler.indice_task[t_idx].worker_slots for t_idx in daily_indices)
    
    if length(worker.days_off) > 0
        # day_off_correction 
        workload_correction = 0
        for day_off in worker.days_off
            workload_correction += length(scheduler.daily_indices[day_off])
        end
        workload_correction_per_day, rem_corection = divrem(workload_correction, scheduler.days - length(worker.days_off))
        workload, rem = divrem(workload + workload_correction_per_day, working_workers)
        return workload, rem_corection+rem
    else 
        return divrem(workload, working_workers)
    end
end


function solve(scheduler::Scheduler)
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    nb_workers = length(scheduler.workers)
    
    @variable(model, x[1:scheduler.total_tasks, 1:nb_workers], Bin)

    # task slots have to be filled
    #@constraint(model, sum(x) == sum(t.worker_slots for t in values(scheduler.indice_task)))
    for (idx, task) in scheduler.indice_task
        @constraint(model, sum(x[idx, :]) == task.worker_slots)
    end

    # total workload constraints
    total_work = sum(t.worker_slots for (i, t) in scheduler.indice_task)
    nb_workers = length(scheduler.workers)
    workload, rem = divrem(sum(t.worker_slots for (i, t) in scheduler.indice_task), nb_workers)
    minimum_offday = minimum(length(w.days_off) for w in scheduler.workers)

    for (idx, worker) in enumerate(scheduler.workers)
        workload, rem = workload_by_worker(scheduler, total_work, nb_workers, worker, minimum_offday)
        println("$workload $rem $idx")
        if rem == 0
            @constraint(model, sum(x[:, idx]) == workload)
        else
            @constraint(model, sum(x[:, idx]) <= workload + 1)
            @constraint(model, sum(x[:, idx]) >= workload)
        end
    end

    # task workload per worker (task diversity) constraints
    for (task, indices) in scheduler.tasks_indices_per_day
        task_workload, rem = divrem(length(indices) * task.worker_slots, nb_workers)
        for (idx_w, worker) in enumerate(scheduler.workers)
            if rem == 0
                @constraint(model, sum(x[indices, idx_w]) == task_workload)
            else
                @constraint(model, sum(x[indices, idx_w]) <= task_workload + 1)
                @constraint(model, sum(x[indices, idx_w]) >= task_workload)
            end
        end
    end

    no_day_off = sum(length(w.days_off) for w in scheduler.workers) == 0
    # daily workload constraints
    for (day_idx, day_indices) in enumerate(scheduler.daily_indices)
        #daily_workload, rem = divrem(sum(scheduler.indice_task[i].worker_slots for i in day_idx), nb_workers)
        for (idx, worker) in enumerate(scheduler.workers)
            #daily_workload, rem = divrem(sum(scheduler.indice_task[i].worker_slots for i in day_idx), nb_workers)
            daily_workload, rem = daily_workload_by_worker(scheduler, worker, day_idx)
            #println("$day_idx $day_indices $daily_workload $rem $(worker.days_off)")
            if day_idx ∈ worker.days_off
                @constraint(model, sum(x[day_indices, idx]) == 0)
            elseif rem == 0 && no_day_off
                @constraint(model, sum(x[day_indices, idx]) == daily_workload)
            else
                @constraint(model, sum(x[day_indices, idx]) <= daily_workload + 1)
                @constraint(model, sum(x[day_indices, idx]) >= daily_workload -1)
            end
        end
    end

    # 2.4
    JuMP.optimize!(model)

    assert_is_solved_and_feasible(model)
    solution = round.(Int, value.(x))
    display_schedule(scheduler, solution)
    return solution
end


function solveOLD(scheduler::Scheduler)
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    nb_workers = length(scheduler.workers)
    
    @variable(model, x[1:scheduler.total_tasks, 1:nb_workers], Bin)

    # task slots have to be filled
    #@constraint(model, sum(x) == sum(t.worker_slots for t in values(scheduler.indice_task)))
    for (idx, task) in scheduler.indice_task
        @constraint(model, sum(x[idx, :]) == task.worker_slots)
    end

    # total workload constraints
    total_work = sum(t.worker_slots for (i, t) in scheduler.indice_task)
    nb_workers = length(scheduler.workers)
    workload, rem = divrem(sum(t.worker_slots for (i, t) in scheduler.indice_task), nb_workers)
    minimum_offday = minimum(length(w.days_off) for w in scheduler.workers)

    for (idx, worker) in enumerate(scheduler.workers)
        workload, rem = workload_by_worker(scheduler, total_work, nb_workers, worker, minimum_offday)
        #println("$workload $rem")
        if rem == 0
            @constraint(model, sum(x[:, idx]) == workload)
        else
            @constraint(model, sum(x[:, idx]) <= workload + 1)
            @constraint(model, sum(x[:, idx]) >= workload)
        end
    end

    # task workload per worker (task diversity) constraints
    for (task, indices) in scheduler.tasks_indices_per_day
        task_workload, rem = divrem(length(indices) * task.worker_slots, nb_workers)
        for (idx_w, worker) in enumerate(scheduler.workers)
            if rem == 0
                @constraint(model, sum(x[indices, idx_w]) == task_workload)
            else
                @constraint(model, sum(x[indices, idx_w]) <= task_workload + 1)
                @constraint(model, sum(x[indices, idx_w]) >= task_workload)
            end
        end
    end

    no_day_off = sum(length(w.days_off) for w in scheduler.workers) == 0
    # daily workload constraints
    for (day_idx, day_indices) in enumerate(scheduler.daily_indices)
        #daily_workload, rem = divrem(sum(scheduler.indice_task[i].worker_slots for i in day_idx), nb_workers)
        for (idx, worker) in enumerate(scheduler.workers)
            #daily_workload, rem = divrem(sum(scheduler.indice_task[i].worker_slots for i in day_idx), nb_workers)
            daily_workload, rem = daily_workload_by_worker(scheduler, worker, day_idx)
            #println("$day_idx $day_indices $daily_workload $rem $(worker.days_off)")
            if day_idx ∈ worker.days_off
                @constraint(model, sum(x[day_indices, idx]) == 0)
            elseif rem == 0 && no_day_off
                @constraint(model, sum(x[day_indices, idx]) == daily_workload)
            else
                @constraint(model, sum(x[day_indices, idx]) <= daily_workload + 1)
                @constraint(model, sum(x[day_indices, idx]) >= daily_workload -1)
            end
        end
    end

    # 2.4
    JuMP.optimize!(model)

    assert_is_solved_and_feasible(model)
    solution = round.(Int, value.(x))
    return solution
end