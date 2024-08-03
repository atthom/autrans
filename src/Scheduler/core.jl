
function can_work(perm, day, worker_off)
    for (i, days_off) in worker_off
        if day in days_off && perm[i] == 1
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


function task_per_day_loss(scheduler, schedule, nb_worker)
    # equity between worker in type of task assigned
    agg_all_tasks_per_day = zeros(Int, (length(scheduler.all_task_indices_per_day), nb_worker))
    for (id_t, (t, indices)) in enumerate(scheduler.all_task_indices_per_day)
        agg_all_tasks_per_day[id_t, :] = sum(schedule[indices, :], dims=1)
    end
    coeff_task = [length(w.days_off) for w in scheduler.workers]
    coeff_task = scheduler.days ./ (scheduler.days .- coeff_task)

    agg_all_tasks_per_day = agg_all_tasks_per_day .* coeff_task'
    return agg_all_tasks_per_day, mse(agg_all_tasks_per_day)
end

function type_task_loss(scheduler, agg_all_tasks_per_day, nb_worker)
    agg_type_task = zeros(Int, (length(scheduler.task_type_indices), nb_worker))
    for (id_t, indices) in enumerate(scheduler.task_type_indices)
        agg_type_task[id_t, :] = sum(agg_all_tasks_per_day[indices, :], dims=1)
    end

    # update agg_tasks (people with less days should work less)
    coeff_task = [length(w.days_off) for w in scheduler.workers]
    coeff_task = scheduler.days ./ (scheduler.days .- coeff_task)

    agg_type_task = agg_type_task .* coeff_task'
    return mse(agg_type_task)
end

function workload_loss(scheduler, schedule, nb_worker)
    # equity between worker in daily workload
    agg_all_days = zeros(Int, (scheduler.days, nb_worker))
    for (i, d) in enumerate(scheduler.daily_indices)
        agg_all_days[i, :] = sum(schedule[d, :], dims=1)
    end
    return mse(agg_all_days)
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

    coeff_task = [length(w1.days_off) + length(w2.days_off) for w1 in scheduler.workers for w2 in scheduler.workers]
    coeff_task = scheduler.days ./ (scheduler.days .- coeff_task)
    agg_shuffle = agg_shuffle .* coeff_task

    agg_shuffle = maximum(agg_shuffle) - minimum(agg_shuffle)

    return agg_shuffle^2 * 0.1
end


function fitness(scheduler, schedule, verbose=false)
    #per_worker = sum(schedule, dims=1)
    # equity between worker in number of tasks assigned
    #per_worker_balance = maximum(per_worker) - minimum(per_worker)
    nb_worker = length(scheduler.workers)

    agg_all_tasks_per_day, agg_type_loss = task_per_day_loss(scheduler, schedule, nb_worker)

    agg_type_loss2 = type_task_loss(scheduler, agg_all_tasks_per_day, nb_worker)

    agg_workload_loss = workload_loss(scheduler, schedule, nb_worker)

    #agg_shuffle_loss = shuffle_team_loss(scheduler, schedule, nb_worker)

    if verbose
        print("balance=$per_worker_balance, agg_workload_loss=$agg_workload_loss,")
        print("agg_type_loss2=$agg_type_loss2, agg_time_loss=$agg_time_loss")
        println("")
    end

    #return per_worker_balance +agg_type_loss + agg_type_loss2 + agg_time_loss + agg_time_loss2
    return agg_type_loss*2 + agg_workload_loss + agg_type_loss2 #+ agg_shuffle_loss
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