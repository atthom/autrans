using JuMP
using GLPK
using Chain
using PrettyTables

using ConstraintSolver
const CS = ConstraintSolver
#autrans = Model(GLPK.Optimizer)
autrans = Model(CS.Optimizer)

nb_days = 7
nb_task_per_day = 5
nb_pers_per_work = 2 
nb_workers = 8
nb_tasks= nb_task_per_day*nb_days

task_per_worker_per_day = div(div(nb_tasks*nb_pers_per_work, nb_workers), nb_days) + 1

@variable(autrans, x[tasks=1:nb_tasks, workers=1:nb_workers], Bin)

# 2 guys per job
[@constraint(autrans, sum(x[i, :]) == 2) for i = 1:nb_tasks]

# spread load across the workers
[@constraint(autrans, sum(x[:, j]) == sum(x[:, j+1])) for j in 1:nb_workers-2]
@constraint(autrans, 1 <= sum(x[:, end]) <= nb_tasks)

# not everytime the same job for a worker
@constraint(autrans, [n = 1:5, workers=1:nb_workers], sum(x[n:5:end, workers]) <= 3)

# no too many task for a guy on the same day
#@expression(autrans, cum_diff, )
@constraint(autrans, [n = 1:div(nb_tasks, nb_days)-1, workers=1:nb_workers], diff(cumsum(x, dims=1)[5:5:end, :], dims=1)[n, workers] <= task_per_worker_per_day)
#@objective(autrans, Min, cum_diff)


optimize!(autrans)


@enum TypeTask begin
    cuisine
    vaisselle
 end
 
 @enum TypeTime begin
    matin
    midi
    soir
 end
 

function pprint(schedule)
    workers = [:thomas, :chronos, :curt, :astor, :manal, :thibs, :laura, :benj ]
    nb_days = 7
    nb_task_per_day = 5
    
    works_per_day = @chain instances(TypeTime) begin
      (_, instances(TypeTask))
      Iterators.product(_...)
      Iterators.map(x -> join(reverse(x), " "), _)
      collect
      _[2:end]
    end

    ll = length(works_per_day)
    p_schedule = [Symbol[] for i in 1:ll, j in 1:nb_days]

    workers_per_task = @chain schedule begin
        findall(!iszero, _)
        Tuple.(_)
        map(x -> (workers[x[2]], x[1]), _)
    end
    
    for (w, idx) in workers_per_task
        push!(p_schedule[idx], w)
    end

    header = ["Jour $i" for i in 1:nb_days]
    pretty_table(p_schedule, header, row_names=works_per_day)

end


function fitness(schedule)
    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
   
    balance = maximum(per_worker) - minimum(per_worker)
    job_size = fill(2, length(per_job))
    balanced_work = (per_job .- job_size).^2
    balanced_work = sum(balanced_work)^2 
    
    
    spread = @chain schedule begin
        cumsum(_, dims=1)
        _[5:5:end, :]
        diff(_, dims=1)
        _ .- fill(1, size(_))
        _ .* _
        sum
    end
    println("$balanced_work, $(balance^2), $spread")
    
    return -balanced_work -balance^2  -spread
end

value.(x)