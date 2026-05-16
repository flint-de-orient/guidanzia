#!/bin/bash

# EduBot Development Setup Script
echo "🚀 Starting EduBot Career Guidance System..."

# Check if Python is installed
if ! command -v python &> /dev/null; then
    echo "❌ Python is not installed. Please install Python 3.8+ first."
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 16+ first."
    exit 1
fi

# Function to run backend
start_backend() {
    echo "🔧 Setting up backend..."
    cd backend
    
    # Install Python dependencies
    echo "📦 Installing Python dependencies..."
    pip install -r requirements.txt
    
    # Start backend server
    echo "🌐 Starting backend server on port 8080..."
    python app.py &
    BACKEND_PID=$!
    echo "Backend PID: $BACKEND_PID"
    
    cd ..
}

# Function to run frontend
start_frontend() {
    echo "🔧 Setting up frontend..."
    cd frontend
    
    # Install Node.js dependencies
    echo "📦 Installing Node.js dependencies..."
    npm install
    
    # Start frontend development server
    echo "🌐 Starting frontend development server on port 5173..."
    npm run dev &
    FRONTEND_PID=$!
    echo "Frontend PID: $FRONTEND_PID"
    
    cd ..
}

# Function to cleanup processes
cleanup() {
    echo "🛑 Shutting down servers..."
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null
        echo "Backend server stopped"
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null
        echo "Frontend server stopped"
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Start both servers
start_backend
sleep 3
start_frontend

echo ""
echo "✅ EduBot is now running!"
echo "📱 Frontend: http://localhost:5173"
echo "🔌 Backend API: http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop all servers"

# Wait for processes
wait