using DataFrames, Printf

function print_schedule(schedule::Array{Int, 3}, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    task_names = [task.name for task in scheduler.tasks]
    day_cols = [String[] for _ in 1:scheduler.num_days]
    
    for d in 1:scheduler.num_days, (t, task) in enumerate(scheduler.tasks)
        if d ∈ task.day_range
            workers_assigned = [scheduler.workers[w].name for w in 1:N if schedule[w, d, t] == 1]
            push!(day_cols[d], isempty(workers_assigned) ? "-" : join(workers_assigned, ", "))
        else
            push!(day_cols[d], "-")
        end
    end
    
    df = DataFrame(Task = task_names)
    for d in 1:scheduler.num_days
        df[!, "Day $d"] = day_cols[d]
    end
    
    println("\n", "="^100, "\nSCHEDULE: Tasks × Days\n", "="^100)
    println(df)
end

function print_debug_tasks_workers(schedule::Array{Int, 3}, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    task_names = [task.name for task in scheduler.tasks]
    push!(task_names, "TOTAL")
    
    worker_cols = [String[] for _ in 1:N]
    for w in 1:N, t in 1:T
        count = sum(schedule[w, d, t] for d in 1:D)
        has_day_off = any(d in scheduler.workers[w].days_off for d in scheduler.tasks[t].day_range if d <= D)
        push!(worker_cols[w], has_day_off ? "$count*" : "$count")
    end
    
    for w in 1:N
        total = sum(schedule[w, :, :])
        has_any_day_off = !isempty(scheduler.workers[w].days_off ∩ Set(1:D))
        push!(worker_cols[w], has_any_day_off ? "$total*" : "$total")
    end
    
    total_col = [string(sum(schedule[:, :, t])) for t in 1:T]
    push!(total_col, string(sum(schedule)))
    
    df = DataFrame(Task = task_names)
    for (w, worker) in enumerate(scheduler.workers)
        df[!, worker.name] = worker_cols[w]
    end
    df[!, "TOTAL"] = total_col
    
    println("\n", "="^100, "\nDEBUG: Tasks × Workers (Total assignments across all days)\n", "="^100)
    println(df)
end

function print_debug_days_workers(schedule::Array{Int, 3}, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    day_names = ["Day $d" for d in 1:scheduler.num_days]
    push!(day_names, "TOTAL")
    
    worker_cols = [String[] for _ in 1:N]
    for w in 1:N, d in 1:scheduler.num_days
        count = sum(schedule[w, d, t] for t in 1:T)
        is_day_off = d in scheduler.workers[w].days_off
        push!(worker_cols[w], is_day_off ? "$count*" : "$count")
    end
    
    for w in 1:N
        total = sum(schedule[w, :, :])
        has_any_day_off = !isempty(scheduler.workers[w].days_off ∩ Set(1:D))
        push!(worker_cols[w], has_any_day_off ? "$total*" : "$total")
    end
    
    total_col = [string(sum(schedule[:, d, :])) for d in 1:scheduler.num_days]
    push!(total_col, string(sum(schedule)))
    
    df = DataFrame(Day = day_names)
    for (w, worker) in enumerate(scheduler.workers)
        df[!, worker.name] = worker_cols[w]
    end
    df[!, "TOTAL"] = total_col
    
    println("\n", "="^100, "\nDEBUG: Days × Workers (Tasks per day per worker)\n", "="^100)
    println(df)
end

function print_all(schedule, scheduler::AutransScheduler)
    print_schedule(schedule, scheduler)
    print_debug_tasks_workers(schedule, scheduler)
    print_debug_days_workers(schedule, scheduler)
end

