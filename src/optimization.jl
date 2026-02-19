# Optimization functions for Autrans module

"""
Relaxation configuration for hierarchical constraint relaxation
"""
struct RelaxationConfig
    task_diversity::Int      # Per-task workload distribution (least important)
    daily_equity::Int        # Daily workload balance (medium importance)
    overall_equity::Int      # Overall workload balance (most important)
end

"""
Define relaxation hierarchy - constraints relax in order of importance
"""
const RELAXATION_HIERARCHY = [
    RelaxationConfig(0, 0, 0),    # Level 0: Strict
    RelaxationConfig(2, 0, 0),    # Level 1: Relax task diversity
    RelaxationConfig(4, 1, 0),    # Level 2: More task diversity, start daily
    RelaxationConfig(6, 2, 0),    # Level 3: Heavy task diversity, more daily
    RelaxationConfig(8, 3, 1),    # Level 4: Very relaxed task diversity, start overall
    RelaxationConfig(10, 4, 2),   # Level 5: Maximum relaxation
]

"""
Detailed failure information
"""
struct FailureInfo
    level::Int
    config::RelaxationConfig
    status::String
    capacity_analysis::Dict{String, Any}
    constraint_details::Vector{String}
end

"""
Analyze problem capacity and feasibility
"""
function analyze_capacity(scheduler::AutransScheduler, N, D, T)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) for worker in scheduler.workers)
    
    utilization = available_worker_days > 0 ? (total_slots / available_worker_days * 100) : Inf
    
    # Per-day analysis
    daily_issues = String[]
    for d in 1:D
        workers_needed = sum(task.num_workers for task in scheduler.tasks if d in task.day_range)
        workers_available = count(w -> d ∉ w.days_off, scheduler.workers)
        
        if workers_needed > workers_available
            push!(daily_issues, "Day $d: needs $workers_needed workers, only $workers_available available (deficit: $(workers_needed - workers_available))")
        end
    end
    
    return Dict(
        "total_slots" => total_slots,
        "available_worker_days" => available_worker_days,
        "utilization_percent" => round(utilization, digits=1),
        "daily_issues" => daily_issues,
        "num_workers" => N,
        "num_days" => D,
        "num_tasks" => T
    )
end

"""
Analyze overall equity constraints for proportional equity
"""
function analyze_overall_equity_constraints!(details::Vector{String}, scheduler::AutransScheduler{ProportionalEquity}, 
                                            N, D, T, total_slots, available_worker_days, avg_tasks_per_worker_day, config::RelaxationConfig)
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        if !isempty(work_days)
            expected_workload = length(work_days) * avg_tasks_per_worker_day
            lower_bound = max(0, expected_workload - config.overall_equity)
            upper_bound = expected_workload + config.overall_equity + 1
            
            push!(details, "Worker '$(worker.name)': must do $lower_bound-$upper_bound total tasks ($(length(work_days)) work days)")
        end
    end
end

"""
Analyze overall equity constraints for absolute equity
"""
function analyze_overall_equity_constraints!(details::Vector{String}, scheduler::AutransScheduler{AbsoluteEquity}, 
                                            N, D, T, total_slots, available_worker_days, avg_tasks_per_worker_day, config::RelaxationConfig)
    expected_per_worker = div(total_slots, N)
    lower_bound = max(0, expected_per_worker - config.overall_equity)
    upper_bound = expected_per_worker + config.overall_equity + 1
    push!(details, "All workers: must do $lower_bound-$upper_bound total tasks (absolute equity)")
end

"""
Analyze constraint requirements for a given configuration
"""
function analyze_constraints(scheduler::AutransScheduler, N, D, T, config::RelaxationConfig)
    details = String[]
    
    total_slots, available_worker_days, avg_tasks_per_worker_day = calculate_workload_stats(scheduler, D)
    
    # Task diversity constraints
    for (t, task) in enumerate(scheduler.tasks)
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        lower_bound = max(0, workload_per_worker - config.task_diversity)
        upper_bound = workload_per_worker + 1 + config.task_diversity
        
        push!(details, "Task '$(task.name)': each worker must do $lower_bound-$upper_bound slots (total: $workload slots)")
    end
    
    # Overall equity constraints - check type parameter
    analyze_overall_equity_constraints!(details, scheduler, N, D, T, total_slots, available_worker_days, avg_tasks_per_worker_day, config)
    
    # Daily equity constraints
    if config.daily_equity > 0
        total_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) for worker in scheduler.workers)
        if total_worker_days > 0
            avg_tasks_per_day = total_slots / total_worker_days
            max_daily = ceil(Int, avg_tasks_per_day) + 1 + config.daily_equity
            push!(details, "Daily limit: max $max_daily tasks per worker per day")
        end
    end
    
    return details
end

"""
Create the JuMP model with decision variables
"""
function create_model(scheduler::AutransScheduler, N, D, T)
    model = Model(HiGHS.Optimizer)
    set_time_limit_sec(model, scheduler.max_solve_time)
    set_optimizer_attribute(model, "log_to_console", false)  # We'll handle logging ourselves
    @variable(model, assign[1:N, 1:D, 1:T], Bin)
    return model, assign
end

"""
Add task assignment constraints
"""
function add_task_constraints!(model, assign, scheduler::AutransScheduler, N, D, config::RelaxationConfig)
    # HARD CONSTRAINT: Each task must have exact number of workers on active days
    for (t, task) in enumerate(scheduler.tasks)
        for d in 1:D
            val = d in task.day_range ? task.num_workers : 0
            @constraint(model, sum(assign[w, d, t] for w in 1:N) == val)
        end
        
        # SOFT CONSTRAINT: Per-task workload distribution (task diversity)
        # Priority 3 - Least important, relaxes first and most
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        
        # Apply hierarchical relaxation
        lower_bound = max(0, workload_per_worker - config.task_diversity)
        upper_bound = workload_per_worker + 1 + config.task_diversity
        
        @constraint(model, [w=1:N], sum(assign[w, d, t] for d in 1:D) >= lower_bound)
        @constraint(model, [w=1:N], sum(assign[w, d, t] for d in 1:D) <= upper_bound)
    end
end

"""
Add worker-specific constraints
"""
function add_worker_constraints!(model, assign, scheduler::AutransScheduler, N, D, T, config::RelaxationConfig)
    # HARD CONSTRAINT: No consecutive tasks for workers (max 1 task per day)
    @constraint(model, [w=1:N, d=1:D, t=1:(T-1)], assign[w, d, t] + assign[w, d, t+1] <= 1)

    # HARD CONSTRAINT: Days off
    for (w, worker) in enumerate(scheduler.workers)
        for day in worker.days_off
            if 1 <= day <= D
                @constraint(model, [t=1:T], assign[w, day, t] == 0)
            end
        end
    end

    # Add daily equity constraint (Priority 2)
    add_daily_equity_constraints!(model, assign, scheduler, N, D, T, config)
    
    # Add overall equity constraints (Priority 1 - Most important soft constraint)
    total_slots, available_worker_days, avg_tasks_per_worker_day = calculate_workload_stats(scheduler, D)
    
    if available_worker_days > 0
        add_overall_equity_constraints!(model, assign, scheduler, N, D, T, avg_tasks_per_worker_day, total_slots, config)
    end
end

"""
Add daily equity constraints - workers should do similar work each day
Priority 2 constraint (medium importance)
"""
function add_daily_equity_constraints!(model, assign, scheduler::AutransScheduler, N, D, T, config::RelaxationConfig)
    # Calculate expected tasks per worker per day
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    total_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) for worker in scheduler.workers)
    
    if total_worker_days == 0
        return
    end
    
    avg_tasks_per_day = total_slots / total_worker_days
    
    # For each worker, constrain daily workload variation
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        
        if isempty(work_days)
            continue
        end
        
        # Expected tasks per day for this worker
        expected_daily = avg_tasks_per_day
        
        # Apply relaxation - allow more variation as relaxation increases
        # At relaxation=0, allow ±1 task per day
        # At higher relaxation, allow more variation
        max_daily = ceil(Int, expected_daily) + 1 + config.daily_equity
        
        for d in work_days
            @constraint(model, sum(assign[w, d, t] for t in 1:T) <= max_daily)
        end
    end
end

"""
Calculate expected workload statistics
"""
function calculate_workload_stats(scheduler::AutransScheduler, D)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) for worker in scheduler.workers)
    
    # Calculate average - use ceiling to ensure we don't underestimate
    # For proportional equity, this represents tasks per worker-day
    avg_tasks_per_worker_day = available_worker_days > 0 ? ceil(Int, total_slots / available_worker_days) : 0
    
    return total_slots, available_worker_days, avg_tasks_per_worker_day
end

"""
Add overall equity constraints - total workload balance
Priority 1 constraint (most important soft constraint)
"""
function add_overall_equity_constraints!(model, assign, scheduler::AutransScheduler{ProportionalEquity}, 
                                        N, D, T, avg_tasks_per_worker_day, total_slots, config::RelaxationConfig)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) for worker in scheduler.workers)
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        
        if isempty(work_days)
            continue
        end

        # Total workload equity: proportional to available days
        # Use float division to get the true expected workload
        expected_workload_float = (length(work_days) / available_worker_days) * total_slots
        expected_workload = round(Int, expected_workload_float)
        
        # Apply minimal relaxation (most important constraint)
        lower_bound = max(0, expected_workload - config.overall_equity)
        upper_bound = expected_workload + config.overall_equity + 1

        @constraint(model, sum(assign[w, d, t] for t in 1:T, d in 1:D) >= lower_bound)
        @constraint(model, sum(assign[w, d, t] for t in 1:T, d in 1:D) <= upper_bound)
    end
end

"""
Add overall equity constraints for absolute equity strategy
"""
function add_overall_equity_constraints!(model, assign, scheduler::AutransScheduler{AbsoluteEquity}, 
                                        N, D, T, avg_tasks_per_worker_day, total_slots, config::RelaxationConfig)
    expected_per_worker = div(total_slots, N)
    
    for (w, worker) in enumerate(scheduler.workers)
        # Total workload: same for everyone
        lower_bound = max(0, expected_per_worker - config.overall_equity)
        upper_bound = expected_per_worker + config.overall_equity + 1
        
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= lower_bound)
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= upper_bound)
    end
end

"""
Quick feasibility check before attempting full solve
Returns (is_feasible, reason)
"""
function quick_feasibility_check(scheduler::AutransScheduler)
    # Calculate basic capacity
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    available_worker_days = sum(scheduler.num_days - length(worker.days_off ∩ Set(1:scheduler.num_days)) 
                                for worker in scheduler.workers)
    
    utilization = available_worker_days > 0 ? (total_slots / available_worker_days) : Inf
    
    # If utilization is over 200%, it's definitely infeasible
    if utilization > 2.0
        return (false, "Utilization $(round(utilization*100, digits=1))% exceeds 200% - not enough worker capacity")
    end
    
    # Check if any day has impossible requirements
    for d in 1:scheduler.num_days
        workers_needed = sum(task.num_workers for task in scheduler.tasks if d in task.day_range)
        workers_available = count(w -> d ∉ w.days_off, scheduler.workers)
        
        # If any single day needs more workers than available, it's infeasible
        if workers_needed > workers_available
            return (false, "Day $d requires $workers_needed workers but only $workers_available available")
        end
    end
    
    return (true, "")
end

"""
Solve the scheduling optimization problem with hierarchical relaxation
Returns a tuple: (solution, failure_info)
- solution: 3D array [worker, day, task] with 0/1 assignments, or nothing if no solution
- failure_info: FailureInfo struct with detailed diagnostics, or nothing if successful
"""
function solve(scheduler::AutransScheduler)
    N = length(scheduler.workers)
    D = scheduler.num_days
    T = length(scheduler.tasks)
    
    # Analyze capacity
    capacity_analysis = analyze_capacity(scheduler, N, D, T)
    
    if scheduler.verbose
        println("\n" * "="^80)
        println("CAPACITY ANALYSIS")
        println("="^80)
        println("Workers: $N | Days: $D | Tasks: $T")
        println("Total slots needed: $(capacity_analysis["total_slots"])")
        println("Available worker-days: $(capacity_analysis["available_worker_days"])")
        println("Utilization: $(capacity_analysis["utilization_percent"])%")
        
        if !isempty(capacity_analysis["daily_issues"])
            println("\n⚠️  Daily capacity issues:")
            for issue in capacity_analysis["daily_issues"]
                println("  - $issue")
            end
        end
        println("="^80)
    end
    
    # Quick feasibility check
    is_feasible, reason = quick_feasibility_check(scheduler)
    if !is_feasible
        if scheduler.verbose
            println("\n❌ QUICK FEASIBILITY CHECK FAILED")
            println("Reason: $reason")
        end
        
        failure_info = FailureInfo(
            0,
            RelaxationConfig(0, 0, 0),
            "INFEASIBLE",
            capacity_analysis,
            [reason]
        )
        return (nothing, failure_info)
    end
    
    # Try each relaxation level in hierarchy
    all_failures = FailureInfo[]
    
    for (level_idx, config) in enumerate(RELAXATION_HIERARCHY)
        if scheduler.verbose
            println("\n" * "-"^80)
            println("RELAXATION LEVEL $level_idx")
            println("-"^80)
            println("Task diversity: $(config.task_diversity)")
            println("Daily equity: $(config.daily_equity)")
            println("Overall equity: $(config.overall_equity)")
            println()
        end
        
        # Analyze constraints for this level
        constraint_details = analyze_constraints(scheduler, N, D, T, config)
        
        if scheduler.verbose
            println("Constraint requirements:")
            for detail in constraint_details
                println("  • $detail")
            end
            println()
        end
        
        # Create model and add variables
        model, assign = create_model(scheduler, N, D, T)
        
        # Add constraints with hierarchical relaxation
        add_task_constraints!(model, assign, scheduler, N, D, config)
        add_worker_constraints!(model, assign, scheduler, N, D, T, config)
        
        # Solve (pure feasibility problem - no objective)
        optimize!(model)
        
        # Extract solution
        status = termination_status(model)
        status_str = string(status)
        
        if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED || 
           (status == MOI.TIME_LIMIT && has_values(model))
            if scheduler.verbose
                println("✅ SOLUTION FOUND at relaxation level $level_idx")
                println("Status: $status_str")
            end
            return (round.(Int, value.(assign)), nothing)
        else
            if scheduler.verbose
                println("❌ FAILED at relaxation level $level_idx")
                println("Status: $status_str")
            end
            
            push!(all_failures, FailureInfo(
                level_idx,
                config,
                status_str,
                capacity_analysis,
                constraint_details
            ))
        end
    end
    
    # All levels failed - return the last failure info
    if scheduler.verbose
        println("\n" * "="^80)
        println("❌ NO SOLUTION FOUND AT ANY RELAXATION LEVEL")
        println("="^80)
    end
    
    return (nothing, all_failures[end])
end