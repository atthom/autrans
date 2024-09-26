
struct SWorker
    name::String
    days_off::Vector{Int}
end
SWorker(tp::Tuple{String, Vector{Int64}}) = SWorker(tp[1], tp[2])


struct STask
    name::String
    worker_slots::Int
    difficulty::Int
end

STask(tp::Tuple{String, Int, Int}) = STask(tp[1], tp[2], tp[3])
STask(tp::Tuple{String, Int}) = STask(tp[1], tp[2], 1)
STask(a::String, b::Int) = STask(a, b, 1)

struct Scheduler
    workers::Vector{SWorker}
    task_per_day::Vector{STask}
    days::Int
    total_tasks::Int
    cutoff_N_first::Int
    cutoff_N_last::Int
    all_task_indices_per_day::Vector{Tuple{STask, Vector{Int}}}
    task_type_indices::Vector{Vector{Int}}
    daily_indices::Vector{Vector{Int}}
    balance_daysoff::Bool
end

function Scheduler(payload::Dict)
    workers = SWorker.(payload["workers"])
    tasks = STask.(payload["tasks"])

    balance_daysoff = payload["balance_daysoff"]

    N_first, N_last, days = payload["cutoff_N_first"], payload["cutoff_N_last"], payload["days"]
    task_per_day = [tasks[i] for i in payload["task_per_day"] .+ 1]
    total_task = length(task_per_day)*days - N_first - N_last

    all_task_indices_per_day = task_indices(task_per_day, days, N_first, N_last)

    unique_tasks = unique(task_per_day)
    task_type = [[idx for (idx, (t2, task_indices)) in 
                enumerate(zip(task_per_day, all_task_indices_per_day)) 
                if t1 == t2 && length(task_indices[2]) > 0] 
                for t1 in unique_tasks]

    daily = daily_indices(task_per_day, days, N_first, N_last)
    
    return Scheduler(workers, task_per_day, days, total_task, N_first, N_last, all_task_indices_per_day, task_type, daily, balance_daysoff)
end


function check_satisfability(scheduler::Scheduler; cutoff_workers=30, cutoff_tasks=20, cutoff_days=40)
    if length(scheduler.workers) > cutoff_workers
        return false, "Too many workers ($cutoff_workersm max)"
    elseif length(scheduler.task_per_day) > cutoff_tasks
        return false, "Too many tasks ($cutoff_tasks max)"
    elseif scheduler.days > cutoff_days
        return false, "Too many days ($cutoff_days max)"
    end

    for (idx_day, indices) in enumerate(scheduler.daily_indices)
        required_workers = [get_task(scheduler, i) for i in indices]
        daily_worker = length([w for w in scheduler.workers if !in(idx_day-1, w.days_off)])

        for t in required_workers
            if t.worker_slots > daily_worker
                return false, "Not enough worker for task $(t.name) on day $idx_day"
            end
        end
    end

    return true, "OK"
end

function get_task(s::Scheduler, id::Int)
    task_id = (id + s.cutoff_N_first) % length(s.task_per_day)
    if task_id == 0
        return s.task_per_day[end]
    else
        return s.task_per_day[task_id]
    end
end

function seed(s::Scheduler)
    nb_workers = length(s.workers)
    slots = zeros(Bool, (s.total_tasks, nb_workers))
    for (day_idx, indices) in enumerate(s.daily_indices)
        worker_working = [w for w in 1:nb_workers if !in(day_idx-1, s.workers[w].days_off)]
        
        for t in indices
            task = get_task(s, t)
            random_affectation = StatsBase.sample(worker_working, task.worker_slots, replace=false)
            slots[t, random_affectation] .= 1
        end
    end
    return slots
end

function difficulty(s::Scheduler)
    nb_workers = length(s.workers)
    possible_states = 1

    for (day_idx, indices) in enumerate(s.daily_indices)
        worker_working = [w for w in 1:nb_workers if !in(day_idx-1, s.workers[w].days_off)]
        
        for t in indices
            task = get_task(s, t)
            possible_states *= binomial(length(worker_working), task.worker_slots)
        end
    end
    return possible_states
end


function task_indices(task_per_day::Vector{STask}, days::Int, cutoff_N_first::Int, cutoff_N_last::Int)
    all_indices = Vector{Tuple{STask, Vector{Int}}}()
    nb_task_per_day = length(task_per_day)
    
    max_task = length(task_per_day)*days - cutoff_N_last

    base_indice = 0:days-1 |> collect 
    base_indice = base_indice .* nb_task_per_day

    for (idx, task) in enumerate(task_per_day)
        current_indices = base_indice .+ idx
        current_indices = [i for i in current_indices if cutoff_N_first < i <= max_task]
        current_indices = current_indices .- cutoff_N_first

        push!(all_indices, (task, current_indices))
    end
    return all_indices
end


function task_type_indices(all_task_indices_per_day)
    unique_tasks = unique([t for (t, i) in all_task_indices_per_day])
    all_indices = [(t, Int[]) for t in unique_tasks]

    for (t, indices) in all_indices
        for (t2, idx) in all_task_indices_per_day
            if t == t2
                push!(indices, idx...)
            end
        end
    end
    return all_indices
end

function daily_indices(task_per_day::Vector{STask}, days::Int, cutoff_N_first::Int, cutoff_N_last::Int)
    all_indices = Vector{Vector{Int64}}()
    nb_jobs = length(task_per_day)
    offset = cutoff_N_first

    max_task = nb_jobs*days - cutoff_N_last
    
    for day in 0:days-1
        current_day = [i + (nb_jobs*day) for i in 1:nb_jobs if offset < i + (nb_jobs*day) <= max_task]
        current_day = current_day .- offset
        push!(all_indices, current_day)
    end
    return all_indices
end