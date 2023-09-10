
using Chain
using Combinatorics
using DataFrames
using StatsBase
using DataStructures

function can_work(perm, day, worker_off)
    for (i, days_off) in worker_off
        if day in days_off && perm[i] == 1
            return false
        end
    end
    return true
end

function get_neighbors(s::Scheduler, schedule)
    neighbors = Vector{Matrix{Bool}}()
    nb_task, nb_workers = size(schedule) 
    worker_off = [(i, w.days_off) for (i, w) in enumerate(s.workers) if length(w.days_off) != 0]
    days_indices = day_indices(s)

    for id_task in 1:nb_task
        all_perm = multiset_permutations(schedule[id_task, :], nb_workers)
        day = findfirst(x -> id_task in x, days_indices)

        for perm in all_perm
            if can_work(perm, day, worker_off) && schedule[id_task, :] != perm
                nei = copy(schedule)
                nei[id_task, :] .= perm
                push!(neighbors, nei)
            end
        end
    end
    return neighbors
end


mse(arr) = @chain arr begin
    extrema(_, dims=2)
    map(x -> x[2] - x[1], _)
    _ .^ 2
    sum
end

function fitness(scheduler, schedule, verbose=false)
    #per_worker = sum(schedule, dims=1)
    
    # equity between worker in number of tasks assigned
    #per_worker_balance = maximum(per_worker) - minimum(per_worker)
    nb_worker = length(scheduler.workers)

    # equity between worker in type of task assigned
    agg_all_tasks = zeros(Int, (length(scheduler.all_task_indices), nb_worker))
    for (id_t, (t, indices)) in enumerate(scheduler.all_task_indices)
        agg_all_tasks[id_t, :] = sum(schedule[indices, :], dims=1) * t.difficulty
    end

    agg_all_tasks_per_day = zeros(Int, (length(scheduler.all_task_indices_per_day), nb_worker))
    for (id_t, (t, indices)) in enumerate(scheduler.all_task_indices_per_day)
        agg_all_tasks_per_day[id_t, :] = sum(schedule[indices, :], dims=1)
    end

    # update agg_tasks (people with less days should work less)
    coeff_task = [length(w.days_off) for w in scheduler.workers]
    coeff_task = scheduler.days ./ (scheduler.days .- coeff_task)

    agg_all_tasks = agg_all_tasks .* coeff_task'
    agg_type_loss = mse(agg_all_tasks)

    agg_all_tasks_per_day = agg_all_tasks_per_day .* coeff_task'
    agg_type_loss2 = mse(agg_all_tasks_per_day)

    
    # equity between worker in daily workload
    agg_all_days = zeros(Int, (scheduler.days, nb_worker))
    for (i, d) in enumerate(day_indices(scheduler))
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)
    end
    agg_time_loss = mse(agg_all_days)

    # add offdays loss

    if verbose
        print("balance=$per_worker_balance, agg_type_loss=$agg_type_loss,")
        print("agg_type_loss2=$agg_type_loss2, agg_time_loss=$agg_time_loss")
        println("")
    end

    #return per_worker_balance +agg_type_loss + agg_type_loss2 + agg_time_loss + agg_time_loss2
    return agg_type_loss + agg_time_loss + agg_type_loss2
end




function simple_search(scheduler; nb_gen = 50)
    best = seed(scheduler)
    
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(scheduler, best)
        println("gen $i, best fitness: $(fitness(scheduler, best))")
        for nei in all_nei
            current_fit = fitness(scheduler, nei)
            if current_fit < best_fit
                best = nei
                best_fit = current_fit
            end
        end
        i += 1
    end
    return best
end


function tabu_search(scheduler; nb_gen = 50, maxTabuSize=50)
    best = seed(scheduler)
    bestCandidate = best
    tabu_list = Vector{Matrix{Bool}}()
    push!(tabu_list, best)
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(scheduler, bestCandidate)
        println("gen $i, tabu_size: $(length(tabu_list)) best fitness: $(fitness(scheduler, bestCandidate))")
        for nei in all_nei
            current_fit = fitness(scheduler, nei)
            if nei ∉ tabu_list && current_fit < best_fit
                bestCandidate = nei
                best_fit = current_fit
            end
        end
        if best_fit == 10000000 
            break
        elseif best_fit < fitness(scheduler, best)
            best = bestCandidate
        end
        
        push!(tabu_list, bestCandidate)

        if length(tabu_list) > maxTabuSize
            popfirst!(tabu_list)
        end
        i += 1
    end

    return best
end