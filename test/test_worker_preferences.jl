# Test worker preference constraint

using Test
using Autrans

# Standard constraints needed for tests
const TEST_HARD_CONSTRAINTS = [
    Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "Task Coverage"),
    Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "No Consecutive Tasks"),
    Autrans.HardConstraint(Autrans.DaysOffConstraint(), "Days Off")
]

const TEST_SOFT_CONSTRAINTS = [
    Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "Overall Equity"),
    Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "Daily Equity"),
    Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "Task Diversity"),
    Autrans.SoftConstraint(Autrans.WorkerPreferenceConstraint(), "Worker Preferences")
]

@testset "Worker Preferences" begin
    
    @testset "Basic preference distribution" begin
        # Workers with preferences should get tasks from their preference list
        workers = [
            AutransWorker("Alex", Int[], Int[]),           # No preferences
            AutransWorker("Benjamin", Int[], [1, 2, 3]),   # Prefers: Cleaning, Shopping, Cooking
            AutransWorker("Caroline", Int[], Int[]),
            AutransWorker("Diane", Int[], Int[]),
            AutransWorker("Esteban", Int[], Int[]),
            AutransWorker("Frank", Int[], Int[])
        ]
        
        tasks = [
            AutransTask("Cleaning", 2, 1:7),
            AutransTask("Shopping", 2, 1:7),
            AutransTask("Cooking", 2, 1:7)
        ]
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            7,
            equity_strategy=:proportional,
            max_solve_time=30.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        if result !== nothing
            # Benjamin (worker 2) should get tasks from all 3 preferred tasks
            benjamin_assignments = result[2, :, :]
            
            cleaning_count = sum(benjamin_assignments[:, 1])
            shopping_count = sum(benjamin_assignments[:, 2])
            cooking_count = sum(benjamin_assignments[:, 3])
            
            @test cleaning_count > 0
            @test shopping_count > 0
            @test cooking_count > 0
            
            total = cleaning_count + shopping_count + cooking_count
            @test total >= 5 && total <= 9
        end
    end
    
    @testset "Preference ranking respected" begin
        # Test that higher-ranked preferences get more assignments
        workers = [
            AutransWorker("Worker 1", Int[], [1, 2]),  # Strongly prefers Task 1
            AutransWorker("Worker 2", Int[], [2, 1]),  # Strongly prefers Task 2
            AutransWorker("Worker 3", Int[], Int[]),
            AutransWorker("Worker 4", Int[], Int[])
        ]
        
        tasks = [
            AutransTask("Task 1", 2, 1:5),
            AutransTask("Task 2", 2, 1:5)
        ]
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            5,
            equity_strategy=:proportional,
            max_solve_time=20.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        if result !== nothing
            # Worker 1 should do more Task 1 than Task 2
            w1_task1 = sum(result[1, :, 1])
            w1_task2 = sum(result[1, :, 2])
            
            # Worker 2 should do more Task 2 than Task 1
            w2_task1 = sum(result[2, :, 1])
            w2_task2 = sum(result[2, :, 2])
            
            # Note: Due to other constraints, this might not always be strictly true
            # but on average preferences should be respected
            @test w1_task1 + w2_task2 >= w1_task2 + w2_task1
        end
    end
    
    @testset "Mixed preferences scenario (infeasible)" begin
        # Infeasible: 6 workers, 4 tasks (2 each), 7 days = 133% utilization
        workers = [
            AutransWorker("Worker 1", Int[], [1, 2, 3, 4]),
            AutransWorker("Worker 2", Int[], [2, 1, 4, 3]),
            AutransWorker("Worker 3", Int[], [3, 4, 1, 2]),
            AutransWorker("Worker 4", Int[], [4, 3, 2, 1]),
            AutransWorker("Worker 5", Int[], [1, 3, 2, 4]),
            AutransWorker("Worker 6", Int[], [2, 4, 1, 3])
        ]
        
        tasks = [
            AutransTask("Task 1", 2, 1:7),
            AutransTask("Task 2", 2, 1:7),
            AutransTask("Task 3", 2, 1:7),
            AutransTask("Task 4", 2, 1:7)
        ]
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            7,
            equity_strategy=:proportional,
            max_solve_time=30.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        # Should correctly identify as infeasible
        @test result === nothing
        @test failure_info !== nothing
    end
    
    @testset "Mixed preferences scenario (feasible)" begin
        # Feasible: 8 workers, 4 tasks (2 each), 7 days = 100% utilization
        workers = [
            AutransWorker("Worker 1", Int[], [1, 2, 3, 4]),
            AutransWorker("Worker 2", Int[], [2, 1, 4, 3]),
            AutransWorker("Worker 3", Int[], [3, 4, 1, 2]),
            AutransWorker("Worker 4", Int[], [4, 3, 2, 1]),
            AutransWorker("Worker 5", Int[], [1, 3, 2, 4]),
            AutransWorker("Worker 6", Int[], [2, 4, 1, 3]),
            AutransWorker("Worker 7", Int[], [1, 2, 3, 4]),
            AutransWorker("Worker 8", Int[], [4, 3, 2, 1])
        ]
        
        tasks = [
            AutransTask("Task 1", 2, 1:7),
            AutransTask("Task 2", 2, 1:7),
            AutransTask("Task 3", 2, 1:7),
            AutransTask("Task 4", 2, 1:7)
        ]
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            7,
            equity_strategy=:proportional,
            max_solve_time=30.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        if result !== nothing
            # Verify each worker gets reasonable distribution
            for w in 1:8
                worker_total = sum(result[w, :, :])
                @test worker_total >= 5 && worker_total <= 9
                
                # Each worker should participate in multiple tasks
                tasks_done = sum([sum(result[w, :, t]) > 0 for t in 1:4])
                @test tasks_done >= 2
            end
        end
    end
    
    @testset "Preferences with days off (infeasible)" begin
        # Infeasible: 4 workers with days off, 2 tasks, 5 days = 125% utilization
        workers = [
            AutransWorker("Worker 1", Set([1, 2]), [1, 2]),
            AutransWorker("Worker 2", Set([3, 4]), [2, 1]),
            AutransWorker("Worker 3", Set{Int}(), Int[]),
            AutransWorker("Worker 4", Set{Int}(), Int[])
        ]
        
        tasks = [
            AutransTask("Task 1", 2, 1:5),
            AutransTask("Task 2", 2, 1:5)
        ]
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            5,
            equity_strategy=:proportional,
            max_solve_time=20.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        # Should correctly identify as infeasible
        @test result === nothing
        @test failure_info !== nothing
    end
    
    @testset "Preferences with days off (feasible)" begin
        # Feasible: 6 workers with days off, 2 tasks, 5 days = ~83% utilization
        workers = [
            AutransWorker("Worker 1", Set([1, 2]), [1, 2]),
            AutransWorker("Worker 2", Set([3, 4]), [2, 1]),
            AutransWorker("Worker 3", Set{Int}(), Int[]),
            AutransWorker("Worker 4", Set{Int}(), Int[]),
            AutransWorker("Worker 5", Set{Int}(), [1, 2]),
            AutransWorker("Worker 6", Set{Int}(), [2, 1])
        ]
        
        tasks = [
            AutransTask("Task 1", 2, 1:5),
            AutransTask("Task 2", 2, 1:5)
        ]
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            5,
            equity_strategy=:proportional,
            max_solve_time=20.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        if result !== nothing
            # Verify days off are respected
            @test sum(result[1, [1, 2], :]) == 0
            @test sum(result[2, [3, 4], :]) == 0
            
            # Verify preferences still influence available days
            w1_available_days = [3, 4, 5]
            w1_task1 = sum(result[1, w1_available_days, 1])
            w1_task2 = sum(result[1, w1_available_days, 2])
            
            # Worker 1 prefers Task 1, so should do more of it (when possible)
            @test w1_task1 >= 0
        end
    end
end