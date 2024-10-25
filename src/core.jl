
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


function check_days_off(scheduler, s)

    for (w_id, w) in enumerate(scheduler.workers)
        task_off = [t for i in w.days_off for t in scheduler.daily_indices[i+1]]
        if any(s[task_off, w_id])
            println("worker $w_id is working on his day off")
        end
    end
    
end


function permutations_seedOLD(scheduler)
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
    task_type_correction = zeros(Int, (length(scheduler.all_task_indices_per_day), nb_workers))
    task_type_map = Dict{String, Int}(task.name => id_type for (id_type, (task, indices)) in enumerate(scheduler.all_task_indices_per_day))

    for (day_idx, indices) in enumerate(scheduler.daily_indices)
        daily_workload = zeros(Int, (1, nb_workers))
        
        for t in indices
            task = get_task(scheduler, t)
            workload = sum(slots, dims=1) + daily_workload
            if scheduler.balance_daysoff
                workload += rebalance
            end

            type_task = task_type_map[task.name]
            task_type_workload = reshape(task_type_correction[type_task, :], 1, nb_workers)
            workload = workload + task_type_workload // 2 

            #println("task_type_workload: $task_type_workload, size(task_type_workload): $(size(task_type_workload))")
            #println("workload: $workload, size(workload): $(size(workload))")

            
            workload = [(i, w) for (i, w) in enumerate(workload) if !in(day_idx-1, scheduler.workers[i].days_off)]
            workload = sort(workload, by=x->x[2], rev=false)
            #println("slots: $(task.worker_slots) workload: $workload")
            selected_workers = getindex.(workload, 1)
            selected_workers = selected_workers[1:task.worker_slots]
            slots[t, selected_workers] .= 1

            task_type_correction[type_task, selected_workers] .+= 1

            #show(stdout, "text/plain", task_type_correction)
            #@chain workload begin
            #    get_weights(_, task.worker_slots)
            #    StatsBase.sample(workload, _, task.worker_slots, replace=false)
            #    getindex.(_, 1)
            #    slots[t, _] .= 1
            #end
            daily_workload += reshape(slots[t, :], 1, nb_workers)
        end
    end
    slots
end


function optimize_task_per_day2(scheduler, best::Matrix{Bool})
    nb_workers = length(scheduler.workers)
    map_task_day = Dict{Int64, Int64}(id_t => day for (day, task) in enumerate(scheduler.daily_indices) for id_t in task)

    cost_matrix, loss =  task_per_day_loss(scheduler, best, nb_workers)
    task_affected, _ = size(cost_matrix)
    
    all_squares = Iterators.product(1:task_affected, 1:task_affected, 1:nb_workers, 1:nb_workers)
    all_squares2 = Iterators.filter(x -> (x[1] != x[2]) & (x[3] != x[4]), all_squares)
    all_squares3 = Iterators.filter(x -> cost_matrix[x[1], x[3]] > cost_matrix[x[1], x[4]]+1, all_squares2)
    all_squares4 = Iterators.filter(x -> cost_matrix[x[2], x[4]] > cost_matrix[x[2], x[3]], all_squares3)
    all_squares5 = Iterators.map(x -> (scheduler.all_task_indices_per_day[x[1]][2], 
                                    scheduler.all_task_indices_per_day[x[2]][2],
                                    x[3], x[4], x[1], x[2]), all_squares4)
    all_squares6 = Iterators.flatmap(x -> Iterators.product(x[1], x[2], x[3], x[4], x[5], x[6]), all_squares5)
    all_squares7 = Iterators.filter(x -> map_task_day[x[1]] == map_task_day[x[2]], all_squares6)
    all_squares8 = Iterators.filter(x -> best[x[1], x[3]] & !best[x[1], x[4]], all_squares7)
    all_squares9 = Iterators.filter(x -> !best[x[2], x[3]] & best[x[2], x[4]], all_squares8)


    # task1, task2, worker1, worker2, type_task1, type_task2 
    for (t1, t2, w1, w2, tp1, tp2) in all_squares9

        #if w1 == 1 && w2 == 2 
        #    println("swap $w1, $w2, $t1, $t2, $tp1, $tp2")
        #    println("cost_matrix[tp1, w1] $(cost_matrix[tp1, w1]), cost_matrix[tp1, w2] $(cost_matrix[tp1, w2])")
        #    println("cost_matrix[tp2, w1] $(cost_matrix[tp2, w1]), cost_matrix[tp2, w2] $(cost_matrix[tp2, w2])")
        #    show(stdout, "text/plain", cost_matrix)
        #    println("fitness: $(fitness(scheduler, best, true))")
        #end

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


# BenchmarkTools.Trial: 173 samples with 1 evaluation.
# Range (min … max):   3.214 ms … 143.372 ms  ┊ GC (min … max):  0.00% … 69.80%
# Time  (median):     42.544 ms               ┊ GC (median):     0.00%
# Time  (mean ± σ):   28.905 ms ±  25.128 ms  ┊ GC (mean ± σ):  16.49% ± 21.46%

#  ▄█▇                    ▆█▇                                    
#  ███▇▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▅███▅▅▁▁▁▅▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▅▁▆▅ ▅
#  3.21 ms       Histogram: log(frequency) by time       103 ms <

# Memory estimate: 6.69 MiB, allocs estimate: 32902.
#BenchmarkTools.Trial: 1337 samples with 1 evaluation.
# Range (min … max):  2.211 ms … 25.222 ms  ┊ GC (min … max):  0.00% … 2.90%
# Time  (median):     3.612 ms              ┊ GC (median):    14.89%
# Time  (mean ± σ):   3.727 ms ±  1.460 ms  ┊ GC (mean ± σ):  10.03% ± 9.16%

#           ▁▄▄▃▂▃▆█▄▄▅█▇▄█▇▄ ▁                                
#  ▂▂▂▃▃▄▅▆████████████████████▆▇▇▅▅▄▂▃▃▂▃▂▁▂▁▂▁▂▂▁▁▁▂▁▂▂▂▁▁▂ ▄
#  2.21 ms        Histogram: frequency by time         6.4 ms <#
#
# Memory estimate: 5.93 MiB, allocs estimate: 29472.

function optimize_permutations(scheduler)
    best = permutations_seed(scheduler)

    if fitness(scheduler, best) != 0
        best = optimize_task_per_day2(scheduler, best)
    end
    
    return best
end
