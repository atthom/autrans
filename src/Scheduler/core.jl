

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

using Chain



mse(arr) = @chain arr begin
    extrema(_, dims=2)
    map(x -> x[2] - x[1], _)
    _ .^ 2
    sum
end

function fitness(scheduler, schedule, verbose=false)
    per_worker = sum(schedule, dims=1)
    per_worker_balance = maximum(per_worker) - minimum(per_worker)
    nb_worker = length(scheduler.workers)

    agg_all_tasks = zeros(Int, (length(scheduler.all_task_indices), nb_worker))

    for (id_t, (t, indices)) in enumerate(scheduler.all_task_indices)
        agg_all_tasks[id_t, :] = sum(schedule[indices, :], dims=1)
    end

    agg_type_loss = mse(agg_all_tasks)
    
    agg_all_days = zeros(Int, (scheduler.days, nb_worker))
    for (i, d) in enumerate(day_indices(scheduler))
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)
    end
    
    agg_time_loss = mse(agg_all_days)
    #agg_time_loss = extrema(agg_all_days)
    

    if verbose
        print("balance=$per_worker_balance, agg_type_loss=$agg_type_loss,")
        print("agg_type_loss2=$agg_type_loss2, agg_time_loss=$agg_time_loss")
        println("")
    end

    #return per_worker_balance +agg_type_loss + agg_type_loss2 + agg_time_loss + agg_time_loss2
    return per_worker_balance + agg_type_loss + agg_time_loss
end

using Combinatorics
using DataFrames
using StatsBase
using DataStructures
function agg_jobs(s::Scheduler, schedule)
    tasks_agg = DataFrame(Tasks=[t.name for t in s.task_per_day])
    nb_jobs = length(s.task_per_day)
    nb_workers = length(s.workers)
    for id_worker in 1:nb_workers
        jobs = findall(x -> x==1, schedule[:, id_worker])
        jobs = (jobs .+ s.cutoff_N_first) .% nb_jobs
        jobs = countmap(jobs)
        jobs = DefaultDict(0, jobs) 
        jobs[nb_jobs] = jobs[0]
        tasks_agg[!, s.workers[id_worker].name] = [jobs[i] for i in 1:nb_jobs]
    end
    return tasks_agg
    #println(tasks_agg)
end

function agg_type(s::Scheduler, schedule)
    df_jobs = agg_jobs(s, schedule)
    grp_df =  groupby(df_jobs, :Tasks)
    workers = [w.name for w in s.workers] 
    new_df = combine(grp_df, workers .=> sum)

    col_names = vcat(["Tasks"], [w.name for w in s.workers])
    return rename(new_df, col_names)
end


function agg_time(s::Scheduler, schedule)
    nb_jobs = length(s.task_per_day)
    offset = s.cutoff_N_first
    all_days = []

    for day in 1:nb_jobs:s.total_tasks
        if day == 1
            day_idx = 1:nb_jobs-offset
        else
            day_idx = day-offset:day+nb_jobs-offset-1
        end
        push!(all_days, sum(schedule[day_idx, :], dims=1))
    end

    df = DataFrame(vcat(all_days...), [w.name for w in scheduler.workers])
    days = DataFrame(Days=["Jour $i" for i in 1:s.days])
    return hcat(days, df)
end


function tabu_search(scheduler; nb_gen = 50, maxTabuSize=100)
    best = seed(scheduler)
    bestCandidate = best
    tabu_list = Vector{Matrix{Bool}}()
    push!(tabu_list, best)
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(bestCandidate)
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