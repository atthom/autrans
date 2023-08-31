
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
        new(workers, task_per_day, days, length(task_per_day)*days,N_first, N_last)
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
