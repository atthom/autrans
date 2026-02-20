using DataFrames, Printf

"""
Format count with day-off marker
"""
format_with_marker(count::Int, has_day_off::Bool) = has_day_off ? "$count*" : "$count"

"""
Check if worker has any day off in the given range
"""
function has_day_off_in_range(worker::AutransWorker, day_range, max_days::Int)
    return any(d in worker.days_off for d in day_range if d <= max_days)
end

"""
Build worker columns with counts and day-off markers
- dimensions: range or collection to iterate over (e.g., 1:T for tasks, 1:D for days)
- compute_count_func: (schedule, worker_idx, dimension_value) -> count
- check_dayoff_func: (worker, dimension_value) -> bool
"""
function build_worker_columns(schedule, scheduler::AutransScheduler, 
                              dimensions, compute_count_func, check_dayoff_func)
    N, D, T = size(schedule)
    worker_cols = [String[] for _ in 1:N]
    
    # Build counts for each dimension
    for w in 1:N
        for dim in dimensions
            count = compute_count_func(schedule, w, dim)
            has_day_off = check_dayoff_func(scheduler.workers[w], dim)
            push!(worker_cols[w], format_with_marker(count, has_day_off))
        end
        
        # Add total
        total = sum(schedule[w, :, :])
        has_any_day_off = !isempty(scheduler.workers[w].days_off ∩ Set(1:D))
        push!(worker_cols[w], format_with_marker(total, has_any_day_off))
    end
    
    return worker_cols
end

"""
Create and print DataFrame with worker columns
"""
function create_and_print_dataframe(first_col_name::String, row_labels::Vector{String}, 
                                   worker_cols::Vector{Vector{String}}, 
                                   total_col::Vector{String},
                                   scheduler::AutransScheduler, 
                                   title::String)
    df = DataFrame(Symbol(first_col_name) => row_labels)
    
    for (w, worker) in enumerate(scheduler.workers)
        df[!, worker.name] = worker_cols[w]
    end
    df[!, "TOTAL"] = total_col
    
    println("\n", "="^100, "\n$title\n", "="^100)
    println(df)
end

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
    
    # Build worker columns using helper
    worker_cols = build_worker_columns(
        schedule, scheduler, 1:T,
        (sched, w, t) -> sum(sched[w, d, t] for d in 1:D),
        (worker, t) -> has_day_off_in_range(worker, scheduler.tasks[t].day_range, D)
    )
    
    # Build total column
    total_col = [string(sum(schedule[:, :, t])) for t in 1:T]
    push!(total_col, string(sum(schedule)))
    
    # Create row labels
    task_names = [task.name for task in scheduler.tasks]
    push!(task_names, "TOTAL")
    
    # Create and print DataFrame
    create_and_print_dataframe(
        "Task", task_names, worker_cols, total_col, scheduler,
        "DEBUG: Tasks × Workers (Total assignments across all days)"
    )
end

function print_debug_days_workers(schedule::Array{Int, 3}, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    
    # Build worker columns using helper
    worker_cols = build_worker_columns(
        schedule, scheduler, 1:D,
        (sched, w, d) -> sum(sched[w, d, t] for t in 1:T),
        (worker, d) -> d in worker.days_off
    )
    
    # Build total column
    total_col = [string(sum(schedule[:, d, :])) for d in 1:D]
    push!(total_col, string(sum(schedule)))
    
    # Create row labels
    day_names = ["Day $d" for d in 1:D]
    push!(day_names, "TOTAL")
    
    # Create and print DataFrame
    create_and_print_dataframe(
        "Day", day_names, worker_cols, total_col, scheduler,
        "DEBUG: Days × Workers (Tasks per day per worker)"
    )
end

function print_all(schedule, scheduler::AutransScheduler)
    print_schedule(schedule, scheduler)
    print_debug_tasks_workers(schedule, scheduler)
    print_debug_days_workers(schedule, scheduler)
end

