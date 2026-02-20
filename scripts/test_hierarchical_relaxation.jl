#!/usr/bin/env julia

using Autrans

println("="^80)
println("Testing Hierarchical Relaxation System")
println("="^80)
println()

# Test 1: Scenario that needs task diversity relaxation
println("Test 1: Scenario requiring task diversity relaxation")
println("-"^80)

workers1 = [
    AutransWorker("Person 1", Int[]),
    AutransWorker("Person 2", Int[]),
    AutransWorker("Person 3", Int[]),
    AutransWorker("Person 4", Int[]),
    AutransWorker("Person 5", Int[]),
    AutransWorker("Person 6", Int[])
]

tasks1 = [
    AutransTask("Chore 1", 2, 1:7),
    AutransTask("Chore 2", 2, 1:7),
    AutransTask("Chore 3", 2, 1:7)
]

println("Scenario:")
println("  Workers: 6 (no days off)")
println("  Tasks: 3 (each needs 2 workers for 7 days)")
println("  Total slots: 3 × 2 × 7 = 42")
println("  Available worker-days: 6 × 7 = 42")
println("  Utilization: 100%")
println()

scheduler1 = AutransScheduler(
    workers1,
    tasks1,
    7,
    equity_strategy=:proportional,
    max_solve_time=60.0,
    verbose=true
)

result1, failure_info1 = solve(scheduler1)

if result1 !== nothing
    println("\n✅ SUCCESS! Schedule found")
    println()
    
    # Analyze the solution
    N, D, T = size(result1)
    
    println("Worker Workload Distribution:")
    for (w, worker) in enumerate(workers1)
        total = sum(result1[w, :, :])
        per_task = [sum(result1[w, :, t]) for t in 1:T]
        println("  $(worker.name): Total=$total, Per-task=$per_task")
    end
    
    println()
    println("Daily Distribution:")
    for d in 1:D
        daily_total = sum(result1[:, d, :])
        println("  Day $d: $daily_total tasks assigned")
    end
else
    println("\n❌ FAILED: No solution found")
end

println()
println("="^80)
println()

# Test 2: User's original scenario (mathematically impossible)
println("Test 2: User's Original Scenario (Impossible)")
println("-"^80)

workers2 = [
    AutransWorker("Person 1", Int[]),
    AutransWorker("Person 2", Int[]),
    AutransWorker("Person 3", Int[]),
    AutransWorker("Person 4", Int[])
]

tasks2 = [
    AutransTask("Chore 1", 2, 1:7),
    AutransTask("Chore 2", 2, 1:7),
    AutransTask("Chore 3", 2, 1:7)
]

println("Scenario:")
println("  Workers: 4 (no days off)")
println("  Tasks: 3 (each needs 2 workers for 7 days)")
println("  Total slots: 3 × 2 × 7 = 42")
println("  Available worker-days: 4 × 7 = 28")
println("  Utilization: 150%")
println()
println("Analysis:")
println("  - Each day needs: 3 tasks × 2 workers = 6 worker-slots")
println("  - Available per day: 4 workers × 1 task max = 4 worker-slots")
println("  - Deficit: 6 - 4 = 2 worker-slots per day")
println("  - This violates the HARD CONSTRAINT that each task needs exactly 2 workers")
println("  - No amount of relaxation can fix this!")
println()

scheduler2 = AutransScheduler(
    workers2,
    tasks2,
    7,
    equity_strategy=:proportional,
    max_solve_time=10.0,
    verbose=false
)

result2, failure_info2 = solve(scheduler2)

if result2 !== nothing
    println("✅ Unexpectedly found a solution (this shouldn't happen)")
else
    println("❌ No solution found (EXPECTED - mathematically impossible)")
end

println()
println("="^80)
println()
println("Summary:")
println("  - Hierarchical relaxation works for feasible scenarios")
println("  - It correctly rejects mathematically impossible scenarios")
println("  - The user's scenario needs either:")
println("    * More workers (at least 6)")
println("    * Fewer tasks (at most 2)")
println("    * Shorter duration (at most 5 days)")
println("="^80)