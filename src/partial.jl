using JuMP
using GLPK
using Chain
using PrettyTables

#autrans = Model(GLPK.Optimizer)

using ConstraintSolver
# define a shorter name ;)
const CS = ConstraintSolver

#autrans = Model(optimizer_with_attributes(CS.Optimizer, 
#"all_optimal_solutions" => true))

if false
    autrans = Model(optimizer_with_attributes(CS.Optimizer, 
    "all_solutions" => true, 
    #"traverse_strategy" => "DBFS",
    "time_limit" => 20)
    )
end

autrans = Model(GLPK.Optimizer)

nb_days = 7
nb_task_per_day = 5
nb_pers_per_work = 2 
nb_workers = 8
nb_tasks = nb_task_per_day*nb_days
nb_task_per_worker = div(nb_tasks*nb_pers_per_work, nb_workers) + 1

task_per_worker_per_day = div(nb_task_per_worker, nb_days) + 1

@variable(autrans, x[tasks=1:nb_tasks, workers=1:nb_workers], Bin)

# 2 guys per job
@constraint(autrans, sum(x) == nb_tasks*2)
@constraint(autrans, [i= 1:nb_tasks], sum(x[i, :]) == 2)

#@constraint(autrans, [j= 1:nb_workers], nb_task_per_worker-1 <= sum(x[:, j]) <= nb_task_per_worker +1)
# equilibrer le travail entre les workers
@constraint(autrans, [j= 1:nb_workers], nb_task_per_worker-1 <= sum(x[:, j]))
@constraint(autrans, [j= 1:nb_workers], nb_task_per_worker >= sum(x[:, j]))


# pas trop de travail dans une journée pour un worker
for day in 1:nb_task_per_day:nb_tasks-nb_task_per_day
    @constraint(autrans, [j= 1:nb_workers], sum(x[day:day+5, j]) <= 2)
end

# faire varier les taches
for t in 1:nb_task_per_day
    @constraint(autrans, [j= 1:nb_workers], sum(x[t:nb_task_per_day:end, j]) <= 2)
end

# faire varier les équipes


#@constraint(autrans, [i= 1:div(nb_tasks, nb_task_per_day)-1, j= 1:nb_workers], diff(cumsum(x, dims=1)[1:5:end, :], dims=1)[i, j] <= 2)

# `AffExpr`-in-`MathOptInterface.EqualTo{Float64}`: 35 constraints
# `VariableRef`-in-`MathOptInterface.ZeroOne`: 280 constraints
# result_count(autrans) => 18335
# `AffExpr`-in-`ConstraintProgrammingExtensions.Strictly{MathOptInterface.LessThan{Float64}, Float64}`: 8 constraints
# `AffExpr`-in-`ConstraintProgrammingExtensions.Strictly{MathOptInterface.GreaterThan{Float64}, Float64}`: 8 constraints

optimize!(autrans)
d = value.(x)


#[@constraint(autrans, sum(x[:, j]) <= nb_task_per_worker) for j in 1:nb_workers]

#[@constraint(autrans, 1 < sum(x[:, j])) for j in 1:nb_workers]

#[@constraint(autrans, sum(x[:, j]) <= nb_task_per_worker) for j in 1:nb_workers]


#[@constraint(autrans, sum(x[:, j]) == sum(x[:, j+1])) for j in 1:nb_workers-2]

#@constraint(autrans, 1 <= sum(x[:, end]) <= nb_tasks)

optimize!(autrans)



if false
    for i in 2:result_count(autrans)
        @assert has_values(autrans; result = i)
        println("Solution $(i) = ", value.(x; result = i))
        obj = objective_value(autrans; result = i)
        println("Objective $(i) = ", obj)
        if isapprox(obj, optimal_objective; atol = 1e-8)
            print("Solution $(i) is also optimal!")
        end
    end
end
