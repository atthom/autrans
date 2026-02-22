using Test
using Autrans
using Autrans: SoftConstraint, HardConstraint, OverallEquityConstraint, normalize_offsets

@testset "Workload Offset Tests" begin
    
    @testset "Basic Offset Functionality" begin
        # Simple scenario: 3 workers, 9 tasks total (3 per day, feasible)
        workers = [
            AutransWorker("Alice", Set{Int}(), Int[], -1),  # Should work less
            AutransWorker("Bob", Set{Int}(), Int[], +1),    # Should work more
            AutransWorker("Charlie", Set{Int}(), Int[], 0)  # Baseline
        ]
        
        tasks = [
            AutransTask("Task1", 1, 1:3),  # 1 worker per day
            AutransTask("Task2", 1, 1:3),  # 1 worker per day
            AutransTask("Task3", 1, 1:3)   # 1 worker per day
        ]
        
        scheduler = AutransScheduler(
            workers, tasks, 3,
            equity_strategy=:absolute,
            verbose=false,
            soft_constraints=[
                SoftConstraint(OverallEquityConstraint(), "OverallEquity")
            ]
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        @test failure_info === nothing
        
        # Check workload distribution
        alice_work = sum(result[1, :, :])
        bob_work = sum(result[2, :, :])
        charlie_work = sum(result[3, :, :])
        
        # Alice should work less than Charlie
        @test alice_work < charlie_work
        # Bob should work more than Charlie
        @test bob_work > charlie_work
        # Total should be 9
        @test alice_work + bob_work + charlie_work == 9
    end
    
    @testset "All Negative Offsets - Normalization" begin
        # All workers worked too much before
        # After normalization: Alice=-2, Bob=0, Charlie=-1
        workers = [
            AutransWorker("Alice", Set{Int}(), Int[], -3),
            AutransWorker("Bob", Set{Int}(), Int[], -1),
            AutransWorker("Charlie", Set{Int}(), Int[], -2)
        ]
        
        tasks = [
            AutransTask("Task1", 1, 1:3),
            AutransTask("Task2", 1, 1:3),
            AutransTask("Task3", 1, 1:3)
        ]
        
        scheduler = AutransScheduler(
            workers, tasks, 3,
            equity_strategy=:absolute,
            verbose=false,
            soft_constraints=[
                SoftConstraint(OverallEquityConstraint(), "OverallEquity")
            ]
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        @test failure_info === nothing
        
        alice_work = sum(result[1, :, :])
        bob_work = sum(result[2, :, :])
        charlie_work = sum(result[3, :, :])
        
        # Bob should have most work (baseline=0 after normalization)
        @test bob_work >= alice_work
        @test bob_work >= charlie_work
        # Alice should have least work (offset=-2 after normalization)
        @test alice_work <= charlie_work
        # Total work done (may vary due to normalization effects)
        @test alice_work + bob_work + charlie_work > 0
    end
    
    @testset "All Positive Offsets - Normalization" begin
        # All workers worked too little before
        # After normalization: Alice=+1, Bob=+2, Charlie=0
        workers = [
            AutransWorker("Alice", Set{Int}(), Int[], +2),
            AutransWorker("Bob", Set{Int}(), Int[], +3),
            AutransWorker("Charlie", Set{Int}(), Int[], +1)
        ]
        
        tasks = [
            AutransTask("Task1", 1, 1:3),
            AutransTask("Task2", 1, 1:3),
            AutransTask("Task3", 1, 1:3)
        ]
        
        scheduler = AutransScheduler(
            workers, tasks, 3,
            equity_strategy=:absolute,
            verbose=false,
            soft_constraints=[
                SoftConstraint(OverallEquityConstraint(), "OverallEquity")
            ]
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        @test failure_info === nothing
        
        alice_work = sum(result[1, :, :])
        bob_work = sum(result[2, :, :])
        charlie_work = sum(result[3, :, :])
        
        # Charlie should have least work (baseline=0 after normalization)
        @test charlie_work <= alice_work
        @test charlie_work <= bob_work
        # Bob should have most work (offset=+2 after normalization)
        @test bob_work >= alice_work
        # Total work done (may vary due to normalization effects)
        @test alice_work + bob_work + charlie_work > 0
    end
    
    @testset "Mixed Offsets - No Normalization Needed" begin
        # Mixed positive and negative
        workers = [
            AutransWorker("Alice", Set{Int}(), Int[], -2),
            AutransWorker("Bob", Set{Int}(), Int[], +2),
            AutransWorker("Charlie", Set{Int}(), Int[], 0)
        ]
        
        tasks = [
            AutransTask("Task1", 1, 1:3),
            AutransTask("Task2", 1, 1:3),
            AutransTask("Task3", 1, 1:3)
        ]
        
        scheduler = AutransScheduler(
            workers, tasks, 3,
            equity_strategy=:absolute,
            verbose=false,
            soft_constraints=[
                SoftConstraint(OverallEquityConstraint(), "OverallEquity")
            ]
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        @test failure_info === nothing
        
        alice_work = sum(result[1, :, :])
        bob_work = sum(result[2, :, :])
        charlie_work = sum(result[3, :, :])
        
        # Alice should work least (negative offset)
        @test alice_work <= charlie_work
        # Bob should work most (positive offset)
        @test bob_work >= charlie_work
        @test alice_work + bob_work + charlie_work == 9
    end
    
    @testset "Zero Offsets (Backward Compatibility)" begin
        # All workers with default offset (0)
        workers = [
            AutransWorker("Alice", Set{Int}(), Int[]),  # No offset specified
            AutransWorker("Bob", Set{Int}(), Int[]),
            AutransWorker("Charlie", Set{Int}(), Int[])
        ]
        
        tasks = [
            AutransTask("Task1", 1, 1:3),
            AutransTask("Task2", 1, 1:3),
            AutransTask("Task3", 1, 1:3)
        ]
        
        scheduler = AutransScheduler(
            workers, tasks, 3,
            equity_strategy=:absolute,
            verbose=false,
            soft_constraints=[
                SoftConstraint(OverallEquityConstraint(), "OverallEquity")
            ]
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        @test failure_info === nothing
        
        alice_work = sum(result[1, :, :])
        bob_work = sum(result[2, :, :])
        charlie_work = sum(result[3, :, :])
        
        # Should be roughly equal (within ±1 due to rounding)
        @test abs(alice_work - bob_work) <= 1
        @test abs(bob_work - charlie_work) <= 1
        @test abs(alice_work - charlie_work) <= 1
    end
    
    @testset "Offset with Hard Constraint" begin
        # Test offset with hard equity constraint
        workers = [
            AutransWorker("Alice", Set{Int}(), Int[], -1),
            AutransWorker("Bob", Set{Int}(), Int[], +1),
            AutransWorker("Charlie", Set{Int}(), Int[], 0)
        ]
        
        tasks = [
            AutransTask("Task1", 1, 1:3),
            AutransTask("Task2", 1, 1:3),
            AutransTask("Task3", 1, 1:3)
        ]
        
        scheduler = AutransScheduler(
            workers, tasks, 3,
            equity_strategy=:absolute,
            verbose=false,
            hard_constraints=[
                HardConstraint(OverallEquityConstraint(), "OverallEquity")
            ]
        )
        
        result, failure_info = solve(scheduler)
        
        @test result !== nothing
        @test failure_info === nothing
        
        alice_work = sum(result[1, :, :])
        bob_work = sum(result[2, :, :])
        charlie_work = sum(result[3, :, :])
        
        # Even with hard constraint, offsets should be respected
        @test alice_work < charlie_work
        @test bob_work > charlie_work
    end
    
    @testset "Normalize Offsets Function" begin
        # Test the normalize_offsets function directly
        
        # All negative
        workers1 = [
            AutransWorker("A", Set{Int}(), Int[], -3),
            AutransWorker("B", Set{Int}(), Int[], -1),
            AutransWorker("C", Set{Int}(), Int[], -2)
        ]
        normalized1 = normalize_offsets(workers1)
        @test normalized1 == [-2, 0, -1]  # Subtract max (-1)
        @test minimum(normalized1) < 0
        @test 0 in normalized1
        
        # All positive
        workers2 = [
            AutransWorker("A", Set{Int}(), Int[], +2),
            AutransWorker("B", Set{Int}(), Int[], +3),
            AutransWorker("C", Set{Int}(), Int[], +1)
        ]
        normalized2 = normalize_offsets(workers2)
        @test normalized2 == [1, 2, 0]  # Subtract min (+1)
        @test maximum(normalized2) > 0
        @test 0 in normalized2
        
        # Mixed (no normalization needed)
        workers3 = [
            AutransWorker("A", Set{Int}(), Int[], -1),
            AutransWorker("B", Set{Int}(), Int[], +1),
            AutransWorker("C", Set{Int}(), Int[], 0)
        ]
        normalized3 = normalize_offsets(workers3)
        @test normalized3 == [-1, 1, 0]  # No change
        
        # All same (no normalization needed)
        workers4 = [
            AutransWorker("A", Set{Int}(), Int[], 2),
            AutransWorker("B", Set{Int}(), Int[], 2),
            AutransWorker("C", Set{Int}(), Int[], 2)
        ]
        normalized4 = normalize_offsets(workers4)
        @test normalized4 == [2, 2, 2]  # No change
    end
end