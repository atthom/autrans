#!/usr/bin/env julia

"""
API Test Runner for Autrans Server

This script runs the comprehensive API test suite.
Make sure the server is running before executing tests.

Usage:
    julia scripts/run_api_tests.jl

To start the server in another terminal:
    julia scripts/start_server.jl
"""

using Pkg

# Ensure we're in the project environment
Pkg.activate(".")

println("="^80)
println("Autrans API Test Runner")
println("="^80)
println()

# Check if server is running
using HTTP
try
    response = HTTP.get("http://127.0.0.1:8080/", timeout=2.0)
    println("✅ Server is running at http://127.0.0.1:8080")
    println()
catch e
    println("❌ ERROR: Server is not running!")
    println()
    println("Please start the server in another terminal:")
    println("   julia scripts/start_server.jl")
    println()
    println("Then run this test script again.")
    exit(1)
end

# Run the test suite
println("Running API test suite...")
println("-"^80)
println()

include("../test/test_api_server.jl")