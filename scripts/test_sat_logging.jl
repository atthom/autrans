#!/usr/bin/env julia

using Autrans

println("="^80)
println("Testing SAT Logging with Detailed Diagnostics")
println("="^80)
println()

# Test 1: Impossible scenario (too many tasks, not enough workers)
println("Test 1: Impossible Scenario - Insufficient Workers")
println("-"^80)

workers1 = [
    AutransWorker("Alice", Int[]),
    AutransWorker("Bob", Int[]),
    AutransWorker("Charlie", Int[]),
    AutransWorker("Diana", Int[])
]

tasks1 = [
    AutransTask("Cooking", 2, 1:7),
    AutransTask("Cleaning", 2, 1:7),
    AutransTask("Shopping", 2, 1:7)
]

scheduler1 = AutransScheduler(
    workers1,
    tasks1,
    7,
    equity_strategy=:proportional,
    max_solve_time=10.0,
    verbose=true  # Enable verbose logging
)

result1, failure_info1 = solve(scheduler1)

if result1 === nothing && failure_info1 !== nothing
    println("\n" * "="^80)
    println("FAILURE ANALYSIS")
    println("="^80)
    println("Failed at relaxation level: $(failure_info1.level)")
    println("Status: $(failure_info1.status)")
    println("\nCapacity Analysis:")
    for (key, value) in failure_info1.capacity_analysis
        println("  $key: $value")
    end
    println("\nConstraint Details:")
    for detail in failure_info1.constraint_details
        println("  - $detail")
    end
end

println("\n" * "="^80)
println()

# Test 2: Feasible scenario
println("Test 2: Feasible Scenario - Adequate Workers")
println("-"^80)

workers2 = [
    AutransWorker("Alice", Int[]),
    AutransWorker("Bob", Int[]),
    AutransWorker("Charlie", Int[]),
    AutransWorker("Diana", Int[]),
    AutransWorker("Eve", Int[]),
    AutransWorker("Frank", Int[])
]

tasks2 = [
    AutransTask("Cooking", 2, 1:7),
    AutransTask("Cleaning", 2, 1:7),
    AutransTask("Shopping", 2, 1:7)
]

scheduler2 = AutransScheduler(
    workers2,
    tasks2,
    7,
    equity_strategy=:proportional,
    max_solve_time=10.0,
    verbose=true
)

result2, failure_info2 = solve(scheduler2)

if result2 !== nothing
    println("\n✅ SUCCESS! Schedule found")
    N, D, T = size(result2)
    println("Total assignments: $(sum(result2))")
else
    println("\n❌ FAILED (unexpected)")
end

println("\n" * "="^80)
println("Test Complete!")
println("="^80)