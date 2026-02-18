# This file contains example usage of the Autrans module.
# For comprehensive test cases, please refer to test/test_autrans.jl

using Autrans: AutransTask, AutransWorker, AutransScheduler, ProportionalEquity, AbsoluteEquity
using BenchmarkTools

function run_test(name::String, scheduler::AutransScheduler)
    println("\n" * "="^100)
    println("TEST: $name")
    println("="^100)
    
    start_time = time()
    result = solve(scheduler)
    elapsed = time() - start_time
    
    if result !== nothing
        println("✅ Solution found in $(round(elapsed, digits=3)) seconds")
        try
            print_all(result, scheduler)
        catch e
            println("❌ Error printing schedule: ", e)
        end
    else
        println("❌ No solution found")
    end
end

function example_usage()
    # Common task definitions
    tasks = [
        AutransTask("Morning Setup", 2, 1:5),
        AutransTask("Customer Service", 3, 1:5),
        AutransTask("Inventory Check", 2, 1:5),
        AutransTask("Lunch Coverage", 2, 1:5),
        AutransTask("Afternoon Shift", 2, 1:5),
        AutransTask("Cleaning", 1, 1:5),
        AutransTask("Weekly Report", 2, 1),
        AutransTask("End of Week Review", 3, 5),
    ]
    
    # Workers with days off
    workers_with_days_off = [
        AutransWorker("Alice"),
        AutransWorker("Bob", [3]),
        AutransWorker("Charlie", [1, 5]),
        AutransWorker("Diana"),
        AutransWorker("Eve", [2, 4]),
        AutransWorker("Frank"),
        AutransWorker("Grace"),
        AutransWorker("Henry", [3]),
        AutransWorker("Ivy"),
        AutransWorker("Jack", [5])
    ]
    
    # Workers without days off
    workers_no_days_off = [
        AutransWorker("Alice"),
        AutransWorker("Bob"),
        AutransWorker("Charlie"),
        AutransWorker("Diana"),
        AutransWorker("Eve"),
        AutransWorker("Frank"),
        AutransWorker("Grace"),
        AutransWorker("Henry"),
        AutransWorker("Ivy"),
        AutransWorker("Jack")
    ]
    
    # Test 1: Proportional equity with days off
    scheduler1 = AutransScheduler{ProportionalEquity}(
        workers_with_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Proportional Equity WITH Days Off", scheduler1)
    
    # Test 2: Proportional equity without days off
    scheduler2 = AutransScheduler{ProportionalEquity}(
        workers_no_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Proportional Equity WITHOUT Days Off", scheduler2)
    
    # Test 3: Absolute equity with days off
    scheduler3 = AutransScheduler{AbsoluteEquity}(
        workers_with_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Absolute Equity WITH Days Off", scheduler3)
    
    # Test 4: Absolute equity without days off
    scheduler4 = AutransScheduler{AbsoluteEquity}(
        workers_no_days_off,
        tasks,
        5,
        max_solve_time = 60.0,
        verbose = false
    )
    run_test("Absolute Equity WITHOUT Days Off", scheduler4)
end

# Run the examples
example_usage()