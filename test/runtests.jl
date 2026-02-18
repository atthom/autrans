using Test
using Autrans
# using Chain
# using BenchmarkTools


function make_simple_payload(nb_days, nb_tasks, nb_workers, nb_worker_per_task)
    return Dict(
        "workers" => [("Worker $i_worker", Int[]) for i_worker in 1:nb_workers],
        "tasks"=> [("Task $i_task", nb_worker_per_task, 1, 1, nb_days) for i_task in 1:nb_tasks],
        "task_per_day"=> 0:nb_tasks-1 |> collect,
        "days" => nb_days, 
        "balance_daysoff" => false
    )
end


function make_complex_payload(nb_days_worker, nb_tasks, nb_worker_per_task, balance_daysoff)
    tasks = [("Task 1", nb_worker_per_task, 1, 2, nb_days_worker)]
    tasks = vcat([("Task  $i_task", nb_worker_per_task, 1, 1, nb_days_worker) for i_task in 2:nb_tasks-1]..., tasks)
    tasks = push!(tasks, ("Task $nb_tasks", nb_worker_per_task, 1, 1, nb_days_worker - 1))
    return Dict(
        "workers" => [("Worker $i_worker", [i_worker]) for i_worker in 1:nb_days_worker],
        "tasks" => tasks,
        "task_per_day" => 0:nb_tasks-1 |> collect,
        "days" => nb_days_worker, 
        "balance_daysoff" => balance_daysoff
    )
end

function seed_opti(payload)
    scheduler = Autrans.Scheduler(payload)
    @test Autrans.check_satisfability(scheduler) == (true, "OK")
    seed = Autrans.permutations_seed(scheduler)
    res = Autrans.solve(scheduler)
    return scheduler, seed, res
end

@testset "impossible_payload" begin
    payload = make_simple_payload(10, 10, 1, 2)
    scheduler = Autrans.Scheduler(payload)
    @test Autrans.check_satisfability(scheduler) == (false, "Not enough worker for task Task 1 on day 1")
    
    payload = make_simple_payload(6, 2, 2, 2)
    payload["workers"][2] = ("Worker 2",  [2, 3, 4])
    @test Autrans.check_satisfability(scheduler) == (false, "Not enough worker for task Task 1 on day 1")

end

@testset "perfect_payload" begin
    payload = make_simple_payload(10, 10, 2, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, seed)  == Autrans.fitness(scheduler, res) == 0
    payload = make_simple_payload(10, 10, 2, 2)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, seed) == Autrans.fitness(scheduler, res) == 0

    payload = make_simple_payload(3, 2, 3, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 3

    payload = make_simple_payload(2, 2, 2, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 0
    
    payload = make_simple_payload(4, 2, 4, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 4

    payload = make_simple_payload(4, 2, 4, 2)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 0

    payload = make_simple_payload(2, 2, 2, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 0

    payload = make_simple_payload(3, 3, 3, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 0
end

@testset "inexact_payload" begin

    payload = make_simple_payload(5, 5, 5, 2)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    @test Autrans.fitness(scheduler, res) == 0
    
    payload = make_simple_payload(3, 3, 3, 2)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    @test Autrans.fitness(scheduler, res) == 0
    #display(scheduler, seed)

end

@testset "complex_payload" begin
    payload = make_complex_payload(5, 5, 2, false)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    @test Autrans.fitness(scheduler, res) == 10

    # issue
    payload = make_complex_payload(10, 10, 2, false)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    
    payload = make_simple_payload(12, 3, 3, 2)
    payload["workers"][2] = ("Worker 2",  [2, 3])
    scheduler, seed, res = seed_opti(payload)
    # @test @chain sum(seed, dims=1) extrema _[2] - _[1] == 0
    @test maximum(sum(seed, dims=1)) - minimum(sum(seed, dims=1)) == 0
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    @test Autrans.fitness(scheduler, res) == 13

    payload = make_simple_payload(6, 3, 3, 2)
    payload["workers"][2] = ("Worker 2",  [2, 3])
    scheduler, seed, res = seed_opti(payload)
    @test @chain sum(seed, dims=1) extrema _[2] - _[1] == 0
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    @test Autrans.fitness(scheduler, res) == 13
end


@testset "balance_daysoff" begin

    payload = make_simple_payload(6, 3, 3, 2)
    payload["workers"][2] = ("Worker 2",  [2, 3])
    scheduler, seed, res = seed_opti(payload)
    @test @chain sum(seed, dims=1) extrema _[2] - _[1] == 0
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    @test Autrans.fitness(scheduler, res) == 13
    
    payload["balance_daysoff"] = true
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) <= Autrans.fitness(scheduler, seed) 
    @test Autrans.fitness(scheduler, seed) == 87

end

@testset "JuMP Benchmark" begin
    payload = make_complex_payload(10, 10, 2, true)
    println("Benchmark")
    println("Scheduler Creation")
    scheduler = Autrans.Scheduler(payload)
    println("Scheduler SAT")
    @test Autrans.check_satisfability(scheduler) == (true, "OK")
    println("Scheduler permutations_seed")
    seed = Autrans.permutations_seed(scheduler)
    println("Scheduler Solving")
    res = Autrans.solve(scheduler)
    @test Autrans.fitness(scheduler, res) <= 15
    #@test Autrans.fitness(scheduler, seed) == 0
end

@testset "primediv" begin
    payload = make_simple_payload(5, 7, 11, 3)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) <= 20
    @test Autrans.fitness(scheduler, seed) == 70

    #payload = make_complex_payload(5, 7, 11, 3)
    #scheduler, seed, res = seed_opti(payload)

end


@testset "JuMP" begin
    payload = make_simple_payload(10, 10, 10, 2)
    scheduler, seed, res = seed_opti(payload)

    @test Autrans.fitness(scheduler, res) == 0
    @test Autrans.fitness(scheduler, seed) == 64

    payload = make_simple_payload(3, 2, 3, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 3

    payload = make_simple_payload(4, 2, 4, 1)
    scheduler, seed, res = seed_opti(payload)
    @test Autrans.fitness(scheduler, res) == Autrans.fitness(scheduler, seed) == 4
    
end

# Run new tests
include("test_autrans.jl")
