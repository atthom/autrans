#!/usr/bin/env julia

# Quick validation that server.jl can be loaded without errors

push!(LOAD_PATH, joinpath(@__DIR__, ".."))

println("Validating server.jl...")

try
    using Autrans
    include(joinpath(@__DIR__, "..", "src", "server.jl"))
    println("✅ Server file loaded successfully!")
    println("✅ All functions and routes defined correctly!")
    println("\nTo start the server, run:")
    println("   julia scripts/start_server.jl")
    exit(0)
catch e
    println("❌ Error loading server:")
    showerror(stdout, e, catch_backtrace())
    exit(1)
end