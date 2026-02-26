#!/bin/bash

# Start the Stipple UI for Autrans
echo "Starting Autrans Stipple UI..."
echo "Make sure the Julia backend server is running on port 8080"
echo ""
echo "Starting UI on http://localhost:8081"
echo ""

julia --project=. -e 'include("src/StippleUI.jl")'