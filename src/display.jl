using DataFrames, Printf

# ============================================================================
# INFEASIBILITY DIAGNOSTIC FORMATTING
# ============================================================================

"""
Format a task impossibility issue - clean, no decorations
Returns: "Day X: Task 'Y' requires N workers, only M available"
"""
function format_task_impossible(issue::Dict)
    return "Day $(issue["day"]): Task '$(issue["task"])' requires $(issue["required"]) workers, only $(issue["available"]) available"
end

"""
Format a capacity violation issue - clean, concise
Returns: "Day X: Needs N assignments, only M possible"
"""
function format_capacity_violation(issue::Dict)
    return "Day $(issue["day"]): Needs $(issue["needed"]) assignments across $(issue["num_tasks"]) tasks, only $(issue["max_possible"]) possible"
end

"""
Format a consecutive task conflict issue - clean
Returns: "Day X: Tasks 'A' and 'B' conflict (need N workers, only M available)"
"""
function format_consecutive_impossible(issue::Dict)
    return "Day $(issue["day"]): Tasks '$(issue["task1"])' and '$(issue["task2"])' conflict (need $(issue["min_workers_needed"]) workers, only $(issue["available"]) available)"
end

"""
Generate actionable suggestions based on issue types found
Returns array of clean suggestion strings (no bullets)
"""
function generate_suggestions(issues::Vector)
    suggestions = String[]
    
    has_type(type) = any(i["type"] == type for i in issues)
    
    if has_type("task_impossible")
        push!(suggestions, "Add more workers (some tasks exceed total worker count)")
    end
    if has_type("capacity_violation_absolute")
        push!(suggestions, "Add more workers OR reduce task requirements OR spread tasks across more days")
    end
    if has_type("consecutive_impossible")
        push!(suggestions, "Change NoConsecutiveTasks to SOFT constraint OR add more workers")
    end
    
    return suggestions
end

"""
Generate diagnostic data structure from infeasibility issues
Returns structured Dict for card-based UI rendering:
{
    "title" => "Schedule Analysis",
    "warnings" => ["Day 1: Task 'X' requires...", ...],
    "suggestions" => ["Add more workers", ...],
    "emoji" => "💡"
}
"""
function generate_obvious_diagnostics(issues::Vector)
    isempty(issues) && return Dict(
        "title" => "Schedule Analysis",
        "warnings" => String[],
        "suggestions" => String[]
    )
    
    warnings = String[]
    
    # Process each issue and create clean warning strings
    for issue in issues
        warning = if issue["type"] == "task_impossible"
            format_task_impossible(issue)
        elseif issue["type"] == "capacity_violation_absolute"
            format_capacity_violation(issue)
        elseif issue["type"] == "consecutive_impossible"
            format_consecutive_impossible(issue)
        else
            "Day $(issue["day"]): Unknown issue type"
        end
        
        push!(warnings, warning)
    end
    
    # Generate suggestions
    suggestions = generate_suggestions(issues)
    
    return Dict(
        "title" => "Schedule Analysis",
        "warnings" => warnings,
        "suggestions" => suggestions
    )
end

"""
Format diagnostics for console/CLI output (backward compatibility)
Converts structured diagnostic data back to text format
"""
function format_diagnostics_for_console(diagnostic_data::Dict)
    lines = String[]
    
    # Title
    push!(lines, diagnostic_data["title"])
    push!(lines, "")
    
    # Warnings
    for warning in diagnostic_data["warnings"]
        push!(lines, warning)
    end
    
    if !isempty(diagnostic_data["suggestions"])
        push!(lines, "")
        push!(lines, "💡 Suggestions:")
        for suggestion in diagnostic_data["suggestions"]
            push!(lines, suggestion)
        end
    end
    
    return lines
end

"""
Format diagnostics for console/CLI output - handles both old and new format
"""
function format_diagnostics_for_console(diagnostics::Vector{String})
    return diagnostics  # Already formatted
end

# ============================================================================
# SCHEDULE DISPLAY FUNCTIONS
# ============================================================================

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

