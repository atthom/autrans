
using DataFrames
using Metaheuristics
using Chain
using Combinatorics
using DataStructures
using StatsBase
using HTTP
using Oxygen

include("structures.jl")
include("core.jl")
include("display.jl")

function test_new_format2()
    workers = ["Chronos", "Jon", "Beurre", "Poulpy", "LeRat", "Alichat", "Bendo", "Curt", "Fishy", "Melanight", "Bizzard", "Arc", "Zozo"]
    payload = Dict(
        "workers" => [("Chronos", Int[]), ("Jon", Int[]), ("Beurre", Int[]), ("Poulpy", Int[]), 
                    ("LeRat", Int[]), ("Alichat", Int[]), ("Bendo", Int[]), ("Curt", Int[0, 1, 2, 3, 4, 5]), 
                    ("Fishy", Int[]), ("Melanight", Int[4, 5]), ("Bizzard", Int[]),
                    ("Arc", Int[0, 1, 2, 3, 4]), ("Zozo", Int[0, 1, 2, 3, 4])],
        "tasks"=> [
            ("Vaiselle", 2, 1),
            ("Repas", 3, 1),
        ],
        "task_per_day"=> [0, 1, 0, 1, 0],
        "days" => 7, 
        "cutoff_N_first" => 3,
        "cutoff_N_last" => 0
    )
    # arc, zozo => jeudi arrive
    # curt => vendredi arrive
    # melanight => dimanche soir au mercredi, vendredi soir => dimanche matin
    # fishy dimanche matin
    scheduler = Scheduler(payload)
 
    #schedule = tabu_search(scheduler, nb_gen = 500, maxTabuSize=200)
    #schedule = genetic_search(scheduler, pop_size=50, nb_gen = 2000)
    #schedule = simple_search(scheduler, nb_gen = 2000)
    schedule = optimize_permutations(scheduler, nb_gen = 10)

    println(agg_jobs(scheduler, schedule))
    println(agg_type(scheduler, schedule))
    println(agg_time(scheduler, schedule))
    println(agg_display(scheduler, schedule))

    return scheduler
end



struct SchedulePayload
    workers::Vector{Tuple{String, Vector{Int}}}
    tasks::Vector{Tuple{String, Int, Int}}
    task_per_day::Vector{String}
    nb_days::Int
    cutoff_first::Int
    cutoff_last::Int
end


@post "/schedule" function(req::HTTP.Request)

    schedule_payload = Oxygen.json(req, SchedulePayload)
    task_id = Dict(t => i-1 for (i, t) in enumerate(unique(schedule_payload.task_per_day))) 
    
    payload = Dict(
        "workers" => schedule_payload.workers,
        "tasks"=> schedule_payload.tasks,
        "task_per_day" => [task_id[t] for t in schedule_payload.task_per_day], 
        "days" => schedule_payload.nb_days, 
        "cutoff_N_first"=> schedule_payload.cutoff_first,
        "cutoff_N_last"=> schedule_payload.cutoff_last
    )

    @show payload

    scheduler = Scheduler(payload)
    schedule = tabu_search(scheduler, nb_gen = 500, maxTabuSize=200)

    payload_back = Dict(
        "jobs" => agg_jobs(scheduler, schedule),
        "type" => agg_type(scheduler, schedule),
        "time" => agg_time(scheduler, schedule),
        "display" => agg_display(scheduler, schedule)
    )
    return payload_back
end


serve()
