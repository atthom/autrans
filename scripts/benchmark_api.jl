#!/usr/bin/env julia

using HTTP
using JSON3
using Statistics
using Dates

println("=" ^ 80)
println("Autrans API Benchmark Test")
println("=" ^ 80)
println("\nThis benchmark will test the API server's performance under various loads.")
println("Make sure the server is running: julia scripts/start_server.jl")
println()

# Benchmark result structure
struct BenchmarkResult
    scenario::String
    payload_size::String
    total_requests::Int
    successful::Int
    failed::Int
    duration_seconds::Float64
    requests_per_second::Float64
    latency_min_ms::Float64
    latency_max_ms::Float64
    latency_mean_ms::Float64
    latency_median_ms::Float64
    latency_p95_ms::Float64
    latency_p99_ms::Float64
end

# Test payloads of different sizes (all feasible)
function get_test_payloads()
    return Dict(
        "small" => Dict(
            "workers" => [
                ["Alice", []],
                ["Bob", []],
                ["Charlie", []]
            ],
            "tasks" => [
                ["Task1", 1, 1, 1, 3],
                ["Task2", 1, 1, 1, 3],
                ["Task3", 1, 1, 1, 3]
            ],
            "nb_days" => 3,
            "balance_daysoff" => false
        ),
        "medium" => Dict(
            "workers" => [
                ["Alice", []],
                ["Bob", []],
                ["Charlie", []],
                ["Diana", []],
                ["Eve", []],
                ["Frank", []]
            ],
            "tasks" => [
                ["Morning Setup", 1, 1, 1, 5],
                ["Customer Service", 1, 1, 1, 5],
                ["Cleaning", 1, 1, 1, 5]
            ],
            "nb_days" => 5,
            "balance_daysoff" => false
        ),
        "large" => Dict(
            "workers" => [
                ["Worker$i", []] for i in 1:10
            ],
            "tasks" => [
                ["Task$i", 1, 1, 1, 7] for i in 1:5
            ],
            "nb_days" => 7,
            "balance_daysoff" => false
        )
    )
end

# Make a single API request and measure latency
function make_request(url::String, payload::Dict)
    start_time = time()
    try
        response = HTTP.post(
            url,
            ["Content-Type" => "application/json"],
            JSON3.write(payload),
            readtimeout=30
        )
        latency_ms = (time() - start_time) * 1000
        return (success=true, latency_ms=latency_ms, status=response.status, error=nothing)
    catch e
        latency_ms = (time() - start_time) * 1000
        error_msg = string(e)
        
        # Try to extract HTTP status and error message
        if isa(e, HTTP.ExceptionRequest.StatusError)
            status = e.status
            try
                body = String(e.response.body)
                error_detail = JSON3.read(body)
                error_msg = "HTTP $status: $(get(error_detail, :error, body))"
            catch
                error_msg = "HTTP $status: $(string(e))"
            end
        end
        
        return (success=false, latency_ms=latency_ms, status=nothing, error=error_msg)
    end
end

# Run sequential requests
function run_sequential_test(url::String, payload::Dict, num_requests::Int)
    results = []
    
    for i in 1:num_requests
        result = make_request(url, payload)
        push!(results, result)
        
        # Progress indicator
        if i % 10 == 0
            print(".")
        end
    end
    println()
    
    return results
end

# Run concurrent requests
function run_concurrent_test(url::String, payload::Dict, num_requests::Int, concurrency::Int)
    results = []
    results_lock = ReentrantLock()
    
    # Create tasks for concurrent execution
    tasks = []
    for batch_start in 1:concurrency:num_requests
        batch_end = min(batch_start + concurrency - 1, num_requests)
        batch_size = batch_end - batch_start + 1
        
        for i in 1:batch_size
            task = @async begin
                result = make_request(url, payload)
                lock(results_lock) do
                    push!(results, result)
                end
                result
            end
            push!(tasks, task)
        end
        
        # Wait for this batch to complete before starting next
        for task in tasks[end-batch_size+1:end]
            wait(task)
        end
        
        print(".")
    end
    println()
    
    return results
end

# Calculate statistics from results
function calculate_stats(results, duration_seconds::Float64, scenario::String, payload_size::String)
    successful = count(r -> r.success, results)
    failed = length(results) - successful
    
    latencies = [r.latency_ms for r in results]
    
    return BenchmarkResult(
        scenario,
        payload_size,
        length(results),
        successful,
        failed,
        duration_seconds,
        length(results) / duration_seconds,
        minimum(latencies),
        maximum(latencies),
        mean(latencies),
        median(latencies),
        quantile(latencies, 0.95),
        quantile(latencies, 0.99)
    )
end

# Print benchmark results
function print_results(result::BenchmarkResult)
    println("\nScenario: $(result.scenario) ($(result.payload_size) payload)")
    println("-" ^ 80)
    println("Total Requests:     $(result.total_requests)")
    println("Successful:         $(result.successful) ($(round(result.successful/result.total_requests*100, digits=1))%)")
    println("Failed:             $(result.failed) ($(round(result.failed/result.total_requests*100, digits=1))%)")
    println("Duration:           $(round(result.duration_seconds, digits=2)) seconds")
    println("Throughput:         $(round(result.requests_per_second, digits=2)) req/s")
    println()
    println("Latency:")
    println("  Min:              $(round(result.latency_min_ms, digits=1)) ms")
    println("  Max:              $(round(result.latency_max_ms, digits=1)) ms")
    println("  Mean:             $(round(result.latency_mean_ms, digits=1)) ms")
    println("  Median (P50):     $(round(result.latency_median_ms, digits=1)) ms")
    println("  P95:              $(round(result.latency_p95_ms, digits=1)) ms")
    println("  P99:              $(round(result.latency_p99_ms, digits=1)) ms")
end

# Health check
println("Checking server health...")
try
    response = HTTP.get("http://127.0.0.1:8080/")
    println("✅ Server is running\n")
catch e
    println("❌ Server is not responding!")
    println("Please start the server: julia scripts/start_server.jl")
    exit(1)
end

# Get test payloads
payloads = get_test_payloads()
url = "http://127.0.0.1:8080/schedule"

all_results = []

# Warmup phase
println("\n" * "=" ^ 80)
println("Warmup Phase")
println("=" ^ 80)
println("Warming up server with 10 requests...")
for i in 1:10
    make_request(url, payloads["small"])
    print(".")
end
println("\n✅ Warmup complete\n")

# Test 1: Sequential requests with small payload
println("\n" * "=" ^ 80)
println("Test 1: Sequential Requests (Small Payload)")
println("=" ^ 80)
println("Running 50 sequential requests...")
start_time = time()
results = run_sequential_test(url, payloads["small"], 50)
duration = time() - start_time
stats = calculate_stats(results, duration, "Sequential", "small")
print_results(stats)
push!(all_results, stats)

# Test 2: Sequential requests with medium payload
println("\n" * "=" ^ 80)
println("Test 2: Sequential Requests (Medium Payload)")
println("=" ^ 80)
println("Running 100 sequential requests...")
start_time = time()
results = run_sequential_test(url, payloads["medium"], 100)
duration = time() - start_time
stats = calculate_stats(results, duration, "Sequential", "medium")
print_results(stats)
push!(all_results, stats)

# Test 3: Concurrent requests (5 concurrent)
println("\n" * "=" ^ 80)
println("Test 3: Concurrent Requests (5 concurrent, Medium Payload)")
println("=" ^ 80)
println("Running 50 requests with 5 concurrent...")
start_time = time()
results = run_concurrent_test(url, payloads["medium"], 50, 5)
duration = time() - start_time
stats = calculate_stats(results, duration, "Concurrent (5)", "medium")
print_results(stats)
push!(all_results, stats)

# Test 4: Concurrent requests (10 concurrent)
println("\n" * "=" ^ 80)
println("Test 4: Concurrent Requests (10 concurrent, Medium Payload)")
println("=" ^ 80)
println("Running 50 requests with 10 concurrent...")
start_time = time()
results = run_concurrent_test(url, payloads["medium"], 50, 10)
duration = time() - start_time
stats = calculate_stats(results, duration, "Concurrent (10)", "medium")
print_results(stats)
push!(all_results, stats)

# Test 5: Large payload sequential
println("\n" * "=" ^ 80)
println("Test 5: Sequential Requests (Large Payload)")
println("=" ^ 80)
println("Running 30 sequential requests...")
start_time = time()
results = run_sequential_test(url, payloads["large"], 30)
duration = time() - start_time
stats = calculate_stats(results, duration, "Sequential", "large")
print_results(stats)
push!(all_results, stats)

# Test 6: Sustained load test
println("\n" * "=" ^ 80)
println("Test 6: Sustained Load (60 seconds)")
println("=" ^ 80)
println("Running continuous requests for 60 seconds...")
start_time = time()
sustained_results = []
while time() - start_time < 60
    result = make_request(url, payloads["medium"])
    push!(sustained_results, result)
    if length(sustained_results) % 50 == 0
        print(".")
    end
end
println()
duration = time() - start_time
stats = calculate_stats(sustained_results, duration, "Sustained Load (60s)", "medium")
print_results(stats)
push!(all_results, stats)

# Test 7: Stress test - find breaking point
println("\n" * "=" ^ 80)
println("Test 7: Stress Test - Finding Breaking Point")
println("=" ^ 80)
println("Testing with increasing concurrency levels...")

for concurrency in [5, 10, 20, 30, 40, 50]
    println("\nTesting with $concurrency concurrent requests...")
    start_time = time()
    results = run_concurrent_test(url, payloads["medium"], concurrency, concurrency)
    duration = time() - start_time
    stats = calculate_stats(results, duration, "Stress Test ($concurrency concurrent)", "medium")
    
    success_rate = stats.successful / stats.total_requests * 100
    
    println("  Success Rate: $(round(success_rate, digits=1))%")
    println("  Throughput: $(round(stats.requests_per_second, digits=2)) req/s")
    println("  Mean Latency: $(round(stats.latency_mean_ms, digits=1)) ms")
    println("  P95 Latency: $(round(stats.latency_p95_ms, digits=1)) ms")
    
    push!(all_results, stats)
    
    # Stop if we're seeing failures or very high latency
    if success_rate < 95 || stats.latency_p95_ms > 10000
        println("\n⚠️  Breaking point detected at $concurrency concurrent requests!")
        println("   Success rate dropped below 95% or P95 latency exceeded 10 seconds")
        break
    end
end

# Summary
println("\n" * "=" ^ 80)
println("BENCHMARK SUMMARY")
println("=" ^ 80)

println("\nThroughput Comparison:")
println("-" ^ 80)
for result in all_results
    println("$(rpad(result.scenario * " (" * result.payload_size * ")", 50)) $(round(result.requests_per_second, digits=2)) req/s")
end

println("\nLatency Comparison (P95):")
println("-" ^ 80)
for result in all_results
    println("$(rpad(result.scenario * " (" * result.payload_size * ")", 50)) $(round(result.latency_p95_ms, digits=1)) ms")
end

println("\nSuccess Rate:")
println("-" ^ 80)
for result in all_results
    success_rate = result.successful / result.total_requests * 100
    status = success_rate == 100.0 ? "✅" : success_rate >= 95.0 ? "⚠️" : "❌"
    println("$(rpad(result.scenario * " (" * result.payload_size * ")", 50)) $(round(success_rate, digits=1))% $status")
end

println("\n" * "=" ^ 80)
println("Benchmark Complete!")
println("=" ^ 80)
println("\nKey Findings:")
println("  • Best throughput: $(round(maximum(r.requests_per_second for r in all_results), digits=2)) req/s")
println("  • Lowest P95 latency: $(round(minimum(r.latency_p95_ms for r in all_results), digits=1)) ms")
println("  • Highest P95 latency: $(round(maximum(r.latency_p95_ms for r in all_results), digits=1)) ms")

# Recommendations
println("\nRecommendations:")
best_throughput = maximum(r.requests_per_second for r in all_results)
if best_throughput < 5
    println("  ⚠️  Low throughput detected. Consider:")
    println("     - Optimizing the solver algorithm")
    println("     - Using a faster solver backend")
    println("     - Implementing request caching")
elseif best_throughput < 20
    println("  ✅ Moderate throughput. Server can handle typical workloads.")
    println("     - Consider load balancing for high-traffic scenarios")
else
    println("  ✅ Excellent throughput! Server is well-optimized.")
end

worst_p95 = maximum(r.latency_p95_ms for r in all_results)
if worst_p95 > 5000
    println("  ⚠️  High latency detected under load. Consider:")
    println("     - Implementing request queuing")
    println("     - Setting up multiple server instances")
    println("     - Adding request timeouts")
elseif worst_p95 > 1000
    println("  ✅ Acceptable latency for most use cases.")
else
    println("  ✅ Excellent latency! Very responsive server.")
end