using Test
using Autrans

function quick_test(days, n1, n2, workers, shouldbe)
    schedule = SmallSchedule(days, n1, n2, workers)
    schedule, searchspace = SearchPathBoxConstraint(schedule)
    result = optimize(schedule, searchspace)
    @info fitness(result, schedule)
    @test fitness(result, schedule) <= shouldbe
end

function test_cardinality(days, n1, n2, workers, shouldbe)
    schedule = SmallSchedule(days, n1, n2, workers)
    c = cardinality(schedule)
    @test c == shouldbe
end


@testset "test_exact" begin
    quick_test(7, 2, 2,  ["Cookie", "Fish"], 0)
    quick_test(7, 1, 1,  ["Cookie"], 0)
    quick_test(7, 2, 1,  ["Cookie", "Fish"], 0)
    quick_test(7, 1, 2,  ["Cookie", "Fish"], 0)
    quick_test(7, 4, 1,  ["Cookie", "Fish"], 0)
    quick_test(7, 1, 1,  ["W$i" for i in 1:7], 0)
    quick_test(7, 1, 2,  ["W$i" for i in 1:7], 0)
    quick_test(7, 2, 1,  ["W$i" for i in 1:7], 0)
end

@testset "test_inexact" begin
    quick_test(7, 2, 1,  ["W$i" for i in 1:14], 12)
    quick_test(7, 1, 2,  ["W$i" for i in 1:14], 12)
    quick_test(7, 13, 3,  ["W$i" for i in 1:7], 12)
    quick_test(7, 3, 13,  ["W$i" for i in 1:14], 80)
    quick_test(7, 1, 1,  ["Cookie", "Fish"], 5)
end

@testset "test_impossible" begin
    test_cardinality(7, 1, 2,  ["Cookie"], 0)
    test_cardinality(7, 1, 4,  ["Cookie", "Fish"], 0)
end

@testset "test_single_solution" begin
    test_cardinality(7, 2, 2,  ["Cookie", "Fish"], 1)
    test_cardinality(7, 1, 1,  ["Cookie"], 1)
    test_cardinality(7, 1, 2,  ["Cookie", "Fish"], 1)
end
