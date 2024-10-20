
using Chain

function agg_jobs(scheduler::Scheduler, schedule)
    tasks_agg = DataFrame(Tasks=[t.name for t in scheduler.task_per_day])
    nb_jobs = length(scheduler.task_per_day)
    
    for id_worker in 1:length(scheduler.workers)
        
        jobs = findall(x -> x==1, schedule[:, id_worker])
        jobs = (jobs .+ scheduler.cutoff_N_first) .% nb_jobs
        jobs = countmap(jobs)
        jobs = DefaultDict(0, jobs) 
        jobs[nb_jobs] = jobs[0]
        tasks_agg[!, scheduler.workers[id_worker].name] = [jobs[i] for i in 1:nb_jobs]
    end

    push!(tasks_agg, vcat("Total", sum(schedule, dims=1)...))
    return tasks_agg
end

function agg_type(scheduler::Scheduler, schedule)
    names = [w.name for w in scheduler.workers]

    @chain schedule begin
        agg_jobs(scheduler, _)
        groupby(_, :Tasks)
        combine(_, names .=> sum)
        rename(_, vcat(["Tasks"], names))
        push!(_, vcat("Total", sum(schedule, dims=1)...))
    end
end


function agg_time(scheduler::Scheduler, schedule)
    names = [w.name for w in scheduler.workers]
    days = DataFrame(Days=["Jour $i" for i in 1:scheduler.days])

    @chain scheduler.daily_indices begin
        [sum(schedule[day, :], dims=1) for day in _]
        vcat(_...)
        DataFrame(_, names)
        hcat(days, _)
        push!(_, vcat("Total", sum(schedule, dims=1)...))
    end
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
                w_names = join(w_names, ", ", " et ")
            else
                w_names = ""
            end

            push!(one_day, w_names)
        end
        tasks_agg[!, "Day $(i_day)"] = one_day
    end
    return tasks_agg
end
