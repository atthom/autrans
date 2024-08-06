

function agg_jobs(s::Scheduler, schedule)
    tasks_agg = DataFrame(Tasks=[t.name for t in s.task_per_day])
    nb_jobs = length(s.task_per_day)
    nb_workers = length(s.workers)
    for id_worker in 1:nb_workers
        jobs = findall(x -> x==1, schedule[:, id_worker])
        jobs = (jobs .+ s.cutoff_N_first) .% nb_jobs
        jobs = countmap(jobs)
        jobs = DefaultDict(0, jobs) 
        jobs[nb_jobs] = jobs[0]
        tasks_agg[!, s.workers[id_worker].name] = [jobs[i] for i in 1:nb_jobs]
    end
    return tasks_agg
end

function agg_type(s::Scheduler, schedule)
    df_jobs = agg_jobs(s, schedule)
    grp_df =  groupby(df_jobs, :Tasks)
    workers = [w.name for w in s.workers] 
    new_df = combine(grp_df, workers .=> sum)

    col_names = vcat(["Tasks"], [w.name for w in s.workers])
    return rename(new_df, col_names)
end


function agg_time(s::Scheduler, schedule)
    nb_jobs = length(s.task_per_day)
    offset = s.cutoff_N_first
    all_days = []

    for day in s.daily_indices
        push!(all_days, sum(schedule[day, :], dims=1))
    end

    df = DataFrame(vcat(all_days...), [w.name for w in scheduler.workers])
    days = DataFrame(Days=["Jour $i" for i in 1:s.days])
    return hcat(days, df)
end


function agg_display(scheduler::Scheduler, schedule)
    tasks_agg = DataFrame(Tasks=[t.name for t in scheduler.task_per_day])
    nb_jobs = length(scheduler.task_per_day)
    for i in 1:scheduler.days
        tasks_agg[!, "Day $i"] = repeat([""], nb_jobs)
    end

    for (i_day, day) in enumerate(scheduler.daily_indices)
        one_day = Vector{String}()
        for (task, indices) in scheduler.all_task_indices_per_day
            daily_task = [i for i in indices if i in day]

            if length(daily_task) == 1
                daily_task = daily_task[1]
                w_ids = findall(x -> x==1, schedule[daily_task, :])
                w_names = [scheduler.workers[i].name for i in w_ids]
                w_names = join(w_names, " ")
            else
                w_names = ""
            end

            push!(one_day, w_names)
        end
        tasks_agg[!, "Day $(i_day)"] = one_day
    end
    return tasks_agg
end
