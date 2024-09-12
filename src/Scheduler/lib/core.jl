using DataFrames
using StatsBase
using DataStructures
using Chain
using Combinatorics


function get_neighbors(schedule)
    neighbors = Vector{Matrix{Bool}}()
    nb_task, nb_workers = size(schedule) 
    for t in 1:nb_task
        all_perm = multiset_permutations(schedule[t, :], nb_workers)
        for perm in all_perm
            if schedule[t, :] != perm
                nei = copy(schedule)
                nei[t, :] .= perm
                push!(neighbors, nei)
            end
        end
    end
    return neighbors
end


function fitness(scheduler, schedule, verbose=false)
    per_worker = sum(schedule, dims=1)
    per_worker_balance = maximum(per_worker) - minimum(per_worker)
    nb_worker = length(scheduler.workers)

    tasks = unique(scheduler.task_per_day)
    agg_all_tasks = zeros(Int, (length(tasks), nb_worker))
    for (id_t, t) in enumerate(tasks)
        for i in task_indices(scheduler, t)
            agg_all_tasks[id_t, :] += schedule[i, :]
        end
    end

    agg_type_loss = maximum(agg_all_tasks, dims=2) - minimum(agg_all_tasks, dims=2)
    agg_type_loss = agg_type_loss .^ 2
    agg_type_loss = sum(agg_type_loss)

    agg_type_loss2 = maximum(agg_all_tasks) - minimum(agg_all_tasks)
    agg_type_loss2 = agg_type_loss2 ^ 2
    
    agg_all_days = zeros(Int, (scheduler.days, nb_worker))
    for (i, d) in enumerate(day_indices(scheduler))
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)
    end
    
    agg_time_loss = maximum(agg_all_days, dims=2) - minimum(agg_all_days, dims=2)
    agg_time_loss = agg_time_loss .^ 2
    agg_time_loss = sum(agg_time_loss)

    agg_time_loss2 = maximum(agg_all_days) - minimum(agg_all_days)
    agg_time_loss2 = agg_time_loss2 ^ 2
    
    if verbose
        print("balance=$per_worker_balance, agg_type_loss=$agg_type_loss,")
        print("agg_type_loss2=$agg_type_loss2, agg_time_loss=$agg_time_loss")
        println("")
    end

    return per_worker_balance + agg_type_loss + agg_type_loss2 + agg_time_loss + agg_time_loss2
end


function tabu_search(s::Scheduler; nb_gen = 100, maxTabuSize=100)
    best = seed(s)
    bestCandidate = best
    tabu_list = Vector{Matrix{Bool}}()
    push!(tabu_list, best)
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(bestCandidate)
        println("gen $i, tabu_size: $(length(tabu_list)) best fitness: $(fitness(s, bestCandidate))")
        for nei in all_nei
            current_fit = fitness(s, nei)
            if nei ∉ tabu_list && current_fit < best_fit
                bestCandidate = nei
                best_fit = current_fit
            end
        end
        if best_fit == 10000000 
            break
        elseif best_fit < fitness(s, best)
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