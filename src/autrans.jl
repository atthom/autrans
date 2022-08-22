module autrans

using ProgressBars
using Distributions: maximum
using Chain
using StatsBase
using Distributions
using PrettyTables

function fitness(schedule, pers_per_work, verbose=false)
    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
   
    #balance = maximum(per_worker) - minimum(per_worker)
    job_size = fill(pers_per_work, length(per_job))
    balanced_work = (per_job .- job_size).^2
    balanced_work = 500 * sum(balanced_work)

    spread = @chain schedule begin
        cumsum(_, dims=1)
        _[5:5:end, :]
        diff(_, dims=1)
        _ .- fill(1, size(_))
        _ .* _
        sum
    end

    if verbose
        println("$balanced_work, $spread")
    end

    return -balanced_work -2*spread
end

rand_mutate(schedule, p_mutate) = schedule .⊻ rand(Bernoulli(p_mutate), size(schedule))


function permute(schedule)
    new_schedule = copy(schedule)
    l, w = size(new_schedule)
    xx = rand(1:l, 2)
    yy = rand(1:w, 2)
    x1 = CartesianIndex(xx[1], yy[1])
    x2 = CartesianIndex(xx[2], yy[2])

    tmp = new_schedule[x1]
    new_schedule[x1] = new_schedule[x2]
    new_schedule[x2] = new_schedule[x1]
    return new_schedule
end

min_max(v) = (v .- minimum(v)) / (maximum(v) - minimum(v))

standard(v) = (v .- minimum(v)) / std(v)

selection(schedules, pers_per_work, pop_min) = @chain schedules fitness.(_, pers_per_work) standard wsample(schedules, _, pop_min)

function generation(schedules, pers_per_work, pop_min, pop_max)
    selected = selection(schedules, pers_per_work, pop_min)

    return @chain selected begin
        sample(_, pop_max - pop_min, replace=true)
        permute.(_)
        vcat(selected, _)
    end
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
    
    iter = ProgressBar(1:nb_generation)
    for i in iter
        scores = fitness.(schedules)
        m, med = maximum(scores), median(scores)
        set_description(iter, "Maximum: $m, Median: $med")

        if m == med 
            println("max == median population, early stopping")
            break
        end
        schedules = generation(schedules, pers_per_work, pop_min, pop_max)
    end

    return @chain schedules sort(_, by=fitness, rev=true) pprint(_[1], workers, days)
end

end

# [:thomas, :chronos, :curt, :astor, :manal, :thibs, :laura, :benj]

#res = exec2()

#pprint(res[2])
