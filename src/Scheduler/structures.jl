
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
    all_task_indices::Vector{Tuple{Task, Vector{Int}}}

    function Scheduler(li_workers, task_per_day, days, N_first, N_last) 
        workers = Worker.(li_workers)
        total_task = length(task_per_day)*days
        all_task_indices = Vector{Tuple{Task, Vector{Int}}}()
        for t in unique(task_per_day)
            indices = task_indices(task_per_day, total_task, N_first, t)
            push!(all_task_indices, (t, indices |> collect))
        end

        new(workers, task_per_day, days, total_task, N_first, N_last, all_task_indices)
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


function task_indices(task_per_day::Vector{Task}, total_tasks::Int, cutoff_N_first::Int, t::Task)
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


function day_indices(s::Scheduler)
    all_indices = Vector{UnitRange{Int64}}()
    nb_jobs = length(s.task_per_day)
    offset = s.cutoff_N_first
    
    for day in 1:nb_jobs:s.total_tasks
        if day == 1
            day_idx = 1:nb_jobs-offset
        else
            day_idx = day-offset:day+nb_jobs-offset-1
        end
        push!(all_indices, day_idx)
    end

    return all_indices
end



struct Teams
    n_worker::Int
    n_total::Int
    all_teams::Vector{Vector{Bool}}
    function Teams(n_total, n_worker) 
        slots = fill(false, n_total)
        slots[1:n_worker] .= 1

        new(n_total, n_worker, multiset_permutations(n_total, n_worker) |> collect)
    end
end
