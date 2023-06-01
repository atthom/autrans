

function fitness(result, s, verbose=false)
    schedule = reshape(result, (s.days*s.task_per_day, s.nb_workers))
    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
   
    balance = maximum(per_worker) - minimum(per_worker)
    job_size = fill(2, length(per_job))
    balanced_work = (per_job .- job_size).^2
    balanced_work = sum(balanced_work)

    spread = @chain schedule begin
        cumsum(_, dims=1)
        _[5:5:end, :]
        diff(_, dims=1)
        _ .- fill(1, size(_))
        _ .* _
        sum
    end

    if verbose
        println("balanced_work=$balanced_work, balance=$balance, spread=$spread")
    end

    return 10*balanced_work + 5*balance + 2*spread
end


@enum TypeTask begin
    cuisine
    vaiselle
 end
 
@enum TypeTime begin
    matin
    midi
    soir
end

struct SmallSchedule
    days::Int
    task_per_day::Int
    worker_per_work::Int
    workers::Vector{String}
    nb_workers::Int
end

struct SmallTask
    worker_per_task::Int
    per_day::Int
end

struct SmallWorker
    name::String
    preference_task::Vector{SmallTask}
    preference_worker::Vector{SmallWorker}
end


SmallSchedule(days::Int, task_per_day::Int, worker_per_work::Int, workers::Vector{String}) = SmallSchedule(days, task_per_day, worker_per_work, workers, length(workers))


Searchpath(s::SmallSchedule) = BitArraySpace(s.days*s.task_per_day*s.nb_workers)
Base.reshape(result, s::SmallSchedule) = reshape(result, (s.days*s.task_per_day, s.nb_workers))

function Metaheuristics.optimize(f::Function, s::SmallSchedule)
    gg = GA(;N = 1000, initializer = RandomPermutation(N=1000))
    opti_set =optimize(f, Searchpath(s), gg)
    print(opti_set)
    return minimizer(opti_set)
end

@get "/schedule" function(req)

    schedule = json(req, SmallSchedule)
    result = optimize(x -> fitness(x, schedule), schedule)
    println(fitness(result, schedule, true))
    pprint(schedule, result)
    return a * b
end



function run()
    nb_days = 7
    nb_task_per_day = 5
    nb_pers_per_work = 2 
    nb_workers = 8
    workers = ["thomas", "chronos", "curt", "astor", "manal", "thibs", "laura", "benj"]
    schedule = SmallSchedule(nb_days, nb_task_per_day, nb_pers_per_work, workers)
    result = optimize(x -> fitness(x, schedule), schedule)
    println(fitness(result, schedule, true))
    pprint(schedule, result)
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
    pretty_table(p_schedule; header=header, row_names=works_per_day)
end

#schedule1 = fill(false, (nb_days*nb_task_per_day, nb_workers))


#perm = BitArraySpace(nb_days*nb_task_per_day*nb_workers)

#gg = GA(;N = 1000, initializer = RandomPermutation(N=500))

#opti_set = optimize(fitness, perm, gg)

#result = minimizer(opti_set)

#pprint(result, nb_days, nb_task_per_day, nb_workers)