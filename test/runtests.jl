using Test

# Comprehensive test suite for Autrans scheduling system
# Tests core functionality, edge cases, preferences, and all constraint combinations

@testset verbose=true "Autrans Test Suite" begin
    @testset verbose=true "Core Functionality" begin
        include("test_autrans.jl")
    end
    
    @testset verbose=true "Hierarchical Relaxation" begin
        include("test_hierarchical_relaxation.jl")
    end
    
    @testset verbose=true "Worker Preferences" begin
        include("test_worker_preferences.jl")
    end
    
    @testset verbose=true "Workload Offset" begin
        include("test_workload_offset.jl")
    end
    
    @testset verbose=true "Constraint Combinations (Full)" begin
        include("test_constraint_combinations.jl")
    end
end
