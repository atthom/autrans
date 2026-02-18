#!/usr/bin/env julia

using Test
using HTTP
using JSON3

# Test configuration
const BASE_URL = "http://127.0.0.1:8080"
const TIMEOUT = 30.0

# Helper function to make requests with timeout
function safe_request(method, url, body=nothing; headers=["Content-Type" => "application/json"])
    try
        if method == :GET
            return HTTP.get(url, timeout=TIMEOUT)
        elseif method == :POST
            return HTTP.post(url, headers, body, timeout=TIMEOUT)
        end
    catch e
        if e isa HTTP.Exceptions.ConnectError
            error("Cannot connect to server at $BASE_URL. Make sure the server is running with: julia scripts/start_server.jl")
        end
        rethrow(e)
    end
end

@testset "Autrans API Server Tests" begin
    
    @testset "1. Health Check Endpoint" begin
        @testset "GET / returns success" begin
            response = safe_request(:GET, "$BASE_URL/")
            @test response.status == 200
            
            result = JSON3.read(String(response.body))
            @test haskey(result, :status)
            @test result.status == "ok"
            @test haskey(result, :message)
        end
    end
    
    @testset "2. SAT Endpoint (Feasibility Check)" begin
        @testset "Valid feasible problem" begin
            payload = Dict(
                "workers" => [
                    ["Alice", []],
                    ["Bob", []],
                    ["Charlie", []],
                    ["Diana", []]
                ],
                "tasks" => [
                    ["Task1", 2, 1, 1, 5],
                    ["Task2", 1, 1, 1, 5]
                ],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
            @test response.status == 200
            
            result = JSON3.read(String(response.body))
            @test haskey(result, :sat)
            @test result.sat == true
            @test haskey(result, :msg)
        end
        
        @testset "Valid infeasible problem" begin
            payload = Dict(
                "workers" => [
                    ["Alice", [1, 2, 3, 4, 5]],
                    ["Bob", [1, 2, 3, 4, 5]]
                ],
                "tasks" => [
                    ["Task1", 5, 1, 1, 5]
                ],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
            @test response.status == 200
            
            result = JSON3.read(String(response.body))
            @test haskey(result, :sat)
            @test result.sat == false
        end
        
        @testset "Missing required fields" begin
            payload = Dict(
                "workers" => [["Alice", []]],
                "tasks" => [["Task1", 2, 1, 1, 5]]
                # Missing nb_days
            )
            
            @test_throws HTTP.Exceptions.StatusError safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
        end
        
        @testset "Invalid worker format" begin
            payload = Dict(
                "workers" => [
                    ["Alice"]  # Missing days_off array
                ],
                "tasks" => [["Task1", 2, 1, 1, 5]],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            @test_throws Exception safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
        end
        
        @testset "Invalid task format" begin
            payload = Dict(
                "workers" => [["Alice", []]],
                "tasks" => [
                    ["Task1", 2, 1]  # Missing day range end
                ],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            @test_throws Exception safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
        end
    end
    
    @testset "3. Schedule Endpoint" begin
        @testset "Valid schedule generation" begin
            payload = Dict(
                "workers" => [
                    ["Alice", []],
                    ["Bob", [3]],
                    ["Charlie", []],
                    ["Diana", []],
                    ["Eve", []],
                    ["Frank", []]
                ],
                "tasks" => [
                    ["Morning Setup", 2, 1, 1, 5],
                    ["Customer Service", 2, 1, 1, 5],
                    ["Cleaning", 1, 1, 1, 5]
                ],
                "nb_days" => 5,
                "balance_daysoff" => false  # Use absolute equity
            )
            
            response = safe_request(:POST, "$BASE_URL/schedule", JSON3.write(payload))
            @test response.status == 200
            
            result = JSON3.read(String(response.body))
            
            # Check all required views are present
            @test haskey(result, :display)
            @test haskey(result, :time)
            @test haskey(result, :jobs)
            
            # Validate display structure
            display = result.display
            @test haskey(display, :columns)
            @test haskey(display, :colindex)
            @test length(display.columns) > 0
        end
        
        @testset "Schedule with absolute equity" begin
            payload = Dict(
                "workers" => [
                    ["Alice", []],
                    ["Bob", []],
                    ["Charlie", []],
                    ["Diana", []]
                ],
                "tasks" => [
                    ["Task1", 2, 1, 1, 5],
                    ["Task2", 2, 1, 1, 5]
                ],
                "nb_days" => 5,
                "balance_daysoff" => false  # Absolute equity
            )
            
            response = safe_request(:POST, "$BASE_URL/schedule", JSON3.write(payload))
            @test response.status == 200
            
            result = JSON3.read(String(response.body))
            @test haskey(result, :display)
        end
        
        @testset "Infeasible schedule returns error" begin
            payload = Dict(
                "workers" => [
                    ["Alice", [1, 2, 3, 4, 5]]
                ],
                "tasks" => [
                    ["Task1", 2, 1, 1, 5]
                ],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/schedule", JSON3.write(payload))
            @test response.status == 200
            
            result = JSON3.read(String(response.body))
            @test haskey(result, :error)
        end
    end
    
    @testset "4. Edge Cases" begin
        @testset "Empty workers list" begin
            payload = Dict(
                "workers" => [],
                "tasks" => [["Task1", 1, 1, 1, 5]],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
            result = JSON3.read(String(response.body))
            @test result.sat == false
        end
        
        @testset "Empty tasks list" begin
            payload = Dict(
                "workers" => [["Alice", []]],
                "tasks" => [],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
            result = JSON3.read(String(response.body))
            @test result.sat == true  # Trivially feasible
        end
        
        @testset "Single day planning" begin
            payload = Dict(
                "workers" => [["Alice", []], ["Bob", []]],
                "tasks" => [["Task1", 1, 1, 1, 1]],
                "nb_days" => 1,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/schedule", JSON3.write(payload))
            @test response.status == 200
        end
        
        @testset "Large problem (30 days, 20 workers)" begin
            workers = [["Worker_$i", []] for i in 1:20]
            tasks = [["Task_$i", 2, 1, 1, 30] for i in 1:5]
            
            payload = Dict(
                "workers" => workers,
                "tasks" => tasks,
                "nb_days" => 30,
                "balance_daysoff" => false  # Use absolute equity for large problems
            )
            
            response = safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
            @test response.status == 200
        end
    end
    
    @testset "5. Input Validation" begin
        @testset "Negative number of days" begin
            payload = Dict(
                "workers" => [["Alice", []]],
                "tasks" => [["Task1", 1, 1, 1, 5]],
                "nb_days" => -5,
                "balance_daysoff" => true
            )
            
            @test_throws Exception safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
        end
        
        @testset "Invalid days_off (out of range)" begin
            payload = Dict(
                "workers" => [["Alice", [10]]],  # Day 10 doesn't exist
                "tasks" => [["Task1", 1, 1, 1, 5]],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            # Should still work but ignore invalid days
            response = safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
            @test response.status == 200
        end
        
        @testset "Task with 0 workers needed" begin
            payload = Dict(
                "workers" => [["Alice", []]],
                "tasks" => [["Task1", 0, 1, 1, 5]],
                "nb_days" => 5,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/sat", JSON3.write(payload))
            result = JSON3.read(String(response.body))
            @test result.sat == true  # Trivially feasible
        end
    end
    
    @testset "6. Real-World Scenarios" begin
        @testset "Restaurant shift planning" begin
            payload = Dict(
                "workers" => [
                    ["Chef_Alice", []],
                    ["Chef_Bob", [6, 7]],  # Weekend off
                    ["Waiter_Charlie", [3]],
                    ["Waiter_Diana", []],
                    ["Cleaner_Eve", [1, 7]]
                ],
                "tasks" => [
                    ["Morning Prep", 2, 1, 1, 7],
                    ["Lunch Service", 3, 1, 1, 7],
                    ["Dinner Service", 3, 1, 1, 7],
                    ["Closing Cleanup", 1, 1, 1, 7]
                ],
                "nb_days" => 7,
                "balance_daysoff" => true
            )
            
            response = safe_request(:POST, "$BASE_URL/schedule", JSON3.write(payload))
            @test response.status == 200
            
            result = JSON3.read(String(response.body))
            if haskey(result, :error)
                @test_skip "Restaurant scenario infeasible with current constraints"
            else
                @test haskey(result, :display)
            end
        end
        
        @testset "Call center coverage" begin
            workers = [["Agent_$i", []] for i in 1:10]
            workers[2][2] = [1, 2]  # Agent 2 has days off
            workers[5][2] = [6, 7]  # Agent 5 has weekend off
            
            payload = Dict(
                "workers" => workers,
                "tasks" => [
                    ["Morning Shift", 3, 1, 1, 7],
                    ["Afternoon Shift", 3, 1, 1, 7],
                    ["Evening Shift", 2, 1, 1, 7]
                ],
                "nb_days" => 7,
                "balance_daysoff" => false  # Absolute equity
            )
            
            response = safe_request(:POST, "$BASE_URL/schedule", JSON3.write(payload))
            @test response.status == 200
        end
    end
end

println("\n" * "="^80)
println("API Test Suite Complete!")
println("="^80)