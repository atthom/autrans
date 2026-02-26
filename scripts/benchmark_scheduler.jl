#!/usr/bin/env julia

using Autrans
using Printf
using Statistics

"""
Generate test scenario with specified parameters
Uses varied task requirements for better feasibility
"""
function generate_scenario(num_workers::Int, num_days::Int, num_tasks::Int; 
                          days_off_probability::Float64=0.1,
                          target_utilization::Float64=0.5)
    
    # Generate workers with random days off
    workers = AutransWorker[]
    for i in 1:num_workers
        days_off = Int[]
        for d in 1:num_days
            if rand() < days_off_probability
                push!(days_off, d)
            end
        end
        push!(workers, AutransWorker("Worker_$i", days_off))
    end
    
    # Generate tasks with varied requirements (like examples.jl)
    tasks = AutransTask[]
    for i in 1:num_tasks
        # Vary workers needed: 1, 2, or 3 workers per task
        if i % 3 == 0
            num_workers_needed = 1  # Some easy tasks
        elseif i % 3 == 1
            num_workers_needed = 2  # Most tasks
        else
            num_workers_needed = 3  # Some harder tasks
        end
        
        # Vary task duration: most span full period, some are shorter
        if i == 1 || i == num_tasks
            # First and last tasks might be special (like setup/review)
            if num_days >= 5
                day_range = (i == 1) ? (1:1) : (num_days:num_days)
            else
                day_range = 1:num_days
            end
        else
            # Regular tasks span full period
            day_range = 1:num_days
        end
        
        push!(tasks, AutransTask("Task_$i", num_workers_needed, day_range))
    end
    
    return workers, tasks
end

"""
Run a single benchmark test
"""
function run_benchmark(name::String, num_workers::Int, num_days::Int, num_tasks::Int;
                      equity_strategy::Symbol=:proportional,
                      days_off_prob::Float64=0.1,
                      max_solve_time::Float64=300.0)
    
    println("\n" * "="^80)
    println("Benchmark: $name")
    println("="^80)
    println("Workers: $num_workers | Days: $num_days | Tasks: $num_tasks | Strategy: $equity_strategy")
    println("Days off probability: $(Int(days_off_prob*100))%")
    
    # Generate scenario
    print("Generating scenario... ")
    workers, tasks = generate_scenario(num_workers, num_days, num_tasks, 
                                      days_off_probability=days_off_prob)
    println("✓")
    
    # Calculate problem size
    total_slots = sum(task.num_workers * length(task.day_range) for task in tasks)
    available_worker_days = sum(num_days - length(worker.days_off) for worker in workers)
    
    println("Problem size:")
    println("  - Total task slots: $total_slots")
    println("  - Available worker-days: $available_worker_days")
    println("  - Utilization: $(round(total_slots/available_worker_days*100, digits=1))%")
    
    # Define standard constraints for benchmarking
    hard_constraints = [
        Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "Task Coverage"),
        Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "No Consecutive Tasks"),
        Autrans.HardConstraint(Autrans.DaysOffConstraint(), "Days Off")
    ]
    
    soft_constraints = [
        Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "Overall Equity"),
        Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "Daily Equity"),
        Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "Task Diversity")
    ]
    
    # Create scheduler
    scheduler = AutransScheduler(
        workers,
        tasks,
        num_days,
        equity_strategy=equity_strategy,
        max_solve_time=max_solve_time,
        verbose=true,
        hard_constraints=hard_constraints,
        soft_constraints=soft_constraints
    )
    
    # Solve and measure time using @btime for accuracy
    print("Solving... ")
    
    # Use @timed for accurate benchmarking
    bench_result = @timed solve(scheduler)
    solution, failure_info = bench_result.value
    elapsed = bench_result.time
    
    if solution !== nothing
        println("✅ SOLVED in $(round(elapsed, digits=2))s")
        
        # Calculate statistics
        N, D, T = size(solution)
        total_assignments = sum(solution)
        
        # Worker workload distribution
        worker_loads = [sum(solution[w, :, :]) for w in 1:N]
        
        println("\nResults:")
        println("  - Total assignments: $total_assignments")
        println("  - Worker load: min=$(minimum(worker_loads)), max=$(maximum(worker_loads)), " *
                "mean=$(round(mean(worker_loads), digits=1)), std=$(round(std(worker_loads), digits=1))")
        
        return (success=true, time=elapsed, assignments=total_assignments, 
                worker_loads=worker_loads)
    else
        println("❌ NO SOLUTION FOUND ($(round(elapsed, digits=2))s)")
        return (success=false, time=elapsed, assignments=0, worker_loads=Int[])
    end
end

"""
Generate intentionally impossible scenario (high utilization)
"""
function generate_impossible_scenario(num_workers::Int, num_days::Int, num_tasks::Int;
                                     days_off_probability::Float64=0.3)
    
    # Generate workers with many days off
    workers = AutransWorker[]
    for i in 1:num_workers
        days_off = Int[]
        for d in 1:num_days
            if rand() < days_off_probability
                push!(days_off, d)
            end
        end
        push!(workers, AutransWorker("Worker_$i", days_off))
    end
    
    # Generate tasks that require too many workers
    tasks = AutransTask[]
    for i in 1:num_tasks
        # Require many workers per task
        num_workers_needed = rand(4:6)
        push!(tasks, AutransTask("Task_$i", num_workers_needed, 1:num_days))
    end
    
    return workers, tasks
end

"""
Generate controlled infeasible scenario with specific infeasibility type
"""
function generate_controlled_infeasible(infeasibility_type::Symbol, 
                                       num_workers::Int, num_days::Int, num_tasks::Int)
    
    if infeasibility_type == :overcapacity_mild
        # 20% overcapacity - not enough total capacity
        workers = [AutransWorker("Worker_$i", Int[]) for i in 1:num_workers]
        tasks = AutransTask[]
        # Calculate slots to create 120% utilization
        available_worker_days = num_workers * num_days
        target_slots = Int(round(available_worker_days * 1.2))
        slots_per_task = div(target_slots, num_tasks)
        for i in 1:num_tasks
            workers_needed = max(2, min(slots_per_task, num_workers-1))
            push!(tasks, AutransTask("Task_$i", workers_needed, 1:num_days))
        end
        
    elseif infeasibility_type == :overcapacity_severe
        # 50% overcapacity - significantly not enough capacity
        workers = [AutransWorker("Worker_$i", Int[]) for i in 1:num_workers]
        tasks = AutransTask[]
        # Calculate slots to create 150% utilization
        available_worker_days = num_workers * num_days
        target_slots = Int(round(available_worker_days * 1.5))
        slots_per_task = div(target_slots, num_tasks)
        for i in 1:num_tasks
            workers_needed = max(3, min(slots_per_task, num_workers))
            push!(tasks, AutransTask("Task_$i", workers_needed, 1:num_days))
        end
        
    elseif infeasibility_type == :impossible_day
        # One day requires more workers than available
        workers = [AutransWorker("Worker_$i", Int[]) for i in 1:num_workers]
        tasks = AutransTask[]
        critical_day = div(num_days, 2)
        # Most tasks are reasonable
        for i in 1:(num_tasks-2)
            push!(tasks, AutransTask("Task_$i", 2, 1:num_days))
        end
        # Two tasks on the same day require too many workers combined
        push!(tasks, AutransTask("Task_$(num_tasks-1)", num_workers, critical_day:critical_day))
        push!(tasks, AutransTask("Task_$(num_tasks)", 2, critical_day:critical_day))
        
    elseif infeasibility_type == :conflicting_constraints
        # Create scenario where consecutive tasks constraint conflicts with coverage
        # Few workers, many tasks on same day, all require same workers
        workers = [AutransWorker("Worker_$i", Int[]) for i in 1:min(5, num_workers)]
        tasks = AutransTask[]
        target_day = max(1, div(num_days, 2))
        # Create many tasks on the same day, each requiring most workers
        # Need at least 2 workers to create the conflict
        workers_per_task = max(2, length(workers)-1)
        for i in 1:num_tasks
            # All tasks on same day range, each needs most workers
            # This creates conflict: can't do consecutive tasks but need to cover all
            push!(tasks, AutransTask("Task_$i", workers_per_task, target_day:target_day))
        end
        
    else
        error("Unknown infeasibility type: $infeasibility_type")
    end
    
    return workers, tasks
end

"""
Benchmark a single infeasible scenario with detailed timing breakdown
Returns timing statistics and conflict analysis results
"""
function benchmark_infeasible_scenario(name::String, infeasibility_type::Symbol,
                                      num_workers::Int, num_days::Int, num_tasks::Int;
                                      max_solve_time::Float64=60.0)
    
    println("\n" * "="^80)
    println("Infeasibility Benchmark: $name")
    println("="^80)
    println("Type: $infeasibility_type | Workers: $num_workers | Days: $num_days | Tasks: $num_tasks")
    
    # Generate scenario
    print("Generating infeasible scenario... ")
    workers, tasks = generate_controlled_infeasible(infeasibility_type, num_workers, num_days, num_tasks)
    println("✓")
    
    # Calculate problem metrics
    total_slots = sum(task.num_workers * length(task.day_range) for task in tasks)
    available_worker_days = sum(num_days - length(worker.days_off) for worker in workers)
    utilization = available_worker_days > 0 ? (total_slots / available_worker_days * 100) : Inf
    
    println("Problem metrics:")
    println("  - Total task slots: $total_slots")
    println("  - Available worker-days: $available_worker_days")
    println("  - Utilization: $(round(utilization, digits=1))%")
    
    # Standard constraints
    hard_constraints = [
        Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "Task Coverage"),
        Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "No Consecutive Tasks"),
        Autrans.HardConstraint(Autrans.DaysOffConstraint(), "Days Off")
    ]
    
    soft_constraints = [
        Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "Overall Equity"),
        Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "Daily Equity"),
        Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "Task Diversity")
    ]
    
    # Create scheduler with verbose=true to capture IIS analysis
    scheduler = AutransScheduler(
        workers,
        tasks,
        num_days,
        equity_strategy=:proportional,
        max_solve_time=max_solve_time,
        verbose=true,  # Enable to get IIS details
        hard_constraints=hard_constraints,
        soft_constraints=soft_constraints
    )
    
    # Measure solve time (includes IIS computation)
    println("\nSolving with IIS analysis enabled...")
    
    start_time = time()
    solution, failure_info = solve(scheduler)
    total_time = time() - start_time
    
    # Extract results
    if solution === nothing && failure_info !== nothing
        println("✅ Correctly identified as INFEASIBLE")
        println("  - Total time: $(round(total_time, digits=3))s")
        println("  - Failure level: $(failure_info.level)")
        println("  - Status: $(failure_info.status)")
        println("  - Conflicts found: $(length(failure_info.conflict_analysis))")
        
        if !isempty(failure_info.conflict_analysis)
            println("\n  Conflict details:")
            for (i, conflict) in enumerate(failure_info.conflict_analysis[1:min(5, end)])
                println("    $i. $conflict")
            end
            if length(failure_info.conflict_analysis) > 5
                println("    ... and $(length(failure_info.conflict_analysis) - 5) more")
            end
        end
        
        return (
            success=true,  # Successfully detected infeasibility
            total_time=total_time,
            num_conflicts=length(failure_info.conflict_analysis),
            infeasibility_type=infeasibility_type,
            utilization=utilization,
            failure_level=failure_info.level
        )
    else
        println("❌ UNEXPECTED: Found solution or wrong failure mode")
        return (
            success=false,
            total_time=total_time,
            num_conflicts=0,
            infeasibility_type=infeasibility_type,
            utilization=utilization,
            failure_level=0
        )
    end
end

"""
Run comprehensive infeasibility benchmark suite
Tests different types and scales of infeasible problems
"""
function run_infeasibility_benchmark_suite()
    println("\n" * "█"^80)
    println("INFEASIBILITY & CONSTRAINT ANALYSIS BENCHMARK SUITE")
    println("█"^80)
    println("\nPurpose: Characterize slowdown from constraint analysis (IIS computation)")
    println("Tests various infeasibility types across different problem scales")
    
    results = []
    
    # Small scale tests
    println("\n" * "─"^80)
    println("SMALL SCALE (5-10 workers, 5-7 days)")
    println("─"^80)
    
    push!(results, benchmark_infeasible_scenario(
        "1. Small - Mild Overcapacity",
        :overcapacity_mild,
        8, 5, 4,
        max_solve_time=30.0
    ))
    
    push!(results, benchmark_infeasible_scenario(
        "2. Small - Impossible Day",
        :impossible_day,
        6, 7, 5,
        max_solve_time=30.0
    ))
    
    # Medium scale tests
    println("\n" * "─"^80)
    println("MEDIUM SCALE (20-30 workers, 14-21 days)")
    println("─"^80)
    
    push!(results, benchmark_infeasible_scenario(
        "3. Medium - Mild Overcapacity",
        :overcapacity_mild,
        20, 14, 8,
        max_solve_time=60.0
    ))
    
    push!(results, benchmark_infeasible_scenario(
        "4. Medium - Severe Overcapacity",
        :overcapacity_severe,
        20, 14, 10,
        max_solve_time=60.0
    ))
    
    push!(results, benchmark_infeasible_scenario(
        "5. Medium - Impossible Day",
        :impossible_day,
        25, 21, 10,
        max_solve_time=60.0
    ))
    
    push!(results, benchmark_infeasible_scenario(
        "6. Medium - Conflicting Constraints",
        :conflicting_constraints,
        5, 14, 8,
        max_solve_time=60.0
    ))
    
    # Large scale tests
    println("\n" * "─"^80)
    println("LARGE SCALE (50+ workers, 30 days)")
    println("─"^80)
    
    push!(results, benchmark_infeasible_scenario(
        "7. Large - Mild Overcapacity",
        :overcapacity_mild,
        50, 30, 12,
        max_solve_time=120.0
    ))
    
    push!(results, benchmark_infeasible_scenario(
        "8. Large - Severe Overcapacity",
        :overcapacity_severe,
        50, 30, 15,
        max_solve_time=120.0
    ))
    
    push!(results, benchmark_infeasible_scenario(
        "9. Large - Impossible Day",
        :impossible_day,
        60, 30, 15,
        max_solve_time=120.0
    ))
    
    # Summary
    println("\n" * "█"^80)
    println("INFEASIBILITY BENCHMARK SUMMARY")
    println("█"^80)
    
    successful = count(r -> r.success, results)
    total = length(results)
    
    println("\nSuccess Rate: $successful/$total ($(round(successful/total*100, digits=1))%)")
    println("(Success = correctly identified as infeasible)\n")
    
    # Timing statistics
    if successful > 0
        successful_results = filter(r -> r.success, results)
        times = [r.total_time for r in successful_results]
        
        println("Timing Statistics:")
        println("  - Fastest: $(round(minimum(times), digits=3))s")
        println("  - Slowest: $(round(maximum(times), digits=3))s")
        println("  - Average: $(round(mean(times), digits=3))s")
        println("  - Median: $(round(median(times), digits=3))s")
        
        # Conflict analysis statistics
        conflicts = [r.num_conflicts for r in successful_results]
        println("\nConflict Analysis:")
        println("  - Min conflicts found: $(minimum(conflicts))")
        println("  - Max conflicts found: $(maximum(conflicts))")
        println("  - Avg conflicts found: $(round(mean(conflicts), digits=1))")
    end
    
    # Detailed results table
    println("\n" * "─"^80)
    println("Detailed Results")
    println("─"^80)
    @printf("%-35s %-12s %8s %11s %9s\n", "Test", "Type", "Util%", "Time(s)", "Conflicts")
    println("─"^80)
    
    test_names = [
        "1. Small - Mild Overcap",
        "2. Small - Impossible Day",
        "3. Medium - Mild Overcap",
        "4. Medium - Severe Overcap",
        "5. Medium - Impossible Day",
        "6. Medium - Conflicting",
        "7. Large - Mild Overcap",
        "8. Large - Severe Overcap",
        "9. Large - Impossible Day"
    ]
    
    for (name, result) in zip(test_names, results)
        type_short = String(result.infeasibility_type)[1:min(12, end)]
        @printf("%-35s %-12s %7.1f%% %10.3f %9d\n", 
                name, type_short, result.utilization, result.total_time, result.num_conflicts)
    end
    
    println("="^80)
    
    return results
end

"""
Run comprehensive benchmark suite
"""
function run_benchmark_suite()
    println("\n" * "█"^80)
    println("AUTRANS SCHEDULER PERFORMANCE BENCHMARK SUITE")
    println("█"^80)
    println("\nTests 1-6: Feasible scenarios (should solve)")
    println("Tests 7-8: Impossible scenarios (stress tests)")
    
    results = []
    
    # Test 1: Very Simple - Small team, short period (FEASIBLE)
    push!(results, run_benchmark(
        "1. Very Simple (Small Team)",
        8, 5, 3,  # More workers to ensure feasibility
        equity_strategy=:proportional,
        days_off_prob=0.0,
        max_solve_time=60.0
    ))
    
    # Test 2: Simple - Medium team, week planning (FEASIBLE)
    push!(results, run_benchmark(
        "2. Simple (Week Planning)",
        12, 7, 5,  # More workers
        equity_strategy=:proportional,
        days_off_prob=0.1,
        max_solve_time=60.0
    ))
    
    # Test 3: Medium - Larger team, two weeks (FEASIBLE)
    push!(results, run_benchmark(
        "3. Medium (Two Weeks)",
        20, 14, 6,  # Fewer workers for better balance
        equity_strategy=:absolute,  # Use absolute equity
        days_off_prob=0.05,  # Very few days off
        max_solve_time=120.0
    ))
    
    # Test 4: Large - Big team, month planning (FEASIBLE)
    push!(results, run_benchmark(
        "4. Large (Month Planning)",
        30, 30, 8,  # Fewer workers for better balance
        equity_strategy=:absolute,  # Use absolute equity
        days_off_prob=0.05,  # Very few days off
        max_solve_time=180.0
    ))
    
    # Test 5: Very Large - 50 workers, month planning (FEASIBLE)
    push!(results, run_benchmark(
        "5. Very Large (50 Workers)",
        50, 30, 10,  # Keep 50 workers
        equity_strategy=:absolute,  # Use absolute equity for large teams
        days_off_prob=0.05,  # Very few days off
        max_solve_time=300.0
    ))
    
    # Test 6: Absolute Equity Strategy (FEASIBLE)
    push!(results, run_benchmark(
        "6. Absolute Equity (30 Workers)",
        30, 30, 10,
        equity_strategy=:absolute,
        days_off_prob=0.1,  # Less days off
        max_solve_time=180.0
    ))
    
    println("\n" * "─"^80)
    println("IMPOSSIBLE SCENARIOS (Stress Tests)")
    println("─"^80)
    
    # Test 7: IMPOSSIBLE - Too many tasks, not enough workers (IMPOSSIBLE)
    println("\n" * "="^80)
    println("Benchmark: 7. IMPOSSIBLE - Overloaded (Too Many Tasks)")
    println("="^80)
    println("Workers: 15 | Days: 30 | Tasks: 20 | Strategy: proportional")
    println("Days off probability: 30%")
    print("Generating impossible scenario... ")
    workers7, tasks7 = generate_impossible_scenario(15, 30, 20, days_off_probability=0.3)
    println("✓")
    
    total_slots7 = sum(task.num_workers * length(task.day_range) for task in tasks7)
    available_days7 = sum(30 - length(worker.days_off) for worker in workers7)
    println("Problem size:")
    println("  - Total task slots: $total_slots7")
    println("  - Available worker-days: $available_days7")
    println("  - Utilization: $(round(total_slots7/available_days7*100, digits=1))%")
    
    # Define constraints for impossible scenario
    hard_constraints7 = [
        Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "Task Coverage"),
        Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "No Consecutive Tasks"),
        Autrans.HardConstraint(Autrans.DaysOffConstraint(), "Days Off")
    ]
    
    soft_constraints7 = [
        Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "Overall Equity"),
        Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "Daily Equity"),
        Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "Task Diversity")
    ]
    
    scheduler7 = AutransScheduler(workers7, tasks7, 30, 
                                  equity_strategy=:proportional,
                                  max_solve_time=60.0, verbose=false,
                                  hard_constraints=hard_constraints7,
                                  soft_constraints=soft_constraints7)
    print("Solving... ")
    start7 = time()
    solution7, failure_info7 = solve(scheduler7)
    elapsed7 = time() - start7
    
    if solution7 !== nothing
        println("✅ SOLVED in $(round(elapsed7, digits=2))s (Unexpected!)")
        push!(results, (success=true, time=elapsed7, assignments=sum(solution7), worker_loads=Int[]))
    else
        println("❌ NO SOLUTION FOUND ($(round(elapsed7, digits=2))s) [Expected]")
        push!(results, (success=false, time=elapsed7, assignments=0, worker_loads=Int[]))
    end
    
    # Test 8: IMPOSSIBLE - Extreme constraints (IMPOSSIBLE)
    println("\n" * "="^80)
    println("Benchmark: 8. IMPOSSIBLE - Extreme Constraints")
    println("="^80)
    println("Workers: 10 | Days: 30 | Tasks: 25 | Strategy: proportional")
    println("Days off probability: 40%")
    print("Generating impossible scenario... ")
    workers8, tasks8 = generate_impossible_scenario(10, 30, 25, days_off_probability=0.4)
    println("✓")
    
    total_slots8 = sum(task.num_workers * length(task.day_range) for task in tasks8)
    available_days8 = sum(30 - length(worker.days_off) for worker in workers8)
    println("Problem size:")
    println("  - Total task slots: $total_slots8")
    println("  - Available worker-days: $available_days8")
    println("  - Utilization: $(round(total_slots8/available_days8*100, digits=1))%")
    
    # Define constraints for impossible scenario
    hard_constraints8 = [
        Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "Task Coverage"),
        Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "No Consecutive Tasks"),
        Autrans.HardConstraint(Autrans.DaysOffConstraint(), "Days Off")
    ]
    
    soft_constraints8 = [
        Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "Overall Equity"),
        Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "Daily Equity"),
        Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "Task Diversity")
    ]
    
    scheduler8 = AutransScheduler(workers8, tasks8, 30,
                                  equity_strategy=:proportional,
                                  max_solve_time=60.0, verbose=false,
                                  hard_constraints=hard_constraints8,
                                  soft_constraints=soft_constraints8)
    print("Solving... ")
    start8 = time()
    solution8, failure_info8 = solve(scheduler8)
    elapsed8 = time() - start8
    
    if solution8 !== nothing
        println("✅ SOLVED in $(round(elapsed8, digits=2))s (Unexpected!)")
        push!(results, (success=true, time=elapsed8, assignments=sum(solution8), worker_loads=Int[]))
    else
        println("❌ NO SOLUTION FOUND ($(round(elapsed8, digits=2))s) [Expected]")
        push!(results, (success=false, time=elapsed8, assignments=0, worker_loads=Int[]))
    end
    
    # Summary
    println("\n" * "█"^80)
    println("BENCHMARK SUMMARY")
    println("█"^80)
    
    successful = count(r -> r.success, results)
    total = length(results)
    
    println("\nSuccess Rate: $successful/$total ($(round(successful/total*100, digits=1))%)")
    
    if successful > 0
        successful_times = [r.time for r in results if r.success]
        println("\nSolve Times (successful runs):")
        println("  - Fastest: $(round(minimum(successful_times), digits=2))s")
        println("  - Slowest: $(round(maximum(successful_times), digits=2))s")
        println("  - Average: $(round(mean(successful_times), digits=2))s")
        println("  - Median: $(round(median(successful_times), digits=2))s")
    end
    
    println("\nDetailed Results:")
    println("-"^80)
    @printf("%-40s %10s %10s\n", "Test", "Status", "Time (s)")
    println("-"^80)
    
    test_names = [
        "1. Very Simple (Small Team)",
        "2. Simple (Week Planning)",
        "3. Medium (Two Weeks)",
        "4. Large (Month Planning)",
        "5. Very Large (50 Workers)",
        "6. Absolute Equity (30 Workers)",
        "7. IMPOSSIBLE - Overloaded",
        "8. IMPOSSIBLE - Extreme Constraints"
    ]
    
    for (i, (name, result)) in enumerate(zip(test_names, results))
        status = result.success ? "✅ SOLVED" : "❌ FAILED"
        @printf("%-40s %10s %10.2f\n", name, status, result.time)
    end
    
    println("="^80)
    println("\nBenchmark complete!")
    
    return results
end

"""
Main entry point - run benchmark suite with options
"""
function main()
    # Check for command line arguments
    run_infeasibility = length(ARGS) > 0 && (ARGS[1] == "--infeasible" || ARGS[1] == "-i")
    run_both = length(ARGS) > 0 && (ARGS[1] == "--all" || ARGS[1] == "-a")
    
    if length(ARGS) > 0 && ARGS[1] == "--help"
        println("""
        Autrans Benchmark Suite
        
        Usage:
          julia benchmark_scheduler.jl [options]
        
        Options:
          (none)              Run standard feasible benchmark suite
          --infeasible, -i    Run infeasibility & constraint analysis benchmarks
          --all, -a           Run both feasible and infeasibility benchmarks
          --help              Show this help message
        
        Examples:
          julia benchmark_scheduler.jl                  # Standard benchmarks
          julia benchmark_scheduler.jl --infeasible     # Infeasibility benchmarks
          julia benchmark_scheduler.jl --all            # All benchmarks
        """)
        return
    end
    
    println("Starting benchmark suite...")
    println("This may take several minutes depending on problem complexity.")
    println()
    
    # Warmup run to trigger JIT compilation
    println("Running warmup to compile functions...")
    warmup_workers = [AutransWorker("W$i") for i in 1:5]
    warmup_tasks = [AutransTask("T$i", 2, 1:3) for i in 1:2]
    
    # Define constraints for warmup
    warmup_hard = [
        Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "Task Coverage"),
        Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "No Consecutive Tasks"),
        Autrans.HardConstraint(Autrans.DaysOffConstraint(), "Days Off")
    ]
    
    warmup_soft = [
        Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "Overall Equity"),
        Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "Daily Equity"),
        Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "Task Diversity")
    ]
    
    warmup_scheduler = AutransScheduler(warmup_workers, warmup_tasks, 3, 
                                       equity_strategy=:proportional, 
                                       max_solve_time=10.0, verbose=false,
                                       hard_constraints=warmup_hard,
                                       soft_constraints=warmup_soft)
    solve(warmup_scheduler)
    println("Warmup complete!\n")
    
    # Run requested benchmarks
    if run_infeasibility
        println("Running INFEASIBILITY benchmarks only...\n")
        infeasible_results = run_infeasibility_benchmark_suite()
        println("\n✅ Infeasibility benchmarks complete!")
    elseif run_both
        println("Running ALL benchmarks (feasible + infeasible)...\n")
        feasible_results = run_benchmark_suite()
        infeasible_results = run_infeasibility_benchmark_suite()
        println("\n✅ All benchmarks complete!")
    else
        println("Running FEASIBLE benchmarks only...\n")
        feasible_results = run_benchmark_suite()
        println("\n✅ Feasible benchmarks complete!")
        println("\nTip: Run with --infeasible to benchmark constraint analysis,")
        println("     or --all to run both feasible and infeasible benchmarks.")
    end
end

# Run main function
main()
