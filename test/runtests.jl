using Test

# The old test suite used a different API (Autrans.Scheduler, fitness, etc.) 
# that no longer exists in the current codebase.
# 
# The current API uses:
# - AutransWorker, AutransTask, AutransScheduler
# - solve() returns (solution, failure_info)
# - Explicit constraint configuration
#
# All current tests are in test_autrans.jl

@testset "Autrans Test Suite" begin
    include("test_autrans.jl")
end