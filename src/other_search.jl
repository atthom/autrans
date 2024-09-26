






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


