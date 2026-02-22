using Test
using Autrans

@testset "Task Difficulty" begin
    
    @testset "Difficulty Field Exists" begin
        # Test that difficulty field is present and works
        task = AutransTask("Test", 1, 1:5, 3)
        @test task.difficulty == 3
        
        # Test default difficulty
        task_default = AutransTask("Test", 1, 1:5)
        @test task_default.difficulty == 1
    end
    
    @testset "Difficulty Validation" begin
        # Test that difficulty < 1 is rejected
        @test_throws AssertionError AutransTask("Invalid", 1, 1:5, 0)
        @test_throws AssertionError AutransTask("Invalid", 1, 1:5, -1)
        
        # Test that difficulty >= 1 is valid
        @test AutransTask("Valid", 1, 1:5, 1) isa AutransTask
        @test AutransTask("Valid", 1, 1:5, 10) isa AutransTask
    end
    
    @testset "Default Difficulty" begin
        # Test that difficulty defaults to 1 when not specified
        task1 = AutransTask("Task", 1, 1:5)
        @test task1.difficulty == 1
        
        task2 = AutransTask("Task", 1, 1, 5)
        @test task2.difficulty == 1
        
        task3 = AutransTask("Task", 1, 1)
        @test task3.difficulty == 1
    end
    
    @testset "Simple Schedule with Difficulty=1" begin
        workers = [
            AutransWorker("Alice", Int[]),
            AutransWorker("Bob", Int[])
        ]
        
        tasks = [
            AutransTask("Task1", 1, 1:3, 1),
            AutransTask("Task2", 1, 1:3, 1)
        ]
        
        scheduler = AutransScheduler(workers, tasks, 3, equity_strategy=:absolute)
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        @test failure_info === nothing
    end
    
    @testset "Schedule with Mixed Difficulties" begin
        workers = [
            AutransWorker("Alice", Int[]),
            AutransWorker("Bob", Int[])
        ]
        
        tasks = [
            AutransTask("Easy", 1, 1:3, 1),
            AutransTask("Hard", 1, 1:3, 3)
        ]
        
        scheduler = AutransScheduler(workers, tasks, 3, equity_strategy=:absolute)
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        # Calculate difficulty points for each worker
        alice_pts = sum(result[1, d, t] * tasks[t].difficulty for d in 1:3, t in 1:2)
        bob_pts = sum(result[2, d, t] * tasks[t].difficulty for d in 1:3, t in 1:2)
        
        # Both workers should have similar difficulty points
        @test abs(alice_pts - bob_pts) <= 3  # Allow some variance
    end
    
    @testset "Workload Offset Uses Difficulty Points" begin
        workers = [
            AutransWorker("Alice", Int[], Int[], -2),  # Should work less
            AutransWorker("Bob", Int[], Int[], 2)      # Should work more
        ]
        
        tasks = [
            AutransTask("Task", 1, 1:4, 2)
        ]
        
        scheduler = AutransScheduler(workers, tasks, 4, equity_strategy=:absolute)
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        alice_pts = sum(result[1, d, t] * tasks[t].difficulty for d in 1:4, t in 1:1)
        bob_pts = sum(result[2, d, t] * tasks[t].difficulty for d in 1:4, t in 1:1)
        
        # Bob should work more than Alice
        @test bob_pts >= alice_pts
    end
    
    @testset "Backward Compatibility - Constructor" begin
        # Test that old constructors still work (without difficulty parameter)
        task_old1 = AutransTask("Task", 1, 1:5)
        @test task_old1.difficulty == 1
        
        task_old2 = AutransTask("Task", 1, 1, 5)
        @test task_old2.difficulty == 1
        
        # Test new constructor with difficulty
        task_new = AutransTask("Task", 1, 1, 5, 3)
        @test task_new.difficulty == 3
    end
    
end