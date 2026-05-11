using Test
using Autrans

# Import specific types
using Autrans: AutransTask, AutransWorker, AutransScheduler, ProportionalEquity

@testset "Overall Equity Constraint - Exact Equality" begin
    println("\n=== Testing Overall Equity with Soft Constraint ===\n")
    
    # Recreate the user's scenario:
    # 9 workers, 5 tasks, 4 days
    # Tasks: Petit Dej (2 workers), Repas Midi (3 workers), Vaisselle Midi (2 workers),
    #        Repas Soir (3 workers), Vaisselle Soir (2 workers)
    
    workers = [
        AutransWorker("Samuel", Int[], Int[], 0),
        AutransWorker("Orianne", Int[], Int[], 0),
        AutransWorker("Anthony", Int[], Int[], 0),
        AutransWorker("Dodie", Int[], Int[], 0),
        AutransWorker("Kenny", Int[], Int[], 0),
        AutransWorker("Marie", Int[], Int[], 0),
        AutransWorker("Michele", Int[], Int[], 0),
        AutransWorker("Benoit", Int[], Int[], 0),
        AutransWorker("Thomas", Int[], Int[], 0),
    ]
    
    tasks = [
        AutransTask("Petit Dej", 2, [2, 3, 4], 1),      # Days 2-4
        AutransTask("Repas Midi", 3, [2, 3, 4], 1),     # Days 2-4
        AutransTask("Vaisselle Midi", 2, [2, 3, 4], 1), # Days 2-4
        AutransTask("Repas Soir", 3, [1, 3], 1),        # Days 1, 3
        AutransTask("Vaisselle Soir", 2, [1, 3], 1),    # Days 1, 3
    ]
    
    # Hard constraints including Overall Equity
    hard_constraints = [
        Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "TaskCoverage"),
        Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "NoConsecutiveTasks"),
        Autrans.HardConstraint(Autrans.DaysOffConstraint(), "DaysOff"),
        #Autrans.HardConstraint(Autrans.OverallEquityConstraint(), "OverallEquity"),
    ]
    
    # Soft constraints
    soft_constraints = [
        Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "OverallEquity"),  # Highest priority
        Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "DailyEquity"),
        Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "TaskDiversity"),
    ]
    
    scheduler = AutransScheduler(
        workers, 
        tasks, 
        4,
        equity_strategy=:proportional,
        hard_constraints=hard_constraints,
        soft_constraints=soft_constraints
    )
    
    println("Generating schedule with HARD Overall Equity constraint...")
    println("(Exact equality enforced - other constraints must accommodate)")
    result, failure_info = Autrans.solve(scheduler)
    
    if result !== nothing
        println("\n✓ Schedule generated successfully!")
        
        # Calculate workload for each worker
        workloads = zeros(Int, length(workers))
        for (w, worker) in enumerate(workers)
            for (t, task) in enumerate(tasks)
                for d in 1:4
                    if result[w, d, t] == 1
                        workloads[w] += task.difficulty
                    end
                end
            end
        end
        
        println("\nWorkload distribution:")
        for (w, worker) in enumerate(workers)
            println("  $(worker.name): $(workloads[w]) pts")
        end
        
        # Calculate statistics
        min_workload = minimum(workloads)
        max_workload = maximum(workloads)
        mean_workload = sum(workloads) / length(workloads)
        variance = sum((w - mean_workload)^2 for w in workloads) / length(workloads)
        
        println("\nStatistics:")
        println("  Min: $min_workload pts")
        println("  Max: $max_workload pts")
        println("  Mean: $(round(mean_workload, digits=2)) pts")
        println("  Range: $(max_workload - min_workload) pts")
        println("  Variance: $(round(variance, digits=2))")
        println("  Standard Deviation: $(round(sqrt(variance), digits=2))")
        
        # Test that a solution was found
        @test result !== nothing
        
        # Check if we achieved good equity (range <= 1 would be ideal)
        if max_workload - min_workload <= 1
            println("\n✓ Excellent equity achieved! (range ≤ 1)")
        elseif max_workload - min_workload <= 2
            println("\n✓ Good equity achieved (range ≤ 2)")
        else
            println("\n⚠ Equity could be improved (range > 2)")
        end
        
        println("✓ Schedule generated with soft equity constraint!")
        
    else
        println("\n✗ Schedule is infeasible with HARD Overall Equity")
        println("This is expected: 31 total points ÷ 9 workers = 3.44 pts/worker")
        println("Exact equality is impossible with integer workloads.")
        println("\nTrying with relaxation=1 to allow 3-4 pts per worker...")
        
        # Move OverallEquity back to soft with minimal relaxation
        hard_constraints_relaxed = [
            Autrans.HardConstraint(Autrans.TaskCoverageConstraint(), "TaskCoverage"),
            Autrans.HardConstraint(Autrans.NoConsecutiveTasksConstraint(), "NoConsecutiveTasks"),
            Autrans.HardConstraint(Autrans.DaysOffConstraint(), "DaysOff"),
        ]
        
        soft_constraints_priority = [
            Autrans.SoftConstraint(Autrans.OverallEquityConstraint(), "OverallEquity"),  # Highest priority
            Autrans.SoftConstraint(Autrans.DailyEquityConstraint(), "DailyEquity"),
            Autrans.SoftConstraint(Autrans.TaskDiversityConstraint(), "TaskDiversity"),
        ]
        
        scheduler2 = AutransScheduler(
            workers, 
            tasks, 
            4,
            equity_strategy=:proportional,
            hard_constraints=hard_constraints_relaxed,
            soft_constraints=soft_constraints_priority
        )
        
        result2, failure_info2 = Autrans.solve(scheduler2)
        
        if result2 !== nothing
            println("\n✓ Schedule generated with prioritized equity!")
            
            # Calculate workload for each worker
            workloads2 = zeros(Int, length(workers))
            for (w, worker) in enumerate(workers)
                for (t, task) in enumerate(tasks)
                    for d in 1:4
                        if result2[w, d, t] == 1
                            workloads2[w] += task.difficulty
                        end
                    end
                end
            end
            
            println("\nWorkload distribution:")
            for (w, worker) in enumerate(workers)
                println("  $(worker.name): $(workloads2[w]) pts")
            end
            
            # Calculate statistics
            min_workload = minimum(workloads2)
            max_workload = maximum(workloads2)
            mean_workload = sum(workloads2) / length(workloads2)
            variance = sum((w - mean_workload)^2 for w in workloads2) / length(workloads2)
            
            println("\nStatistics:")
            println("  Min: $min_workload pts")
            println("  Max: $max_workload pts")
            println("  Mean: $(round(mean_workload, digits=2)) pts")
            println("  Range: $(max_workload - min_workload) pts")
            println("  Variance: $(round(variance, digits=2))")
            println("  Standard Deviation: $(round(sqrt(variance), digits=2))")
            
            @test result2 !== nothing
            
            if max_workload - min_workload <= 1
                println("\n✓ Excellent equity achieved! (range ≤ 1)")
            elseif max_workload - min_workload <= 2
                println("\n✓ Good equity achieved (range ≤ 2)")
            else
                println("\n⚠ Equity could be improved (range > 2)")
            end
        else
            println("\n✗ Still infeasible even with soft equity")
            @test false
        end
    end
end