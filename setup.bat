@echo off
REM 🚀 Inventory App - Quick Setup Script for Windows
REM This script helps you get started with the complete DevOps pipeline

setlocal enabledelayedexpansion

echo 🚀 Inventory Management System - DevOps Pipeline Setup
echo ==================================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH
    echo Please install Docker Desktop: https://docs.docker.com/desktop/windows/
    pause
    exit /b 1
)

REM Check if Docker Compose is available
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker Compose is not available
    echo Please ensure Docker Desktop is running
    pause
    exit /b 1
)

echo [INFO] Prerequisites check passed ✓
echo.

REM Parse command line argument
set setup_type=%1
if "%setup_type%"=="" set setup_type=monitoring

echo [INFO] Setup type: %setup_type%
echo.

REM Setup based on type
if "%setup_type%"=="quick" (
    echo [INFO] 🚀 Quick Setup - API Only
    docker-compose up -d inventory-service
) else if "%setup_type%"=="monitoring" (
    echo [INFO] 📊 Monitoring Setup - Full Stack
    docker-compose up -d
) else if "%setup_type%"=="build" (
    echo [INFO] 🔨 Build Setup - From Source
    docker-compose up --build -d
) else if "%setup_type%"=="cleanup" (
    echo [INFO] 🧹 Cleaning up...
    docker-compose down -v
    docker system prune -f
    echo [SUCCESS] Cleanup completed
    goto :end
) else if "%setup_type%"=="help" (
    goto :show_help
) else (
    echo [INFO] 📊 Default Setup - Full Stack
    docker-compose up -d
)

echo.
echo [INFO] Waiting for services to start...
timeout /t 30 /nobreak >nul

REM Test the deployment
echo [INFO] Testing deployment...

REM Test health endpoint
curl -f http://localhost:5000/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Health check passed
) else (
    echo [ERROR] ✗ Health check failed
    echo Check logs with: docker-compose logs inventory-service
    pause
    exit /b 1
)

REM Test API endpoint
curl -f http://localhost:5000/items >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ API endpoint accessible
) else (
    echo [ERROR] ✗ API endpoint failed
)

REM Check monitoring services
curl -f http://localhost:9090/-/healthy >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Prometheus monitoring active
) else (
    echo [WARNING] ⚠ Prometheus not running (quick setup?)
)

curl -f http://localhost:3000/api/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Grafana dashboards active
) else (
    echo [WARNING] ⚠ Grafana not running (quick setup?)
)

echo.
echo 🎉 Setup Complete! Your DevOps pipeline is ready.
echo.
echo 📱 Access your applications:
echo    Inventory API:    http://localhost:5000
echo    API Health:       http://localhost:5000/health
echo    API Items:        http://localhost:5000/items
echo.

REM Check if monitoring is running
curl -f http://localhost:9090/-/healthy >nul 2>&1
if %errorlevel% equ 0 (
    echo 📊 Monitoring Stack:
    echo    Prometheus:       http://localhost:9090
    echo    Grafana:          http://localhost:3000 (admin/admin123)
    echo    cAdvisor:         http://localhost:8080
    echo.
)

echo 🔧 Management Commands:
echo    View logs:        docker-compose logs -f
echo    Stop services:    docker-compose down
echo    Restart:          docker-compose restart
echo    Rebuild:          docker-compose up --build -d
echo.
echo 🧪 Test the API:
echo    curl http://localhost:5000/health
echo    curl http://localhost:5000/items
echo.
echo 📚 Next Steps:
echo    1. Explore the monitoring dashboards
echo    2. Run the test suite: cd inventory-service ^&^& python -m pytest
echo    3. Try the load testing: scripts\test.sh load-test
echo    4. Check out the GitHub Actions workflows
echo.

goto :end

:show_help
echo Usage: %0 [OPTION]
echo.
echo Options:
echo   quick      Setup API only (fastest, minimal resources)
echo   monitoring Setup full monitoring stack (recommended)
echo   build      Build from source code
echo   cleanup    Stop and remove all containers
echo   help       Show this help message
echo.
echo Examples:
echo   %0 quick          # Quick API-only setup
echo   %0 monitoring     # Full stack with monitoring
echo   %0 cleanup        # Clean up everything
echo.

:end
echo.
echo Press any key to continue...
pause >nul
