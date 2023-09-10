
using Stipple, StippleUI
using DataFrames
using Metaheuristics
using Chain
using Combinatorics
using DataStructures
using StatsBase

include("structures.jl")
include("core.jl")


function test_new_format()
    workers =  ["Chronos","Jon", "Beurre","Fishy","Bendo","Alicia","Poulpy","Curt","LeRat","Bizard"]
    days_off = repeat([Int[]], length(workers))
    v = Task("Vaiselle", 2)
    r = Task("Repas", 2)
    task_per_day = [v, r, v, r, v]
    days = 7
    cutoff_N_first = 1
    cutoff_N_last = 1
    scheduler = Scheduler(zip(workers, days_off), task_per_day, days, cutoff_N_first, cutoff_N_last)

    return scheduler
end

function test_new_format2()

    payload = Dict(
        "workers" => [("Chronos", []), ("Jon", []), ("Beurre", []),
                    ("Fishy", []),("Bendo", []),("Alicia", []),
                    ("Poulpy", []),("Curt", []),("LeRat", []),
                    ("Bizard", [6, 7])],
        "tasks"=> [
            ("Vaiselle", 2, 1),
            ("Repas", 2, 1),
        ],
        "task_per_day"=> [0, 1, 0, 1, 0],
        "days"=> 7, 
        "cutoff_N_first"=>1,
        "cutoff_N_last"=> 1
    )
    scheduler = Scheduler(payload)

    return scheduler
end