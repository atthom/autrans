#!/usr/bin/env julia

"""
Test case for Worker Preference bug
Issue: Benjamin prefers [Cleaning, Shopping, Cooking] but gets 3 Cleaning + 1 Shopping
Expected: Should get tasks distributed across all 3 preferred tasks
"""

using HTTP
using JSON3

# Build test payload based on user's scenario
function build_test_payload()
    # Workers with Benjamin having preferences: Cleaning (1), Shopping (2), Cooking (3)
    workers = [
        ("Alex", Int[], Int[]),           # No preferences
        ("Benjamin", Int[], [1, 2, 3]),   # Prefers: Cleaning, Shopping, Cooking
        ("Caroline", Int[], Int[]),
        ("Diane", Int[], Int[]),
        ("Esteban", Int[], Int[]),
        ("Frank", Int[], Int[])
    ]
    
    # Tasks: Cleaning, Shopping, Cooking (each needs 2 workers for 7 days)
    tasks = [
        ("Cleaning", 2, 1, 1, 7),
        ("Shopping", 2, 1, 1, 7),
        ("Cooking", 2, 1, 1, 7)
    ]
    
    return Dict(
        "workers" => workers,
        "tasks" => tasks,
        "nb_days" => 7,
        "task_per_day" => ["Cleaning", "Shopping", "Cooking"],
        "balance_daysoff" => true,
        "hard_constraints" => ["TaskCoverage", "NoConsecutiveTasks", "DaysOff", "WorkerPreference"],
        "soft_constraints" => ["OverallEquity", "DailyEquity", "TaskDiversity"]
    )
end

# Main test
function main()
    println("="^80)
    println("Testing Worker Preference Bug")
    println("="^80)
    println()
    
    println("Building test payload...")
    payload = build_test_payload()
    
    println("Payload built!")
    println("  Workers: $(length(payload["workers"]))")
    println("  Tasks: $(length(payload["tasks"]))")
    println("  Days: $(payload["nb_days"])")
    println("  Hard constraints: $(payload["hard_constraints"])")
    println("  Soft constraints: $(payload["soft_constraints"])")
    println()
    
    println("Benjamin's preferences: [Cleaning, Shopping, Cooking]")
    println()
    
    # Test SAT
    println("Testing SAT feasibility...")
    sat_response = HTTP.post(
        "http://127.0.0.1:8080/sat",
        ["Content-Type" => "application/json"],
        JSON3.write(payload)
    )
    
    sat_result = JSON3.read(String(sat_response.body))
    println("SAT Result: $(sat_result[:sat])")
    
    if !sat_result[:sat]
        println("❌ Schedule is not feasible!")
        println("Message: $(sat_result[:msg])")
        return
    end
    
    println()
    
    # Generate schedule
    println("Generating schedule...")
    schedule_response = HTTP.post(
        "http://127.0.0.1:8080/schedule",
        ["Content-Type" => "application/json"],
        JSON3.write(payload)
    )
    
    schedule_result = JSON3.read(String(schedule_response.body))
    println("Schedule generated successfully!")
    println()
    
    # Analyze Benjamin's assignments
    println("="^80)
    println("Analyzing Benjamin's Task Distribution")
    println("="^80)
    
    # Find Benjamin's index (should be worker 1)
    benjamin_idx = findfirst(w -> w[1] == "Benjamin", payload["workers"])
    
    if benjamin_idx === nothing
        println("❌ Benjamin not found in workers!")
        return
    end
    
    println("Benjamin's preferences: [Cleaning, Shopping, Cooking]")
    println()
    
    # Count tasks from jobs data
    jobs_data = schedule_result[:jobs]
    
    # Structure: First column has task names, subsequent columns have worker counts
    # columns[1] = ["Task1", "Task2", "Task3", "TOTAL"]
    # columns[2] = [alex_task1, alex_task2, alex_task3, alex_total]  (Alex's counts)
    # columns[3] = [ben_task1, ben_task2, ben_task3, ben_total]      (Benjamin's counts)
    
    task_names_col = jobs_data[:columns][1]
    benjamin_col = jobs_data[:columns][benjamin_idx + 1]  # +1 because first column is task names
    
    println("Benjamin's actual assignments:")
    task_counts = Dict{String, Int}()
    
    for (i, task_name) in enumerate(task_names_col)
        if task_name == "TOTAL"
            break
        end
        
        benjamin_value = benjamin_col[i]
        
        # Parse the count
        count_str = string(benjamin_value)
        count = 0
        if !isempty(count_str)
            clean_str = replace(count_str, "*" => "")
            if !isempty(clean_str) && all(c -> isdigit(c) || c == '-', clean_str)
                try
                    count = parse(Int, clean_str)
                catch
                    count = 0
                end
            end
        end
        
        task_counts[task_name] = count
        println("  $task_name: $count times")
    end
    
    println()
    println("="^80)
    println("Analysis:")
    println("="^80)
    
    # Check if all preferred tasks are assigned
    all_tasks_assigned = all(count > 0 for count in values(task_counts))
    
    if all_tasks_assigned
        println("✅ GOOD: Benjamin got assignments from ALL 3 preferred tasks")
        println("   Distribution: Cleaning=$( task_counts["Cleaning"]), Shopping=$(task_counts["Shopping"]), Cooking=$(task_counts["Cooking"])")
        println()
        println("   This is working as expected! The Worker Preference constraint")
        println("   ensures workers get tasks from their preference list.")
    else
        println("❌ BUG CONFIRMED: Benjamin did NOT get all preferred tasks")
        println("   Distribution: Cleaning=$(task_counts["Cleaning"]), Shopping=$(task_counts["Shopping"]), Cooking=$(task_counts["Cooking"])")
        println()
        println("   Expected: All 3 tasks should have count > 0")
        println("   Issue: Worker Preference constraint not distributing across all preferences")
    end
    
    println("="^80)
end

# Run the test
main()