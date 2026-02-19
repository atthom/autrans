#!/usr/bin/env julia

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Load the Autrans module
using Autrans

# Include the server file
include(joinpath(@__DIR__, "..", "src", "server.jl"))

# Start the server
println("=" ^ 60)
println("Starting Autrans API Server")
println("=" ^ 60)
println("Endpoints:")
println("  GET  /            - Health check")
println("  POST /sat         - Check schedule feasibility")
println("  POST /schedule    - Generate complete schedule")
println("  POST /export/ics  - Export schedule as iCalendar (.ics)")
println("  POST /export/csv  - Export schedule as CSV")
println("=" ^ 60)

start_server("127.0.0.1", 8080)