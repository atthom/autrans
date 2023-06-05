using ProgressBars
using Distributions: maximum
using Chain
using StatsBase
using Distributions
using PrettyTables


struct AutransTask
    name::String
    info::String
    nb_workers::Int
end


function fitness(schedule, days, task_per_day, work_load, verbose=false)::Float64
    nb_jobs, nb_workers = size(schedule)

    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
    pers_per_work = [w.nb_workers for w in work_load]
    
    balance = (maximum(per_worker) - minimum(per_worker))*nb_workers
    balanced_work = 100*sum((per_job - pers_per_work) .^2)
    
    spread = @chain schedule begin
        reshape(_, (days, task_per_day, nb_workers))
        sum(_, dims=1)
        reshape(_, (task_per_day, nb_workers))
        maximum(_, dims=1) - minimum(_, dims=1) .+ 1
        prod
    end

    if verbose
        println("$balanced_work, $balance, $spread")
    end

    return -balanced_work -balance^2 -spread
end

function permute(schedule)
    new_schedule = copy(schedule)
    l, w = size(new_schedule)
    xx = rand(1:l)
    yy = rand(1:w, 2)
    x1 = CartesianIndex(xx, yy[1])
    x2 = CartesianIndex(xx, yy[2])

    tmp = new_schedule[x1]
    new_schedule[x1] = new_schedule[x2]
    new_schedule[x2] = tmp
    return new_schedule
end

min_max(v) = (v .- minimum(v)) / (maximum(v) - minimum(v))

standard(v) = (v .- minimum(v)) / std(v)


selection(schedules, fitness_score, pop_min) = @chain fitness_score begin
    partialsortperm(_, 1:pop_min, rev=true) 
    schedules[_]
end


function generation(schedules, days, task_per_day, pers_per_work, pop_min, pop_max)
    schedules = unique(schedules)
    fitness_score::Vector{Float64} = fitness.(schedules, days, task_per_day, pers_per_work)

    if length(schedules) > pop_min
        selected = selection(schedules, fitness_score, pop_min)
    else
        selected = schedules
    end

    return fitness_score, @chain selected begin
        sample(_, pop_max - pop_min, replace=true)
        permute.(_)
        vcat(selected, _)
    end
end



function pprint(schedule, workers, days)
    works_per_day = @chain instances(TypeTime) begin
      (_, instances(TypeTask))
      Iterators.product(_...)
      Iterators.map(x -> join(reverse(x), " "), _)
      collect
      _[2:end]
    end

    p_schedule = [Symbol[] for i in 1:length(works_per_day), j in 1:days]

    workers_per_task = @chain schedule begin
        findall(!iszero, _)
        Tuple.(_)
        map(x -> (workers[x[2]], x[1]), _)
    end
    
    for (w, idx) in workers_per_task
        push!(p_schedule[idx], w)
    end

    p_schedule = [join(li, ", ", " et ") for li in p_schedule]

    header = ["Jour $i" for i in 1:days]
    pretty_table(p_schedule, header, row_names=works_per_day)
end

function first_generation(workers, work_load, pop_max)
    schedule1 = fill(false, (length(work_load), length(workers)))

    for (i, work) in enumerate(work_load)
        schedule1[i, 1:work.nb_workers] .= true
    end
    return [permute(schedule1) for i in 1:pop_max]
end

function find_schedule(workers, daily_workload, nb_days; nb_generation = 5000, pop_min = 1000, pop_max = 5000)
    work_load = repeat(daily_workload, nb_days)
    task_per_day = length(daily_workload)
    schedules = first_generation(workers, work_load, pop_max)
    scores = fitness.(schedules, nb_days, task_per_day, (work_load,), true)
    println(length(unique(schedules)), unique(scores))
    iter = ProgressBar(1:nb_generation)
    for i in iter
        m, q1, q2, q3, minn = maximum(scores), quantile(scores, 0.25), quantile(scores, 0.50), quantile(scores, 0.75),  minimum(scores)
        set_description(iter, "Maximum: $m, q1: $q1, q2: $q2, q3: $q3, minn: $minn")
        #if mod(i, 1) == 0
        #    println("$i, $(length(scores)), $m, $med")
        #end
        if m == q2 
            println("max == median population, early stopping")
            break
        end
        scores, schedules = generation(schedules, nb_days, task_per_day, pers_per_work, pop_min, pop_max)
    end

    return @chain schedules sort(_, by= x -> fitness(x, nb_days, task_per_day, work_load), rev=true) _[1] # pprint(_[1], workers, nb_days)
end

if false
    Cuisine(description) = AutransTask("Cuisine", description, 2)
    Vaiselle(description) = AutransTask("Vaiselle", description, 2)
    workers = [:thomas, :chronos, :curt, :astor, :manal, :thibs, :laura, :benj]
    daily_workload = [Vaiselle("matin"), Cuisine("midi"), Vaiselle("midi"), Cuisine("soir"), Vaiselle("soir")]
end
#res = exec2()

#pprint(res[2])
