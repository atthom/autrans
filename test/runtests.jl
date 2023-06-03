using Test
using Autrans

function quick_test(days, n1, n2, workers, shouldbe)
    schedule = SmallSchedule(days, n1, n2, workers)
    result = optimize(schedule)
    @info make_df(schedule, result)
    @test fitness(result, schedule) <= shouldbe
end

@testset "test_exact" begin
    quick_test(7, 2, 2,  ["Cookie", "Fish"], 0)

    if false
        quick_test(7, 1, 1,  ["Cookie"], 0)
        quick_test(7, 2, 1,  ["Cookie", "Fish"], 10)
        quick_test(7, 1, 2,  ["Cookie", "Fish"], 0)
    end
end
