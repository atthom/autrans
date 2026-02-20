using Test
using Aqua
using Autrans

# Import specific types and functions to ensure they are recognized
using Autrans: AutransTask, AutransWorker, AutransScheduler, ProportionalEquity, AbsoluteEquity, solve
using Test: @test, @testset

# Standard constraints needed for tests to pass
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

function setup()
    # Common task definitions
    tasks = [
        AutransTask("Morning Setup", 2, 1:5),
        AutransTask("Customer Service", 3, 1:5),
        AutransTask("Inventory Check", 2, 1:5),
        AutransTask("Lunch Coverage", 2, 1:5),
        AutransTask("Afternoon Shift", 2, 1:5),
        AutransTask("Cleaning", 1, 1:5),
        AutransTask("Weekly Report", 2, 1),
        AutransTask("End of Week Review", 3, 5),
    ]
    
    # Workers with days off
    workers_with_days_off = [
        AutransWorker("Alice"),
        AutransWorker("Bob", [3]),
        AutransWorker("Charlie", [1, 5]),
        AutransWorker("Diana"),
        AutransWorker("Eve", [2, 4]),
        AutransWorker("Frank"),
        AutransWorker("Grace"),
        AutransWorker("Henry", [3]),
        AutransWorker("Ivy"),
        AutransWorker("Jack", [5])
    ]
    
    # Workers without days off
    workers_no_days_off = [
        AutransWorker("Alice"),
        AutransWorker("Bob"),
        AutransWorker("Charlie"),
        AutransWorker("Diana"),
        AutransWorker("Eve"),
        AutransWorker("Frank"),
        AutransWorker("Grace"),
        AutransWorker("Henry"),
        AutransWorker("Ivy"),
        AutransWorker("Jack")
    ]
    
    return tasks, workers_with_days_off, workers_no_days_off
end

function run_test(scheduler::AutransScheduler)
    result = solve(scheduler)
    return result !== nothing, result
end

function test_proportional_equity_with_days_off()
    tasks, workers, _ = setup()
    scheduler = AutransScheduler{ProportionalEquity}(
        workers, tasks, 5, 
        max_solve_time = 60.0, 
        verbose = false,
        hard_constraints = TEST_HARD_CONSTRAINTS,
        soft_constraints = TEST_SOFT_CONSTRAINTS
    )
    success, result = run_test(scheduler)
    @test success
    # Add more specific assertions here
end

function test_proportional_equity_without_days_off()
    tasks, _, workers = setup()
    scheduler = AutransScheduler{ProportionalEquity}(
        workers, tasks, 5, 
        max_solve_time = 60.0, 
        verbose = false,
        hard_constraints = TEST_HARD_CONSTRAINTS,
        soft_constraints = TEST_SOFT_CONSTRAINTS
    )
    success, result = run_test(scheduler)
    @test success
    # Add more specific assertions here
end

function test_absolute_equity_with_days_off()
    tasks, workers, _ = setup()
    scheduler = AutransScheduler{AbsoluteEquity}(
        workers, tasks, 5, 
        max_solve_time = 60.0, 
        verbose = false,
        hard_constraints = TEST_HARD_CONSTRAINTS,
        soft_constraints = TEST_SOFT_CONSTRAINTS
    )
    success, result = run_test(scheduler)
    @test success
    # Add more specific assertions here
end

function test_absolute_equity_without_days_off()
    tasks, _, workers = setup()
    scheduler = AutransScheduler{AbsoluteEquity}(
        workers, tasks, 5, 
        max_solve_time = 60.0, 
        verbose = false,
        hard_constraints = TEST_HARD_CONSTRAINTS,
        soft_constraints = TEST_SOFT_CONSTRAINTS
    )
    success, result = run_test(scheduler)
    @test success
    # Add more specific assertions here
end

@testset "Autrans" begin
    @testset "Scheduling Tests" begin
        test_proportional_equity_with_days_off()
        test_proportional_equity_without_days_off()
        test_absolute_equity_with_days_off()
        test_absolute_equity_without_days_off()
    end
end

@testset "Aqua Tests" begin
    # Disable stale_deps check since we have dependencies for scripts/server
    # that aren't used in the core library module
    Aqua.test_all(Autrans, stale_deps=false)
end
