

spread(schedule, task_per_day) = @chain schedule begin
    cumsum(_, dims=1)
    _[task_per_day:task_per_day:end, :]
    diff(_, dims=1)
    _ .- fill(1, size(_))
    _ .* _
    sum
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

    return 10*balanced_work + 5*balance + 2*spread(schedule, s.task_per_day)
end


function Metaheuristics.optimize(s::SmallSchedule)
    gg = GA(;N = 1000, initializer = RandomPermutation(N=100))
    opti_set = Metaheuristics.optimize(x -> fitness(x, s), Searchpath(s), gg)
    #@info opti_set
    #@info minimizer(opti_set)
    return minimizer(opti_set)
end

function test()
    nb_days = 7
    nb_task_per_day = 5
    nb_pers_per_work = 1
    #workers = ["thomas", "chronos", "curt", "astor", "manal", "thibs", "laura", "benj"]
    workers = ["Cookie", "Fish", "Chronos"]
    schedule = SmallSchedule(nb_days, nb_task_per_day, nb_pers_per_work, workers)
    @info schedule
    result = optimize(x -> fitness(x, schedule), schedule)
    println(fitness(result, schedule, true))
    pprint(schedule, result)
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


function pprint(s::SmallSchedule, result)
    schedule = reshape(result, s)
    
    works_per_day = @chain instances(TypeTime) begin
      (_, instances(TypeTask))
      Iterators.product(_...)
      Iterators.map(x -> join(reverse(x), " "), _)
      collect
      _[2:end]
    end

    ll = length(works_per_day)
    p_schedule = [String[] for i in 1:ll, j in 1:s.days]

    workers_per_task = @chain schedule begin
        findall(!iszero, _)
        Tuple.(_)
        map(x -> (s.workers[x[2]], x[1]), _)
    end
    
    for (w, idx) in workers_per_task
        push!(p_schedule[idx], w)
    end

    p_schedule = map(li -> join(li, ", "), p_schedule)
    header = ["Jour $i" for i in 1:s.days]

    pretty_table(p_schedule; header=header, row_labels=works_per_day)
    # return pretty_table(String, p_schedule; backend = Val(:html), header=header, row_names=works_per_day)
end
