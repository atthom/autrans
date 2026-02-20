# Test all combinations of constraints
# Scenario: 1 week, 4 tasks (2 workers each), 8 people

using Test
using Autrans

# Test scenario
function create_test_scenario()
    # Create workers with varied task preferences
    workers = [
        AutransWorker("Worker_1", Set{Int}(), [1, 2, 3, 4]),
        AutransWorker("Worker_2", Set{Int}(), [2, 1, 4, 3]),
        AutransWorker("Worker_3", Set{Int}(), [3, 4, 1, 2]),
        AutransWorker("Worker_4", Set{Int}(), [4, 3, 2, 1]),
        AutransWorker("Worker_5", Set{Int}(), [1, 3, 2, 4]),
        AutransWorker("Worker_6", Set{Int}(), [2, 4, 1, 3]),
        AutransWorker("Worker_7", Set{Int}(), [3, 1, 4, 2]),
        AutransWorker("Worker_8", Set{Int}(), [4, 2, 3, 1])
    ]
    tasks = [AutransTask("Task_$i", 2, 1:7) for i in 1:4]
    return workers, tasks, 7
end

# Generate all constraint combinations
function generate_combinations()
    all_constraints = [
        ("TaskCoverage", Autrans.TaskCoverageConstraint()),
        ("NoConsecutiveTasks", Autrans.NoConsecutiveTasksConstraint()),
        ("DaysOff", Autrans.DaysOffConstraint()),
        ("OverallEquity", Autrans.OverallEquityConstraint()),
        ("DailyEquity", Autrans.DailyEquityConstraint()),
        ("TaskDiversity", Autrans.TaskDiversityConstraint()),
        ("WorkerPreference", Autrans.WorkerPreferenceConstraint())
    ]
    
    combinations = []
    
    # For each constraint: 0=not used, 1=hard, 2=soft
    # 3^7 = 2187 combinations
    for i in 0:(3^7 - 1)
        hard_combo = []
        soft_combo = []
        
        temp = i
        for (name, constraint_type) in all_constraints
            choice = temp % 3
            temp = div(temp, 3)
            
            if choice == 1  # Hard
                push!(hard_combo, (name, constraint_type))
            elseif choice == 2  # Soft
                push!(soft_combo, (name, constraint_type))
            end
        end
        
        push!(combinations, (hard_combo, soft_combo))
    end
    
    return combinations
end

# Run a single test
function run_combination_test(workers, tasks, num_days, hard_combo, soft_combo)
    # Build constraint lists
    hard_constraints = [Autrans.HardConstraint(c, n) for (n, c) in hard_combo]
    soft_constraints = [Autrans.SoftConstraint(c, n) for (n, c) in soft_combo]
    
    # Create scheduler
    scheduler = AutransScheduler(
        workers,
        tasks,
        num_days,
        equity_strategy=:proportional,
        max_solve_time=10.0,
        verbose=false,
        hard_constraints=hard_constraints,
        soft_constraints=soft_constraints
    )
    
    # Solve - success means no exception, regardless of feasibility
    result, failure_info = solve(scheduler)
    
    return (result !== nothing, failure_info)
end

# Main test
@testset "Constraint Combinations (3^7 = 2187 tests)" begin
    workers, tasks, num_days = create_test_scenario()
    combinations = generate_combinations()
    
    println("\nTesting $(length(combinations)) constraint combinations...")
    println("Success = solver completes without errors (feasible or infeasible)")
    
    feasible_count = 0
    infeasible_count = 0
    error_count = 0
    
    for (idx, (hard_combo, soft_combo)) in enumerate(combinations)
        # Test that solver doesn't crash
        @testset "Combination $idx" begin
            try
                is_feasible, failure_info = run_combination_test(workers, tasks, num_days, hard_combo, soft_combo)
                
                if is_feasible
                    feasible_count += 1
                else
                    infeasible_count += 1
                end
                
                # Test passes if no exception
                @test true
            catch e
                error_count += 1
                @test false
                println("  ERROR in combination $idx: $e")
            end
        end
        
        # Progress indicator every 100 tests
        if idx % 100 == 0
            println("  Progress: $idx/$(length(combinations)) (Feasible: $feasible_count, Infeasible: $infeasible_count, Errors: $error_count)")
        end
    end
    
    println("\nFinal Results:")
    println("  Total: $(length(combinations))")
    println("  Feasible: $feasible_count ($(round(feasible_count/length(combinations)*100, digits=1))%)")
    println("  Infeasible: $infeasible_count ($(round(infeasible_count/length(combinations)*100, digits=1))%)")
    println("  Errors: $error_count ($(round(error_count/length(combinations)*100, digits=1))%)")
end