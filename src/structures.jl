
struct SWorker
    name::String
    days_off::Vector{Int}
end
SWorker(tp::Tuple{String, Vector{Int64}}) = SWorker(tp[1], tp[2])


struct STask
    name::String
    worker_slots::Int
    difficulty::Int
    range::Tuple{Int, Int}
end

STask(tp::Tuple{String, Int, Int, Int, Int}) = STask(tp[1], tp[2], tp[3], (tp[4], tp[5]))
STask(tp::Tuple{String, Int, Int, Int}) = STask(tp[1], tp[2], 1, (tp[4], tp[5]))

struct Scheduler
    workers::Vector{SWorker}
    tasks_per_day::Vector{STask}
    days::Int
    total_tasks::Int
    tasks_indices_per_day::Vector{Pair{STask, Vector{Int}}}
    indice_task::Dict{Int, STask}
    task_type_indices::Vector{Vector{Int}}
    daily_indices::Vector{Vector{Int}}
    balance_daysoff::Bool
end

function Scheduler(payload::Dict)
    workers = SWorker.(payload["workers"])
    tasks = STask.(payload["tasks"])

    balance_daysoff, days = payload["balance_daysoff"], payload["days"]

    #N_first, N_last, days = payload["cutoff_N_first"], payload["cutoff_N_last"], payload["days"]
    tasks_per_day = [tasks[i] for i in payload["task_per_day"] .+ 1]

    total_task = sum(t.range[2] - t.range[1] + 1 for t in tasks_per_day)

    tasks_indices_per_day, daily, indice_task = task_indices(tasks_per_day, days)

    unique_tasks = unique(tasks_per_day)
    task_type = [[idx for (idx, (t2, task_indices)) in 
                enumerate(zip(tasks_per_day, tasks_indices_per_day)) 
                if t1 == t2 && length(task_indices[2]) > 0] 
                for t1 in unique_tasks]

    
    return Scheduler(workers, tasks_per_day, days, total_task, tasks_indices_per_day, indice_task, task_type, daily, balance_daysoff)
end


function check_satisfability(scheduler::Scheduler; cutoff_workers=30, cutoff_tasks=20, cutoff_days=40)
    if length(scheduler.workers) > cutoff_workers
        return false, "Too many workers ($cutoff_workers max)"
    elseif length(scheduler.tasks_per_day) > cutoff_tasks
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

get_task(s::Scheduler, id::Int) = s.indice_task[id]

function task_indices(task_per_day::Vector{STask}, days::Int)
    all_indices = OrderedDict{STask, Vector{Int}}(t => [] for t in task_per_day)
    daily_indices = [Int[] for i in 1:days]
    idx_tasks = Dict{Int, STask}()
    
    current_ids = 0
    for day in 1:days
        for task in task_per_day
            if task.range[1] <= day <= task.range[2]
                current_ids += 1
                push!(all_indices[task], current_ids)
                push!(daily_indices[day], current_ids)
                push!(idx_tasks, current_ids => task)
            end
        end
    end

    return collect(all_indices), daily_indices, idx_tasks
end
