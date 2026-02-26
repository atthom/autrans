using Autrans

println("="^80)
println("Testing Conflict Analysis with User Scenario")
println("="^80)

# User's scenario: 7 tasks × 2 workers each = 14 slots, 6 workers, 1 day
# With NoConsecutiveTasks=HARD, this should be infeasible
workers = [AutransWorker("Worker $i") for i in 1:6]

tasks = [
    AutransTask("Task 1", 2, 1:1),
    AutransTask("Task 2", 2, 1:1),
    AutransTask("Task 3", 2, 1:1),
    AutransTask("Task 4", 2, 1:1),
    AutransTask("Task 5", 2, 1:1),
    AutransTask("Task 6", 2, 1:1),
    AutransTask("Task 7", 2, 1:1)
]

# With NoConsecutiveTasks as hard constraint
hard_constraints = [
    Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "TaskCoverage"),
    Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "NoConsecutiveTasks"),
    Autrans.HardConstraint(Autrans.DaysOffConstraint(), "DaysOff")
]

soft_constraints = [
    Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "OverallEquity"),
    Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "DailyEquity"),
    Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "TaskDiversity")
]

scheduler = AutransScheduler{Autrans.ProportionalEquity}(
    workers, tasks, 1,
    max_solve_time = 60.0,
    verbose = true,
    hard_constraints = hard_constraints,
    soft_constraints = soft_constraints
)

println("\n📋 Scenario Details:")
println("- Workers: 6")
println("- Tasks: 7 (each requiring 2 workers)")
println("- Total slots needed: 14")
println("- Days: 1")
println("- NoConsecutiveTasks: HARD (workers can do max 1 task/day)")
println("- Expected: INFEASIBLE (max possible = 6 slots, need 14)")
println()

result, failure_info = Autrans.solve(scheduler)

if result === nothing
    println("\n✅ Correctly identified as INFEASIBLE")
    
    if failure_info !== nothing && !isempty(failure_info.conflict_analysis)
        println("\n" * "="^80)
        println("CONFLICT ANALYSIS OUTPUT:")
        println("="^80)
        for diagnostic in failure_info.conflict_analysis
            println(diagnostic)
        end
        println("="^80)
    end
else
    println("\n❌ ERROR: Should have been infeasible!")
end

println("\n" * "="^80)
println("Test Complete")
println("="^80)