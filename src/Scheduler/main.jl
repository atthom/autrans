
using Stipple, StippleUI
using DataFrames
using Metaheuristics
using Chain
using Combinatorics
using DataStructures
using StatsBase

include("structures.jl")
include("core.jl")
include("display.jl")

function test_new_format2()
    payload = Dict(
        "workers" => [("Chronos", Int[]), ("Jon", Int[]), ("Beurre", Int[]),
                    ("Fishy", Int[]),("Bendo", Int[]),("Alicia", Int[]),
                    ("Poulpy", Int[]),("Curt", Int[]),("LeRat", Int[]),
                    ("Bizard", Int[])],
        "tasks"=> [
            ("Vaiselle", 2, 1),
            ("Repas", 3, 1),
        ],
        "task_per_day"=> [0, 1, 0, 1, 0],
        "days"=> 7, 
        "cutoff_N_first"=> 2,
        "cutoff_N_last"=> 1
    )
    
    scheduler = Scheduler(payload)
 
    schedule = tabu_search(scheduler)
    println(agg_jobs(scheduler, schedule))
    println(agg_type(scheduler, schedule))
    println(agg_time(scheduler, schedule))
    println(agg_display(scheduler, schedule))


    return scheduler
end