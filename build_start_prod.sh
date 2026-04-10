#!/bin/bash

# Autrans Production Build and Start Script
# This script builds the React frontend and starts the Julia server

set -e  # Exit on error

echo "🔨 Building Autrans for production..."
echo ""

# Check if we're in the right directory
if [ ! -d "frontend" ]; then
    echo "❌ Error: frontend directory not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Build the frontend
echo "📦 Building React frontend..."
cd frontend
npm run build
cd ..

echo ""
echo "✅ Frontend build complete!"
echo ""

# Start the Julia server
echo "🚀 Starting Autrans server..."
echo "Server will be available at http://localhost:8080"
echo ""

julia --project=. scripts/start_server.jl
