
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


#Searchpath(s::SmallSchedule) = BitArraySpace(s.days*s.task_per_day*s.nb_workers)
Searchpath(s::SmallSchedule) = MixedSpace(s)


function SearchpathPermutation(s::SmallSchedule) 
    number_of_slots = s.days*s.task_per_day*s.worker_per_work
    true_slots = fill(true, number_of_slots)
    false_slots = fill(false, s.days*s.task_per_day*s.nb_workers - number_of_slots)
    return PermutationSpace(vcat(true_slots, false_slots))
end

#Base.reshape(result, s::SmallSchedule) = reshape(result, (s.days*s.task_per_day, s.nb_workers))
Base.reshape(result, s::SmallSchedule) = reshape(vcat(result...), (s.days*s.task_per_day, s.nb_workers))


cardinality(s::SmallSchedule) = BigInt(2)^(s.days*s.task_per_day*s.nb_workers)


function cardinality2(s::SmallSchedule) 
    n = BigInt(s.days*s.task_per_day*s.nb_workers)
    k = BigInt(s.days*s.task_per_day*s.worker_per_work)
    @info n, k
    return card(n, k)
end


card(n, k) = factorial(n) / (factorial(k)*factorial(n - k))

using Combinatorics


function SearchPathMultiSetPermutation(s::SmallSchedule)
    slots = fill(false, s.nb_workers)
    slots[1:s.worker_per_work] .= 1

    subspace = multiset_permutations(slots, s.nb_workers) |> collect
    length(subspace)
    return PermutationSpace(1:length(subspace), s.days*s.task_per_day)
end


function MixedSpace(s::SmallSchedule)
    slots = fill(false, s.nb_workers)
    slots[1:s.worker_per_work] .= 1

    all_spaces = Dict(Symbol(i) => PermutationSpace(slots) for i in 1:s.days*s.task_per_day)
    return MixedSpace(all_spaces...)
end


function find_exact(s::SmallSchedule)
    slots = fill(false, s.nb_workers)
    slots[1:s.worker_per_work] .= 1

    subspace = multiset_permutations(slots, s.nb_workers) |> collect


    


    best, best_score = [], 10e10 
    for current_res in with_replacement_combinations(subspace, s.days*s.task_per_day)
        current_res = vcat(current_res...)
        current_score = fitness(current_res, s)
        if current_score < best_score
            best = current_res
            best_score = current_score
        end
    end

    @info best, score

end