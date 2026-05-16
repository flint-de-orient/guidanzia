@echo off
title EduBot Career Guidance System

echo 🚀 Starting EduBot Career Guidance System...

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python is not installed. Please install Python 3.8+ first.
    pause
    exit /b 1
)

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed. Please install Node.js 16+ first.
    pause
    exit /b 1
)

echo 🔧 Setting up backend...
cd backend

echo 📦 Installing Python dependencies...
pip install -r requirements.txt

echo 🌐 Starting backend server on port 8080...
start "Backend Server" cmd /k "python app.py"

cd ..

echo 🔧 Setting up frontend...
cd frontend

echo 📦 Installing Node.js dependencies...
call npm install

echo 🌐 Starting frontend development server on port 5173...
start "Frontend Server" cmd /k "npm run dev"

cd ..

echo.
echo ✅ EduBot is now running!
echo 📱 Frontend: http://localhost:5173
echo 🔌 Backend API: http://localhost:8080
echo.
echo Press any key to exit...
pause >nul