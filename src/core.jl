
mse(arr) = @chain arr begin
    extrema(_, dims=2)
    map(x -> x[2] - x[1], _)
    _ .^ 2
    sum
end

function mse(arr, scheduler::Scheduler)
    all_mse = 0
    nb_workers = length(scheduler.workers)
    for day_idx in 1:scheduler.days
        worker_working = [w for w in 1:nb_workers if !in(day_idx-1, scheduler.workers[w].days_off)]
        m1, m2 = extrema(arr[day_idx, worker_working])
        all_mse += (m2 - m1)^2
    end
    return all_mse
end

function task_per_day_loss(scheduler, schedule, nb_worker)
    # equity between worker in type of task assigned
    agg_tasks_per_day = zeros(Int, (length(scheduler.tasks_indices_per_day), nb_worker))
    
    for (id_t, (t, indices)) in enumerate(scheduler.tasks_indices_per_day)
        agg_tasks_per_day[id_t, :] = sum(schedule[indices, :], dims=1)
    end
    
    return agg_tasks_per_day, mse(agg_tasks_per_day)
end

function type_task_loss(scheduler, agg_tasks_per_day, nb_worker)
    agg_type_task = zeros((length(scheduler.task_type_indices), nb_worker))
    for (id_t, indices) in enumerate(scheduler.task_type_indices)
        agg_type_task[id_t, :] = sum(agg_tasks_per_day[indices, :], dims=1)
    end

    agg_worker = sum(agg_type_task, dims=1)
    return mse(agg_type_task) + mse(agg_worker)
end

function workload_loss(scheduler, schedule, nb_workers)
    # equity between worker in daily workload
    agg_all_days = zeros(Int, (scheduler.days, nb_workers))
    for (i, d) in enumerate(scheduler.daily_indices)
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)

        for (i_w, w) in enumerate(scheduler.workers)
            if i ∈ w.days_off
                agg_all_days[i, i_w] = div(sum(schedule[d, :]), nb_workers)
            end
        end
    end

    return mse(agg_all_days, scheduler)
end


function fitness(scheduler, schedule, verbose=false)
    nb_workers = length(scheduler.workers)

    # equity in daily workload
    agg_all_tasks_per_day, agg_type_loss = task_per_day_loss(scheduler, schedule, nb_workers)

    # equity in type task
    agg_type_loss2 = type_task_loss(scheduler, agg_all_tasks_per_day, nb_workers)

    # equity in overall workload
    agg_workload_loss = workload_loss(scheduler, schedule, nb_workers)

    if verbose
        println("agg_type_loss=$agg_type_loss, agg_type_loss2=$agg_type_loss2, agg_workload_loss=$agg_workload_loss")
    end

    return agg_type_loss + agg_workload_loss + agg_type_loss2 
end

function permutations_seed(scheduler)
    workload_ratio = @chain scheduler.tasks_indices_per_day begin
        [t.worker_slots*length(indices) for (t, indices) in _]
        sum
        _ / length(scheduler.workers) / scheduler.days 
    end
    rebalance = @chain workload_ratio begin
        [_ * -length(w.days_off) for w in scheduler.workers]
        reshape(_, 1, length(_))
    end
    if scheduler.balance_daysoff
        rebalance .*= -1
    end

    nb_workers = length(scheduler.workers)
    slots = zeros(Bool, (scheduler.total_tasks, nb_workers))
    task_type_correction = zeros(Int, (length(scheduler.tasks_indices_per_day), nb_workers))
    last_workers = Int[]
    
    task_type_map = Dict{String, Int}(task.name => id_type for (id_type, (task, indices)) in enumerate(scheduler.tasks_indices_per_day))

    for (day_idx, indices) in enumerate(scheduler.daily_indices)
        daily_workload = zeros(Int, (1, nb_workers))
        for t in indices
            task = get_task(scheduler, t)

            type_task = task_type_map[task.name]
            task_type_workload = reshape(task_type_correction[type_task, :], 1, nb_workers)

            workload = sum(slots, dims=1) + daily_workload
            workload = float.(workload)
            workload .+= rebalance
            
            workload = workload + task_type_workload // 2 
            workload[last_workers] .-= 1//10
            workload = [(i, w) for (i, w) in enumerate(workload) if !in(day_idx-1, scheduler.workers[i].days_off)]
            workload = sort(workload, by=x->x[2], rev=false)
            
            selected_workers = getindex.(workload, 1)
            selected_workers = selected_workers[1:task.worker_slots]
            last_workers = selected_workers
            slots[t, selected_workers] .= 1

            task_type_correction[type_task, selected_workers] .+= 1
            daily_workload += reshape(slots[t, :], 1, nb_workers)
        end
        update_balance = reshape([workload_ratio * in(day_idx, w.days_off) for w in scheduler.workers], 1, length(scheduler.workers))
        update_balance .*= -2*scheduler.balance_daysoff + 1
        rebalance .+= update_balance
    end
    slots
end



# return array[idx_worker] = ratio of work rescaled by day_off
function workload_corrected(scheduler::Scheduler)
    nb_workers = length(scheduler.workers)
    
    #no_day_off = sum(length(w.days_off) for w in scheduler.workers) == 0
    same_days_offs = unique(length(w.days_off) for w in scheduler.workers) |> length
    if same_days_offs == 1
        return fill(1, nb_workers)
    end

    # compute the ratio of days worked compare to the full planning duration
    all_ratio = (scheduler.days .- [length(w.days_off) for w in scheduler.workers]) ./ scheduler.days
    # problem is that we "miss" some attributions because some workers are away
    # everyone will have to work more to cover theses missed attributions
    # it's easily proven by sum(all_ratio) < workers
    # we need to normalize the array so sum(all_ratio) == workers
    # in other terms we want a new all_ratio where average(all_ratio) = 1
    # this is done with multipling by the number of worker and divided by what is already in the array
    all_ratio .*= nb_workers / sum(all_ratio)
    return all_ratio
end


function solve_same_taskload_same_dayoff(scheduler::Scheduler)
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x[1:scheduler.total_tasks], Bin)
    # global task (task diversity) constraints

    total_work = sum(t.worker_slots for (i, t) in scheduler.indice_task)
    nb_workers = length(scheduler.workers)
    workload, rem = divrem(total_work, nb_workers)
    rem = Int(rem > 0)
    @constraint(model, workload <= sum(x) <= workload + rem)

    for (task, indices) in scheduler.tasks_indices_per_day
        task_workload, rem = divrem(length(indices) * task.worker_slots, nb_workers)
        rem = Int(rem > 0)
        @constraint(model, task_workload <= sum(x[indices]) <= task_workload + rem)
    end

    # daily workload constraints
    for (day_idx, day_indices) in enumerate(scheduler.daily_indices)
        workload = sum(scheduler.indice_task[t_idx].worker_slots for t_idx in day_indices)
        daily_workload, rem = divrem(workload, nb_workers)
        daily_rem = rem > 0 || balance_days
        @constraint(model, daily_workload <= sum(x[day_indices]) <= daily_workload + Int(daily_rem))
        #@constraint(model, [idx_w in 1:nb_workers], sum(x[day_indices, idx_w]) == daily_workload_by_worker_sup[idx_w])
    end

    # 2.4
    JuMP.optimize!(model)
    assert_is_solved_and_feasible(model)
    solution = round.(Int, value.(x))

    results = Vector{Vector{Int}}(undef, nb_workers)
    current = solution

    for i in 1:nb_workers
        results[i] = current
        current = circshift(current, length(scheduler.tasks_per_day))
    end

    return results = hcat(results...)
    #fitness(scheduler, results, true)
end


function solve(scheduler::Scheduler)
    try
        return optimize(scheduler, 0)
    catch
        try
            return optimize(scheduler, 1)
        catch
            return permutations_seed(scheduler)
        end
    end
end

# 2.956 - 3.241ms for the seed_opti make_simple_payload(6, 3, 3, 2) balance = true
# 445ms for optimize make_complex_payload(10, 10, 2, true)
# 379ms for optimize make_complex_payload(10, 10, 2, true)
# 73ms for optimize make_complex_payload(10, 10, 2, true)
# 72ms for optimize make_complex_payload(10, 10, 2, true)
# 345ms for optimize make_complex_payload(10, 10, 2, true) # increased accuracy but unstable
# 158ms for optimize make_complex_payload(10, 10, 2, true)


# 1.5s for optimize make_simple_payload(10, 10, 10, 2)
function optimize(scheduler::Scheduler, relax=0)
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    nb_workers = length(scheduler.workers)
    # total workload constraints
    total_work = sum(t.worker_slots for (i, t) in scheduler.indice_task)
    #minimum_offday = minimum(length(w.days_off) for w in scheduler.workers)
    workload_ratio = workload_corrected(scheduler)
    balance_days = scheduler.balance_daysoff && sum(length(w.days_off) for w in scheduler.workers) != 0
    same_ratio = all(x-> x == 1, workload_ratio)

    @variable(model, x[1:scheduler.total_tasks, 1:nb_workers], Bin)

    # task slots have to be filled
    @constraint(model, [idx in 1:length(scheduler.indice_task)], sum(x[idx, :]) == scheduler.indice_task[idx].worker_slots)
    
    # global task (task diversity) constraints
    workload, rem = divrem(total_work, nb_workers)
    workload_worker = workload .* workload_ratio
    workload_cst = floor.(Int, workload_worker)
    workload_rem = rem .+ workload_cst .- workload_worker
    workload_rem = workload_rem .!= 0

    @constraint(model, [idx_w in 1:nb_workers], workload_cst[idx_w] <= sum(x[:, idx_w]) <= workload_cst[idx_w] + workload_rem[idx_w])

    # task workload per worker (task diversity) constraints
    for (task, indices) in scheduler.tasks_indices_per_day
        task_workload, rem = divrem(length(indices) * task.worker_slots, nb_workers)
        task_workload_w = task_workload .* workload_ratio
        task_workload_w_cst = floor.(Int, task_workload_w)
        # && !balance_days
        task_workload_rem = rem .+ task_workload_w - task_workload_w_cst .!= 0

        @constraint(model, [idx_w in 1:nb_workers], task_workload_w_cst[idx_w] <= sum(x[indices, idx_w]) <= task_workload_w_cst[idx_w] + task_workload_rem[idx_w])
    end


    # daily workload constraints
    for (day_idx, day_indices) in enumerate(scheduler.daily_indices)
        working_workers = sum(day_idx ∉ w.days_off for w in scheduler.workers)
        workload = sum(scheduler.indice_task[t_idx].worker_slots for t_idx in day_indices)
        daily_workload, rem = divrem(workload, working_workers)
        daily_rem = rem != 0 || balance_days

        daily_workload_by_worker_inf = fill(daily_workload, nb_workers)
        daily_workload_by_worker_sup = fill(daily_workload, nb_workers)

        if daily_rem
            daily_workload_by_worker_inf = daily_workload_by_worker_inf .- relax
            daily_workload_by_worker_sup = daily_workload_by_worker_sup .+ 1
        end

        days_off = [i for (i, w) in enumerate(scheduler.workers) if day_idx ∈ w.days_off]
        daily_workload_by_worker_inf[days_off] .= 0
        daily_workload_by_worker_sup[days_off] .= 0

        @constraint(model, [idx_w in 1:nb_workers], daily_workload_by_worker_inf[idx_w] <= sum(x[day_indices, idx_w]) <= daily_workload_by_worker_sup[idx_w])
        #@constraint(model, [idx_w in 1:nb_workers], sum(x[day_indices, idx_w]) == daily_workload_by_worker_sup[idx_w])

    end

    # 2.4
    JuMP.optimize!(model)
    assert_is_solved_and_feasible(model)
    solution = round.(Int, value.(x))
    #display_schedule(scheduler, solution)
    return solution
end

