
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

"""
Normalize workload offsets so at least one worker has offset=0
This prevents infeasibility when all offsets are positive or all negative

Returns a vector of normalized offsets in the same order as workers
"""
function normalize_offsets(workers::Vector{AutransWorker})
    offsets = [w.workload_offset for w in workers]
    
    # If all offsets are the same, no normalization needed
    if all(o == offsets[1] for o in offsets)
        return offsets
    end
    
    # Find the adjustment needed
    all_negative = all(o <= 0 for o in offsets)
    all_positive = all(o >= 0 for o in offsets)
    
    if all_negative
        # Remove the maximum (least negative) to bring someone to 0
        adjustment = maximum(offsets)
        return [o - adjustment for o in offsets]
    elseif all_positive
        # Remove the minimum to bring someone to 0
        adjustment = minimum(offsets)
        return [o - adjustment for o in offsets]
    else
        # Mixed positive/negative - already normalized (has at least one zero or crosses zero)
        return offsets
    end
end


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

"""
Apply a hard constraint (no relaxation)
Delegates to the soft constraint implementation with relaxation=0
"""
function apply!(model, assign, scheduler::AutransScheduler, 
                c::Constraint{Val{:HARD}}, N::Int, D::Int, T::Int)
    # Hard constraints are just soft constraints with relaxation=0
    result = apply_constraint!(model, assign, scheduler, c.constraint, N, D, T, 0)
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

"""
TaskCoverageConstraint implementation
When relaxation=0: Each task has exactly the required number of workers (hard constraint)
When relaxation>0: Tasks can be under-covered by up to 'relaxation' workers (soft constraint)
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

"""
NoConsecutiveTasksConstraint implementation
When relaxation=0: Workers do at most one task per day (hard constraint)
When relaxation>0: Workers can do 1+relaxation tasks per day (soft constraint)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::NoConsecutiveTasksConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    max_tasks_per_day = 1 + relaxation
    @constraint(model, [w=1:N, d=1:D], sum(assign[w, d, t] for t in 1:T) <= max_tasks_per_day)
end

"""
DaysOffConstraint implementation
When relaxation=0: Workers cannot work on their days off (hard constraint)
When relaxation>0: Workers can work up to 'relaxation' tasks on days off (soft constraint)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DaysOffConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    for (w, worker) in enumerate(scheduler.workers)
        days_off_list = [d for d in worker.days_off if 1 <= d <= D]
        if !isempty(days_off_list)
            # Allow at most 'relaxation' tasks on days off
            @constraint(model, sum(assign[w, d, t] for d in days_off_list, t in 1:T) <= relaxation)
        end
    end
end


"""
OverallEquityConstraint implementation (Proportional)
When relaxation=0: Workers work exactly proportional to available days (hard constraint, ±1 for rounding)
When relaxation>0: Workers work proportional with tolerance (soft constraint)
Supports workload_offset: negative = work less, positive = work more
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{ProportionalEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                               for worker in scheduler.workers)
    
    if available_worker_days == 0
        return
    end
    
    # Normalize workload offsets
    normalized_offsets = normalize_offsets(scheduler.workers)
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        if !isempty(work_days)
            # Calculate base expected workload
            expected_float = (length(work_days) / available_worker_days) * total_slots
            expected = round(Int, expected_float)
            
            # Apply normalized offset
            expected = expected + normalized_offsets[w]
            expected = max(0, expected)  # Can't be negative
            
            lower = max(0, expected - relaxation)
            upper = expected + relaxation + 1
            
            @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= lower)
            @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= upper)
        end
    end
end

"""
OverallEquityConstraint implementation (Absolute)
When relaxation=0: All workers work exactly the same amount (hard constraint, ±1 for rounding)
When relaxation>0: All workers work similar amounts with tolerance (soft constraint)
Supports workload_offset: negative = work less, positive = work more
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{AbsoluteEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    expected = div(total_slots, N)
    
    # Normalize workload offsets
    normalized_offsets = normalize_offsets(scheduler.workers)
    
    for (w, worker) in enumerate(scheduler.workers)
        # Apply normalized offset
        adjusted_expected = expected + normalized_offsets[w]
        adjusted_expected = max(0, adjusted_expected)  # Can't be negative
        
        lower = max(0, adjusted_expected - relaxation)
        upper = adjusted_expected + relaxation + 1
        
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) >= lower)
        @constraint(model, sum(assign[w, d, t] for d in 1:D, t in 1:T) <= upper)
    end
end


"""
DailyEquityConstraint implementation
When relaxation=0: Workers do similar amounts each day (hard constraint, +1 for rounding)
When relaxation>0: Workers can do more tasks per day with tolerance (soft constraint)
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

"""
TaskDiversityConstraint implementation
When relaxation=0: Each worker participates in each task fairly (hard constraint, ±1 for rounding)
When relaxation>0: Workers can have uneven task participation with tolerance (soft constraint)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskDiversityConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    for (t, task) in enumerate(scheduler.tasks)
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        lower = max(0, workload_per_worker - relaxation)
        upper = workload_per_worker + 1 + relaxation
        
        @constraint(model, [w in 1:N], sum(assign[w, d, t] for d in 1:D) >= lower)
        @constraint(model, [w in 1:N], sum(assign[w, d, t] for d in 1:D) <= upper)
    end
end

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
WorkerPreferenceConstraint implementation
When relaxation=0: Strong preference enforcement with high penalty (hard constraint)
When relaxation>0: Moderate preference enforcement with lower penalty (soft constraint)
Returns the penalty expression to be added to the objective function.
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::WorkerPreferenceConstraint, N::Int, D::Int, T::Int, relaxation::Int)
    penalties = build_preference_penalties(scheduler, N, T)
    
    # Penalty weight depends on relaxation
    # relaxation=0 (hard): high weight (10x)
    # relaxation>0 (soft): lower weight, reduced by relaxation
    penalty_weight = ifelse(relaxation == 0, 10.0, max(0.1, 2.0 - relaxation * 0.3))
    
    return penalty_weight * sum(penalties[w, t] * assign[w, d, t] for w in 1:N, d in 1:D, t in 1:T)
end
