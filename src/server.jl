using Oxygen
using HTTP
using JSON3
using Dates
using ..Autrans

"""
Parse worker data from JSON request
Returns Vector{AutransWorker}

Worker data format: [name, days_off, task_preferences, workload_offset]
- name: String
- days_off: Vector{Int} (optional, defaults to [])
- task_preferences: Vector{Int} (optional, defaults to [])
- workload_offset: Int (optional, defaults to 0)
  - Negative: worker should work less (worked too much before)
  - Positive: worker should work more (worked too little before)
  - Zero: no adjustment needed
"""
function parse_workers(workers_data)
    workers = AutransWorker[]
    for worker_data in workers_data
        name = worker_data[1]
        # Convert JSON array to Vector{Int64}
        days_off = length(worker_data) >= 2 ? Vector{Int}(worker_data[2]) : Int[]
        # Task preferences (optional, 1-indexed task indices in preference order)
        task_preferences = length(worker_data) >= 3 ? Vector{Int}(worker_data[3]) : Int[]
        # Workload offset (optional, defaults to 0)
        workload_offset = length(worker_data) >= 4 ? Int(worker_data[4]) : 0
        push!(workers, AutransWorker(name, days_off, task_preferences, workload_offset))
    end
    return workers
end

"""
Parse task data from JSON request
Returns Vector{AutransTask}

Task data format: [name, num_workers, difficulty, day_start, day_end]
- name: String
- num_workers: Int
- difficulty: Int (optional, defaults to 1, must be >= 1)
- day_start: Int
- day_end: Int
"""
function parse_tasks(tasks_data)
    tasks = AutransTask[]
    for task_data in tasks_data
        name = task_data[1]
        num_workers = task_data[2]
        # Parse difficulty (defaults to 1 if not provided or if only 4 elements)
        difficulty = length(task_data) >= 5 ? Int(task_data[3]) : 1
        day_start = length(task_data) >= 5 ? task_data[4] : task_data[3]
        day_end = length(task_data) >= 5 ? task_data[5] : task_data[4]
        push!(tasks, AutransTask(name, num_workers, day_start:day_end, difficulty))
    end
    return tasks
end

"""
Build constraint objects from constraint name strings
"""
function build_constraints(hard_names, soft_names)
    # Convert to regular vectors if needed (handles JSON3 arrays)
    hard_names_vec = collect(hard_names)
    soft_names_vec = collect(soft_names)
    
    # Map constraint names to constraint objects
    constraint_map = Dict(
        "TaskCoverage" => Autrans.TaskCoverageConstraint(),
        "NoConsecutiveTasks" => Autrans.NoConsecutiveTasksConstraint(),
        "DaysOff" => Autrans.DaysOffConstraint(),
        "OverallEquity" => Autrans.OverallEquityConstraint(),
        "DailyEquity" => Autrans.DailyEquityConstraint(),
        "TaskDiversity" => Autrans.TaskDiversityConstraint(),
        "WorkerPreference" => Autrans.WorkerPreferenceConstraint()
    )
    
    # Build hard constraints with proper typing
    hard_constraints = Autrans.Constraint{Val{:HARD}}[]
    for name in hard_names_vec
        if haskey(constraint_map, name)
            push!(hard_constraints, Autrans.HardConstraint(constraint_map[name], name))
        end
    end
    
    # Build soft constraints with proper typing
    soft_constraints = Autrans.Constraint{Val{:SOFT}}[]
    for name in soft_names_vec
        if haskey(constraint_map, name)
            push!(soft_constraints, Autrans.SoftConstraint(constraint_map[name], name))
        end
    end
    
    return hard_constraints, soft_constraints
end

"""
Parse request body and create scheduler with all parameters
Returns (scheduler, params, error_response)
- If successful: (scheduler, params_dict, nothing)
- If error: (nothing, nothing, error_response)
"""
function parse_request_and_create_scheduler(req::HTTP.Request; max_solve_time=300.0)
    try
        body = JSON3.read(String(req.body))
        
        # Parse workers and tasks
        workers = parse_workers(body.workers)
        tasks = parse_tasks(body.tasks)
        nb_days = body.nb_days
        balance_daysoff = get(body, :balance_daysoff, false)
        
        # Get constraints
        hard_names = get(body, :hard_constraints, ["TaskCoverage", "NoConsecutiveTasks", "DaysOff"])
        soft_names = get(body, :soft_constraints, ["OverallEquity", "DailyEquity", "TaskDiversity"])
        hard_constraints, soft_constraints = build_constraints(hard_names, soft_names)
        
        # Create scheduler
        equity_strategy = balance_daysoff ? :proportional : :absolute
        scheduler = AutransScheduler(
            workers, tasks, nb_days,
            equity_strategy=equity_strategy,
            max_solve_time=max_solve_time,
            verbose=false,
            hard_constraints=hard_constraints,
            soft_constraints=soft_constraints
        )
        
        # Additional params (for export endpoints)
        params = Dict(
            "start_date" => get(body, :start_date, string(today())),
            "trip_name" => get(body, :trip_name, "Schedule"),
            "nb_days" => nb_days
        )
        
        return (scheduler, params, nothing)
        
    catch e
        @error "Error parsing request" exception=(e, catch_backtrace())
        error_response = json(Dict("error" => "Error: $(sprint(showerror, e))"), status=400)
        return (nothing, nothing, error_response)
    end
end

"""
Build detailed failure response from FailureInfo
"""
function build_failure_response(failure_info)
    if failure_info === nothing
        return Dict(
            "error" => "No feasible schedule found",
            "msg" => "Try adjusting constraints or adding more workers."
        )
    end
    
    msg = "Schedule is not feasible.\n\n"
    msg *= "Capacity Analysis:\n"
    msg *= "- Total slots needed: $(failure_info.capacity_analysis["total_slots"])\n"
    msg *= "- Available worker-days: $(failure_info.capacity_analysis["available_worker_days"])\n"
    msg *= "- Utilization: $(failure_info.capacity_analysis["utilization_percent"])%\n"
    
    if !isempty(failure_info.capacity_analysis["daily_issues"])
        msg *= "\nDaily Capacity Issues:\n"
        for issue in failure_info.capacity_analysis["daily_issues"]
            msg *= "- $issue\n"
        end
    end
    
    msg *= "\nFailed at relaxation level $(failure_info.level)\n"
    msg *= "Constraint requirements that couldn't be satisfied:\n"
    for detail in failure_info.constraint_details[1:min(5, length(failure_info.constraint_details))]
        msg *= "- $detail\n"
    end
    
    return Dict(
        "error" => msg,
        "msg" => msg,
        "details" => Dict(
            "capacity" => failure_info.capacity_analysis,
            "failed_level" => failure_info.level,
            "constraints" => failure_info.constraint_details
        )
    )
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
Shows both task count and difficulty points: "count (difficulty pts)"
"""
function schedule_to_time_agg(schedule, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    columns = []
    colindex = Dict("names" => ["Days"])
    
    # First column: day names
    day_names = ["Day $d" for d in 1:D]
    push!(day_names, "TOTAL")
    push!(columns, day_names)
    
    # Subsequent columns: tasks per day per worker (with difficulty points)
    for (w, worker) in enumerate(scheduler.workers)
        worker_col = String[]
        for d in 1:D
            count = sum(schedule[w, d, t] for t in 1:T)
            difficulty_pts = sum(schedule[w, d, t] * scheduler.tasks[t].difficulty for t in 1:T)
            is_day_off = d in worker.days_off
            display_str = "$count ($(difficulty_pts) pts)"
            push!(worker_col, is_day_off ? "$display_str*" : display_str)
        end
        total_count = sum(schedule[w, :, :])
        total_difficulty = sum(schedule[w, d, t] * scheduler.tasks[t].difficulty 
                              for d in 1:D, t in 1:T)
        has_any_day_off = !isempty(worker.days_off ∩ Set(1:D))
        display_str = "$total_count ($(total_difficulty) pts)"
        push!(worker_col, has_any_day_off ? "$display_str*" : display_str)
        push!(columns, worker_col)
        push!(colindex["names"], worker.name)
    end
    
    # Total column
    total_col = String[]
    for d in 1:D
        count = sum(schedule[:, d, :])
        difficulty_pts = sum(schedule[w, d, t] * scheduler.tasks[t].difficulty 
                            for w in 1:N, t in 1:T)
        push!(total_col, "$count ($(difficulty_pts) pts)")
    end
    total_count = sum(schedule)
    total_difficulty = sum(schedule[w, d, t] * scheduler.tasks[t].difficulty 
                          for w in 1:N, d in 1:D, t in 1:T)
    push!(total_col, "$total_count ($(total_difficulty) pts)")
    push!(columns, total_col)
    push!(colindex["names"], "TOTAL")
    
    return Dict("columns" => columns, "colindex" => colindex)
end

"""
Convert schedule to jobs aggregation (Tasks × Workers)
Shows both task count and difficulty points: "count (difficulty pts)"
"""
function schedule_to_jobs_agg(schedule, scheduler::AutransScheduler)
    N, D, T = size(schedule)
    
    columns = []
    colindex = Dict("names" => ["Tasks"])
    
    # First column: task names
    task_names = [task.name for task in scheduler.tasks]
    push!(task_names, "TOTAL")
    push!(columns, task_names)
    
    # Subsequent columns: total assignments per task per worker (with difficulty points)
    for (w, worker) in enumerate(scheduler.workers)
        worker_col = String[]
        for t in 1:T
            count = sum(schedule[w, d, t] for d in 1:D)
            difficulty_pts = count * scheduler.tasks[t].difficulty
            has_day_off = any(d in worker.days_off for d in scheduler.tasks[t].day_range if d <= D)
            display_str = "$count ($(difficulty_pts) pts)"
            push!(worker_col, has_day_off ? "$display_str*" : display_str)
        end
        total_count = sum(schedule[w, :, :])
        total_difficulty = sum(schedule[w, d, t] * scheduler.tasks[t].difficulty 
                              for d in 1:D, t in 1:T)
        has_any_day_off = !isempty(worker.days_off ∩ Set(1:D))
        display_str = "$total_count ($(total_difficulty) pts)"
        push!(worker_col, has_any_day_off ? "$display_str*" : display_str)
        push!(columns, worker_col)
        push!(colindex["names"], worker.name)
    end
    
    # Total column
    total_col = String[]
    for t in 1:T
        count = sum(schedule[:, :, t])
        difficulty_pts = count * scheduler.tasks[t].difficulty
        push!(total_col, "$count ($(difficulty_pts) pts)")
    end
    total_count = sum(schedule)
    total_difficulty = sum(schedule[w, d, t] * scheduler.tasks[t].difficulty 
                          for w in 1:N, d in 1:D, t in 1:T)
    push!(total_col, "$total_count ($(total_difficulty) pts)")
    push!(columns, total_col)
    push!(colindex["names"], "TOTAL")
    
    return Dict("columns" => columns, "colindex" => colindex)
end

# POST /sat - Check if a schedule is feasible (SAT check)
@post "/sat" function(req::HTTP.Request)
    # Parse request and create scheduler
    scheduler, params, error_response = parse_request_and_create_scheduler(req, max_solve_time=60.0)
    if error_response !== nothing
        return error_response
    end
    
    # Try to solve
    result, failure_info = solve(scheduler)
    
    if result !== nothing
        return json(Dict(
            "sat" => true,
            "msg" => "Schedule is feasible"
        ))
    else
        # Build failure response
        failure_dict = build_failure_response(failure_info)
        return json(Dict(
            "sat" => false,
            "msg" => failure_dict["msg"],
            "details" => get(failure_dict, "details", nothing)
        ))
    end
end

# POST /schedule - Generate a complete schedule with all views
@post "/schedule" function(req::HTTP.Request)
    # Parse request and create scheduler
    scheduler, params, error_response = parse_request_and_create_scheduler(req)
    if error_response !== nothing
        return error_response
    end
    
    # Solve
    result, failure_info = solve(scheduler)
    
    if result === nothing
        # Build failure response
        failure_dict = build_failure_response(failure_info)
        return json(failure_dict, status=400)
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
end

"""
Generate iCalendar (.ics) format from schedule
"""
function generate_icalendar(schedule, scheduler::AutransScheduler, start_date_str::String)
    N, D, T = size(schedule)
    
    # Parse start date (format: YYYY-MM-DD)
    start_date = Date(start_date_str)
    
    # iCalendar header
    ics = "BEGIN:VCALENDAR\r\n"
    ics *= "VERSION:2.0\r\n"
    ics *= "PRODID:-//Autrans//Scheduler//EN\r\n"
    ics *= "CALSCALE:GREGORIAN\r\n"
    ics *= "METHOD:PUBLISH\r\n"
    ics *= "X-WR-CALNAME:Autrans Schedule\r\n"
    ics *= "X-WR-TIMEZONE:UTC\r\n"
    
    # Generate events for each assignment
    for d in 1:D
        event_date = start_date + Day(d - 1)
        date_str = Dates.format(event_date, "yyyymmdd")
        
        for (t, task) in enumerate(scheduler.tasks)
            if d ∈ task.day_range
                # Get assigned workers for this task on this day
                assigned_workers = [scheduler.workers[w].name for w in 1:N if schedule[w, d, t] == 1]
                
                if !isempty(assigned_workers)
                    # Create unique ID
                    uid = "autrans-$(task.name)-day$(d)-$(join(assigned_workers, "-"))@autrans.app"
                    uid = replace(uid, " " => "-")
                    
                    # Event times (9 AM to 5 PM)
                    dtstart = "$(date_str)T090000"
                    dtend = "$(date_str)T170000"
                    
                    # Create event
                    ics *= "BEGIN:VEVENT\r\n"
                    ics *= "UID:$(uid)\r\n"
                    ics *= "DTSTAMP:$(Dates.format(now(), "yyyymmdd"))T$(Dates.format(now(), "HHMMSS"))Z\r\n"
                    ics *= "DTSTART:$(dtstart)\r\n"
                    ics *= "DTEND:$(dtend)\r\n"
                    ics *= "SUMMARY:$(task.name) - $(join(assigned_workers, ", "))\r\n"
                    ics *= "DESCRIPTION:Task: $(task.name)\\nAssigned: $(join(assigned_workers, ", "))\r\n"
                    ics *= "CATEGORIES:$(task.name)\r\n"
                    ics *= "STATUS:CONFIRMED\r\n"
                    ics *= "END:VEVENT\r\n"
                end
            end
        end
    end
    
    ics *= "END:VCALENDAR\r\n"
    return ics
end

"""
Generate CSV format from schedule
"""
function generate_csv(schedule, scheduler::AutransScheduler, start_date_str::String)
    N, D, T = size(schedule)
    
    # Parse start date
    start_date = Date(start_date_str)
    
    # CSV header
    csv = "Date,Day,Task,Assigned Workers\r\n"
    
    # Generate rows for each assignment
    for d in 1:D
        event_date = start_date + Day(d - 1)
        date_str = Dates.format(event_date, "yyyy-mm-dd")
        day_name = Dates.dayname(event_date)
        
        for (t, task) in enumerate(scheduler.tasks)
            if d ∈ task.day_range
                # Get assigned workers for this task on this day
                assigned_workers = [scheduler.workers[w].name for w in 1:N if schedule[w, d, t] == 1]
                
                if !isempty(assigned_workers)
                    workers_str = join(assigned_workers, "; ")
                    csv *= "$(date_str),$(day_name),$(task.name),\"$(workers_str)\"\r\n"
                end
            end
        end
    end
    
    return csv
end

# POST /export/ics - Export schedule as iCalendar
@post "/export/ics" function(req::HTTP.Request)
    # Parse request and create scheduler
    scheduler, params, error_response = parse_request_and_create_scheduler(req)
    if error_response !== nothing
        return error_response
    end
    
    # Solve
    result, failure_info = solve(scheduler)
    
    if result === nothing
        return json(Dict("error" => "Cannot export: schedule is not feasible"), status=400)
    end
    
    # Generate iCalendar
    ics_content = generate_icalendar(result, scheduler, params["start_date"])
    
    # Generate filename
    safe_trip_name = replace(params["trip_name"], r"[^a-zA-Z0-9_-]" => "_")
    filename = "Schedule-$(safe_trip_name)-$(params["start_date"])-$(params["nb_days"])days.ics"
    
    # Return as downloadable file
    return HTTP.Response(
        200,
        ["Content-Type" => "text/calendar; charset=utf-8",
         "Content-Disposition" => "attachment; filename=\"$(filename)\""],
        body=ics_content
    )
end

# POST /export/csv - Export schedule as CSV
@post "/export/csv" function(req::HTTP.Request)
    # Parse request and create scheduler
    scheduler, params, error_response = parse_request_and_create_scheduler(req)
    if error_response !== nothing
        return error_response
    end
    
    # Solve
    result, failure_info = solve(scheduler)
    
    if result === nothing
        return json(Dict("error" => "Cannot export: schedule is not feasible"), status=400)
    end
    
    # Generate CSV
    csv_content = generate_csv(result, scheduler, params["start_date"])
    
    # Generate filename
    safe_trip_name = replace(params["trip_name"], r"[^a-zA-Z0-9_-]" => "_")
    filename = "Schedule-$(safe_trip_name)-$(params["start_date"])-$(params["nb_days"])days.csv"
    
    # Return as downloadable file
    return HTTP.Response(
        200,
        ["Content-Type" => "text/csv; charset=utf-8",
         "Content-Disposition" => "attachment; filename=\"$(filename)\""],
        body=csv_content
    )
end

# GET / - Health check endpoint
@get "/" function()
    return json(Dict(
        "service" => "Autrans API",
        "version" => "0.1.0",
        "status" => "running",
        "endpoints" => Dict(
            "POST /sat" => "Check if a schedule is feasible (SAT check)",
            "POST /schedule" => "Generate a complete schedule with all views",
            "POST /export/ics" => "Export schedule as iCalendar (.ics) file",
            "POST /export/csv" => "Export schedule as CSV file"
        ),
        "export_formats" => Dict(
            "ics" => Dict(
                "description" => "iCalendar format for calendar applications",
                "compatible_with" => ["Microsoft Outlook", "Google Calendar", "Apple Calendar"],
                "filename_format" => "Schedule-{trip_name}-{start_date}-{duration}days.ics"
            ),
            "csv" => Dict(
                "description" => "CSV format for spreadsheet applications",
                "compatible_with" => ["Microsoft Excel", "Google Sheets", "LibreOffice Calc"],
                "filename_format" => "Schedule-{trip_name}-{start_date}-{duration}days.csv"
            )
        )
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