using Test
using Autrans

function quick_test(days, n1, n2, workers, shouldbe)
    schedule = SmallSchedule(days, n1, n2, workers)
    result = optimize(schedule)
    @info fitness(result, schedule)
    @test fitness(result, schedule) <= shouldbe
end

@testset "test_exact" begin

    quick_test(7, 2, 2,  ["Cookie", "Fish"], 24)
    quick_test(7, 1, 1,  ["Cookie"], 0)
    quick_test(7, 2, 1,  ["Cookie", "Fish"], 0)
    quick_test(7, 1, 2,  ["Cookie", "Fish"], 0)

    quick_test(7, 1, 1,  ["W$i" for i in 1:7], 200)
    quick_test(7, 2, 1,  ["W$i" for i in 1:7], 200)
    quick_test(7, 2, 1,  ["W$i" for i in 1:14], 200)
end



@testset "test_inexact" begin

    quick_test(7, 1, 1,  ["Cookie", "Fish"], 17)
    quick_test(7, 4, 1,  ["Cookie", "Fish"], 50)
    quick_test(7, 1, 4,  ["Cookie", "Fish"], 280)

    quick_test(7, 13, 3,  ["W$i" for i in 1:7], 1500)
    quick_test(7, 3, 13,  ["W$i" for i in 1:14], 583)
end
