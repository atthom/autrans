
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

struct Scheduler
    workers::Vector{SWorker}
    task_per_day::Vector{STask}
    days::Int
    total_tasks::Int
    cutoff_N_first::Int
    cutoff_N_last::Int
    all_task_indices::Vector{Tuple{STask, Vector{Int}}}
    all_task_indices_per_day::Vector{Tuple{STask, Vector{Int}}}
end


function Scheduler(li_workers, task_per_day, days, N_first, N_last) 
    workers = SWorker.(li_workers)
    total_task = length(task_per_day)*days
    all_task_indices = Vector{Tuple{STask, Vector{Int}}}()
    for t in unique(task_per_day)
        indices = task_indices(task_per_day, total_task, N_first, t)
        push!(all_task_indices, (t, indices |> collect))
    end

    all_task_indices_per_day = task_indices_per_day(task_per_day, total_task, N_first)

    return Scheduler(workers, task_per_day, days, total_task, N_first, N_last, all_task_indices, all_task_indices_per_day)
end

function Scheduler(payload::Dict)
    n_first, n_last, days = payload["cutoff_N_first"], payload["cutoff_N_first"], payload["days"]
    tasks = STask.(payload["tasks"])

    task_per_day = [tasks[i] for i in payload["task_per_day"] .+ 1]
    li_workers = payload["workers"]
    return Scheduler(li_workers, task_per_day, days, n_first, n_last)
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
    slots = zeros(Bool, (s.total_tasks, length(s.workers)))
    for t in 1:s.total_tasks
        task = get_task(s, t)
        slots[t, 1:task.worker_slots] .= 1
    end
    return slots
end


function task_indices(task_per_day::Vector{STask}, total_tasks::Int, cutoff_N_first::Int, t::STask)
    all_indices = Vector{Int}()
    nb_task_per_day = length(task_per_day)
    for (idx, task) in enumerate(task_per_day)
        if task == t
            indices = idx:nb_task_per_day:total_tasks
            for i in indices
                push!(all_indices, i)
            end
        end
    end
    all_indices = all_indices .- cutoff_N_first
    all_indices = filter(x -> x > 0, all_indices)
    return all_indices
end


function task_indices_per_day(task_per_day::Vector{STask}, total_tasks::Int, cutoff_N_first::Int)
    all_indices = Vector{Tuple{STask, Vector{Int}}}()
    nb_task_per_day = length(task_per_day)
    for (idx, task) in enumerate(task_per_day)
        indices = idx-cutoff_N_first:nb_task_per_day:total_tasks-cutoff_N_first
        push!(all_indices, (task, filter(i -> i > 0, indices) |> collect))
    end
    return all_indices
end


function day_indices(s::Scheduler)
    all_indices = Vector{UnitRange{Int64}}()
    nb_jobs = length(s.task_per_day)
    offset = s.cutoff_N_first
    
    for day in 1:nb_jobs:s.total_tasks
        if day == 1
            # fist day
            day_idx = 1:nb_jobs-offset
        elseif day-offset == (s.days-1) * nb_jobs
            # last day
            day_idx = day-offset:day+nb_jobs-offset-1+s.cutoff_N_last
        else
            day_idx = day-offset:day+nb_jobs-offset-1
        end
        push!(all_indices, day_idx)
    end

    return all_indices
end
