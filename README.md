
# Autrans

Automated scheduling tool for team task assignment with workload balancing and availability constraints.

## Quick Start

### 1. Install Dependencies

```bash
# Install Julia dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Install Python dependencies (for Streamlit UI)
uv sync
```

### 2. Start the Backend Server

```bash
julia scripts/start_server.jl
```

The API server will start on `http://127.0.0.1:8080`

### 3. Start the UI (Optional)

In a separate terminal:

```bash
uv run streamlit run ./src/AutransUI.py
```

The Streamlit UI will open in your browser and connect to the backend server.

## Features

- **Automated Scheduling**: Optimizes task assignments across workers and days
- **Workload Balancing**: Two equity strategies:
  - Proportional: Workers work proportional to their available days
  - Absolute: All workers work the same amount
- **Days Off Support**: Respect worker unavailability
- **Constraint Satisfaction**: Ensures no worker does consecutive tasks
- **Multiple Views**: Schedule, time aggregation, and job distribution views

## API Documentation

See [docs/API.md](docs/API.md) for complete API documentation including:
- Endpoint specifications
- Request/response formats
- Example curl commands
- Integration guide

## Architecture

```
┌─────────────────┐         HTTP          ┌──────────────────┐
│  Streamlit UI   │ ◄──────────────────► │  Julia Backend   │
│  (Python)       │   JSON API Calls     │  (Oxygen.jl)     │
└─────────────────┘                       └──────────────────┘
                                                    │
                                                    ▼
                                          ┌──────────────────┐
                                          │  Optimization    │
                                          │  (JuMP + HiGHS)  │
                                          └──────────────────┘
```

## Project Structure

```
autrans/
├── src/
│   ├── Autrans.jl          # Main module
│   ├── server.jl           # HTTP API server (Oxygen.jl)
│   ├── structs.jl          # Data structures
│   ├── optimization.jl     # Scheduling optimization logic
│   ├── display.jl          # Display utilities
│   └── AutransUI.py        # Streamlit web interface
├── scripts/
│   └── start_server.jl     # Server startup script
├── docs/
│   └── API.md              # API documentation
└── Project.toml            # Julia dependencies
```

## Development

### Running Tests

#### Core Module Tests
Run the core scheduling algorithm tests:
```bash
julia --project=. test/runtests.jl
```

#### API Server Tests
The API server has a comprehensive test suite covering:
- Health check endpoint
- Feasibility checking (SAT)
- Schedule generation
- Error handling and validation
- Edge cases
- Real-world scenarios

To run API tests:

1. **Start the server** (in one terminal):
```bash
julia scripts/start_server.jl
```

2. **Run the test suite** (in another terminal):
```bash
julia scripts/run_api_tests.jl
```

Or run the quick validation test:
```bash
julia scripts/test_api.jl
```

#### Performance Benchmarks
Run comprehensive performance benchmarks:
```bash
julia --project=. scripts/benchmark_scheduler.jl
```

This tests the scheduler with scenarios ranging from simple (8 workers, 5 days) to very large (50 workers, 30 days), including impossible scenarios to test feasibility detection.

### Using the Julia Module Directly

```julia
using Autrans

# Define workers and tasks
workers = [
    AutransWorker("Alice", [2, 4]),
    AutransWorker("Bob", []),
    AutransWorker("Charlie", [1, 5])
]

tasks = [
    AutransTask("Morning Setup", 2, 1:5),
    AutransTask("Customer Service", 3, 1:5),
    AutransTask("Cleaning", 1, 1:5)
]

# Create scheduler
scheduler = AutransScheduler(workers, tasks, 5, equity_strategy=:proportional)

# Solve
result = solve(scheduler)

# Display results
print_all(result, scheduler)
```

## License

See LICENSE file for details.
