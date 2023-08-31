
function fitness(result, s, verbose=false)
    schedule = reshape(result, s)
    per_worker = sum(schedule, dims=1)
    per_worker_balance = maximum(per_worker) - minimum(per_worker)

    work_spread = @chain schedule begin
        accumulate((a,b)-> !b ? 0 : a+b, _; dims=1)
        maximum(_, dims=1)
        maximum(_) - minimum(_)
        _^2
    end

    task_spread = @chain s.days begin
        [[1 + s.task_per_day*i, 3+ s.task_per_day*i, 5+ s.task_per_day*i] for i in 0:_-1]
        vcat(_...)
        filter(x -> x > s.cutoff_N_first, _)
        filter(x -> x < s.days*s.task_per_day - s.cutoff_N_last, _)
        schedule[_, :]
        sum(_, dims=1)
        maximum(_) - minimum(_)
        _^2
    end

    if verbose
        println("balance=$per_worker_balance, spread=$spread, task_spread=$spread")
    end

    return 4*per_worker_balance + 2*work_spread + task_spread
end

function Metaheuristics.optimize(s::SmallSchedule, searchspace)
    gg = GA(;N = 1000, mutation=SlightMutation()) 

    opti_set = Metaheuristics.optimize(x -> fitness(x, s), searchspace, gg)
    return minimizer(opti_set)
end


function get_neighbors(bestCandidate, subspace_size)
    neighbors = Vector{Vector{Int64}}()
    for t in 1:length(bestCandidate), j in 1:subspace_size
        if bestCandidate[t] != j
            current_n = copy(bestCandidate)
            current_n[t] = j
            push!(neighbors, current_n)
        end
    end
    return neighbors
end

function tabu_search(schedule; nb_gen = 100, maxTabuSize=200)
    schedule, searchspace = search_space(schedule)
    best = fill(1, nb_tasks(schedule))
    subspace_size = length(schedule.subspace)
    bestCandidate = best
    tabu_list = Vector{Vector{Int64}}()
    push!(tabu_list, best)
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(bestCandidate, subspace_size)
        println("gen $i, nei size: $(length(all_nei)), best fitness: $(fitness(bestCandidate, schedule))")
        for nei in all_nei
            current_fit = fitness(nei, schedule)
            if nei ∉ tabu_list && current_fit < best_fit
                bestCandidate = nei
                best_fit = current_fit
            end
        end
        if best_fit == 10000000 
            break
        elseif best_fit < fitness(best, schedule)
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

function find_schedule(days::Int, task_per_day::Int, worker_per_task::Int, workers::Vector{String}, N_first::Int, N_last::Int)
    t1 = Base.time() * 1000
    schedule = SmallSchedule(days, task_per_day, worker_per_task, workers, N_first, N_last)
    c = cardinality(schedule)
    
    if c == 0
        return DataFrame(Workers=[], Days=[])
    end

    schedule, searchspace = search_space(schedule)

    if c == 1
        result = sample(searchspace, 1)
    else
        result = optimize(schedule, searchspace)
    end
    
    score = fitness(result, schedule, true)
    t2 = Base.time() * 1000
    @info "Final Score: $score; Difficulty=$c Call Duration: $(round(Int, t2 - t1))ms"
    return make_df(schedule, result)
end

is_vaiselle(idx, s) = (idx+s.cutoff_N_first) % 5 in [1, 3, 0]

function agg_jobs(s::SmallSchedule, result)
    tasks_agg = DataFrame(Tache=["Tache $i" for i in 1:s.task_per_day])
    result = reshape(result, s)
    
    for id_worker in 1:s.nb_workers
        jobs = findall(x -> x==1, result[:, id_worker])
        jobs = (jobs .+ s.cutoff_N_first) .% s.task_per_day
        jobs = countmap(jobs)
        jobs = DefaultDict(0, jobs) 
        jobs[s.task_per_day] = jobs[0]
        tasks_agg[!, s.workers[id_worker]] = [jobs[i] for i in 1:s.task_per_day]
    end
    return tasks_agg
    #println(tasks_agg)
end


function agg_time(s::SmallSchedule, result)
    tasks_agg = DataFrame(Tache=["Jour $i" for i in 1:s.days])
    result = reshape(result, s)
    
    for id_worker in 1:s.nb_workers
        jobs = findall(x -> x==1, result[:, id_worker])
        jobs = (jobs .+ s.cutoff_N_first) .% s.task_per_day
        jobs = countmap(jobs)
        jobs = DefaultDict(0, jobs) 
        jobs[s.task_per_day] = jobs[0]
        tasks_agg[!, s.workers[id_worker]] = [jobs[i] for i in 1:s.task_per_day]
    end
    return tasks_agg
    #println(tasks_agg)
end

function make_df(s::SmallSchedule, result)
    schedule = reshape(result, s)
    works_per_day = ["Tache $i" for i in 1:s.task_per_day]
    tasks = DataFrame(Tache=works_per_day)

    p_schedule = [String[] for i in 1:s.task_per_day, j in 1:s.days]
    workers_per_task = @chain schedule begin
        findall(!iszero, _)
        Tuple.(_)
        map(x -> (s.workers[x[2]], x[1]), _)
    end

    for w in s.workers
        cc_vaiselle = 0
        cc_repas = 0 
        for (name, idx) in workers_per_task
            if name == w 
                if is_vaiselle(idx, s)
                    cc_vaiselle += 1
                else
                    cc_repas += 1
                end
            end
        end
        println("$w : Vaiselle: $cc_vaiselle, repas: $cc_repas")
    end
    
    for (w, idx) in workers_per_task
        push!(p_schedule[idx + s.cutoff_N_first], w)
    end

    println(p_schedule)

    return @chain p_schedule begin
        map(li -> join(li, ", "), _)
        DataFrame(_, :auto)
        rename(_, ["Jour $i" for i in 1:s.days])
        hcat(tasks, _)
    end

end

