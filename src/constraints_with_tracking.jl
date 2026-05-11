# Complete constraint implementations with reference tracking
# This file contains the remaining constraint updates

"""
DaysOffConstraint implementation with tracking
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DaysOffConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    constraint_refs = []
    
    for (w, worker) in enumerate(scheduler.workers)
        days_off_list = [d for d in worker.days_off if 1 <= d <= D]
        if !isempty(days_off_list)
            ref = @constraint(model, sum(assign[w, d, t] for d in days_off_list, t in 1:T) <= relaxation)
            push!(constraint_refs, (ref, Dict(
                "type" => constraint_name,
                "constraint_class" => "DaysOff",
                "worker" => w,
                "worker_name" => worker.name,
                "days_off" => days_off_list,
                "max_tasks" => relaxation,
                "relaxation" => relaxation
            )))
        end
    end
    
    return (nothing, constraint_refs)
end

"""
OverallEquityConstraint implementation (Proportional) with tracking
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{ProportionalEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    constraint_refs = []
    
    total_difficulty = sum(task.num_workers * length(task.day_range) * task.difficulty 
                          for task in scheduler.tasks)
    available_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                               for worker in scheduler.workers)
    
    if available_worker_days == 0
        return (nothing, constraint_refs)
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
            
            ref_lower = @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                                  for d in 1:D, t in 1:T) >= lower)
            push!(constraint_refs, (ref_lower, Dict(
                "type" => constraint_name,
                "constraint_class" => "OverallEquity",
                "bound" => "minimum",
                "worker" => w,
                "worker_name" => worker.name,
                "expected" => expected,
                "lower" => lower,
                "relaxation" => relaxation
            )))
            
            ref_upper = @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                                  for d in 1:D, t in 1:T) <= upper)
            push!(constraint_refs, (ref_upper, Dict(
                "type" => constraint_name,
                "constraint_class" => "OverallEquity",
                "bound" => "maximum",
                "worker" => w,
                "worker_name" => worker.name,
                "expected" => expected,
                "upper" => upper,
                "relaxation" => relaxation
            )))
        end
    end
    
    return (nothing, constraint_refs)
end

"""
OverallEquityConstraint implementation (Absolute) with tracking
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler{AbsoluteEquity},
                          c::OverallEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    constraint_refs = []
    
    total_difficulty = sum(task.num_workers * length(task.day_range) * task.difficulty 
                          for task in scheduler.tasks)
    expected = div(total_difficulty, N)
    normalized_offsets = normalize_offsets(scheduler.workers)
    
    for (w, worker) in enumerate(scheduler.workers)
        adjusted_expected = expected + normalized_offsets[w]
        adjusted_expected = max(0, adjusted_expected)
        
        lower = max(0, adjusted_expected - 1 - relaxation)
        upper = adjusted_expected + 1 + relaxation
        
        ref_lower = @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                              for d in 1:D, t in 1:T) >= lower)
        push!(constraint_refs, (ref_lower, Dict(
            "type" => constraint_name,
            "constraint_class" => "OverallEquity",
            "bound" => "minimum",
            "worker" => w,
            "worker_name" => worker.name,
            "expected" => adjusted_expected,
            "lower" => lower,
            "relaxation" => relaxation
        )))
        
        ref_upper = @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                              for d in 1:D, t in 1:T) <= upper)
        push!(constraint_refs, (ref_upper, Dict(
            "type" => constraint_name,
            "constraint_class" => "OverallEquity",
            "bound" => "maximum",
            "worker" => w,
            "worker_name" => worker.name,
            "expected" => adjusted_expected,
            "upper" => upper,
            "relaxation" => relaxation
        )))
    end
    
    return (nothing, constraint_refs)
end

"""
DailyEquityConstraint implementation with tracking
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::DailyEquityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    constraint_refs = []
    
    total_difficulty = sum(task.num_workers * length(task.day_range) * task.difficulty 
                          for task in scheduler.tasks)
    total_worker_days = sum(D - length(worker.days_off ∩ Set(1:D)) 
                           for worker in scheduler.workers)
    
    if total_worker_days == 0
        return (nothing, constraint_refs)
    end
    
    avg_difficulty_per_day = total_difficulty / total_worker_days
    max_daily_difficulty = ceil(Int, avg_difficulty_per_day) + 1 + relaxation
    
    for (w, worker) in enumerate(scheduler.workers)
        work_days = [d for d in 1:D if d ∉ worker.days_off]
        for d in work_days
            ref = @constraint(model, sum(assign[w, d, t] * scheduler.tasks[t].difficulty 
                                  for t in 1:T) <= max_daily_difficulty)
            push!(constraint_refs, (ref, Dict(
                "type" => constraint_name,
                "constraint_class" => "DailyEquity",
                "worker" => w,
                "worker_name" => worker.name,
                "day" => d,
                "max_daily_difficulty" => max_daily_difficulty,
                "relaxation" => relaxation
            )))
        end
    end
    
    return (nothing, constraint_refs)
end

"""
TaskDiversityConstraint implementation with tracking
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::TaskDiversityConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    constraint_refs = []
    
    for (t, task) in enumerate(scheduler.tasks)
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        lower = max(0, workload_per_worker - relaxation)
        upper = workload_per_worker + 1 + relaxation
        
        for w in 1:N
            ref_lower = @constraint(model, sum(assign[w, d, t] for d in 1:D) >= lower)
            push!(constraint_refs, (ref_lower, Dict(
                "type" => constraint_name,
                "constraint_class" => "TaskDiversity",
                "bound" => "minimum",
                "worker" => w,
                "worker_name" => scheduler.workers[w].name,
                "task" => t,
                "task_name" => task.name,
                "expected_per_worker" => workload_per_worker,
                "lower" => lower,
                "relaxation" => relaxation
            )))
            
            ref_upper = @constraint(model, sum(assign[w, d, t] for d in 1:D) <= upper)
            push!(constraint_refs, (ref_upper, Dict(
                "type" => constraint_name,
                "constraint_class" => "TaskDiversity",
                "bound" => "maximum",
                "worker" => w,
                "worker_name" => scheduler.workers[w].name,
                "task" => t,
                "task_name" => task.name,
                "expected_per_worker" => workload_per_worker,
                "upper" => upper,
                "relaxation" => relaxation
            )))
        end
    end
    
    return (nothing, constraint_refs)
end

"""
WorkerPreferenceConstraint implementation with tracking
Returns the penalty expression and empty constraint list (it's an objective term, not constraints)
"""
function apply_constraint!(model, assign, scheduler::AutransScheduler,
                          c::WorkerPreferenceConstraint, N::Int, D::Int, T::Int, relaxation::Int, constraint_name::String)
    penalties = build_preference_penalties(scheduler, N, T)
    penalty_weight = ifelse(relaxation == 0, 10.0, max(0.1, 2.0 - relaxation * 0.3))
    
    # This constraint doesn't create constraint refs, it returns an objective term
    return (penalty_weight * sum(penalties[w, t] * assign[w, d, t] for w in 1:N, d in 1:D, t in 1:T), [])
end