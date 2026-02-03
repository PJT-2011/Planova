#!/bin/bash
# Local Development Startup Script
# Run this to start all local services

echo "🚀 Starting Planova Backend Local Development..."
echo ""

# Check if Node is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js"
    exit 1
fi

# Start services in background
echo "📦 Starting services..."
echo ""

# 1. Fake Python Service (port 7000)
echo "1️⃣  Starting Fake Python Service (port 7000)..."
node fake-python.js &
FAKE_PYTHON_PID=$!
echo "   PID: $FAKE_PYTHON_PID"
sleep 2

# 2. Express Server (port 5000)
echo "2️⃣  Starting Express Server (port 5000)..."
node server.js &
SERVER_PID=$!
echo "   PID: $SERVER_PID"
sleep 2

# 3. Firebase Functions (port 5001)
echo "3️⃣  Starting Firebase Functions Emulator (port 5001)..."
cd functions
npm run serve &
FUNCTIONS_PID=$!
echo "   PID: $FUNCTIONS_PID"
cd ..

echo ""
echo "✅ All services started!"
echo ""
echo "📍 Available at:"
echo "   • Backend API: http://localhost:5000"
echo "   • Fake Python Service: http://localhost:7000"
echo "   • Functions Emulator: http://localhost:5001"
echo "   • Emulator UI: http://127.0.0.1:4000"
echo ""
echo "⏸️  Press Ctrl+C to stop all services"
echo ""

# Wait for any process to exit
wait

# Cleanup
echo ""
echo "🛑 Stopping services..."
kill $FAKE_PYTHON_PID $SERVER_PID $FUNCTIONS_PID 2>/dev/null
echo "✅ All services stopped"
