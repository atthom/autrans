#!/usr/bin/env julia

using Autrans

println("="^80)
println("Debugging User's Scenario")
println("="^80)
println()

workers = [
    AutransWorker("Alex", [5, 6]),
    AutransWorker("Benjamin", Int[]),
    AutransWorker("Caroline", [3, 6]),
    AutransWorker("Diane", Int[]),
    AutransWorker("Esteban", Int[]),
    AutransWorker("Frank", [3, 6, 7, 4]),
    AutransWorker("Person 7", Int[]),
    AutransWorker("Person 8", Int[]),
    AutransWorker("Person 9", Int[]),
    AutransWorker("Person 10", Int[]),
    AutransWorker("Person 11", [3, 6, 2])
]

tasks = [
    AutransTask("Cooking", 2, 1:13),
    AutransTask("Cleaning", 2, 1:13),
    AutransTask("Shopping", 2, 1:13)
]

println("Scenario:")
println("  Workers: 11")
println("  Tasks: 3 (each needs 2 workers for 13 days)")
println("  Days: 13")
println()

println("Worker availability:")
for (i, worker) in enumerate(workers)
    available_days = 13 - length(worker.days_off)
    println("  $(worker.name): $available_days days available (days off: $(worker.days_off))")
end
println()

# Calculate capacity
total_slots = 3 * 2 * 13  # 78 slots
total_worker_days = sum(13 - length(w.days_off) for w in workers)
println("Capacity:")
println("  Total slots needed: $total_slots")
println("  Total worker-days available: $total_worker_days")
println("  Utilization: $(round(total_slots/total_worker_days*100, digits=1))%")
println()

scheduler = AutransScheduler(
    workers,
    tasks,
    13,
    equity_strategy=:proportional,
    max_solve_time=60.0,
    verbose=true
)

result, failure_info = solve(scheduler)

if result === nothing && failure_info !== nothing
    println("\n" * "="^80)
    println("DETAILED FAILURE ANALYSIS")
    println("="^80)
    println("This scenario should be feasible based on capacity!")
    println("Let's analyze what constraint is too strict...")
    println()
end