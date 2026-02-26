
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
Returns objective_expression or nothing
"""
function apply!(model, assign, scheduler::AutransScheduler, 
                c::Constraint{Val{:HARD}}, N::Int, D::Int, T::Int)
    # Hard constraints are just soft constraints with relaxation=0
    return apply_constraint!(model, assign, scheduler, c.constraint, N, D, T, 0, c.name)
end

"""
Apply a soft constraint (with relaxation)
Returns objective_expression or nothing
"""
function apply!(model, assign, scheduler::AutransScheduler, 
                c::Constraint{Val{:SOFT}}, N::Int, D::Int, T::Int, relaxation::Int)
    return apply_constraint!(model, assign, scheduler, c.constraint, N, D, T, relaxation, c.name)
end

"""
TaskCoverageConstraint implementation
When relaxation=0: Each task has exactly the required number of workers (hard constraint)
When relaxation>0: Tasks can be under-covered by up to 'relaxation' workers (soft constraint)
Returns nothing
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskCoverageConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
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
    
    return nothing
end

"""
NoConsecutiveTasksConstraint implementation
When relaxation=0: Workers cannot do consecutive tasks (t and t+1) on the same day (hard constraint)
When relaxation>0: Workers can do up to 'relaxation' pairs of consecutive tasks per day (soft constraint)
Note: Workers CAN do multiple non-consecutive tasks on the same day
Returns nothing
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::NoConsecutiveTasksConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    # Prevent workers from doing consecutive tasks (t and t+1) on the same day
    for w in 1:N, d in 1:D
        for t in 1:(T-1)
            @constraint(model, assign[w, d, t] + assign[w, d, t+1] <= 1 + relaxation)
        end
    end
    
    return nothing
end

"""
DaysOffConstraint implementation
When relaxation=0: Workers cannot work on their days off (hard constraint)
When relaxation>0: Workers can work up to 'relaxation' tasks on days off (soft constraint)
Returns nothing
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DaysOffConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    for (w, worker) in enumerate(scheduler.workers)
        days_off_list = [d for d in worker.days_off if 1 <= d <= D]
        if !isempty(days_off_list)
            @constraint(model, sum(assign[w, d, t] for d in days_off_list, t in 1:T) <= relaxation)
        end
    end
    
    return nothing
end


"""
OverallEquityConstraint implementation (Proportional)
When relaxation=0: Workers work exactly proportional to available days (hard constraint, ±1 difficulty point)
When relaxation>0: Workers work proportional with tolerance (soft constraint)
Supports workload_offset: negative = work less, positive = work more (in difficulty points)
Uses difficulty-weighted workload: workload = sum(tasks × difficulty)
Returns nothing
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{ProportionalEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    total_difficulty = sum(task.num_workers * length(task.day_range) * task.difficulty 
                          for task in scheduler.tasks)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                               for worker in scheduler.workers)
    
    if available_worker_days == 0
        return nothing
    end
    
    normalized_offsets = normalize_offsets(scheduler.workers)
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        if !isempty(work_days)
            expected_float = (length(work_days) / available_worker_days) * total_difficulty
            expected = round(Int, expected_float)
            expected = expected + normalized_offsets[w]
            expected = max(0, expected)
            
            lower = max(0, expected - 1 - relaxation)
            upper = expected + 1 + relaxation
            
            @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                                  for d in 1:D, t in 1:T) >= lower)
            @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                                  for d in 1:D, t in 1:T) <= upper)
        end
    end
    
    return nothing
end

"""
OverallEquityConstraint implementation (Absolute)
When relaxation=0: All workers work exactly the same amount (hard constraint, ±1 difficulty point)
When relaxation>0: All workers work similar amounts with tolerance (soft constraint)
Supports workload_offset: negative = work less, positive = work more (in difficulty points)
Uses difficulty-weighted workload: workload = sum(tasks × difficulty)
Returns nothing
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{AbsoluteEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    total_difficulty = sum(task.num_workers * length(task.day_range) * task.difficulty 
                          for task in scheduler.tasks)
    expected = div(total_difficulty, N)
    normalized_offsets = normalize_offsets(scheduler.workers)
    
    for (w, worker) in enumerate(scheduler.workers)
        adjusted_expected = expected + normalized_offsets[w]
        adjusted_expected = max(0, adjusted_expected)
        
        lower = max(0, adjusted_expected - 1 - relaxation)
        upper = adjusted_expected + 1 + relaxation
        
        @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                              for d in 1:D, t in 1:T) >= lower)
        @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                              for d in 1:D, t in 1:T) <= upper)
    end
    
    return nothing
end


"""
DailyEquityConstraint implementation
When relaxation=0: Workers do similar amounts each day (hard constraint, ±1 difficulty point)
When relaxation>0: Workers can do more per day with tolerance (soft constraint)
Uses difficulty-weighted workload: daily workload = sum(tasks × difficulty)
Returns nothing
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DailyEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    total_difficulty = sum(task.num_workers * length(task.day_range) * task.difficulty 
                          for task in scheduler.tasks)
    total_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                           for worker in scheduler.workers)
    
    if total_worker_days == 0
        return nothing
    end
    
    avg_difficulty_per_day = total_difficulty / total_worker_days
    max_daily_difficulty = ceil(Int, avg_difficulty_per_day) + 1 + relaxation
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        for d in work_days
            @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                                  for t in 1:T) <= max_daily_difficulty)
        end
    end
    
    return nothing
end

"""
TaskDiversityConstraint implementation
When relaxation=0: Each worker participates in each task fairly (hard constraint, ±1 for rounding)
When relaxation>0: Workers can have uneven task participation with tolerance (soft constraint)
Returns nothing
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskDiversityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
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
    
    return nothing
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
Returns penalty_expression - this is an objective term, not constraints
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::WorkerPreferenceConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    penalties = build_preference_penalties(scheduler, N, T)
    penalty_weight = ifelse(relaxation == 0, 10.0, max(0.1, 2.0 - relaxation * 0.3))
    
    # This constraint returns an objective term to minimize
    return penalty_weight * sum(penalties[w, t] * assign[w, d, t] for w in 1:N, d in 1:D, t in 1:T)
end
