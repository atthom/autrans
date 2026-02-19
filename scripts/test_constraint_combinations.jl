#!/usr/bin/env julia

# Test all combinations of constraints
# Scenario: 1 week, 4 tasks (2 workers each), 8 people

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using Autrans
using Printf

# Test scenario
function create_test_scenario()
    workers = [AutransWorker("Worker_$i") for i in 1:8]
    tasks = [AutransTask("Task_$i", 2, 1:7) for i in 1:4]
    return workers, tasks, 7
end

# Generate all constraint combinations
# All 6 constraints can be: not used, hard, or soft
# Total: 3^6 = 729 combinations
function generate_combinations()
    all_constraints = [
        ("TaskCoverage", Autrans.TaskCoverageConstraint()),
        ("NoConsecutiveTasks", Autrans.NoConsecutiveTasksConstraint()),
        ("DaysOff", Autrans.DaysOffConstraint()),
        ("OverallEquity", Autrans.OverallEquityConstraint()),
        ("DailyEquity", Autrans.DailyEquityConstraint()),
        ("TaskDiversity", Autrans.TaskDiversityConstraint())
    ]
    
    combinations = []
    
    # For each constraint: 0=not used, 1=hard, 2=soft
    # 3^6 = 729 combinations
    for i in 0:(3^6 - 1)
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
            # choice == 0 means not used
        end
        
        push!(combinations, (hard_combo, soft_combo))
    end
    
    return combinations
end

# Run a single test
function run_test(workers, tasks, num_days, hard_combo, soft_combo)
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
    
    # Solve and time it
    start_time = time()
    result, failure_info = solve(scheduler)
    elapsed = time() - start_time
    
    is_feasible = result !== nothing
    assignments = is_feasible ? sum(result) : 0
    
    return (is_feasible, elapsed, assignments, failure_info)
end

# Format constraint flags for table
function format_flags(hard_combo, soft_combo)
    flags = Dict(
        "TaskCoverage" => " - ",
        "NoConsecutiveTasks" => " - ",
        "DaysOff" => " - ",
        "OverallEquity" => " - ",
        "DailyEquity" => " - ",
        "TaskDiversity" => " - "
    )
    
    for (name, _) in hard_combo
        flags[name] = "H"
    end
    
    for (name, _) in soft_combo
        flags[name] = "S"
    end
    
    return flags
end

# Main test suite
function run_test_suite()
    println("="^80)
    println("CONSTRAINT COMBINATION TEST - 1 week, 4 tasks (2 workers), 8 people")
    println("="^80)
    println()
    
    workers, tasks, num_days = create_test_scenario()
    combinations = generate_combinations()
    
    # Table header
    println("# | TC | NC | DO | OE | DE | TD | Result | Time(s) | Notes")
    println("--|----|----|----|----|----|----|--------|---------|-------")
    
    results = []
    
    for (idx, (hard_combo, soft_combo)) in enumerate(combinations)
        is_feasible, elapsed, assignments, failure_info = run_test(workers, tasks, num_days, hard_combo, soft_combo)
        
        # Format flags
        all_flags = format_flags(hard_combo, soft_combo)
        
        # Format result
        result_str = is_feasible ? "✅ OK  " : "❌ FAIL"
        time_str = @sprintf("%.3f", elapsed)
        
        # Notes
        notes = ""
        if !is_feasible
            if isempty(hard_combo)
                notes = "No hard constraints"
            elseif !any(n == "TaskCoverage" for (n, _) in hard_combo)
                notes = "No TaskCoverage"
            else
                notes = "Infeasible"
            end
        end
        
        # Print row
        @printf("%2d | %s  | %s  | %s  | %s  | %s  | %s  | %s | %7s | %s\n",
                idx,
                all_flags["TaskCoverage"],
                all_flags["NoConsecutiveTasks"],
                all_flags["DaysOff"],
                all_flags["OverallEquity"],
                all_flags["DailyEquity"],
                all_flags["TaskDiversity"],
                result_str,
                time_str,
                notes)
        
        push!(results, (is_feasible, elapsed))
    end
    
    println()
    println("Legend:")
    println("TC=TaskCoverage, NC=NoConsecutiveTasks, DO=DaysOff")
    println("OE=OverallEquity, DE=DailyEquity, TD=TaskDiversity")
    println("H=Hard constraint, S=Soft constraint, -=Not used")
    println()
    
    # Summary statistics
    feasible_count = count(r -> r[1], results)
    infeasible_count = length(results) - feasible_count
    
    feasible_times = [r[2] for r in results if r[1]]
    infeasible_times = [r[2] for r in results if !r[1]]
    
    avg_feasible = isempty(feasible_times) ? 0.0 : sum(feasible_times) / length(feasible_times)
    avg_infeasible = isempty(infeasible_times) ? 0.0 : sum(infeasible_times) / length(infeasible_times)
    
    println("="^80)
    println("SUMMARY")
    println("="^80)
    println("Total tests: $(length(results))")
    println("Feasible: $feasible_count ($(round(feasible_count/length(results)*100, digits=1))%)")
    println("Infeasible: $infeasible_count ($(round(infeasible_count/length(results)*100, digits=1))%)")
    println()
    @printf("Avg time (feasible):   %.3fs\n", avg_feasible)
    @printf("Avg time (infeasible): %.3fs\n", avg_infeasible)
    println("="^80)
end

# Run the test suite
run_test_suite()