#!/bin/bash

# =============================================================================
# TechNova Inventory Management System - Test Script
# Description: Comprehensive testing script for all test types
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SERVICE_NAME="inventory-service"
REPORTS_DIR="test-reports"
COVERAGE_THRESHOLD=90

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

# Function to setup test environment
setup_test_environment() {
    print_status "Setting up test environment..."
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Change to service directory
    cd "$SERVICE_NAME"
    
    # Install test dependencies
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    fi
    
    print_success "Test environment ready"
}

# Function to run unit tests
run_unit_tests() {
    print_status "Running unit tests..."
    
    if command_exists pytest; then
        pytest tests/test_app.py \
            -v \
            --cov=. \
            --cov-report=term-missing \
            --cov-report=html:"../$REPORTS_DIR/unit-coverage" \
            --cov-report=xml:"../$REPORTS_DIR/unit-coverage.xml" \
            --junit-xml="../$REPORTS_DIR/unit-test-results.xml" \
            --tb=short \
            -m "not integration and not performance"
        
        # Check coverage threshold
        COVERAGE=$(coverage report --format=total 2>/dev/null || echo "0")
        if [ "$COVERAGE" -ge "$COVERAGE_THRESHOLD" ]; then
            print_success "Unit tests passed with ${COVERAGE}% coverage"
        else
            print_warning "Coverage ${COVERAGE}% is below threshold ${COVERAGE_THRESHOLD}%"
        fi
    else
        print_error "pytest not found"
        return 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    print_status "Running integration tests..."
    
    # Start application in background
    python app.py &
    APP_PID=$!
    
    # Wait for application to start
    sleep 3
    
    # Check if application is running
    if ! curl -f http://localhost:5000/health >/dev/null 2>&1; then
        print_error "Application failed to start"
        kill $APP_PID 2>/dev/null || true
        return 1
    fi
    
    # Run integration tests
    if command_exists pytest; then
        pytest tests/test_integration.py \
            -v \
            --junit-xml="../$REPORTS_DIR/integration-test-results.xml" \
            --tb=short \
            -m "integration" || TEST_RESULT=$?
    fi
    
    # Stop application
    kill $APP_PID 2>/dev/null || true
    
    if [ "${TEST_RESULT:-0}" -eq 0 ]; then
        print_success "Integration tests passed"
    else
        print_error "Integration tests failed"
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    print_status "Running performance tests..."
    
    # Start application in background
    python app.py &
    APP_PID=$!
    
    # Wait for application to start
    sleep 3
    
    # Run performance tests
    if command_exists pytest; then
        pytest tests/test_performance.py \
            -v \
            --junit-xml="../$REPORTS_DIR/performance-test-results.xml" \
            --tb=short \
            -m "performance" || TEST_RESULT=$?
    fi
    
    # Stop application
    kill $APP_PID 2>/dev/null || true
    
    if [ "${TEST_RESULT:-0}" -eq 0 ]; then
        print_success "Performance tests passed"
    else
        print_warning "Performance tests failed or had issues"
    fi
}

# Function to run API tests
run_api_tests() {
    print_status "Running API tests..."
    
    # Start application in background
    python app.py &
    APP_PID=$!
    
    # Wait for application to start
    sleep 3
    
    # API Test Script
    print_status "Testing API endpoints..."
    
    # Test health endpoint
    if curl -f http://localhost:5000/health >/dev/null 2>&1; then
        print_success "Health endpoint: OK"
    else
        print_error "Health endpoint: FAILED"
        kill $APP_PID 2>/dev/null || true
        return 1
    fi
    
    # Test GET items
    if curl -f http://localhost:5000/items >/dev/null 2>&1; then
        print_success "GET items endpoint: OK"
    else
        print_error "GET items endpoint: FAILED"
        kill $APP_PID 2>/dev/null || true
        return 1
    fi
    
    # Test POST item
    RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:5000/items \
        -H "Content-Type: application/json" \
        -d '{"name": "Test Item", "stock": 10}')
    
    if echo "$RESPONSE" | grep -q "201"; then
        print_success "POST item endpoint: OK"
    else
        print_error "POST item endpoint: FAILED"
        kill $APP_PID 2>/dev/null || true
        return 1
    fi
    
    # Test metrics endpoint
    if curl -f http://localhost:5000/metrics >/dev/null 2>&1; then
        print_success "Metrics endpoint: OK"
    else
        print_error "Metrics endpoint: FAILED"
        kill $APP_PID 2>/dev/null || true
        return 1
    fi
    
    # Stop application
    kill $APP_PID 2>/dev/null || true
    
    print_success "API tests completed"
}

# Function to run security tests
run_security_tests() {
    print_status "Running security tests..."
    
    # Run Bandit
    if command_exists bandit; then
        bandit -r . -f json -o "../$REPORTS_DIR/security-bandit.json" || true
        bandit -r . -f txt > "../$REPORTS_DIR/security-bandit.txt" || true
        print_success "Bandit security scan completed"
    else
        print_warning "Bandit not found, skipping"
    fi
    
    # Run Safety
    if command_exists safety; then
        safety check --json > "../$REPORTS_DIR/security-safety.json" || true
        print_success "Safety dependency check completed"
    else
        print_warning "Safety not found, skipping"
    fi
}

# Function to run load tests
run_load_tests() {
    print_status "Running load tests..."
    
    # Start application in background
    python app.py &
    APP_PID=$!
    
    # Wait for application to start
    sleep 3
    
    # Simple load test with curl
    print_status "Running simple load test..."
    
    for i in {1..50}; do
        curl -s http://localhost:5000/items >/dev/null || true
    done
    
    print_success "Load test completed (50 requests)"
    
    # Stop application
    kill $APP_PID 2>/dev/null || true
}

# Function to generate test report
generate_test_report() {
    print_status "Generating test report..."
    
    cd ..
    REPORT_FILE="$REPORTS_DIR/test-summary.txt"
    
    cat > "$REPORT_FILE" << EOF
================================================================================
TechNova Inventory Management System - Test Report
================================================================================
Test Date: $(date)
Test Environment: $(uname -s) $(uname -r)

Test Results Summary:
================================================================================

Unit Tests:
- Status: $([ -f "$REPORTS_DIR/unit-test-results.xml" ] && echo "COMPLETED" || echo "SKIPPED")
- Coverage Report: $REPORTS_DIR/unit-coverage/index.html

Integration Tests:
- Status: $([ -f "$REPORTS_DIR/integration-test-results.xml" ] && echo "COMPLETED" || echo "SKIPPED")

Performance Tests:
- Status: $([ -f "$REPORTS_DIR/performance-test-results.xml" ] && echo "COMPLETED" || echo "SKIPPED")

Security Tests:
- Bandit Scan: $([ -f "$REPORTS_DIR/security-bandit.json" ] && echo "COMPLETED" || echo "SKIPPED")
- Safety Check: $([ -f "$REPORTS_DIR/security-safety.json" ] && echo "COMPLETED" || echo "SKIPPED")

API Tests:
- Health Endpoint: TESTED
- Items Endpoints: TESTED
- Metrics Endpoint: TESTED

Load Tests:
- Simple Load Test: COMPLETED

================================================================================

Test Artifacts:
- Unit Test Coverage: $REPORTS_DIR/unit-coverage/index.html
- Security Reports: $REPORTS_DIR/security-*.{json,txt}
- Test Results: $REPORTS_DIR/*-test-results.xml

Recommendations:
- Maintain test coverage above $COVERAGE_THRESHOLD%
- Review security scan results regularly
- Monitor performance test trends
- Add more edge case scenarios

================================================================================
EOF

    print_success "Test report generated: $REPORT_FILE"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up test environment..."
    
    # Kill any remaining processes
    pkill -f "python app.py" 2>/dev/null || true
    
    # Return to original directory
    cd ..
    
    print_success "Cleanup completed"
}

# Main test function
main() {
    print_status "Starting comprehensive test suite..."
    echo "=================================================="
    
    # Check prerequisites
    if ! command_exists python; then
        print_error "Python not found"
        exit 1
    fi
    
    # Setup
    setup_test_environment
    
    # Run test suites
    run_unit_tests
    run_integration_tests
    run_performance_tests
    run_api_tests
    run_security_tests
    run_load_tests
    
    # Generate report
    generate_test_report
    
    echo "=================================================="
    print_success "All tests completed!"
    print_status "Test report available at: $REPORTS_DIR/test-summary.txt"
    print_status "Coverage report available at: $REPORTS_DIR/unit-coverage/index.html"
}

# Trap to cleanup on exit
trap cleanup EXIT

# Parse command line arguments
case "${1:-all}" in
    unit)
        setup_test_environment
        run_unit_tests
        ;;
    integration)
        setup_test_environment
        run_integration_tests
        ;;
    performance)
        setup_test_environment
        run_performance_tests
        ;;
    api)
        setup_test_environment
        run_api_tests
        ;;
    security)
        setup_test_environment
        run_security_tests
        ;;
    load)
        setup_test_environment
        run_load_tests
        ;;
    all|*)
        main
        ;;
esac
