using Autrans

# Debug: Test the exact user scenario with verbose output
tasks = [
    AutransTask("Task 1", 6, 1),
    AutransTask("Task 2", 6, 1),
]

workers = [AutransWorker("Worker $i") for i in 1:10]

hard_constraints = [
    Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "Task Coverage"),
    Autrans.HardConstraint(Autrans.DaysOffConstraint(), "Days Off")
]

scheduler = AutransScheduler{Autrans.AbsoluteEquity}(
    workers, tasks, 1,
    max_solve_time = 60.0,
    verbose = true,
    hard_constraints = hard_constraints,
    soft_constraints = Autrans.Constraint{Val{:SOFT}}[]
)

println("Solving with AbsoluteEquity...")
result, failure_info = Autrans.solve(scheduler)

if result === nothing
    println("\n❌ No solution found!")
    if failure_info !== nothing
        println("Failure info:")
        println("  Level: ", failure_info.level)
        println("  Status: ", failure_info.status)
        println("  Capacity: ", failure_info.capacity_analysis)
    end
else
    println("\n✅ Solution found!")
    Autrans.print_all(result, scheduler)
end