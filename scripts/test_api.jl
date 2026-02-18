#!/usr/bin/env julia

using HTTP
using JSON3

println("=" ^ 60)
println("Testing Autrans API")
println("=" ^ 60)

# Test data - Using absolute equity for better feasibility
test_payload = Dict(
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

println("\n1. Testing GET / (Health Check)")
println("-" ^ 60)
try
    response = HTTP.get("http://127.0.0.1:8080/")
    result = JSON3.read(String(response.body))
    println("✅ Health check passed")
    println("   Response: ", result)
catch e
    println("❌ Health check failed: ", e)
    println("\nMake sure the server is running:")
    println("   julia scripts/start_server.jl")
    exit(1)
end

println("\n2. Testing POST /sat (Feasibility Check)")
println("-" ^ 60)
try
    response = HTTP.post(
        "http://127.0.0.1:8080/sat",
        ["Content-Type" => "application/json"],
        JSON3.write(test_payload)
    )
    result = JSON3.read(String(response.body))
    println("✅ SAT check passed")
    println("   Feasible: ", result.sat)
    println("   Message: ", result.msg)
catch e
    println("❌ SAT check failed: ", e)
    exit(1)
end

println("\n3. Testing POST /schedule (Generate Schedule)")
println("-" ^ 60)
try
    response = HTTP.post(
        "http://127.0.0.1:8080/schedule",
        ["Content-Type" => "application/json"],
        JSON3.write(test_payload)
    )
    result = JSON3.read(String(response.body))
    println("✅ Schedule generation passed")
    println("   Views returned: ", keys(result))
    
    # Display a sample of the schedule
    if haskey(result, :display)
        println("\n   Sample schedule (first 3 columns):")
        display_data = result.display
        for i in 1:min(3, length(display_data.columns))
            col_name = display_data.colindex.names[i]
            col_data = display_data.columns[i]
            println("     $col_name: ", join(col_data[1:min(3, length(col_data))], ", "), "...")
        end
    end
catch e
    println("❌ Schedule generation failed: ", e)
    exit(1)
end

println("\n" * "=" ^ 60)
println("✅ All tests passed!")
println("=" ^ 60)
println("\nThe API server is working correctly.")
println("You can now start the Streamlit UI:")
println("   uv run streamlit run ./src/AutransUI.py")