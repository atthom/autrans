
struct Worker
    name::String
    days_off::Vector{Int}
end
Worker(tp::Tuple{String, Vector{Int}}) = Worker(tp[1], tp[2])


struct Task
    name::String
    worker_slots::Int
end
Task(tp::Tuple{String, Int}) = Task(tp[1], tp[2])

struct Scheduler
    workers::Vector{Worker}
    task_per_day::Vector{Task}
    days::Int
    total_tasks::Int
    cutoff_N_first::Int
    cutoff_N_last::Int

    function Scheduler(li_workers, task_per_day, days, N_first, N_last) 
        workers = Worker.(li_workers)
        total_tasks = length(task_per_day)*days -N_first -N_last
        new(workers, task_per_day, days, total_tasks, N_first, N_last)
    end
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


function task_indices(s::Scheduler, t::Task)
    all_indices = Vector{Int}()
    nb_task_per_day = length(s.task_per_day)
    for (idx, task) in enumerate(s.task_per_day)
        if task == t
            indices = idx:nb_task_per_day:s.total_tasks
            for i in indices
                push!(all_indices, i)
            end
        end
    end
    all_indices = all_indices .- s.cutoff_N_first
    all_indices = filter(x -> x > 0, all_indices)
    return all_indices
end


function day_indices(s::Scheduler)
    all_indices = Vector{UnitRange{Int64}}()
    nb_jobs = length(s.task_per_day)
    offset1 = s.cutoff_N_first
    offset2 = s.cutoff_N_last
    
    for day in 1:nb_jobs:s.total_tasks
        if day == 1
            day_idx = 1:nb_jobs-offset1
        elseif day == s.total_tasks - s.total_tasks % nb_jobs + 1
            day_idx = s.total_tasks-nb_jobs+offset2+1:s.total_tasks
        else
            day_idx = day-offset1:day+nb_jobs-offset1-1
        end
        push!(all_indices, day_idx)
    end

    return all_indices
end
