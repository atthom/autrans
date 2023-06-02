using Test

using Autrans



@testset "test_exact" begin
    nb_days = 7
    nb_task_per_day = 5
    nb_pers_per_work = 1
    #workers = ["thomas", "chronos", "curt", "astor", "manal", "thibs", "laura", "benj"]
    workers = ["Cookie", "Fish", "Chronos"]
    schedule = SmallSchedule(nb_days, nb_task_per_day, nb_pers_per_work, workers)
    @info schedule
    result = optimize(x -> fitness(x, schedule), schedule)
    @info fitness(result, schedule, true))
    pprint(schedule, result)

end