module autrans


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

# 0,0 => 0
# 1, 0 => 1
# 0, 1 => 1
# 1, 1 => 0
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

selection(schedules) = @chain schedules begin
    fitness.(_)
    min_max
    Bernoulli.(_)
    rand.(_)
    zip(_, schedules)
    collect
    filter(x -> x[1], _)
    map(x -> x[2], _)
end

function generation(schedules, p_mutate, pop_max)
   selected = selection(schedules)
   ll = length(selected)
   while length(selected) < pop_max
       one = selected[rand(1:ll)]
       new_gen = populate(one, p_mutate, 20)
       selected = vcat(selected, new_gen)
   end
   return selected
end


function exec2()
   nb_days = 7
   nb_task_per_day = 5
   nb_pers_per_work = 2 
   nb_workers = 8
   schedule1 = fill(false, (nb_days*nb_task_per_day, nb_workers))
   schedule2 = fill(true, (nb_days*nb_task_per_day, nb_workers))
   schedules = [schedule1, schedule2]
   
   nb_generation = 5000
   p_mutate = 0.01
   pop_max = 1000
   
   for i in 1:nb_generation
       scores = fitness.(schedules)
       m, med = maximum(scores), median(scores)
       println("gen: $i, max: $m, median: $med")
       if m == med 
        println("max: == median")
        break
       end
       schedules = generation(schedules, p_mutate, pop_max)
   end
   
   return @chain schedules begin
        fitness.(_)
        zip(_, schedules)
        collect
        sort(_, by= x-> x[1], rev=true)
        _[1]
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
 

function pprint(schedule)
    workers = [:thomas, :chronos, :curt, :astor, :manal, :thibs, :laura, :benj]
    nb_days = 7
    nb_task_per_day = 5
    
    works_per_day = @chain instances(TypeTime) begin
      (_, instances(TypeTask))
      Iterators.product(_...)
      Iterators.map(x -> join(reverse(x), " "), _)
      collect
      _[2:end]
    end

    ll = length(works_per_day)
    p_schedule = [Symbol[] for i in 1:ll, j in 1:nb_days]

    workers_per_task = @chain schedule begin
        findall(!iszero, _)
        Tuple.(_)
        map(x -> (workers[x[2]], x[1]), _)
    end
    
    for (w, idx) in workers_per_task
        push!(p_schedule[idx], w)
    end

    header = ["Jour $i" for i in 1:nb_days]
    pretty_table(p_schedule, header, row_names=works_per_day)

end


res = exec2()

pprint(res[2])