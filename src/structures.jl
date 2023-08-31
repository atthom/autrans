
struct SmallSchedule
    days::Int
    task_per_day::Int
    worker_per_work::Int
    workers::Vector{String}
    nb_workers::Int
    subspace::Vector{Vector{Bool}}
    cutoff_N_first::Int
    cutoff_N_last::Int
end




SmallSchedule(days::Int, task_per_day::Int, worker_per_work::Int, workers::Vector{String}) = SmallSchedule(days, task_per_day, worker_per_work, workers, length(workers), [], 0, 0)
SmallSchedule(days::Int, task_per_day::Int, worker_per_work::Int, workers::Vector{String}, N_first::Int, N_last::Int) = SmallSchedule(days, task_per_day, worker_per_work, workers, length(workers), [], N_first, N_last)

Base.reshape(result, s::SmallSchedule) = hcat(s.subspace[result]...)'

setSubSpace(s::SmallSchedule, subspace::Vector{Vector{Bool}}) = SmallSchedule(s.days, s.task_per_day, s.worker_per_work, s.workers, length(s.workers), subspace, s.cutoff_N_first, s.cutoff_N_last)

nb_tasks(s::SmallSchedule) = s.days*s.task_per_day - s.cutoff_N_first - s.cutoff_N_last

function search_space(s::SmallSchedule)
    slots = fill(false, s.nb_workers)
    slots[1:s.worker_per_work] .= 1

    subspace = multiset_permutations(slots, s.nb_workers) |> collect
    s = setSubSpace(s, subspace)
    problem_size = ones(Int, nb_tasks(s))

    return s, boxconstraints(problem_size,  length(subspace) .* problem_size)
end

function cardinality(s::SmallSchedule) 
    if s.nb_workers == s.worker_per_work
        return 1
    elseif s.nb_workers < s.worker_per_work
        return 0
    end

    ntasks = nb_tasks(s)
    if ntasks < 1
        return 0
    end
    return BigInt(ntasks)^binomial(s.nb_workers, s.worker_per_work)
end