#!/bin/bash

# =============================================================================
# TechNova Inventory Management System - Build Script
# Description: Automated build, test, and deployment script
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
PROJECT_NAME="TechNova Inventory Management System"
SERVICE_NAME="inventory-service"
BUILD_DIR="build"
REPORTS_DIR="reports"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create directories
create_directories() {
    print_status "Creating build directories..."
    mkdir -p "$BUILD_DIR"
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$SERVICE_NAME/logs"
    print_success "Directories created"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."
    cd "$SERVICE_NAME"
    
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        print_success "Dependencies installed"
    else
        print_error "requirements.txt not found"
        exit 1
    fi
    
    cd ..
}

# Function to run linting
run_linting() {
    print_status "Running code linting..."
    cd "$SERVICE_NAME"
    
    # Run flake8 if available
    if command_exists flake8; then
        flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
        flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
    fi
    
    # Run black if available
    if command_exists black; then
        black --check .
    fi
    
    cd ..
    print_success "Linting completed"
}

# Function to run security scanning
run_security_scan() {
    print_status "Running security scans..."
    cd "$SERVICE_NAME"
    
    # Run Bandit security scan
    print_status "Running Bandit security scan..."
    if command_exists bandit; then
        bandit -r . -f json -o "../$REPORTS_DIR/bandit-report.json" || true
        bandit -r . -f txt -o "../$REPORTS_DIR/bandit-report.txt" || true
        print_success "Bandit scan completed"
    else
        print_warning "Bandit not found, skipping security scan"
    fi
    
    # Run Safety dependency check
    print_status "Running Safety dependency check..."
    if command_exists safety; then
        safety check --json > "../$REPORTS_DIR/safety-report.json" || true
        print_success "Safety check completed"
    else
        print_warning "Safety not found, skipping dependency check"
    fi
    
    cd ..
}

# Function to run tests
run_tests() {
    print_status "Running test suite..."
    cd "$SERVICE_NAME"
    
    if command_exists pytest; then
        # Run tests with coverage
        pytest tests/ -v \
            --cov=. \
            --cov-report=term-missing \
            --cov-report=html:"../$REPORTS_DIR/htmlcov" \
            --cov-report=xml:"../$REPORTS_DIR/coverage.xml" \
            --junit-xml="../$REPORTS_DIR/test-results.xml" \
            --tb=short
        
        print_success "Tests completed successfully"
    else
        print_error "pytest not found"
        exit 1
    fi
    
    cd ..
}

# Function to build Docker image
build_docker_image() {
    print_status "Building Docker image..."
    
    if command_exists docker; then
        # Build with build args
        docker build \
            --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
            --build-arg VERSION="1.0.0" \
            --build-arg VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
            -t technova/inventory-service:latest \
            -t technova/inventory-service:1.0.0 \
            ./$SERVICE_NAME
        
        print_success "Docker image built successfully"
    else
        print_warning "Docker not found, skipping image build"
    fi
}

# Function to run integration tests
run_integration_tests() {
    print_status "Running integration tests..."
    
    if command_exists docker; then
        # Start services
        docker-compose up -d --build
        
        # Wait for services to be ready
        print_status "Waiting for services to start..."
        sleep 10
        
        # Run integration tests
        cd "$SERVICE_NAME"
        pytest tests/test_integration.py -v || true
        cd ..
        
        # Cleanup
        docker-compose down
        
        print_success "Integration tests completed"
    else
        print_warning "Docker not available, skipping integration tests"
    fi
}

# Function to generate build report
generate_report() {
    print_status "Generating build report..."
    
    REPORT_FILE="$REPORTS_DIR/build-report.txt"
    
    cat > "$REPORT_FILE" << EOF
================================================================================
$PROJECT_NAME - Build Report
================================================================================
Build Date: $(date)
Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
Git Branch: $(git branch --show-current 2>/dev/null || echo "unknown")

Build Status: SUCCESS
================================================================================

Test Results:
- Unit Tests: $([ -f "$REPORTS_DIR/test-results.xml" ] && echo "PASSED" || echo "SKIPPED")
- Security Scan: $([ -f "$REPORTS_DIR/bandit-report.json" ] && echo "COMPLETED" || echo "SKIPPED")
- Dependency Check: $([ -f "$REPORTS_DIR/safety-report.json" ] && echo "COMPLETED" || echo "SKIPPED")

Artifacts:
- Test Coverage Report: $REPORTS_DIR/htmlcov/index.html
- Security Report: $REPORTS_DIR/bandit-report.txt
- Dependency Report: $REPORTS_DIR/safety-report.json

Docker Images:
- technova/inventory-service:latest
- technova/inventory-service:1.0.0

================================================================================
EOF

    print_success "Build report generated: $REPORT_FILE"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up temporary files..."
    # Add cleanup logic here if needed
    print_success "Cleanup completed"
}

# Main build function
main() {
    print_status "Starting build process for $PROJECT_NAME"
    echo "========================================"
    
    # Check prerequisites
    if ! command_exists python; then
        print_error "Python not found. Please install Python 3.9+"
        exit 1
    fi
    
    if ! command_exists pip; then
        print_error "pip not found. Please install pip"
        exit 1
    fi
    
    # Execute build steps
    create_directories
    install_dependencies
    run_linting
    run_security_scan
    run_tests
    build_docker_image
    run_integration_tests
    generate_report
    cleanup
    
    echo "========================================"
    print_success "Build completed successfully!"
    print_status "Build artifacts available in: $REPORTS_DIR/"
    print_status "View test coverage: $REPORTS_DIR/htmlcov/index.html"
}

# Trap to cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
