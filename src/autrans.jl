module autrans

using ProgressBars
using Distributions: maximum
using Chain
using StatsBase
using Distributions
using PrettyTables

function fitness(schedule, verbose=false)
    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
   
    balance = maximum(per_worker) - minimum(per_worker)
    job_size = fill(2, length(per_job))
    balanced_work = (per_job .- job_size).^2
    balanced_work = 1000 * sum(balanced_work)

    spread = @chain schedule begin
        cumsum(_, dims=1)
        _[5:5:end, :]
        diff(_, dims=1)
        _ .- fill(1, size(_))
        _ .* _
        sum
    end

    if verbose
        println("$balanced_work, $(balance^2), $spread")
    end

    return -balanced_work -balance^2  -2*spread
end

rand_mutate(schedule, p_mutate) = schedule .⊻ rand(Bernoulli(p_mutate), size(schedule))

function rand_permute(schedule)
    nz_schedule = findall(!iszero, schedule)
    if length(nz_schedule) < 2
        return schedule
    end
    selected = sample(nz_schedule, 2)

    rev_col = @chain selected begin
        Tuple.(_)
        zip(_...)
        collect
        reverse(_[1]), _[2]
        zip(_...)
        collect
        CartesianIndex.(_)
    end
    p_schedule = copy(schedule)
    p_schedule[selected] .= false
    p_schedule[rev_col] .= true

    return p_schedule
end

function mutate(schedule, p_mutate)
    if rand() < 0.3
        return rand_mutate(schedule, p_mutate)
    else
        return rand_permute(schedule)
    end
end

populate(schedule, p_mutate, nb) = [mutate(schedule, p_mutate) for i in 1:nb]

min_max(v) = (v .- minimum(v)) / (maximum(v) - minimum(v))

selection(schedules, pop_min) = @chain schedules fitness.(_) min_max wsample(schedules, _, pop_min)

function generation(schedules, p_mutate, pop_min, pop_max)
    selected = selection(schedules, pop_min)

    return @chain selected begin
        sample(_, pop_max - pop_min, replace=true)
        mutate.(_, p_mutate)
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

function find_schedule(workers, days; pers_per_work=2, task_per_day=5, nb_generation = 5000, p_mutate = 0.01, pop_min = 500, pop_max = 1000)
    nb_workers = length(workers)
    schedule1 = fill(false, (days*task_per_day, nb_workers))
    schedules = [schedule1, schedule1 .+ true]
    
    iter = ProgressBar(1:nb_generation)
    for i in iter
        scores = fitness.(schedules)
        m, med = maximum(scores), median(scores)
        set_description(iter, "Maximum: $m, Median: $med")

        if m == med 
            println("max == median population, early stopping")
            break
        end
        schedules = generation(schedules, p_mutate, pop_min, pop_max)
    end

    return @chain schedules sort(_, by=fitness, rev=true) pprint(_[1], workers, days)
end

end

# [:thomas, :chronos, :curt, :astor, :manal, :thibs, :laura, :benj]

#res = exec2()

#pprint(res[2])
