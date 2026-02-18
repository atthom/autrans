using Oxygen
using HTTP
using JSON3
using ..Autrans

"""
Parse worker data from JSON request
Returns Vector{AutransWorker}
"""
function parse_workers(workers_data)
    workers = AutransWorker[]
    for worker_data in workers_data
        name = worker_data[1]
        # Convert JSON array to Vector{Int64}
        days_off = length(worker_data) >= 2 ? Vector{Int}(worker_data[2]) : Int[]
        push!(workers, AutransWorker(name, days_off))
    end
    return workers
end

"""
Parse task data from JSON request
Returns Vector{AutransTask}
"""
function parse_tasks(tasks_data)
    tasks = AutransTask[]
    for task_data in tasks_data
        name = task_data[1]
        num_workers = task_data[2]
        # task_data[3] is difficulty (not used in current implementation)
        day_start = task_data[4]
        day_end = task_data[5]
        push!(tasks, AutransTask(name, num_workers, day_start:day_end))
    end
    return tasks
end

"""
Convert schedule array to display format (Tasks × Days)
"""
function schedule_to_display(schedule, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    
    columns = []
    colindex = Dict("names" => ["Tasks"])
    
    # First column: task names
    task_names = [task.name for task in scheduler.tasks]
    push!(columns, task_names)
    
    # Subsequent columns: workers assigned per day
    for d in 1:D
        day_col = String[]
        for (t, task) in enumerate(scheduler.tasks)
            if d ∈ task.day_range
                workers_assigned = [scheduler.workers[w].name for w in 1:N if schedule[w, d, t] == 1]
                push!(day_col, isempty(workers_assigned) ? "-" : join(workers_assigned, ", "))
            else
                push!(day_col, "-")
            end
        end
        push!(columns, day_col)
        push!(colindex["names"], "Day $d")
    end
    
    return Dict("columns" => columns, "colindex" => colindex)
end

"""
Convert schedule to time aggregation (Days × Workers)
"""
function schedule_to_time_agg(schedule, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    
    columns = []
    colindex = Dict("names" => ["Days"])
    
    # First column: day names
    day_names = ["Day $d" for d in 1:D]
    push!(day_names, "TOTAL")
    push!(columns, day_names)
    
    # Subsequent columns: tasks per day per worker
    for (w, worker) in enumerate(scheduler.workers)
        worker_col = String[]
        for d in 1:D
            count = sum(schedule[w, d, t] for t in 1:T)
            is_day_off = d in worker.days_off
            push!(worker_col, is_day_off ? "$count*" : "$count")
        end
        total = sum(schedule[w, :, :])
        has_any_day_off = !isempty(worker.days_off ∩ Set(1:D))
        push!(worker_col, has_any_day_off ? "$total*" : "$total")
        push!(columns, worker_col)
        push!(colindex["names"], worker.name)
    end
    
    # Total column
    total_col = String[]
    for d in 1:D
        push!(total_col, string(sum(schedule[:, d, :])))
    end
    push!(total_col, string(sum(schedule)))
    push!(columns, total_col)
    push!(colindex["names"], "TOTAL")
    
    return Dict("columns" => columns, "colindex" => colindex)
end

"""
Convert schedule to jobs aggregation (Tasks × Workers)
"""
function schedule_to_jobs_agg(schedule, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    
    columns = []
    colindex = Dict("names" => ["Tasks"])
    
    # First column: task names
    task_names = [task.name for task in scheduler.tasks]
    push!(task_names, "TOTAL")
    push!(columns, task_names)
    
    # Subsequent columns: total assignments per task per worker
    for (w, worker) in enumerate(scheduler.workers)
        worker_col = String[]
        for t in 1:T
            count = sum(schedule[w, d, t] for d in 1:D)
            has_day_off = any(d in worker.days_off for d in scheduler.tasks[t].day_range if d <= D)
            push!(worker_col, has_day_off ? "$count*" : "$count")
        end
        total = sum(schedule[w, :, :])
        has_any_day_off = !isempty(worker.days_off ∩ Set(1:D))
        push!(worker_col, has_any_day_off ? "$total*" : "$total")
        push!(columns, worker_col)
        push!(colindex["names"], worker.name)
    end
    
    # Total column
    total_col = String[]
    for t in 1:T
        push!(total_col, string(sum(schedule[:, :, t])))
    end
    push!(total_col, string(sum(schedule)))
    push!(columns, total_col)
    push!(colindex["names"], "TOTAL")
    
    return Dict("columns" => columns, "colindex" => colindex)
end

# POST /sat - Check if a schedule is feasible (SAT check)
@post "/sat" function(req::HTTP.Request)
    try
        # Parse JSON request
        body = JSON3.read(String(req.body))
        
        # Extract parameters
        workers = parse_workers(body.workers)
        tasks = parse_tasks(body.tasks)
        nb_days = body.nb_days
        balance_daysoff = get(body, :balance_daysoff, false)
        
        # Determine equity strategy
        equity_strategy = balance_daysoff ? :proportional : :absolute
        
        # Create scheduler
        scheduler = AutransScheduler(
            workers,
            tasks,
            nb_days,
            equity_strategy=equity_strategy,
            max_solve_time=60.0,
            verbose=false
        )
        
        # Try to solve
        result = solve(scheduler)
        
        if result !== nothing
            return json(Dict(
                "sat" => true,
                "msg" => "Schedule is feasible"
            ))
        else
            return json(Dict(
                "sat" => false,
                "msg" => "No feasible schedule found. Try adjusting constraints or adding more workers."
            ))
        end
        
    catch e
        @error "Error in /sat endpoint" exception=(e, catch_backtrace())
        return json(Dict(
            "sat" => false,
            "msg" => "Error: $(sprint(showerror, e))"
        ), status=500)
    end
end

# POST /schedule - Generate a complete schedule with all views
@post "/schedule" function(req::HTTP.Request)
    try
        # Parse JSON request
        body = JSON3.read(String(req.body))
        
        # Extract parameters
        workers = parse_workers(body.workers)
        tasks = parse_tasks(body.tasks)
        nb_days = body.nb_days
        balance_daysoff = get(body, :balance_daysoff, false)
        
        # Determine equity strategy
        equity_strategy = balance_daysoff ? :proportional : :absolute
        
        # Create scheduler
        scheduler = AutransScheduler(
            workers,
            tasks,
            nb_days,
            equity_strategy=equity_strategy,
            max_solve_time=300.0,
            verbose=false
        )
        
        # Solve
        result = solve(scheduler)
        
        if result === nothing
            return json(Dict(
                "error" => "No feasible schedule found"
            ), status=400)
        end
        
        # Generate all three views
        display_data = schedule_to_display(result, scheduler)
        time_data = schedule_to_time_agg(result, scheduler)
        jobs_data = schedule_to_jobs_agg(result, scheduler)
        
        return json(Dict(
            "display" => display_data,
            "time" => time_data,
            "jobs" => jobs_data
        ))
        
    catch e
        @error "Error in /schedule endpoint" exception=(e, catch_backtrace())
        return json(Dict(
            "error" => "Error: $(sprint(showerror, e))"
        ), status=500)
    end
end

# GET / - Health check endpoint
@get "/" function()
    return json(Dict(
        "service" => "Autrans API",
        "version" => "0.1.0",
        "status" => "running"
    ))
end

"""
Start the Oxygen server
"""
function start_server(host="127.0.0.1", port=8080)
    @info "Starting Autrans API server on http://$host:$port"
    serve(host=host, port=port, async=false)
end

# Export the start function
export start_server