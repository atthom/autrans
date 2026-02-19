using Oxygen
using HTTP
using JSON3
using Dates
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
        result, failure_info = solve(scheduler)
        
        if result !== nothing
            return json(Dict(
                "sat" => true,
                "msg" => "Schedule is feasible"
            ))
        else
            # Build detailed failure message
            if failure_info !== nothing
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
                
                return json(Dict(
                    "sat" => false,
                    "msg" => msg,
                    "details" => Dict(
                        "capacity" => failure_info.capacity_analysis,
                        "failed_level" => failure_info.level,
                        "constraints" => failure_info.constraint_details
                    )
                ))
            else
                return json(Dict(
                    "sat" => false,
                    "msg" => "No feasible schedule found. Try adjusting constraints or adding more workers."
                ))
            end
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
        result, failure_info = solve(scheduler)
        
        if result === nothing
            # Build detailed error message
            if failure_info !== nothing
                error_msg = "Schedule is not feasible.\n\n"
                error_msg *= "Capacity: $(failure_info.capacity_analysis["total_slots"]) slots needed, "
                error_msg *= "$(failure_info.capacity_analysis["available_worker_days"]) worker-days available "
                error_msg *= "($(failure_info.capacity_analysis["utilization_percent"])% utilization)\n\n"
                
                if !isempty(failure_info.capacity_analysis["daily_issues"])
                    error_msg *= "Daily issues:\n"
                    for issue in failure_info.capacity_analysis["daily_issues"]
                        error_msg *= "- $issue\n"
                    end
                end
                
                return json(Dict(
                    "error" => error_msg,
                    "details" => Dict(
                        "capacity" => failure_info.capacity_analysis,
                        "failed_level" => failure_info.level,
                        "constraints" => failure_info.constraint_details
                    )
                ), status=400)
            else
                return json(Dict(
                    "error" => "No feasible schedule found"
                ), status=400)
            end
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
    try
        # Parse JSON request
        body = JSON3.read(String(req.body))
        
        # Extract parameters
        workers = parse_workers(body.workers)
        tasks = parse_tasks(body.tasks)
        nb_days = body.nb_days
        balance_daysoff = get(body, :balance_daysoff, false)
        start_date = get(body, :start_date, string(today()))
        trip_name = get(body, :trip_name, "Schedule")
        
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
        result, failure_info = solve(scheduler)
        
        if result === nothing
            return json(Dict(
                "error" => "Cannot export: schedule is not feasible"
            ), status=400)
        end
        
        # Generate iCalendar
        ics_content = generate_icalendar(result, scheduler, start_date)
        
        # Generate filename: Schedule-{trip_name}-{start_date}-{duration}days.ics
        safe_trip_name = replace(trip_name, r"[^a-zA-Z0-9_-]" => "_")
        filename = "Schedule-$(safe_trip_name)-$(start_date)-$(nb_days)days.ics"
        
        # Return as downloadable file
        return HTTP.Response(
            200,
            ["Content-Type" => "text/calendar; charset=utf-8",
             "Content-Disposition" => "attachment; filename=\"$(filename)\""],
            body=ics_content
        )
        
    catch e
        @error "Error in /export/ics endpoint" exception=(e, catch_backtrace())
        return json(Dict(
            "error" => "Error: $(sprint(showerror, e))"
        ), status=500)
    end
end

# POST /export/csv - Export schedule as CSV
@post "/export/csv" function(req::HTTP.Request)
    try
        # Parse JSON request
        body = JSON3.read(String(req.body))
        
        # Extract parameters
        workers = parse_workers(body.workers)
        tasks = parse_tasks(body.tasks)
        nb_days = body.nb_days
        balance_daysoff = get(body, :balance_daysoff, false)
        start_date = get(body, :start_date, string(today()))
        trip_name = get(body, :trip_name, "Schedule")
        
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
        result, failure_info = solve(scheduler)
        
        if result === nothing
            return json(Dict(
                "error" => "Cannot export: schedule is not feasible"
            ), status=400)
        end
        
        # Generate CSV
        csv_content = generate_csv(result, scheduler, start_date)
        
        # Generate filename: Schedule-{trip_name}-{start_date}-{duration}days.csv
        safe_trip_name = replace(trip_name, r"[^a-zA-Z0-9_-]" => "_")
        filename = "Schedule-$(safe_trip_name)-$(start_date)-$(nb_days)days.csv"
        
        # Return as downloadable file
        return HTTP.Response(
            200,
            ["Content-Type" => "text/csv; charset=utf-8",
             "Content-Disposition" => "attachment; filename=\"$(filename)\""],
            body=csv_content
        )
        
    catch e
        @error "Error in /export/csv endpoint" exception=(e, catch_backtrace())
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