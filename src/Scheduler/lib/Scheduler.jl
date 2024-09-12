

include("structures.jl")
include("core.jl")
include("displays.jl")

function find_schedule(s::Scheduler; nb_gen=100, maxTabuSize=100)
    res = tabu_search(s, nb_gen=nb_gen, maxTabuSize=maxTabuSize)
    #return agg_time(scheduler, res), agg_jobs(scheduler, res), agg_type(scheduler, res)
    return res
end

function test_new_format()
    workers =  ["Chronos", "Jon", "Beurre", "Fishy", "Bendo", "Alicia", "Poulpy", "Curt", "LeRat", "Bizard"]
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

