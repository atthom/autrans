# Autrans API Documentation

## Starting the Server

### Option 1: Using the startup script
```bash
julia scripts/start_server.jl
```

### Option 2: From Julia REPL
```julia
using Autrans
include("src/server.jl")
start_server("127.0.0.1", 8080)
```

The server will start on `http://127.0.0.1:8080`

## API Endpoints

### GET /
Health check endpoint to verify the server is running.

**Response:**
```json
{
  "service": "Autrans API",
  "version": "0.1.0",
  "status": "running"
}
```

### POST /sat
Check if a schedule is feasible (satisfiability check).

**Request Body:**
```json
{
  "workers": [
    ["Alice", [2, 4]],
    ["Bob", []],
    ["Charlie", [1, 5]]
  ],
  "tasks": [
    ["Morning Setup", 2, 1, 1, 5],
    ["Customer Service", 3, 1, 1, 5],
    ["Cleaning", 1, 1, 1, 5]
  ],
  "nb_days": 5,
  "balance_daysoff": true
}
```

**Request Parameters:**
- `workers`: Array of `[name, days_off]` where:
  - `name` (string): Worker name
  - `days_off` (array of integers): Days when worker is unavailable
- `tasks`: Array of `[name, num_workers, difficulty, day_start, day_end]` where:
  - `name` (string): Task name
  - `num_workers` (integer): Number of workers required
  - `difficulty` (integer): Task difficulty (currently unused)
  - `day_start` (integer): First day of task
  - `day_end` (integer): Last day of task
- `nb_days` (integer): Total number of days in the planning period
- `balance_daysoff` (boolean): 
  - `true`: Proportional equity (workers work proportional to available days)
  - `false`: Absolute equity (all workers work same amount)

**Response (Success):**
```json
{
  "sat": true,
  "msg": "Schedule is feasible"
}
```

**Response (Failure):**
```json
{
  "sat": false,
  "msg": "No feasible schedule found. Try adjusting constraints or adding more workers."
}
```

### POST /schedule
Generate a complete schedule with all views.

**Request Body:** Same as `/sat` endpoint

**Response:**
```json
{
  "display": {
    "columns": [
      ["Task 1", "Task 2", "Task 3"],
      ["Alice, Bob", "Charlie", "Alice"],
      ["Bob, Charlie", "Alice", "Bob"],
      ...
    ],
    "colindex": {
      "names": ["Tasks", "Day 1", "Day 2", ...]
    }
  },
  "time": {
    "columns": [
      ["Day 1", "Day 2", ..., "TOTAL"],
      ["2", "1*", "2", "5"],
      ...
    ],
    "colindex": {
      "names": ["Days", "Alice", "Bob", ..., "TOTAL"]
    }
  },
  "jobs": {
    "columns": [
      ["Task 1", "Task 2", ..., "TOTAL"],
      ["3", "2", "1", "6"],
      ...
    ],
    "colindex": {
      "names": ["Tasks", "Alice", "Bob", ..., "TOTAL"]
    }
  }
}
```

**Response Views:**
- `display`: Tasks × Days view showing which workers are assigned to each task on each day
- `time`: Days × Workers view showing how many tasks each worker has per day
- `jobs`: Tasks × Workers view showing total assignments per task per worker

**Note:** Values with `*` indicate days off or tasks during days off periods.

## Example Usage with curl

### Health Check
```bash
curl http://127.0.0.1:8080/
```

### Check Feasibility
```bash
curl -X POST http://127.0.0.1:8080/sat \
  -H "Content-Type: application/json" \
  -d '{
    "workers": [["Alice", []], ["Bob", [3]], ["Charlie", []]],
    "tasks": [["Task 1", 2, 1, 1, 5], ["Task 2", 2, 1, 1, 5]],
    "nb_days": 5,
    "balance_daysoff": true
  }'
```

### Generate Schedule
```bash
curl -X POST http://127.0.0.1:8080/schedule \
  -H "Content-Type: application/json" \
  -d '{
    "workers": [["Alice", []], ["Bob", [3]], ["Charlie", []]],
    "tasks": [["Task 1", 2, 1, 1, 5], ["Task 2", 2, 1, 1, 5]],
    "nb_days": 5,
    "balance_daysoff": true
  }'
```

## Integration with Streamlit UI

The Streamlit UI (`src/AutransUI.py`) is already configured to use these endpoints. Simply:

1. Start the Julia backend server:
   ```bash
   julia scripts/start_server.jl
   ```

2. In a separate terminal, start the Streamlit UI:
   ```bash
   uv run streamlit run ./src/AutransUI.py
   ```

The UI will automatically connect to `http://127.0.0.1:8080` and use the `/sat` and `/schedule` endpoints.