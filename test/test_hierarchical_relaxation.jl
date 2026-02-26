# Test hierarchical relaxation system

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
    Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "Task Diversity")
]

@testset "Hierarchical Relaxation" begin
    
    @testset "Feasible scenario with relaxation" begin
        # Scenario that needs task diversity relaxation
        workers = [
            AutransWorker("Person 1", Int[]),
            AutransWorker("Person 2", Int[]),
            AutransWorker("Person 3", Int[]),
            AutransWorker("Person 4", Int[]),
            AutransWorker("Person 5", Int[]),
            AutransWorker("Person 6", Int[])
        ]
        
        tasks = [
            AutransTask("Chore 1", 2, 1:7),
            AutransTask("Chore 2", 2, 1:7),
            AutransTask("Chore 3", 2, 1:7)
        ]
        
        # 6 workers, 3 tasks (2 workers each), 7 days
        # Total slots: 3 × 2 × 7 = 42
        # Available: 6 × 7 = 42 (100% utilization)
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            7,
            equity_strategy=:proportional,
            max_solve_time=60.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        if result !== nothing
            N, D, T = size(result)
            
            # Verify basic constraints
            @test N == 6
            @test D == 7
            @test T == 3
            
            # Verify all assignments are binary
            @test all(x -> x in [0, 1], result)
            
            # Verify total workload
            total_assignments = sum(result)
            @test total_assignments == 42
            
            # Verify each worker has reasonable workload
            for w in 1:N
                worker_total = sum(result[w, :, :])
                @test worker_total >= 5 && worker_total <= 9
            end
        end
    end
    
    @testset "Impossible scenario (insufficient capacity)" begin
        # Mathematically impossible scenario - single task needs more workers than available
        workers = [
            AutransWorker("Person 1", Int[]),
            AutransWorker("Person 2", Int[]),
            AutransWorker("Person 3", Int[]),
            AutransWorker("Person 4", Int[])
        ]
        
        tasks = [
            AutransTask("Chore 1", 5, 1:1)  # Needs 5 workers but only 4 available
        ]
        
        # 4 workers, 1 task needs 5 workers = IMPOSSIBLE
        # This will be caught by pre-check (obvious infeasibility)
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            7,
            equity_strategy=:proportional,
            max_solve_time=10.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        @test result === nothing
        @test failure_info !== nothing
    end
    
    @testset "Scenario with days off" begin
        # Test relaxation with days off
        workers = [
            AutransWorker("Person 1", Set([1, 7])),  # 2 days off
            AutransWorker("Person 2", Set([2])),     # 1 day off
            AutransWorker("Person 3", Set{Int}()),   # No days off
            AutransWorker("Person 4", Set{Int}()),   # No days off
            AutransWorker("Person 5", Set([3, 4])),  # 2 days off
            AutransWorker("Person 6", Set{Int}())    # No days off
        ]
        
        tasks = [
            AutransTask("Task 1", 2, 1:7),
            AutransTask("Task 2", 2, 1:7)
        ]
        
        # Total slots: 2 × 2 × 7 = 28
        # Available worker-days: (5+6+7+7+5+7) = 37
        # Should be feasible with relaxation
        
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
            # Verify days off are respected
            for (w, worker) in enumerate(workers)
                for day in worker.days_off
                    if 1 <= day <= 7
                        day_assignments = sum(result[w, day, :])
                        @test day_assignments == 0
                    end
                end
            end
        end
    end
    
    @testset "Edge case: Minimal scenario" begin
        # Smallest possible scenario
        workers = [
            AutransWorker("Worker 1", Int[]),
            AutransWorker("Worker 2", Int[])
        ]
        
        tasks = [
            AutransTask("Task 1", 2, 1:1)  # 1 task, 2 workers, 1 day
        ]
        
        scheduler = AutransScheduler(
            workers,
            tasks,
            1,
            equity_strategy=:proportional,
            max_solve_time=5.0,
            verbose=false,
            hard_constraints=TEST_HARD_CONSTRAINTS,
            soft_constraints=TEST_SOFT_CONSTRAINTS
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        
        if result !== nothing
            @test sum(result) == 2
            @test result[1, 1, 1] == 1
            @test result[2, 1, 1] == 1
        end
    end
end