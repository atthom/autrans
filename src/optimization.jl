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
Extract solution from solved model
Returns (solution, status_str) where solution is nothing if no valid solution found
"""
function extract_solution(model, assign)
    status = termination_status(model)
    status_str = string(status)
    
    if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED || 
       (status == MOI.TIME_LIMIT && has_values(model))
        return (round.(Int, value.(assign)), status_str)
    else
        return (nothing, status_str)
    end
end

"""
Apply hard constraints and collect objective terms
Returns vector of objective terms from hard constraints
"""
function apply_hard_constraints(model, assign, scheduler::AutransScheduler, N::Int, D::Int, T::Int)
    objective_terms = []
    
    for constraint in scheduler.hard_constraints
        result = apply!(model, assign, scheduler, constraint, N, D, T)
        if result !== nothing
            push!(objective_terms, result)
        end
    end
    
    return objective_terms
end

"""
Apply soft constraints with relaxation and build objective function
"""
function apply_soft_constraints_and_build_objective!(model, assign, scheduler::AutransScheduler,
                                                     N::Int, D::Int, T::Int,
                                                     relaxation_levels::Vector{Int},
                                                     base_objective_terms::Vector=[])
    objective_terms = copy(base_objective_terms)
    
    # Apply soft constraints with relaxation
    for (i, constraint) in enumerate(scheduler.soft_constraints)
        relaxation = relaxation_levels[i]
        result = apply!(model, assign, scheduler, constraint, N, D, T, relaxation)
        if result !== nothing
            push!(objective_terms, result)
        end
    end
    
    # Set objective function if there are any objective terms
    if !isempty(objective_terms)
        @objective(model, Min, sum(objective_terms))
    end
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
Solve at a specific relaxation level (creates new model each time)
Returns a tuple: (solution, status_str)
"""
function solve_at_level(scheduler::AutransScheduler, N::Int, D::Int, T::Int, 
                       relaxation_levels::Vector{Int}, level_idx::Int)
    # Create model
    model, assign = create_model(scheduler, N, D, T)
    
    # Apply hard constraints and collect their objectives
    base_objective_terms = apply_hard_constraints(model, assign, scheduler, N, D, T)
    
    # Apply soft constraints and build objective
    apply_soft_constraints_and_build_objective!(model, assign, scheduler, N, D, T,
                                               relaxation_levels, base_objective_terms)
    
    # Solve and extract solution
    optimize!(model)
    return extract_solution(model, assign)
end

"""
Create a model with hard constraints already applied
Returns (model, assign, objective_terms_from_hard_constraints)
"""
function create_model_with_hard_constraints(scheduler::AutransScheduler, N::Int, D::Int, T::Int)
    model, assign = create_model(scheduler, N, D, T)
    objective_terms = apply_hard_constraints(model, assign, scheduler, N, D, T)
    return model, assign, objective_terms
end

"""
Solve at a specific relaxation level using a pre-built model with hard constraints
Returns a tuple: (solution, status_str)
"""
function solve_at_level_with_model(model, assign, scheduler::AutransScheduler, 
                                   N::Int, D::Int, T::Int,
                                   base_objective_terms::Vector,
                                   relaxation_levels::Vector{Int})
    # Apply soft constraints and build objective
    apply_soft_constraints_and_build_objective!(model, assign, scheduler, N, D, T,
                                               relaxation_levels, base_objective_terms)
    
    # Solve and extract solution
    optimize!(model)
    return extract_solution(model, assign)
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
    max_level = length(hierarchy)
    
    if scheduler.verbose
        println("\n" * "="^80)
        println("ADAPTIVE RELAXATION STRATEGY")
        println("="^80)
        println("Max relaxation levels: $max_level")
        println("="^80)
    end
    
    # Step 1: Try strictest constraints first (level 1) - most common case
    if scheduler.verbose
        println("\nStep 1: Testing strictest constraints (level 1)...")
    end
    
    solution, status_str = solve_at_level(scheduler, N, D, T, hierarchy[1], 1)
    
    if solution !== nothing
        # Success at level 1 - optimal solution!
        if scheduler.verbose
            println("✅ OPTIMAL SOLUTION at level 1 (strictest constraints)")
        end
        return (solution, nothing)
    end
    
    if scheduler.verbose
        println("❌ Failed at level 1, using model reuse with binary search...")
        println("\nCreating reusable model with hard constraints...")
    end
    
    # Create model once with hard constraints (reuse for all relaxation levels)
    model, assign, base_objective_terms = create_model_with_hard_constraints(scheduler, N, D, T)
    
    # Step 2: Try maximum relaxation to check feasibility
    if scheduler.verbose
        println("\nStep 2: Testing maximum relaxation (level $max_level)...")
    end
    
    solution, status_str = solve_at_level_with_model(model, assign, scheduler, N, D, T, 
                                                     base_objective_terms, hierarchy[max_level])
    
    if solution === nothing
        # Even max relaxation failed - truly infeasible
        if scheduler.verbose
            println("❌ INFEASIBLE even at maximum relaxation")
            println("Status: $status_str")
        end
        
        constraint_details = String[]
        for (i, constraint) in enumerate(scheduler.soft_constraints)
            push!(constraint_details, "$(constraint.name): relaxation = $(hierarchy[max_level][i])")
        end
        
        failure_info = FailureInfo(max_level, status_str, capacity_analysis, constraint_details)
        return (nothing, failure_info)
    end
    
    if scheduler.verbose
        println("✅ Feasible at maximum relaxation")
    end
    
    # Step 3: Binary search for minimum relaxation needed (between 2 and max_level)
    # Reuse the same model for all binary search iterations!
    if scheduler.verbose
        println("\nStep 3: Binary search with model reuse...")
    end
    
    low, high = 2, max_level
    best_solution = solution
    best_level = max_level
    
    while low <= high
        mid = div(low + high, 2)
        
        if scheduler.verbose
            println("  Testing level $mid (range: $low-$high)...")
        end
        
        solution, status_str = solve_at_level_with_model(model, assign, scheduler, N, D, T,
                                                         base_objective_terms, hierarchy[mid])
        
        if solution !== nothing
            # Found solution at this level - try tighter constraints
            best_solution = solution
            best_level = mid
            high = mid - 1
            
            if scheduler.verbose
                println("  ✅ Feasible - trying tighter")
            end
        else
            # Need more relaxation
            low = mid + 1
            
            if scheduler.verbose
                println("  ❌ Infeasible - need more relaxation")
            end
        end
    end
    
    if scheduler.verbose
        println("\n" * "="^80)
        println("✅ SOLUTION FOUND")
        println("="^80)
        println("Relaxation level: $best_level")
        for (i, constraint) in enumerate(scheduler.soft_constraints)
            println("  $(constraint.name): relaxation = $(hierarchy[best_level][i])")
        end
        println("="^80)
    end
    
    return (best_solution, nothing)
end