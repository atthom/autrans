
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
function SearchpathPermutation(s::SmallSchedule) 
    number_of_slots = s.days*s.task_per_day*s.worker_per_work
    true_slots = fill(true, number_of_slots)
    false_slots = fill(false, s.days*s.task_per_day*s.nb_workers - number_of_slots)
    return PermutationSpace(vcat(true_slots, false_slots))
end

Base.reshape(result, s::SmallSchedule) = reshape(result, (s.days*s.task_per_day, s.nb_workers))


cardinality(s::SmallSchedule) = BigInt(2)^(s.days*s.task_per_day*s.nb_workers)




function cardinality2(s::SmallSchedule) 
    n = BigInt(s.days*s.task_per_day*s.nb_workers)
    k = BigInt(s.days*s.task_per_day*s.worker_per_work)
    @info n, k
    return factorial(n) / (factorial(k)*factorial(n - k))
end