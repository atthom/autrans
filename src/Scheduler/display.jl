

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

    for day in 1:nb_jobs:s.total_tasks
        if day == 1
            day_idx = 1:nb_jobs-offset
        else
            day_idx = day-offset:day+nb_jobs-offset-1
        end
        push!(all_days, sum(schedule[day_idx, :], dims=1))
    end

    df = DataFrame(vcat(all_days...), [w.name for w in scheduler.workers])
    days = DataFrame(Days=["Jour $i" for i in 1:s.days])
    return hcat(days, df)
end
