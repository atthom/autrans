

function get_neighbors(schedule)
    neighbors = Vector{Matrix{Bool}}()
    nb_task, nb_workers = size(sseed) 
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
function fitness(scheduler, schedule, verbose=false)
    per_worker = sum(schedule, dims=1)
    per_worker_balance = maximum(per_worker) - minimum(per_worker)

    work_spread = @chain schedule begin
        accumulate((a,b)-> !b ? 0 : a+b, _; dims=1)
        maximum(_, dims=1)
        maximum(_) - minimum(_)
        _^2
    end

    
    if verbose
        println("balance=$per_worker_balance, spread=$work_spread")
    end

    return 4*per_worker_balance + 2*work_spread
end

using DataFrames
using StatsBase
using DataStructures
function agg_jobs(s::Scheduler, schedule)
    tasks_agg = DataFrame(Tache=[t.name for t in s.task_per_day])
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

function tabu_search(scheduler; nb_gen = 200, maxTabuSize=100)
    best = seed(scheduler)
    bestCandidate = best
    tabu_list = Vector{Matrix{Bool}}()
    push!(tabu_list, best)
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(bestCandidate)
        println("gen $i, nei size: $(length(all_nei)), best fitness: $(fitness(scheduler, bestCandidate))")
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