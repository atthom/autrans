#!/usr/bin/env julia

using Autrans

println("="^80)
println("Testing User's Scenario with Hierarchical Relaxation")
println("="^80)
println()

# User's scenario: 4 workers, 3 tasks (2 workers each), 7 days
workers = [
    AutransWorker("Person 1", Int[]),
    AutransWorker("Person 2", Int[]),
    AutransWorker("Person 3", Int[]),
    AutransWorker("Person 4", Int[])
]

tasks = [
    AutransTask("Chore 1", 2, 1:7),
    AutransTask("Chore 2", 2, 1:7),
    AutransTask("Chore 3", 2, 1:7)
]

println("Scenario:")
println("  Workers: 4 (no days off)")
println("  Tasks: 3 (each needs 2 workers for 7 days)")
println("  Total slots: 3 × 2 × 7 = 42")
println("  Available worker-days: 4 × 7 = 28")
println("  Utilization: 42/28 = 150%")
println()

# Try with proportional equity (balance_daysoff=true)
println("Testing with Proportional Equity (balance_daysoff=true):")
println("-"^80)

scheduler = AutransScheduler(
    workers,
    tasks,
    7,
    equity_strategy=:proportional,
    max_solve_time=60.0,
    verbose=true
)

result = solve(scheduler)

if result !== nothing
    println("\n✅ SUCCESS! Schedule found with proportional equity")
    println()
    
    # Analyze the solution
    N, D, T = size(result)
    
    println("Worker Workload Distribution:")
    for (w, worker) in enumerate(workers)
        total = sum(result[w, :, :])
        per_task = [sum(result[w, :, t]) for t in 1:T]
        println("  $(worker.name): Total=$total, Per-task=$per_task")
    end
    
    println()
    println("Daily Distribution:")
    for d in 1:D
        daily_total = sum(result[:, d, :])
        println("  Day $d: $daily_total tasks assigned")
    end
    
    println()
    print_all(result, scheduler)
else
    println("\n❌ FAILED: No solution found with proportional equity")
    println()
    println("This suggests the hierarchical relaxation may need further tuning.")
end

println()
println("="^80)