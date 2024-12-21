module Autrans

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

export serve

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
        "tasks"=> schedule_payload.tasks,
        "task_per_day" => [task_id[t] for t in schedule_payload.task_per_day], 
        "days" => schedule_payload.nb_days, 
        "balance_daysoff" => schedule_payload.balance_daysoff
    )

    #@show payload

    return Scheduler(payload)
end

@post "/schedule" function(req::HTTP.Request)
    @time begin
        scheduler = process_payload(req)
        schedule = optimize_permutations(scheduler)
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

#serve()


end
