# Optimization functions for Autrans module


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
function add_task_constraints!(model, assign, scheduler::AutransScheduler, N, D, relaxation_level=0)
    # Each task must have exact number of workers on active days
    for (t, task) in enumerate(scheduler.tasks)
        for d in 1:D
            val = d in task.day_range ? task.num_workers : 0
            @constraint(model, sum(assign[w, d, t] for w in 1:N) == val)
        end
        
        # Per-task workload distribution across workers (soft constraint with relaxation)
        workload = length(task.day_range) * task.num_workers
        workload_per_worker = div(workload, N)
        
        # Apply relaxation to allow flexibility, especially for workers with days off
        lower_bound = max(0, workload_per_worker - relaxation_level)
        upper_bound = workload_per_worker + 1 + relaxation_level
        
        @constraint(model, [w=1:N], sum(assign[w, d, t] for d in 1:D) >= lower_bound)
        @constraint(model, [w=1:N], sum(assign[w, d, t] for d in 1:D) <= upper_bound)
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
Quick feasibility check before attempting full solve
Returns true if problem might be feasible, false if definitely infeasible
"""
function quick_feasibility_check(scheduler::AutransScheduler)
    # Calculate basic capacity
    total_slots = sum(task.num_workers * length(task.day_range) for task in scheduler.tasks)
    available_worker_days = sum(scheduler.num_days - length(worker.days_off ∩ Set(1:scheduler.num_days)) 
                                for worker in scheduler.workers)
    
    # If utilization is over 150%, it's very likely infeasible
    if total_slots > available_worker_days * 1.5
        return false
    end
    
    # Check if any day has impossible requirements
    for d in 1:scheduler.num_days
        workers_needed = sum(task.num_workers for task in scheduler.tasks if d in task.day_range)
        workers_available = count(w -> d ∉ w.days_off, scheduler.workers)
        
        # If any single day needs more workers than available, it's infeasible
        if workers_needed > workers_available
            return false
        end
    end
    
    return true
end

"""
Solve the scheduling optimization problem
Returns a 3D array [worker, day, task] with 0/1 assignments, or nothing if no solution
"""
function solve(scheduler::AutransScheduler)
    N = length(scheduler.workers)
    D = scheduler.num_days
    T = length(scheduler.tasks)
    
    # Quick feasibility check to avoid wasting time on impossible problems
    if !quick_feasibility_check(scheduler)
        return nothing
    end
    
    relaxation_levels = [0, 1, 2, 3]  # Increasing levels of relaxation
    for level in relaxation_levels
        # Create model and add variables
        model, assign = create_model(scheduler, N, D, T)
        
        # Add constraints with relaxation level
        add_task_constraints!(model, assign, scheduler, N, D, level)
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
