# Constraint functions for Autrans scheduling
# Note: Constraint type definitions are in structs.jl

# ============================================================================
# Constraint Deduplication
# ============================================================================

"""
Remove duplicate constraints and ensure hard constraints take precedence over soft
"""
function deduplicate_constraints(hard::Vector{Constraint{Val{:HARD}}}, 
                                soft::Vector{Constraint{Val{:SOFT}}})
    # Remove duplicates within each list (keep first occurrence)
    unique_hard = unique(c -> typeof(c.constraint), hard)
    unique_soft = unique(c -> typeof(c.constraint), soft)
    
    # Remove from soft if exists in hard
    hard_types = Set(typeof(c.constraint) for c in unique_hard)
    filtered_soft = filter(c -> typeof(c.constraint) ∉ hard_types, unique_soft)
    
    return unique_hard, filtered_soft
end

# ============================================================================
# Relaxation Hierarchy Generation
# ============================================================================

"""
Generate relaxation hierarchy based on soft constraints and max level.
Returns a vector of relaxation level vectors, where each inner vector contains
the relaxation amount for each soft constraint at that hierarchy level.

Constraints relax in reverse order of priority:
- First constraint (highest priority) relaxes last
- Last constraint (lowest priority) relaxes first
"""
function generate_relaxation_hierarchy(soft_constraints::Vector{Constraint{Val{:SOFT}}}, 
                                      max_level::Int)
    n_constraints = length(soft_constraints)
    hierarchy = Vector{Vector{Int}}()
    
    for level in 0:max_level
        relaxation_levels = Int[]
        for i in 1:n_constraints
            # Priority offset: first constraint has highest offset, relaxes last
            priority_offset = n_constraints - i
            # Calculate relaxation: multiply by 2 for reasonable progression
            relaxation = max(0, (level - priority_offset) * 2)
            push!(relaxation_levels, relaxation)
        end
        push!(hierarchy, relaxation_levels)
    end
    
    return hierarchy
end

# ============================================================================
# Generic Apply Interface
# ============================================================================

"""
Apply a hard constraint (no relaxation)
"""
function apply!(model, assign, scheduler::AutransScheduler, 
                c::Constraint{Val{:HARD}}, N::Int, D::Int, T::Int)
    result = apply_constraint!(model, assign, scheduler, c.constraint, N, D, T)
    # Only return if it's a valid objective expression (not constraints)
    return result isa Union{JuMP.AffExpr, JuMP.QuadExpr, Number} ? result : nothing
end

"""
Apply a soft constraint (with relaxation)
"""
function apply!(model, assign, scheduler::AutransScheduler, 
                c::Constraint{Val{:SOFT}}, N::Int, D::Int, T::Int, relaxation::Int)
    result = apply_constraint!(model, assign, scheduler, c.constraint, N, D, T, relaxation)
    # Only return if it's a valid objective expression (not constraints)
    return result isa Union{JuMP.AffExpr, JuMP.QuadExpr, Number} ? result : nothing
end

# ============================================================================
# Task Coverage Constraint (HARD or SOFT)
# ============================================================================

"""
As HARD: Each task has exactly the required number of workers on active days
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskCoverageConstraint, N::Int, D::Int, T::Int)
    for (t, task) in enumerate(scheduler.tasks)
        for d in 1:D
            val = d in task.day_range ? task.num_workers : 0
            @constraint(model, sum(assign[w, d, t] for w in 1:N) == val)
        end
    end
end

"""
As SOFT: Tasks can be under-covered by up to 'relaxation' workers
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskCoverageConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    for (t, task) in enumerate(scheduler.tasks)
        for d in 1:D
            if d in task.day_range
                required = task.num_workers
                min_workers = max(0, required - relaxation)
                @constraint(model, sum(assign[w, d, t] for w in 1:N) >= min_workers)
                @constraint(model, sum(assign[w, d, t] for w in 1:N) <= required)
            else
                @constraint(model, sum(assign[w, d, t] for w in 1:N) == 0)
            end
        end
    end
end

# ============================================================================
# No Consecutive Tasks Constraint (HARD or SOFT)
# ============================================================================

"""
As HARD: Workers do at most one task per day
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::NoConsecutiveTasksConstraint, N::Int, D::Int, T::Int)
    @constraint(model, [w=1:N, d=1:D], 
                sum(assign[w, d, t] for t in 1:T) <= 1)
end

"""
As SOFT: Workers can do up to (1 + relaxation) tasks per day
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::NoConsecutiveTasksConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    max_tasks_per_day = 1 + relaxation
    @constraint(model, [w=1:N, d=1:D], 
                sum(assign[w, d, t] for t in 1:T) <= max_tasks_per_day)
end

# ============================================================================
# Days Off Constraint (HARD or SOFT)
# ============================================================================

"""
As HARD: Workers cannot work on their days off (strict enforcement)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DaysOffConstraint, N::Int, D::Int, T::Int)
    for (w, worker) in enumerate(scheduler.workers)
        for day in worker.days_off
            if 1 <= day <= D
                @constraint(model, [t=1:T], assign[w, day, t] == 0)
            end
        end
    end
end

"""
As SOFT: Workers can work on days off but it's limited by relaxation
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DaysOffConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    for (w, worker) in enumerate(scheduler.workers)
        days_off_list = [d for d in worker.days_off if 1 <= d <= D]
        if !isempty(days_off_list)
            # Allow at most 'relaxation' tasks on days off
            @constraint(model, 
                sum(assign[w, d, t] for d in days_off_list, t in 1:T) <= relaxation)
        end
    end
end

# ============================================================================
# Overall Equity Constraint (HARD or SOFT)
# ============================================================================

"""
As HARD (Proportional): Workers work exactly proportional to their available days
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{ProportionalEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                               for worker in scheduler.workers)
    
    if available_worker_days == 0
        return
    end
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        if !isempty(work_days)
            expected_float = (length(work_days) / available_worker_days) * total_slots
            expected = round(Int, expected_float)
            # Strict: allow ±1 for rounding
            @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= expected - 1)
            @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= expected + 1)
        end
    end
end

"""
As HARD (Absolute): All workers work exactly the same amount
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{AbsoluteEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    expected = div(total_slots, N)
    # Strict: allow ±1 for rounding
    for w in 1:N
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= expected - 1)
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= expected + 1)
    end
end

"""
As SOFT (Proportional): Workers work proportional to their available days (with relaxation)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{ProportionalEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                               for worker in scheduler.workers)
    
    if available_worker_days == 0
        return
    end
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        if !isempty(work_days)
            expected_float = (length(work_days) / available_worker_days) * total_slots
            expected = round(Int, expected_float)
            lower = max(0, expected - relaxation)
            upper = expected + relaxation + 1
            
            @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= lower)
            @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= upper)
        end
    end
end

"""
As SOFT (Absolute): All workers work the same amount (with relaxation)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{AbsoluteEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    expected = div(total_slots, N)
    lower = max(0, expected - relaxation)
    upper = expected + relaxation + 1
    
    for w in 1:N
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= lower)
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= upper)
    end
end

# ============================================================================
# Daily Equity Constraint (HARD or SOFT)
# ============================================================================

"""
As HARD: Workers do similar amounts of work each day (strict limit)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DailyEquityConstraint, N::Int, D::Int, T::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    total_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                           for worker in scheduler.workers)
    
    if total_worker_days == 0
        return
    end
    
    avg_tasks_per_day = total_slots / total_worker_days
    max_daily = ceil(Int, avg_tasks_per_day) + 1  # Strict: +1 for rounding
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        for d in work_days
            @constraint(model, sum(assign[w, d, t] for t in 1:T) <= max_daily)
        end
    end
end

"""
As SOFT: Workers should do similar amounts of work each day (with relaxation)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DailyEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    total_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                           for worker in scheduler.workers)
    
    if total_worker_days == 0
        return
    end
    
    avg_tasks_per_day = total_slots / total_worker_days
    max_daily = ceil(Int, avg_tasks_per_day) + 1 + relaxation
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        for d in work_days
            @constraint(model, sum(assign[w, d, t] for t in 1:T) <= max_daily)
        end
    end
end

# ============================================================================
# Task Diversity Constraint (HARD or SOFT)
# ============================================================================

"""
As HARD: Each worker must participate in each task fairly (strict)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskDiversityConstraint, N::Int, D::Int, T::Int)
    for (t, task) in enumerate(scheduler.tasks)
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        # Strict: allow ±1 for rounding
        lower = max(0, workload_per_worker - 1)
        upper = workload_per_worker + 1
        
        for w in 1:N
            @constraint(model, sum(assign[w, d, t] for d in 1:D) >= lower)
            @constraint(model, sum(assign[w, d, t] for d in 1:D) <= upper)
        end
    end
end

"""
As SOFT: Each worker should participate in each task fairly (with relaxation)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskDiversityConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    for (t, task) in enumerate(scheduler.tasks)
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        lower = max(0, workload_per_worker - relaxation)
        upper = workload_per_worker + 1 + relaxation
        
        for w in 1:N
            @constraint(model, sum(assign[w, d, t] for d in 1:D) >= lower)
            @constraint(model, sum(assign[w, d, t] for d in 1:D) <= upper)
        end
    end
end

# ============================================================================
# Worker Preference Constraint (HARD or SOFT)
# ============================================================================

"""
Build preference penalty matrix for workers.
Returns a matrix where penalty[w, t] is the penalty for assigning worker w to task t.
Workers with no preferences get 0 penalty for all tasks.
"""
function build_preference_penalties(scheduler::AutransScheduler, N::Int, T::Int)
    penalties = zeros(Int, N, T)
    
    for (w, worker) in enumerate(scheduler.workers)
        if !isempty(worker.task_preferences)
            # Build reverse mapping: task_idx -> preference_rank
            for (rank, task_idx) in enumerate(worker.task_preferences)
                if 1 <= task_idx <= T
                    # Penalty increases with rank: rank 1 = 0, rank 2 = 1, rank 3 = 2, etc.
                    penalties[w, task_idx] = rank - 1
                end
            end
            
            # Tasks not in preferences get highest penalty
            max_penalty = length(worker.task_preferences)
            for t in 1:T
                if penalties[w, t] == 0 && t ∉ worker.task_preferences
                    penalties[w, t] = max_penalty
                end
            end
        end
    end
    
    return penalties
end

"""
As HARD: Strong preference enforcement (high penalty multiplier)
Returns the penalty expression to be added to the objective function.
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::WorkerPreferenceConstraint, N::Int, D::Int, T::Int)
    penalties = build_preference_penalties(scheduler, N, T)
    
    # High penalty multiplier for hard constraint (10x)
    penalty_weight = 10
    
    # Return penalty expression: sum of (penalty * assignment) for all worker-day-task combinations
    return penalty_weight * sum(penalties[w, t] * assign[w, d, t] 
                               for w in 1:N, d in 1:D, t in 1:T)
end

"""
As SOFT: Moderate preference enforcement (lower penalty, affected by relaxation)
Returns the penalty expression to be added to the objective function.
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::WorkerPreferenceConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    penalties = build_preference_penalties(scheduler, N, T)
    
    # Lower penalty multiplier for soft constraint, reduced by relaxation
    # Base weight of 2, reduced as relaxation increases
    penalty_weight = max(0.1, 2.0 - relaxation * 0.3)
    
    # Return penalty expression
    return penalty_weight * sum(penalties[w, t] * assign[w, d, t] 
                               for w in 1:N, d in 1:D, t in 1:T)
end
