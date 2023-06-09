
struct SmallSchedule
    days::Int
    task_per_day::Int
    worker_per_work::Int
    workers::Vector{String}
    nb_workers::Int
    subspace::Vector{Vector{Bool}}
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


SmallSchedule(days::Int, task_per_day::Int, worker_per_work::Int, workers::Vector{String}) = SmallSchedule(days, task_per_day, worker_per_work, workers, length(workers), [])
#Searchpath(s::SmallSchedule) = BitArraySpace(s.days*s.task_per_day*s.nb_workers)

setSubSpace(s, subspace::Vector{Vector{Bool}}) = SmallSchedule(s.days, s.task_per_day, s.worker_per_work, s.workers, length(s.workers), subspace)

total_task(s::SmallSchedule) = s.task_per_day*s.days

function SearchpathPermutation(s::SmallSchedule) 
    number_of_slots = s.days*s.task_per_day*s.worker_per_work
    true_slots = fill(true, number_of_slots)
    false_slots = fill(false, s.days*s.task_per_day*s.nb_workers - number_of_slots)
    return PermutationSpace(vcat(true_slots, false_slots))
end

function SearchPathBoxConstraint(s::SmallSchedule)
    slots = fill(false, s.nb_workers)
    slots[1:s.worker_per_work] .= 1

    subspace = multiset_permutations(slots, s.nb_workers) |> collect
    s = setSubSpace(s, subspace)
    problem_size = ones(Int, total_task(s))

    return s, boxconstraints(problem_size,  length(subspace) .* problem_size)
end

#Base.reshape(result, s::SmallSchedule) = reshape(hcat(s.subspace[result]...), (s.days*s.task_per_day, s.nb_workers))
Base.reshape(result, s::SmallSchedule) = hcat(s.subspace[result]...)'

function cardinality(s::SmallSchedule) 
    if s.nb_workers == s.worker_per_work
        return 1
    end
    if s.nb_workers < s.worker_per_work
        return 0
    end
    subspace = binomial(s.nb_workers, s.worker_per_work)
    return BigInt(s.days)^subspace
end


function SearchPathMultiSetPermutation(s::SmallSchedule)
    slots = fill(false, s.nb_workers)
    slots[1:s.worker_per_work] .= 1

    subspace = multiset_permutations(slots, s.nb_workers) |> collect
    return PermutationSpace(1:length(subspace), s.days*s.task_per_day)
end