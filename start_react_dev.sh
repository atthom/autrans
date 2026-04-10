#!/bin/bash

echo "======================================"
echo "Starting Autrans React Development"
echo "======================================"
echo ""
echo "This will start TWO servers:"
echo "  1. Oxygen API (Julia) on port 8080"
echo "  2. Vite dev server on port 5173"
echo ""
echo "Press Ctrl+C to stop both servers"
echo "======================================"
echo ""

# Start Oxygen backend in background
echo "Starting Oxygen backend..."
julia -t auto --project=. scripts/start_server.jl &
JULIA_PID=$!

# Give backend time to start
sleep 2

# Start Vite dev server
echo "Starting Vite dev server..."
cd frontend
npm run dev

# Cleanup on exit
trap "echo 'Stopping servers...'; kill $JULIA_PID 2>/dev/null; exit" INT TERM
