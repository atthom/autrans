# Optimization functions for Autrans module

"""
Detailed failure information
"""
struct FailureInfo
    level::Int
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
Create the JuMP model with decision variables
"""
function create_model(scheduler::AutransScheduler, N, D, T)
    model = Model(HiGHS.Optimizer)
    set_time_limit_sec(model, scheduler.max_solve_time)
    set_optimizer_attribute(model, "log_to_console", false)
    @variable(model, assign[1:N, 1:D, 1:T], Bin)
    return model, assign
end

"""
Quick feasibility check before attempting full solve
Returns (is_feasible, reason)
"""
function quick_feasibility_check(scheduler::AutransScheduler)
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
        
        failure_info = FailureInfo(0, "INFEASIBLE", capacity_analysis, [reason])
        return (nothing, failure_info)
    end
    
    # Generate relaxation hierarchy based on soft constraints
    hierarchy = generate_relaxation_hierarchy(scheduler.soft_constraints, scheduler.max_relaxation_level)
    
    # Try each relaxation level
    all_failures = FailureInfo[]
    
    for (level_idx, relaxation_levels) in enumerate(hierarchy)
        if scheduler.verbose
            println("\n" * "-"^80)
            println("RELAXATION LEVEL $level_idx")
            println("-"^80)
            for (i, constraint) in enumerate(scheduler.soft_constraints)
                println("$(constraint.name): relaxation = $(relaxation_levels[i])")
            end
            println()
        end
        
        # Create model
        model, assign = create_model(scheduler, N, D, T)
        
        # Collect objective terms (for preference constraints)
        objective_terms = []
        
        # Apply hard constraints
        for constraint in scheduler.hard_constraints
            if scheduler.verbose
                println("Applying HARD: $(constraint.name)")
            end
            result = apply!(model, assign, scheduler, constraint, N, D, T)
            
            # If constraint returns an objective term, collect it
            if result !== nothing
                push!(objective_terms, result)
            end
        end
        
        # Apply soft constraints with relaxation
        for (i, constraint) in enumerate(scheduler.soft_constraints)
            relaxation = relaxation_levels[i]
            
            if scheduler.verbose
                println("Applying SOFT: $(constraint.name) (relaxation=$relaxation)")
            end
            
            # Apply with relaxation (even if 0, the constraint handles it)
            result = apply!(model, assign, scheduler, constraint, N, D, T, relaxation)
            
            # If constraint returns an objective term, collect it
            if result !== nothing
                push!(objective_terms, result)
            end
        end
        
        # Set objective function if there are any objective terms
        if !isempty(objective_terms)
            @objective(model, Min, sum(objective_terms))
            if scheduler.verbose
                println("Objective: Minimize preference penalties")
            end
        end
        
        if scheduler.verbose
            println()
        end
        
        # Solve
        optimize!(model)
        
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
            
            # Build constraint details for this level
            constraint_details = String[]
            for (i, constraint) in enumerate(scheduler.soft_constraints)
                push!(constraint_details, "$(constraint.name): relaxation = $(relaxation_levels[i])")
            end
            
            push!(all_failures, FailureInfo(
                level_idx,
                status_str,
                capacity_analysis,
                constraint_details
            ))
        end
    end
    
    # All levels failed
    if scheduler.verbose
        println("\n" * "="^80)
        println("❌ NO SOLUTION FOUND AT ANY RELAXATION LEVEL")
        println("="^80)
    end
    
    return (nothing, all_failures[end])
end