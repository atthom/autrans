spread2(schedule) = @chain schedule begin
    accumulate((a,b)-> !b ? 0 : a+b, _; dims=1)
    maximum(_, dims=1)
    maximum(_) - minimum(_)
    _^2
end

function fitness(result, s, verbose=false)
    schedule = reshape(result, (s.days*s.task_per_day, s.nb_workers))
    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
   
    balance = maximum(per_worker) - minimum(per_worker)
    job_size = fill(s.worker_per_work, length(per_job))
    balanced_work = (per_job .- job_size).^2
    balanced_work = sum(balanced_work)

    if verbose
        println("balanced_work=$balanced_work, balance=$balance, spread=$spread")
    end

    return 10*balanced_work + 5*balance + 2*spread2(schedule)
end


function Metaheuristics.optimize(s::SmallSchedule)
    gg = GA(;N = 1000, initializer = RandomPermutation(N=1000))
    opti_set = Metaheuristics.optimize(x -> fitness(x, s), Searchpath(s), gg)
    #@info opti_set
    #@info minimizer(opti_set)
    return minimizer(opti_set)
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

