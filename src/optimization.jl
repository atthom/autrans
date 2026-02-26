# Optimization functions for Autrans module

"""
Detailed failure information
"""
struct FailureInfo
    level::Int
    status::String
    capacity_analysis::Dict{String, Any}
    constraint_details::Vector{String}
    conflict_analysis::Vector{String}
end

"""
Analyze problem capacity and feasibility
"""
function analyze_capacity(scheduler::AutransScheduler, N, D, T)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks; init=0)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) for worker in scheduler.workers)
    
    utilization = available_worker_days > 0 ? (total_slots / available_worker_days * 100) : Inf
    
    # Day-by-day breakdown
    daily_breakdown = []
    for d in 1:D
        slots_needed = sum(task.num_workers for task in scheduler.tasks if d in task.day_range; init=0)
        workers_available = count(w -> d ∉ w.days_off, scheduler.workers)
        push!(daily_breakdown, Dict(
            "day" => d,
            "slots_needed" => slots_needed,
            "workers_available" => workers_available
        ))
    end
    
    return Dict(
        "total_slots" => total_slots,
        "available_worker_days" => available_worker_days,
        "utilization_percent" => round(utilization, digits=1),
        "daily_breakdown" => daily_breakdown,
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

# ============================================================================
# INFEASIBILITY DETECTION - Fast arithmetic checks
# ============================================================================

"""
Day context for infeasibility checking
"""
struct DayContext
    day::Int
    available_workers::Int
    tasks_on_day::Vector{AutransTask}
end

"""
Prepare context for a specific day
"""
function prepare_day_context(day::Int, scheduler::AutransScheduler)
    available_workers = count(w -> day ∉ w.days_off, scheduler.workers)
    tasks_on_day = [task for task in scheduler.tasks if day in task.day_range]
    return DayContext(day, available_workers, tasks_on_day)
end

"""
Check if any single task requires more workers than available
"""
function check_task_impossibility(ctx::DayContext, found_types::Set{String})
    in("task_impossible", found_types) && return nothing
    
    for task in ctx.tasks_on_day
        if task.num_workers > ctx.available_workers
            return Dict(
                "type" => "task_impossible",
                "day" => ctx.day,
                "task" => task.name,
                "required" => task.num_workers,
                "available" => ctx.available_workers
            )
        end
    end
    return nothing
end

"""
Check if total capacity is mathematically impossible (even with worker reuse)
"""
function check_capacity_violation(ctx::DayContext, found_types::Set{String})
    in("capacity_violation_absolute", found_types) && return nothing
    
    total_slots_needed = sum(task.num_workers for task in ctx.tasks_on_day)
    max_possible_slots = ctx.available_workers * length(ctx.tasks_on_day)
    
    if total_slots_needed > max_possible_slots
        return Dict(
            "type" => "capacity_violation_absolute",
            "day" => ctx.day,
            "needed" => total_slots_needed,
            "max_possible" => max_possible_slots,
            "num_tasks" => length(ctx.tasks_on_day),
            "available_workers" => ctx.available_workers
        )
    end
    return nothing
end

"""
Check if NoConsecutiveTasks constraint makes the day impossible
"""
function check_consecutive_impossibility(ctx::DayContext, scheduler::AutransScheduler, found_types::Set{String})
    in("consecutive_impossible", found_types) && return nothing
    
    # Check if NoConsecutiveTasks constraint exists
    has_no_consecutive = any(c -> c.constraint isa NoConsecutiveTasksConstraint, scheduler.hard_constraints)
    !has_no_consecutive && return nothing
    
    # Check all pairs of tasks on this day
    for i in 1:length(ctx.tasks_on_day)
        for j in (i+1):length(ctx.tasks_on_day)
            task1 = ctx.tasks_on_day[i]
            task2 = ctx.tasks_on_day[j]
            
            # If these tasks can't overlap and together need more workers than available
            min_workers_needed = task1.num_workers + task2.num_workers
            if min_workers_needed > ctx.available_workers
                return Dict(
                    "type" => "consecutive_impossible",
                    "day" => ctx.day,
                    "task1" => task1.name,
                    "task2" => task2.name,
                    "min_workers_needed" => min_workers_needed,
                    "available" => ctx.available_workers
                )
            end
        end
    end
    return nothing
end

"""
Detect obvious infeasibilities using simple arithmetic (no solver needed)
Returns vector of issue dictionaries, or empty vector if no obvious issues found
"""
function detect_obvious_infeasibilities(scheduler::AutransScheduler, N::Int, D::Int)
    issues = []
    found_types = Set{String}()
    max_types = 3  # task_impossible, capacity_violation_absolute, consecutive_impossible
    
    for day in 1:D
        # Early exit if we've found all types of issues
        length(found_types) >= max_types && break
        
        # Prepare day context
        ctx = prepare_day_context(day, scheduler)
        isempty(ctx.tasks_on_day) && continue
        
        # Try each check - add issue if found and update found_types
        for check_fn in [check_task_impossibility, check_capacity_violation]
            issue = check_fn(ctx, found_types)
            if issue !== nothing
                push!(issues, issue)
                push!(found_types, issue["type"])
            end
        end
        
        # Consecutive check needs scheduler parameter
        if length(found_types) < max_types
            issue = check_consecutive_impossibility(ctx, scheduler, found_types)
            if issue !== nothing
                push!(issues, issue)
                push!(found_types, issue["type"])
            end
        end
    end
    
    return issues
end


# ============================================================================
# SOLVER FUNCTIONS
# ============================================================================

"""
Apply hard constraints and collect objective terms
"""
function apply_hard_constraints(model, assign, scheduler::AutransScheduler, N::Int, D::Int, T::Int)
    objective_terms = []
    
    for constraint in scheduler.hard_constraints
        obj_result = apply!(model, assign, scheduler, constraint, N, D, T)
        obj_result !== nothing && push!(objective_terms, obj_result)
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
        obj_result = apply!(model, assign, scheduler, constraint, N, D, T, relaxation)
        obj_result !== nothing && push!(objective_terms, obj_result)
    end
    
    # Set objective function if there are any objective terms
    !isempty(objective_terms) && @objective(model, Min, sum(objective_terms))
    
    return nothing
end

"""
Solve at a specific relaxation level (creates new model each time)
"""
function solve_at_level(scheduler::AutransScheduler, N::Int, D::Int, T::Int, 
                       relaxation_levels::Vector{Int})
    model, assign = create_model(scheduler, N, D, T)
    base_objective_terms = apply_hard_constraints(model, assign, scheduler, N, D, T)
    apply_soft_constraints_and_build_objective!(model, assign, scheduler, N, D, T,
                                               relaxation_levels, base_objective_terms)
    optimize!(model)
    return extract_solution(model, assign)
end

"""
Create a model with hard constraints already applied
"""
function create_model_with_hard_constraints(scheduler::AutransScheduler, N::Int, D::Int, T::Int)
    model, assign = create_model(scheduler, N, D, T)
    objective_terms = apply_hard_constraints(model, assign, scheduler, N, D, T)
    return model, assign, objective_terms
end

"""
Solve at a specific relaxation level using a pre-built model with hard constraints
"""
function solve_at_level_with_model(model, assign, scheduler::AutransScheduler, 
                                   N::Int, D::Int, T::Int,
                                   base_objective_terms::Vector,
                                   relaxation_levels::Vector{Int})
    apply_soft_constraints_and_build_objective!(model, assign, scheduler, N, D, T,
                                               relaxation_levels, base_objective_terms)
    optimize!(model)
    return extract_solution(model, assign)
end

# ============================================================================
# MAIN SOLVE FUNCTION
# ============================================================================

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
        
        println("\nDay-by-Day Breakdown:")
        for day_info in capacity_analysis["daily_breakdown"]
            println("  Day $(day_info["day"]): $(day_info["slots_needed"]) slots needed, $(day_info["workers_available"]) workers available")
        end
        println("="^80)
    end
    
    # Pre-check: Detect obvious infeasibilities BEFORE any solver attempts
    if scheduler.verbose
        println("\n🔍 Pre-check: Testing for obvious infeasibilities...")
    end
    
    obvious_issues = detect_obvious_infeasibilities(scheduler, N, D)
    
    if !isempty(obvious_issues)
        if scheduler.verbose
            println("✓ Found obvious infeasibility - skipping solver entirely")
            println("  Detected $(length(obvious_issues)) issue(s) via fast arithmetic checks")
        end
        
        # Generate structured diagnostic data
        diagnostic_data = generate_obvious_diagnostics(obvious_issues)
        
        # Convert to text format for console display
        console_output = format_diagnostics_for_console(diagnostic_data)
        
        if scheduler.verbose && !isempty(console_output)
            println("\n" * "="^80)
            println(diagnostic_data["title"])
            println("="^80)
            for line in console_output[2:end]  # Skip title (already printed)
                println(line)
            end
            println("="^80)
        end
        
        # Store the structured data directly in conflict_analysis as a single JSON-formatted string
        # This allows the UI to parse it properly
        conflict_analysis_json = JSON3.write(diagnostic_data)
        conflict_analysis = [conflict_analysis_json]
        
        failure_info = FailureInfo(0, "OBVIOUSLY_INFEASIBLE", capacity_analysis, String[], conflict_analysis)
        return (nothing, failure_info)
    end
    
    if scheduler.verbose
        println("  No obvious issues detected, proceeding with solver...")
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
    
    solution, status_str = solve_at_level(scheduler, N, D, T, hierarchy[1])
    
    if solution !== nothing
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
        
        # Generic infeasibility message (no IIS analysis)
        conflict_analysis = [
            "Problem is infeasible with current constraints.",
            "",
            "The pre-check did not find obvious issues, but the solver could not find a solution.",
            "",
            "Consider:",
            "  - Add more workers to handle the workload",
            "  - Adjust worker days off",
            "  - Change some hard constraints to soft constraints"
        ]
        
        if scheduler.verbose
            println("\n" * "="^80)
            println("CONFLICT ANALYSIS")
            println("="^80)
            for diagnostic in conflict_analysis
                println(diagnostic)
            end
            println("="^80)
        end
        
        failure_info = FailureInfo(max_level, status_str, capacity_analysis, constraint_details, conflict_analysis)
        return (nothing, failure_info)
    end
    
    if scheduler.verbose
        println("✅ Feasible at maximum relaxation")
    end
    
    # Step 3: Binary search for minimum relaxation needed
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
        
        solution, _ = solve_at_level_with_model(model, assign, scheduler, N, D, T,
                                                base_objective_terms, hierarchy[mid])
        
        if solution !== nothing
            # Found solution at this level - try tighter constraints
            best_solution = solution
            best_level = mid
            high = mid - 1
            scheduler.verbose && println("  ✅ Feasible - trying tighter")
        else
            # Need more relaxation
            low = mid + 1
            scheduler.verbose && println("  ❌ Infeasible - need more relaxation")
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