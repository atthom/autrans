
using Plots

function can_work(perm, day, worker_off)
    for (i, days_off) in worker_off
        if day-1 in days_off && perm[i] == 1
            return false
        end
    end
    return true
end

function get_neighbors(s::Scheduler, schedule)
    neighbors = Vector{Matrix{Bool}}()
    nb_task, nb_workers = size(schedule) 
    worker_off = [(i, w.days_off) for (i, w) in enumerate(s.workers) if length(w.days_off) != 0]

    for id_task in 1:nb_task
        all_perm = multiset_permutations(schedule[id_task, :], nb_workers)
        day = findfirst(x -> id_task in x, s.daily_indices)

        for perm in all_perm
            if can_work(perm, day, worker_off) && schedule[id_task, :] != perm
                nei = copy(schedule)
                nei[id_task, :] .= perm
                push!(neighbors, nei)
            end
        end
    end
    return neighbors
end



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
    agg_all_tasks_per_day = zeros(Int, (length(scheduler.all_task_indices_per_day), nb_worker))

    #worker_off = [length(w.days_off) for w in scheduler.workers]
    for (id_t, (t, indices)) in enumerate(scheduler.all_task_indices_per_day)
        agg_all_tasks_per_day[id_t, :] = sum(schedule[indices, :], dims=1)
        #avg_task = t.worker_slots / nb_worker
        #agg_all_tasks_per_day[id_t, :] += (worker_off*avg_task)

    end
    
    #coeff_task = [scheduler.days - length(w.days_off) for w in scheduler.workers]
    #coeff_task = scheduler.days ./ coeff_task
    
    #agg_all_tasks_per_day_coeff = agg_all_tasks_per_day .* coeff_task'
    return agg_all_tasks_per_day, mse(agg_all_tasks_per_day)
end

function type_task_loss(scheduler, agg_all_tasks_per_day, nb_worker)
    agg_type_task = zeros((length(scheduler.task_type_indices), nb_worker))
    for (id_t, indices) in enumerate(scheduler.task_type_indices)
        agg_type_task[id_t, :] = sum(agg_all_tasks_per_day[indices, :], dims=1)
    end

    # update agg_tasks (people with less days should work less)
    #coeff_task = [scheduler.days - length(w.days_off) for w in scheduler.workers]
    #coeff_task = coeff_task ./ scheduler.days

    #agg_type_task = agg_type_task .* coeff_task'
    agg_worker = sum(agg_type_task, dims=1)
    return mse(agg_type_task) + mse(agg_worker)
end

function workload_loss(scheduler, schedule, nb_workers)
    # equity between worker in daily workload
    agg_all_days = zeros(Int, (scheduler.days, nb_workers))
    for (i, d) in enumerate(scheduler.daily_indices)
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)
    end

    return mse(agg_all_days, scheduler)
end

function shuffle_team_loss(scheduler, schedule, nb_worker)
    # to mix the team a bit
    #agg_shuffle = zeros(Int, div(nb_worker*(nb_worker+1), 2))
    agg_shuffle = zeros(Int, nb_worker*nb_worker)
    c = 0
    for w1 in 1:nb_worker
        for w2 in 1:nb_worker
            c +=1
            agg_shuffle[c] = sum(schedule[:, w1] .&& schedule[:, w2])
        end
    end

    #coeff_task = [scheduler.days - length(w.days_off) for w in scheduler.workers]
    #coeff_task = coeff_task ./ scheduler.days

    #agg_shuffle = agg_shuffle .* coeff_task

    agg_shuffle = maximum(agg_shuffle) - minimum(agg_shuffle)

    return agg_shuffle^2 * 0.1
end


function fitness(scheduler, schedule, verbose=false)
    #per_worker = sum(schedule, dims=1)
    # equity between worker in number of tasks assigned
    #per_worker_balance = maximum(per_worker) - minimum(per_worker)
    nb_workers = length(scheduler.workers)

    agg_all_tasks_per_day, agg_type_loss = task_per_day_loss(scheduler, schedule, nb_workers)

    agg_type_loss2 = type_task_loss(scheduler, agg_all_tasks_per_day, nb_workers)

    agg_workload_loss = workload_loss(scheduler, schedule, nb_workers)

    #agg_shuffle_loss = shuffle_team_loss(scheduler, schedule, nb_workers)

    if verbose
        println("agg_type_loss=$agg_type_loss, agg_type_loss2=$agg_type_loss2, agg_workload_loss=$agg_workload_loss")
    end

    #return per_worker_balance +agg_type_loss + agg_type_loss2 + agg_time_loss + agg_time_loss2
    return agg_type_loss + agg_workload_loss + agg_type_loss2 #+ agg_shuffle_loss
end



function genetic_search(scheduler; pop_size=50, nb_gen = 2000)
    population = [seed(scheduler) for i in 1:pop_size]
    
    current_gen = 0
    while current_gen < nb_gen
        all_fitness = fitness.(Ref(scheduler), population) * -1
        min_fit, max_fit = extrema(all_fitness)

        println("$current_gen : Best fit $max_fit, Worse fit $min_fit")

        min_max_fitness = @. (all_fitness - min_fit) / (max_fit - min_fit)
        selected = [idx for (idx, p) in enumerate(min_max_fitness) if p >= rand()]
        population = population[selected]

        to_reproduce = pop_size - length(population)

        all_nei = [nei for individual in population for nei in get_neighbors(scheduler, individual)]
        selected_birth = all_nei[rand(1:length(all_nei), to_reproduce)]
        
        population = vcat(population, selected_birth)
        current_gen += 1
    end

    all_fitness = fitness.(Ref(scheduler), population)
    best = population[argmax(all_fitness)]

    return best
end


function simple_search(scheduler; nb_gen = 5000)
    best = seed(scheduler)
    
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(scheduler, best)
        println("gen $i, best fitness: $(fitness(scheduler, best))")
        for nei in all_nei
            current_fit = fitness(scheduler, nei)
            if current_fit < best_fit
                best = nei
                best_fit = current_fit
            end
        end
        i += 1
    end
    return best
end


function tabu_search(scheduler; nb_gen = 200, maxTabuSize=50)
    best = seed(scheduler)
    #best = permutations_seed(scheduler)
    bestCandidate = best
    tabu_list = Vector{Matrix{Bool}}()
    push!(tabu_list, best)
    i = 0
    while i < nb_gen
        best_fit = 10000000
        all_nei = get_neighbors(scheduler, bestCandidate)
        println("gen $i, tabu_size: $(length(tabu_list)) best fitness: $(fitness(scheduler, bestCandidate))")
        for nei in all_nei
            current_fit = fitness(scheduler, nei)
            if nei ∉ tabu_list && current_fit < best_fit
                bestCandidate = nei
                best_fit = current_fit
            end
        end
        if best_fit == 10000000 
            break
        elseif best_fit < fitness(scheduler, best)
            best = bestCandidate
        end

        push!(tabu_list, bestCandidate)

        if length(tabu_list) > maxTabuSize
            popfirst!(tabu_list)
        end
        i += 1
    end

    return best
end


function permutations_seed(scheduler)

    to_balance = true

    nb_slots = sum([t.worker_slots*length(indices) for (t, indices) in scheduler.all_task_indices_per_day])
    avg_work = nb_slots / length(scheduler.workers) / scheduler.days
    rebalance = [avg_work*length(w.days_off) for w in scheduler.workers]
    rebalance = reshape(rebalance, 1, length(rebalance))

    nb_workers = length(scheduler.workers)
    slots = zeros(Bool, (scheduler.total_tasks, nb_workers))

    for (day_idx, indices) in enumerate(scheduler.daily_indices)
        for t in indices
            task = get_task(scheduler, t)
            
            workload = sum(slots, dims=1) 
            if to_balance
                workload += rebalance
            end
            workload = [(i, w) for (i, w) in enumerate(workload) if !in(day_idx-1, scheduler.workers[i].days_off)]

            wv = getindex.(workload, 2)
            min_work, max_work = extrema(wv)
            
            if max_work == min_work
                wv = ones(Int, length(workload))
            else
                wv = max_work .- wv
                if length(findall(x-> x != 0, wv)) < task.worker_slots
                    wv = wv .+ 1
                end
            end

            wv = wv .^ 2
            
            random_affectation = StatsBase.sample(workload, Weights(wv), task.worker_slots, replace=false)
            random_affectation = getindex.(random_affectation, 1)

            slots[t, random_affectation] .= 1
        end
    end
    slots
end

function sequence_swap(best, worker_max, worker_min, task_give, task_take)
    affectation_give = CartesianIndex(task_give, worker_max)
    affectation_take = CartesianIndex(task_give, worker_min)

    affectation_giveback = CartesianIndex(task_take, worker_min)
    affectation_takeback = CartesianIndex(task_take, worker_max)

    if best[affectation_take] || best[affectation_takeback] == 1
        #println("here")
        return best
    end
    if best[affectation_give] && best[affectation_giveback] == 0
        #println("there")
        return best
    end

    best[affectation_give] = 0
    best[affectation_take] = 1

    best[affectation_giveback] = 0
    best[affectation_takeback] = 1

    return best
end


function optimize_task_per_day(scheduler, best, nb_workers)

    for (task_row, (task, task_index)) in enumerate(scheduler.all_task_indices_per_day)
        t, l = task_per_day_loss(scheduler, best, nb_workers)

        m1, m2 = extrema(t[task_row, :])
        if m2 - m1 < 2
            continue
        end

        worker_max = argmax(t[task_row, :])
        worker_min = argmin(t[task_row, :])
        
        task_to_give = argmax(best[task_index, worker_max])

        idx_type_task_min = argmin(t[:, worker_max])
        next_type_task_indices = scheduler.all_task_indices_per_day[idx_type_task_min][2]

        task_to_giveback = argmax(best[next_type_task_indices, worker_min])

        days_off = vcat(scheduler.workers[worker_max].days_off, scheduler.workers[worker_min].days_off)
        tasks_off = [t for i in days_off for t in scheduler.daily_indices[i+1]]
        if task_to_give in tasks_off || task_to_giveback in tasks_off
            continue
        end
        
        best = sequence_swap(best, worker_max, worker_min, task_index[task_to_give], next_type_task_indices[task_to_giveback])

    end

    return best
end

function square_trick(scheduler, best)
    nb_tasks, nb_workers = size(best)

    map_day_task = Dict(
        i => idx for i in 1:scheduler.total_tasks for (idx, (t, indices)) in enumerate(scheduler.all_task_indices_per_day) if i in indices
    )

    for indices in scheduler.daily_indices
        agg_day = sum(best[indices, :], dims=1)

        m1, m2 = extrema(agg_day)
        if m2 - m1 < 2
            continue
        end

        all_max = getindex.(findall(x-> x == m2, agg_day), 2)
        all_min = getindex.(findall(x-> x == m1, agg_day), 2)

        for (worker_max, worker_min) in Base.product(all_max, all_min)
            start_idx = indices[end] +1
            possible_t2 = start_idx:nb_tasks

            possible_task = Base.product(indices, possible_t2) |> collect
            
            possible_task_idx = findfirst(x-> best[x[1], worker_max] && !best[x[1], worker_min] &&
                                          !best[x[2], worker_max] && best[x[2], worker_min] && 
                                          map_day_task[x[1]] == map_day_task[x[2]], possible_task) 
            if possible_task_idx === nothing
                #println("no possible task")
                continue
            else
                t1, t2 = possible_task[possible_task_idx]
            end


            days_off = vcat(scheduler.workers[worker_max].days_off, scheduler.workers[worker_min].days_off)
            tasks_off = [t for i in days_off for t in scheduler.daily_indices[i+1]]
            if t1 in tasks_off || t2 in tasks_off
                continue
            end

            best = sequence_swap(best, worker_max, worker_min, t1, t2)
        end
    end
    return best
end

function optimize_workload(scheduler, all_schedules, best, nb_workers)
    current_loss = workload_loss(scheduler, best, nb_workers)


    for (idx_day, indices) in enumerate(scheduler.daily_indices)
        t, l = task_per_day_loss(scheduler, best, nb_workers)
        agg_all_days = zeros(Int, (scheduler.days, nb_workers))

        for (i, d) in enumerate(scheduler.daily_indices)
            agg_all_days[i, :] = sum(best[d, :], dims=1)
        end

        m1, m2 = extrema(agg_all_days[idx_day, :])
        if m2 - m1 < 2
            continue
        end

        all_worker_max = findall(x-> x > m1, agg_all_days[idx_day, :])
        all_worker_min = findall(x-> x < m2, agg_all_days[idx_day, :])

        possible_arrangements = []
        for (worker_max, worker_min) in Base.product(all_worker_max, all_worker_min)
            possible_tasks = zip(best[indices, worker_max], best[indices, worker_min]) |> collect
            possible_tasks = indices[findall(x-> x[1] && !x[2], possible_tasks)]
            
            for t in possible_tasks
                push!(possible_arrangements, (worker_max, worker_min, t))
            end
        end

        for (worker_max, worker_min, id_t1) in possible_arrangements
            
            #println("$(length(possible_arrangements)), $(length(good_day))")
            for indice_idx in scheduler.daily_indices
                
                all_task_day = zip(best[indice_idx, worker_max], best[indice_idx, worker_min]) |> collect
                indices_t2 = indice_idx[findall(x-> !x[1] && x[2], all_task_day)]
                
                for id_t2 in indices_t2
                    new_schedule = sequence_swap(copy(best), worker_max, worker_min, id_t1, id_t2)
                    l = workload_loss(scheduler, new_schedule, nb_workers)
                    #println("$worker_max, $worker_min, $id_t1, $id_t2, $l")
                    if (new_schedule != best) && (l < current_loss)
                        push!(all_schedules, new_schedule)
                    end
                end
            end
        end

    end
end

function optimize_permutations(scheduler; nb_gen=10)
    all_res = []

    for i in 1:nb_gen
        best = permutations_seed(scheduler)
        nb_tasks, nb_workers = size(best)

        fit = 100000000000000
        for i in 1:100
            best = optimize_task_per_day(scheduler, best, nb_workers)
            best = square_trick(scheduler, best)

            current_fit = fitness(scheduler, best)
            if current_fit < fit
                fit = current_fit
            else
                break
            end
        end
        push!(all_res, best)
    end
    
    best = all_res[argmin(fitness.(Ref(scheduler), all_res))]
    println("best fitness: $(fitness(scheduler, best, true))")

    #check_days_off(scheduler, best)

    return best
end


function check_days_off(scheduler, s)

    for (w_id, w) in enumerate(scheduler.workers)
        task_off = [t for i in w.days_off for t in scheduler.daily_indices[i+1]]
        if any(s[task_off, w_id])
            println("worker $w_id is working on his day off")
        end
    end
    
end