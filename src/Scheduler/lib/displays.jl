

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
    grp_df = groupby(df_jobs, :Tasks)
    workers = [w.name for w in s.workers] 
    new_df = combine(grp_df, workers .=> sum)
    col_names = vcat(["Tasks"], [w.name for w in s.workers])
    return rename(new_df, col_names)
end


function agg_time(s::Scheduler, schedule)
    return @chain s begin
        day_indices
        [sum(schedule[day, :], dims=1) for day in _]
        vcat(_...)
        DataFrame(_, [w.name for w in s.workers])
        hcat(DataFrame(Days=["Jour $i" for i in 1:s.days]), _)
    end
end


function agg_workers(s::Scheduler, schedule)
    tasks = DataFrame(Tache=[t.name for t in s.task_per_day])
    p_schedule = [String[] for i in 1:s.total_tasks + s.cutoff_N_first + s.cutoff_N_last]

    workers_per_task = @chain schedule begin
        findall(!iszero, _)
        Tuple.(_)
        map(x -> (s.workers[x[2]], x[1]), _)
    end
    
    for (w, idx) in workers_per_task
        push!(p_schedule[idx + s.cutoff_N_first], w.name)
    end

    return @chain p_schedule begin
        map(li -> join(li, ", "), _)
        reshape(_, (length(s.task_per_day), s.days))
        DataFrame(_, :auto)
        rename(_, ["Jour $i" for i in 1:s.days])
        hcat(tasks, _)
    end
end
