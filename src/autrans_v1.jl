
using ProgressBars
using Distributions: maximum
using Chain
using StatsBase
using Distributions
using PrettyTables


function fitness(schedule, days, task_per_day, pers_per_work, verbose=false)::Float64
    nb_jobs, nb_workers = size(schedule)

    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
   
    balance = (maximum(per_worker) - minimum(per_worker))*nb_workers

    balanced_work = 100*sum((per_job .- pers_per_work) .^2)

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

rand_mutate(schedule, p_mutate) = schedule .⊻ rand(Bernoulli(p_mutate), size(schedule))

function permute(schedule)
    new_schedule = copy(schedule)
    l, w = size(new_schedule)
    xx = rand(1:l, 2)
    yy = rand(1:w)
    x1 = CartesianIndex(xx[1], yy)
    x2 = CartesianIndex(xx[2], yy)

    tmp = new_schedule[x1]
    new_schedule[x1] = new_schedule[x2]
    new_schedule[x2] = new_schedule[x1]
    return new_schedule
end

function fitness2(schedules, days, task_per_day, pers_per_work, verbose=false)
    nb_schedules = length(schedules)
    nb_workers = size(schedules[end])[2]
    
    all_schedules = reshape(vcat(schedules...), (nb_schedules, days, task_per_day, nb_workers))

    schedule_sumday = sum(all_schedules, dims=2)
    
    per_worker = reshape(sum(schedule_sumday, dims=3), (nb_schedules, nb_workers))
    per_job = reshape(sum(all_schedules, dims=4), (nb_schedules, days*task_per_day))
    
    balance = (maximum(per_worker, dims=2) - minimum(per_worker, dims=2))*nb_workers
    job_size = fill(pers_per_work, (nb_schedules, days*task_per_day))

    balanced_work = (per_job .- job_size).^2
    balanced_work = 500 * sum(balanced_work, dims=2)

    if verbose
        println("$balanced_work, $balance")
    end
    return -balanced_work[:, 1] - balance[:, 1]
end

min_max(v) = (v .- minimum(v)) / (maximum(v) - minimum(v))

standard(v) = (v .- minimum(v)) / std(v)

selection(schedules, fitness_score, pop_min) = @chain fitness_score standard wsample(schedules, _, pop_min)


selectionXX(schedules, fitness_score, pop_min) = @chain fitness_score begin
    partialsortperm(_, 1:pop_min, rev=true) 
    schedules[_]
end


function generation(schedules, days, task_per_day, pers_per_work, pop_min, pop_max)
    schedules = unique(schedules)
    fitness_score::Vector{Float64} = fitness.(schedules, days, task_per_day, pers_per_work)

    if length(schedules) > pop_min
        selected = selectionXX(schedules, fitness_score, pop_min)
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

function first_generation(days, task_per_day, nb_workers, pers_per_work, pop_max)
    schedule1 = fill(false, (days*task_per_day, nb_workers))
    schedule1[1:pers_per_work, :] .= true
    return [permute(schedule1) for i in 1:pop_max]
end

function find_schedule(workers, days; pers_per_work=2, task_per_day=5, nb_generation = 5000, p_mutate = 0.01, pop_min = 500, pop_max = 1000)
    nb_workers = length(workers)
    schedules = first_generation(days, task_per_day, nb_workers, pers_per_work, pop_max)
    scores = fitness.(schedules, days, task_per_day, pers_per_work)

    
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
        scores, schedules = generation(schedules, days, task_per_day, pers_per_work, pop_min, pop_max)
    end

    return @chain schedules sort(_, by= x -> fitness(x, days, task_per_day, pers_per_work), rev=true) _[1] # pprint(_[1], workers, days)
end


# [:thomas, :chronos, :curt, :astor, :manal, :thibs, :laura, :benj]

#res = exec2()

#pprint(res[2])
