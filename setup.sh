#!/bin/bash

# 🚀 Inventory App - Quick Setup Script
# This script helps you get started with the complete DevOps pipeline

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if ! command_exists docker-compose; then
        missing_deps+=("docker-compose")
    fi
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo "- Docker: https://docs.docker.com/get-docker/"
        echo "- Docker Compose: https://docs.docker.com/compose/install/"
        echo "- Git: https://git-scm.com/downloads"
        exit 1
    fi
    
    print_success "All prerequisites installed ✓"
}

# Check system resources
check_system_resources() {
    print_status "Checking system resources..."
    
    # Check available memory (Linux/macOS)
    if command_exists free; then
        available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        if [ "$available_mem" -lt 4000 ]; then
            print_warning "Low available memory: ${available_mem}MB. Recommend 4GB+ for full stack"
        fi
    fi
    
    # Check available disk space
    available_disk=$(df . | tail -1 | awk '{print $4}')
    if [ "$available_disk" -lt 10000000 ]; then  # 10GB in KB
        print_warning "Low disk space. Recommend 10GB+ free space"
    fi
    
    print_success "System resources checked ✓"
}

# Setup function
setup_project() {
    local setup_type=$1
    
    print_status "Setting up Inventory App - DevOps Pipeline..."
    
    case $setup_type in
        "quick")
            print_status "🚀 Quick Setup - API Only"
            docker-compose up -d inventory-service
            ;;
        "monitoring")
            print_status "📊 Monitoring Setup - Full Stack"
            docker-compose up -d
            ;;
        "build")
            print_status "🔨 Build Setup - From Source"
            docker-compose up --build -d
            ;;
        *)
            print_status "📊 Default Setup - Full Stack"
            docker-compose up -d
            ;;
    esac
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:5000/health >/dev/null 2>&1; then
            print_success "Inventory service is ready! ✓"
            break
        fi
        
        print_status "Attempt $attempt/$max_attempts - Waiting for inventory service..."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Inventory service failed to start within 5 minutes"
        print_status "Check logs with: docker-compose logs inventory-service"
        exit 1
    fi
}

# Test the deployment
test_deployment() {
    print_status "Testing deployment..."
    
    # Test health endpoint
    if curl -f http://localhost:5000/health >/dev/null 2>&1; then
        print_success "✓ Health check passed"
    else
        print_error "✗ Health check failed"
        return 1
    fi
    
    # Test API endpoints
    if curl -f http://localhost:5000/items >/dev/null 2>&1; then
        print_success "✓ API endpoint accessible"
    else
        print_error "✗ API endpoint failed"
        return 1
    fi
    
    # Check if Prometheus is running (if full stack)
    if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
        print_success "✓ Prometheus monitoring active"
    else
        print_warning "⚠ Prometheus not running (quick setup?)"
    fi
    
    # Check if Grafana is running (if full stack)
    if curl -f http://localhost:3000/api/health >/dev/null 2>&1; then
        print_success "✓ Grafana dashboards active"
    else
        print_warning "⚠ Grafana not running (quick setup?)"
    fi
    
    print_success "Deployment test completed! ✓"
}

# Show access information
show_access_info() {
    echo ""
    echo "🎉 Setup Complete! Your DevOps pipeline is ready."
    echo ""
    echo "📱 Access your applications:"
    echo "   Inventory API:    http://localhost:5000"
    echo "   API Health:       http://localhost:5000/health"
    echo "   API Items:        http://localhost:5000/items"
    echo ""
    
    if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
        echo "📊 Monitoring Stack:"
        echo "   Prometheus:       http://localhost:9090"
        echo "   Grafana:          http://localhost:3000 (admin/admin123)"
        echo "   cAdvisor:         http://localhost:8080"
        echo ""
    fi
    
    echo "🔧 Management Commands:"
    echo "   View logs:        docker-compose logs -f"
    echo "   Stop services:    docker-compose down"
    echo "   Restart:          docker-compose restart"
    echo "   Rebuild:          docker-compose up --build -d"
    echo ""
    
    echo "🧪 Test the API:"
    echo "   curl http://localhost:5000/health"
    echo "   curl http://localhost:5000/items"
    echo ""
    
    echo "📚 Next Steps:"
    echo "   1. Explore the monitoring dashboards"
    echo "   2. Run the test suite: cd inventory-service && python -m pytest"
    echo "   3. Try the load testing: ./scripts/test.sh load-test"
    echo "   4. Check out the GitHub Actions workflows"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up Docker resources..."
    docker-compose down -v
    docker system prune -f
    print_success "Cleanup completed"
}

# Main script
main() {
    echo "🚀 Inventory Management System - DevOps Pipeline Setup"
    echo "=================================================="
    echo ""
    
    case "$1" in
        "quick")
            check_prerequisites
            check_system_resources
            setup_project "quick"
            wait_for_services
            test_deployment
            show_access_info
            ;;
        "monitoring"|"full")
            check_prerequisites
            check_system_resources
            setup_project "monitoring"
            wait_for_services
            test_deployment
            show_access_info
            ;;
        "build")
            check_prerequisites
            check_system_resources
            setup_project "build"
            wait_for_services
            test_deployment
            show_access_info
            ;;
        "test")
            test_deployment
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  quick      Setup API only (fastest, minimal resources)"
            echo "  monitoring Setup full monitoring stack (recommended)"
            echo "  build      Build from source code"
            echo "  test       Test current deployment"
            echo "  cleanup    Stop and remove all containers"
            echo "  help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 quick          # Quick API-only setup"
            echo "  $0 monitoring     # Full stack with monitoring"
            echo "  $0 test           # Test the deployment"
            echo "  $0 cleanup        # Clean up everything"
            ;;
        *)
            print_status "No option specified, using default (full monitoring stack)"
            check_prerequisites
            check_system_resources
            setup_project "monitoring"
            wait_for_services
            test_deployment
            show_access_info
            ;;
    esac
}

# Run main function with all arguments
main "$@"
