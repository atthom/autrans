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
    
    # Create scheduler
    scheduler = AutransScheduler(
        workers,
        tasks,
        num_days,
        equity_strategy=equity_strategy,
        max_solve_time=max_solve_time,
        verbose=false
    )
    
    # Solve and measure time using @btime for accuracy
    print("Solving... ")
    
    # Use @btime for accurate benchmarking
    bench_result = @timed solve(scheduler)
    result = bench_result.value
    elapsed = bench_result.time
    
    if result !== nothing
        println("✅ SOLVED in $(round(elapsed, digits=2))s")
        
        # Calculate statistics
        N, D, T = size(result)
        total_assignments = sum(result)
        
        # Worker workload distribution
        worker_loads = [sum(result[w, :, :]) for w in 1:N]
        
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
    
    scheduler7 = AutransScheduler(workers7, tasks7, 30, 
                                  equity_strategy=:proportional,
                                  max_solve_time=60.0, verbose=false)
    print("Solving... ")
    start7 = time()
    result7 = solve(scheduler7)
    elapsed7 = time() - start7
    
    if result7 !== nothing
        println("✅ SOLVED in $(round(elapsed7, digits=2))s (Unexpected!)")
        push!(results, (success=true, time=elapsed7, assignments=sum(result7), worker_loads=Int[]))
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
    
    scheduler8 = AutransScheduler(workers8, tasks8, 30,
                                  equity_strategy=:proportional,
                                  max_solve_time=60.0, verbose=false)
    print("Solving... ")
    start8 = time()
    result8 = solve(scheduler8)
    elapsed8 = time() - start8
    
    if result8 !== nothing
        println("✅ SOLVED in $(round(elapsed8, digits=2))s (Unexpected!)")
        push!(results, (success=true, time=elapsed8, assignments=sum(result8), worker_loads=Int[]))
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

# Run the benchmark suite
println("Starting benchmark suite...")
println("This may take several minutes depending on problem complexity.")
println()

# Warmup run to trigger JIT compilation
println("Running warmup to compile functions...")
warmup_workers = [AutransWorker("W$i") for i in 1:5]
warmup_tasks = [AutransTask("T$i", 2, 1:3) for i in 1:2]
warmup_scheduler = AutransScheduler(warmup_workers, warmup_tasks, 3, 
                                   equity_strategy=:proportional, 
                                   max_solve_time=10.0, verbose=false)
solve(warmup_scheduler)
println("Warmup complete!\n")

results = run_benchmark_suite()
