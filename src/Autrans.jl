module Autrans

using DataFrames
#using Metaheuristics
using Chain
#using Combinatorics
using DataStructures
using StatsBase
using HTTP
using Oxygen
using OrderedCollections
using JuMP
using HiGHS
#using LinearAlgebra

include("structures.jl")
include("core.jl")
include("display.jl")

export serve, STask, SWorker, Scheduler, fitness, display_schedule
export permutations_seed, optimize_permutations, check_satisfability, solve

struct SchedulePayload
    workers::Vector{Tuple{String, Vector{Int}}}
    tasks::Vector{Tuple{String, Int, Int, Int, Int}}
    task_per_day::Vector{String}
    nb_days::Int
    balance_daysoff::Bool
end

function process_payload(req::HTTP.Request)
    schedule_payload = Oxygen.json(req, SchedulePayload)
    task_id = Dict(t => i-1 for (i, t) in enumerate(unique(schedule_payload.task_per_day))) 
    
    payload = Dict(
        "workers" => schedule_payload.workers,
        "tasks" => schedule_payload.tasks,
        "task_per_day" => [task_id[t] for t in schedule_payload.task_per_day], 
        "days" => schedule_payload.nb_days, 
        "balance_daysoff" => schedule_payload.balance_daysoff
    )

    @show payload

    return Scheduler(payload)
end

@post "/schedule" function(req::HTTP.Request)
    @time begin
        scheduler = process_payload(req)
        schedule = solve(scheduler)
        payload_back = Dict(
            "jobs" => agg_jobs(scheduler, schedule),
            "type" => agg_type(scheduler, schedule),
            "time" => agg_time(scheduler, schedule),
            "display" => agg_display(scheduler, schedule)
        )
    end
    return payload_back
end


@post "/sat" function(req::HTTP.Request)
    @time begin
        scheduler = process_payload(req)
        sat, answer = check_satisfability(scheduler)
        payload_back = Dict(
            "sat" => sat,
            "msg" => answer
        )
    end
    return payload_back
end

staticfiles("content", "static")

serve()



# payload = Dict{String, Any}("tasks" => [("Vaisselle Matin", 2, 1, 1, 7), ("Repas Midi", 3, 1, 0, 7), ("Vaisselle Midi", 2, 1, 0, 7), ("Repas Soir", 3, 1, 0, 6), ("Vaisselle Soir", 2, 1, 0, 6)], "days" => 7, "workers" => [("Jon", Int64[]), ("KAYOU", Int64[]), ("Bizzard", Int64[]), ("Bentho", Int64[]), ("Beurre", Int64[]), ("Poulpy", Int64[]), ("xX_Loan_Xx", [0]), ("Azriel", [0]), ("Melanight", [0, 3, 4]), ("Fishy", [0]), ("Cedric", [1]), ("Bere", [0, 1]), ("Curtis", Int64[]), ("Vydrat", [0, 1, 2, 3])], "balance_daysoff" => true, "task_per_day" => [0, 1, 2, 3, 4])
end
