
function fitness(result, s, verbose=false)
    schedule = reshape(result, s)
    per_worker = sum(schedule, dims=1)
    per_worker_balance = maximum(per_worker) - minimum(per_worker)
    #per_job = sum(schedule, dims=2)
    #job_size = fill(s.worker_per_work, length(per_job))
    #balanced_work = (per_job .- job_size).^2
    #balanced_work = sum(balanced_work)

    spread = @chain schedule begin
        accumulate((a,b)-> !b ? 0 : a+b, _; dims=1)
        maximum(_, dims=1)
        maximum(_) - minimum(_)
        _^2
    end

    if verbose
        #println("balanced_work=$balanced_work, balance=$per_worker_balance, spread=$spread")
        println("balance=$per_worker_balance, spread=$spread")
    end

    #return 10*balanced_work + 5*per_worker_balance + 2*spread2(schedule)
    return 5*per_worker_balance + 2*spread
end

function Metaheuristics.optimize(s::SmallSchedule, searchspace)
    #gg = GA(;N = 100, mutation=SlightMutation())
    gg = GA(;N = 100, mutation=SlightMutation()) #, initializer = RandomInBounds(N=100), p_mutation =0, mutation=SlightMutation())

    opti_set = Metaheuristics.optimize(x -> fitness(x, s), searchspace, gg)
    return minimizer(opti_set)
end

function find_schedule(days, task_per_day, worker_per_task, workers)
    t1 = Base.time() * 1000
    schedule = SmallSchedule(days, task_per_day, worker_per_task, workers)
    c = cardinality(schedule)
    
    if c == 0
        return DataFrames(Workers=workers, Days=[])
    end

    schedule, searchspace = SearchPathBoxConstraint(schedule)

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
    
    for (w, idx) in workers_per_task
        push!(p_schedule[idx], w)
    end

    return @chain p_schedule begin
        map(li -> join(li, ", "), _)
        DataFrame(_, :auto)
        rename(_, ["Jour $i" for i in 1:s.days])
        hcat(tasks, _)
    end
end

