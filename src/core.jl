
function fitness(result, s, verbose=false)
    schedule = reshape(result, s)
    per_worker = sum(schedule, dims=1)
    per_worker_balance = maximum(per_worker) - minimum(per_worker)

    spread = @chain schedule begin
        accumulate((a,b)-> !b ? 0 : a+b, _; dims=1)
        maximum(_, dims=1)
        maximum(_) - minimum(_)
        _^2
    end

    if verbose
        println("balance=$per_worker_balance, spread=$spread")
    end

    return 5*per_worker_balance + 2*spread
end

function Metaheuristics.optimize(s::SmallSchedule, searchspace)
    gg = GA(;N = 100, mutation=SlightMutation()) 

    opti_set = Metaheuristics.optimize(x -> fitness(x, s), searchspace, gg)
    return minimizer(opti_set)
end

function find_schedule(days::Int, task_per_day::Int, worker_per_task::Int, workers::Vector{String}, N_first::Int, N_last::Int)
    t1 = Base.time() * 1000
    schedule = SmallSchedule(days, task_per_day, worker_per_task, workers, N_first, N_last)
    c = cardinality(schedule)
    
    if c == 0
        return DataFrame(Workers=[], Days=[])
    end

    schedule, searchspace = search_space(schedule)

    if c == 1
        result = sample(searchspace, 1)
    else
        result = optimize(schedule, searchspace)
    end
    
    score = fitness(result, schedule, true)
    t2 = Base.time() * 1000
    @info "Final Score: $score; Difficulty=$c Call Duration: $(round(Int, t2 - t1))ms"
    return make_df(schedule, result)
end


function make_df(s::SmallSchedule, result)
    schedule = reshape(result, s)
    works_per_day = ["Tache $i" for i in 1:s.task_per_day]
    tasks = DataFrame(Tache=works_per_day)

    p_schedule = [String[] for i in 1:s.task_per_day, j in 1:s.days]
    workers_per_task = @chain schedule begin
        findall(!iszero, _)
        Tuple.(_)
        map(x -> (s.workers[x[2]], x[1]), _)
    end
    

    for (w, idx) in workers_per_task
        push!(p_schedule[idx + s.cutoff_N_first], w)
    end


    return @chain p_schedule begin
        map(li -> join(li, ", "), _)
        DataFrame(_, :auto)
        rename(_, ["Jour $i" for i in 1:s.days])
        hcat(tasks, _)
    end
end

