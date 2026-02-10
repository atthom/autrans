using JuMP
using HiGHS
using DataFrames
using Printf

"""
Represents a worker with their availability constraints
"""
struct AutransWorker
    name::String
    days_off::Set{Int}
    
    AutransWorker(name::String, days_off::Set{Int} = Set{Int}()) = new(name, days_off)
    AutransWorker(name::String, days_off::Vector{Int}) = new(name, Set(days_off))
end

"""
Represents a task with its requirements
"""
struct AutransTask
    name::String
    num_workers::Int
    day_range::UnitRange{Int}
    
    AutransTask(name::String, num_workers::Int, day_range::UnitRange{Int}) = new(name, num_workers, day_range)
    AutransTask(name::String, num_workers::Int, day_in::Int, day_out::Int) = new(name, num_workers, UnitRange(day_in, day_out))
    AutransTask(name::String, num_workers::Int, day_in::Int) = new(name, num_workers, UnitRange(day_in, day_in))
end

"""
Equity strategy types for compile-time dispatch
"""
abstract type EquityStrategy end
struct ProportionalEquity <: EquityStrategy end
struct AbsoluteEquity <: EquityStrategy end

"""
Main scheduler that coordinates workers and tasks
"""
struct AutransScheduler{S <: EquityStrategy}
    workers::Vector{AutransWorker}
    tasks::Vector{AutransTask}
    num_days::Int
    max_solve_time::Float64
    verbose::Bool
    
    function AutransScheduler{S}(
        workers::Vector{AutransWorker},
        tasks::Vector{AutransTask},
        num_days::Int;
        max_solve_time::Float64 = 300.0,
        verbose::Bool = true
    ) where {S <: EquityStrategy}
        new{S}(workers, tasks, num_days, max_solve_time, verbose)
    end
end

# Convenience constructors
AutransScheduler(workers, tasks, num_days; equity_strategy::Symbol = :proportional, kwargs...) =
    equity_strategy == :proportional ? 
        AutransScheduler{ProportionalEquity}(workers, tasks, num_days; kwargs...) :
        AutransScheduler{AbsoluteEquity}(workers, tasks, num_days; kwargs...)

"""
Create the JuMP model with decision variables
"""
function create_model(scheduler::AutransScheduler, N, D, T)
    model = Model(HiGHS.Optimizer)
    set_time_limit_sec(model, scheduler.max_solve_time)
    set_optimizer_attribute(model, "log_to_console", scheduler.verbose)
    @variable(model, assign[1:N, 1:D, 1:T], Bin)
    return model, assign
end

"""
Add task assignment constraints
"""
function add_task_constraints!(model, assign, scheduler::AutransScheduler, N, D)
    # Each task must have exact number of workers on active days
    for (t, task) in enumerate(scheduler.tasks)
        for d in 1:D
            val = d in task.day_range ? task.num_workers : 0
            @constraint(model, sum(assign[w, d, t] for w in 1:N) == val)
        end
        
        # Per-task workload distribution across workers
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        @constraint(model, [w=1:N], sum(assign[w, d, t] for d in 1:D) >= workload_per_worker)
        @constraint(model, [w=1:N], sum(assign[w, d, t] for d in 1:D) <= workload_per_worker + 1)
    end
end

"""
Add worker-specific constraints
"""
function add_worker_constraints!(model, assign, scheduler::AutransScheduler, N, D, T, relaxation_level=0)
    # No consecutive tasks for workers
    @constraint(model, [w=1:N, d=1:D, t=1:(T-1)], assign[w, d, t] + assign[w, d, t+1] <= 1)

    # Days off constraints
    for (w, worker) in enumerate(scheduler.workers)
        for day in worker.days_off
            if 1 <= day <= D
                @constraint(model, [t=1:T], assign[w, day, t] == 0)
            end
        end
    end

    # Add equity constraints (dispatches based on strategy type)
    total_slots, available_worker_days, avg_tasks_per_worker_day = calculate_workload_stats(scheduler, D)
    
    if available_worker_days > 0
        add_equity_constraints!(model, assign, scheduler, N, D, T, avg_tasks_per_worker_day, total_slots, relaxation_level)
    end
end

"""
Calculate expected workload statistics
"""
function calculate_workload_stats(scheduler::AutransScheduler, D)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) for worker in scheduler.workers)
    
    # Use div to match the integer arithmetic used in constraints
    avg_tasks_per_worker_day = available_worker_days > 0 ? div(total_slots, available_worker_days) : 0
    
    return total_slots, available_worker_days, avg_tasks_per_worker_day
end

"""
Precompute workers available per day (for performance)
"""
function compute_daily_availability(scheduler::AutransScheduler, D)
    return [count(w -> d ∉ w.days_off, scheduler.workers) for d in 1:D]
end

"""
Add proportional equity constraints (compile-time dispatch)
"""
function add_equity_constraints!(model, assign, scheduler::AutransScheduler{ProportionalEquity}, 
                                N, D, T, avg_tasks_per_worker_day, total_slots, relaxation_level=0)
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        
        if isempty(work_days)
            continue
        end

        # Total workload equity: proportional to available days with a wider acceptable range
        expected_workload = length(work_days) * avg_tasks_per_worker_day
        lower_bound = max(0, expected_workload - relaxation_level)
        upper_bound = expected_workload + relaxation_level + 1

        @constraint(model, sum(assign[w, d, t] for t in 1:T, d in 1:D) >= lower_bound)
        @constraint(model, sum(assign[w, d, t] for t in 1:T, d in 1:D) <= upper_bound)
    end
end

"""
Add absolute equity constraints (compile-time dispatch)
"""
function add_equity_constraints!(model, assign, scheduler::AutransScheduler{AbsoluteEquity}, 
                                N, D, T, avg_tasks_per_worker_day, total_slots, relaxation_level=0)
    expected_per_worker = div(total_slots, N)
    
    for (w, worker) in enumerate(scheduler.workers)
        # Total workload: same for everyone (with relaxation)
        lower_bound = max(0, expected_per_worker - relaxation_level)
        upper_bound = expected_per_worker + relaxation_level + 1
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= lower_bound)
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= upper_bound)
        
        # Daily max: prevent cramming all tasks into few days
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        if !isempty(work_days)
            max_daily = div(expected_per_worker, length(work_days)) + 2 + relaxation_level
            for d in work_days
                @constraint(model, sum(assign[w, d, t] for t in 1:T) <= max_daily)
            end
        end
    end
end

"""
Solve the scheduling optimization problem
Returns a 3D array [worker, day, task] with 0/1 assignments, or nothing if no solution
"""
function solve(scheduler::AutransScheduler)
    N = length(scheduler.workers)
    D = scheduler.num_days
    T = length(scheduler.tasks)
    
    relaxation_levels = [0, 1, 2, 3]  # Increasing levels of relaxation
    for level in relaxation_levels
        # Create model and add variables
        model, assign = create_model(scheduler, N, D, T)
        
        # Add constraints
        add_task_constraints!(model, assign, scheduler, N, D)
        add_worker_constraints!(model, assign, scheduler, N, D, T, level)
        
        # Solve (pure feasibility problem - no objective)
        optimize!(model)
        
        # Extract solution
        status = termination_status(model)
        if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED || 
           (status == MOI.TIME_LIMIT && has_values(model))
            return round.(Int, value.(assign))
        end
    end
    return nothing
end

"""
Print main schedule: tasks as rows (index), days as columns, workers in cells
"""
function print_schedule(schedule::Array{Int, 3}, scheduler::AutransScheduler)
    # Check for empty/invalid schedule
    if size(schedule) == (0, 0, 0)
        error("Cannot print schedule: No valid solution found")
    end
    
    N, D, T = size(schedule)
    
    println("\n" * "="^100)
    println("SCHEDULE: Tasks × Days")
    println("="^100)
    
    task_names = [task.name for task in scheduler.tasks]
    
    day_cols = []
    for d in 1:scheduler.num_days
        day_col = String[]
        for (t, task) in enumerate(scheduler.tasks)
            if d ∈ task.day_range
                workers_assigned = [scheduler.workers[w].name for w in 1:N if schedule[w, d, t] == 1]
                push!(day_col, isempty(workers_assigned) ? "-" : join(workers_assigned, ", "))
            else
                push!(day_col, "-")
            end
        end
        push!(day_cols, day_col)
    end
    
    df = DataFrame(Task = task_names)
    for d in 1:scheduler.num_days
        df[!, "Day $d"] = day_cols[d]
    end
    
    println(df)
end

"""
Print debug info: Tasks × Workers (sum across all days)
"""
function print_debug_tasks_workers(schedule::Array{Int, 3}, scheduler::AutransScheduler)
    # Check for empty/invalid schedule
    if size(schedule) == (0, 0, 0)
        error("Cannot print debug info: No valid solution found")
    end
    
    N, D, T = size(schedule)
    
    println("\n" * "="^100)
    println("DEBUG: Tasks × Workers (Total assignments across all days)")
    println("="^100)
    
    task_names = [task.name for task in scheduler.tasks]
    push!(task_names, "TOTAL")
    
    worker_cols = []
    for (w, worker) in enumerate(scheduler.workers)
        col = String[]
        for t in 1:T
            count = sum(schedule[w, d, t] for d in 1:D)
            has_day_off = any(d in worker.days_off for d in scheduler.tasks[t].day_range if d <= D)
            push!(col, has_day_off ? "$count*" : "$count")
        end
        total = sum(schedule[w, :, :])
        has_any_day_off = !isempty(worker.days_off ∩ Set(1:D))
        push!(col, has_any_day_off ? "$total*" : "$total")
        push!(worker_cols, col)
    end
    
    total_col = String[]
    for t in 1:T
        push!(total_col, string(sum(schedule[:, :, t])))
    end
    push!(total_col, string(sum(schedule)))
    
    df = DataFrame(Task = task_names)
    for (w, worker) in enumerate(scheduler.workers)
        df[!, worker.name] = worker_cols[w]
    end
    df[!, "TOTAL"] = total_col
    
    println(df)
end

"""
Print debug info: Days × Workers (sum across all tasks per day)
"""
function print_debug_days_workers(schedule::Array{Int, 3}, scheduler::AutransScheduler)
    # Check for empty/invalid schedule
    if size(schedule) == (0, 0, 0)
        error("Cannot print debug info: No valid solution found")
    end
    
    N, D, T = size(schedule)
    
    println("\n" * "="^100)
    println("DEBUG: Days × Workers (Tasks per day per worker)")
    println("="^100)
    
    day_names = ["Day $d" for d in 1:scheduler.num_days]
    push!(day_names, "TOTAL")
    
    worker_cols = []
    for (w, worker) in enumerate(scheduler.workers)
        col = String[]
        for d in 1:scheduler.num_days
            count = sum(schedule[w, d, t] for t in 1:T)
            is_day_off = d in worker.days_off
            push!(col, is_day_off ? "$count*" : "$count")
        end
        total = sum(schedule[w, :, :])
        has_any_day_off = !isempty(worker.days_off ∩ Set(1:D))
        push!(col, has_any_day_off ? "$total*" : "$total")
        push!(worker_cols, col)
    end
    
    total_col = String[]
    for d in 1:scheduler.num_days
        push!(total_col, string(sum(schedule[:, d, :])))
    end
    push!(total_col, string(sum(schedule)))
    
    df = DataFrame(Day = day_names)
    for (w, worker) in enumerate(scheduler.workers)
        df[!, worker.name] = worker_cols[w]
    end
    df[!, "TOTAL"] = total_col
    
    println(df)
end

"""
Print all schedule information
"""
function print_all(schedule, scheduler::AutransScheduler)
    if schedule === nothing || size(schedule) == (0, 0, 0)
        error("Cannot print schedule: No valid solution found")
    end
    
    print_schedule(schedule, scheduler)
    print_debug_tasks_workers(schedule, scheduler)
    print_debug_days_workers(schedule, scheduler)
end

"""
Helper function to run a test case
"""
function run_test(name::String, scheduler::AutransScheduler)
    println("\n" * "="^100)
    println("TEST: $name")
    println("="^100)
    
    start_time = time()
    result = solve(scheduler)
    elapsed = time() - start_time
    
    if result !== nothing
        println("✅ Solution found in $(round(elapsed, digits=3)) seconds")
        try
            print_all(result, scheduler)
        catch e
            println("❌ Error printing schedule: ", e)
        end
    else
        println("❌ No solution found")
    end
end

# ==================== EXAMPLE USAGE ====================

function example_usage()
    # Common task definitions
    tasks = [
        AutransTask("Morning Setup", 2, 1:5),
        AutransTask("Customer Service", 3, 1:5),
        AutransTask("Inventory Check", 2, 1:5),
        AutransTask("Lunch Coverage", 2, 1:5),
        AutransTask("Afternoon Shift", 2, 1:5),
        AutransTask("Cleaning", 1, 1:5),
        AutransTask("Weekly Report", 2, 1),
        AutransTask("End of Week Review", 3, 5),
    ]
    
    # Workers with days off
    workers_with_days_off = [
        AutransWorker("Alice"),
        AutransWorker("Bob", [3]),
        AutransWorker("Charlie", [1, 5]),
        AutransWorker("Diana"),
        AutransWorker("Eve", [2, 4]),
        AutransWorker("Frank"),
        AutransWorker("Grace"),
        AutransWorker("Henry", [3]),
        AutransWorker("Ivy"),
        AutransWorker("Jack", [5])
    ]
    
    # Workers without days off
    workers_no_days_off = [
        AutransWorker("Alice"),
        AutransWorker("Bob"),
        AutransWorker("Charlie"),
        AutransWorker("Diana"),
        AutransWorker("Eve"),
        AutransWorker("Frank"),
        AutransWorker("Grace"),
        AutransWorker("Henry"),
        AutransWorker("Ivy"),
        AutransWorker("Jack")
    ]
    
    # Test 1: Proportional equity with days off
    scheduler1 = AutransScheduler{ProportionalEquity}(
        workers_with_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Proportional Equity WITH Days Off", scheduler1)
    
    # Test 2: Proportional equity without days off
    scheduler2 = AutransScheduler{ProportionalEquity}(
        workers_no_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Proportional Equity WITHOUT Days Off", scheduler2)
    
    # Test 3: Absolute equity with days off
    scheduler3 = AutransScheduler{AbsoluteEquity}(
        workers_with_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Absolute Equity WITH Days Off", scheduler3)
    
    # Test 4: Absolute equity without days off
    scheduler4 = AutransScheduler{AbsoluteEquity}(
        workers_no_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Absolute Equity WITHOUT Days Off", scheduler4)
end

# Run the examples
example_usage()