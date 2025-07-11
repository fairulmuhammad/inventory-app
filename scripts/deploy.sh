#!/bin/bash

# =============================================================================
# TechNova Inventory Management System - Deployment Script
# Description: Production deployment automation script
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-staging}
SERVICE_NAME="inventory-service"
IMAGE_NAME="technova/inventory-service"
VERSION=${2:-latest}
NAMESPACE="technova-inventory"
BACKUP_DIR="backups"

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking deployment prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to backup current deployment
backup_current_deployment() {
    print_status "Creating backup of current deployment..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    # Backup docker-compose and configuration files
    tar -czf "$BACKUP_FILE" \
        docker-compose.yml \
        monitoring/ \
        .env* 2>/dev/null || true
    
    print_success "Backup created: $BACKUP_FILE"
}

# Function to pull latest images
pull_images() {
    print_status "Pulling latest Docker images..."
    
    docker-compose pull
    
    print_success "Images pulled successfully"
}

# Function to run health checks
run_health_checks() {
    print_status "Running health checks..."
    
    # Wait for services to be ready
    sleep 10
    
    # Check inventory service health
    if curl -f http://localhost:5001/health >/dev/null 2>&1; then
        print_success "Inventory service: HEALTHY"
    else
        print_error "Inventory service: UNHEALTHY"
        return 1
    fi
    
    # Check Prometheus
    if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
        print_success "Prometheus: HEALTHY"
    else
        print_warning "Prometheus: UNHEALTHY (non-critical)"
    fi
    
    # Check Grafana
    if curl -f http://localhost:3000/api/health >/dev/null 2>&1; then
        print_success "Grafana: HEALTHY"
    else
        print_warning "Grafana: UNHEALTHY (non-critical)"
    fi
    
    print_success "Health checks completed"
}

# Function to deploy to staging
deploy_staging() {
    print_status "Deploying to staging environment..."
    
    # Stop existing containers
    docker-compose down || true
    
    # Start services
    docker-compose up -d --build
    
    # Run health checks
    run_health_checks
    
    print_success "Staging deployment completed"
}

# Function to deploy to production
deploy_production() {
    print_status "Deploying to production environment..."
    
    # Additional checks for production
    print_status "Running pre-production checks..."
    
    # Check if we have the required version
    if [ "$VERSION" = "latest" ]; then
        print_warning "Using 'latest' tag in production is not recommended"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Deployment cancelled"
            exit 1
        fi
    fi
    
    # Rolling deployment strategy
    print_status "Starting rolling deployment..."
    
    # Scale up new version
    docker-compose up -d --scale inventory-service=2 --no-recreate
    
    # Wait for new instance to be healthy
    sleep 15
    run_health_checks
    
    # Scale down old version
    docker-compose up -d --scale inventory-service=1
    
    # Final health check
    run_health_checks
    
    print_success "Production deployment completed"
}

# Function to rollback deployment
rollback_deployment() {
    print_status "Rolling back deployment..."
    
    # Find latest backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        print_error "No backup found for rollback"
        exit 1
    fi
    
    print_status "Using backup: $LATEST_BACKUP"
    
    # Stop current deployment
    docker-compose down
    
    # Restore backup
    tar -xzf "$LATEST_BACKUP"
    
    # Start services
    docker-compose up -d
    
    # Health check
    run_health_checks
    
    print_success "Rollback completed"
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status:"
    echo "==================="
    
    # Docker containers status
    echo "Docker Containers:"
    docker-compose ps
    echo
    
    # Service endpoints
    echo "Service Endpoints:"
    echo "- Inventory Service: http://localhost:5001"
    echo "- Prometheus: http://localhost:9090"
    echo "- Grafana: http://localhost:3000"
    echo
    
    # Quick health check
    echo "Health Status:"
    curl -s http://localhost:5001/health | jq -r '.status // "UNKNOWN"' 2>/dev/null && echo " - Inventory: OK" || echo " - Inventory: ERROR"
    curl -s http://localhost:9090/-/healthy >/dev/null 2>&1 && echo " - Prometheus: OK" || echo " - Prometheus: ERROR"
    curl -s http://localhost:3000/api/health >/dev/null 2>&1 && echo " - Grafana: OK" || echo " - Grafana: ERROR"
}

# Function to cleanup old resources
cleanup() {
    print_status "Cleaning up old resources..."
    
    # Remove old Docker images
    docker image prune -f
    
    # Remove old backups (keep last 5)
    ls -t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Function to validate configuration
validate_config() {
    print_status "Validating configuration..."
    
    # Check docker-compose file
    if ! docker-compose config >/dev/null 2>&1; then
        print_error "Invalid docker-compose configuration"
        exit 1
    fi
    
    # Check required files
    REQUIRED_FILES=(
        "docker-compose.yml"
        "inventory-service/Dockerfile"
        "monitoring/prometheus/prometheus.yml"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            exit 1
        fi
    done
    
    print_success "Configuration validation passed"
}

# Main deployment function
main() {
    print_status "Starting deployment process..."
    echo "Environment: $ENVIRONMENT"
    echo "Version: $VERSION"
    echo "========================================="
    
    # Validate configuration
    validate_config
    
    # Check prerequisites
    check_prerequisites
    
    # Create backup
    backup_current_deployment
    
    case "$ENVIRONMENT" in
        staging)
            deploy_staging
            ;;
        production)
            pull_images
            deploy_production
            ;;
        rollback)
            rollback_deployment
            ;;
        status)
            show_status
            exit 0
            ;;
        cleanup)
            cleanup
            exit 0
            ;;
        *)
            print_error "Unknown environment: $ENVIRONMENT"
            echo "Usage: $0 {staging|production|rollback|status|cleanup} [version]"
            exit 1
            ;;
    esac
    
    # Final status check
    show_status
    
    # Cleanup
    cleanup
    
    echo "========================================="
    print_success "Deployment process completed successfully!"
    print_status "Monitor the deployment at:"
    print_status "- Application: http://localhost:5001"
    print_status "- Monitoring: http://localhost:3000"
}

# Script usage
usage() {
    echo "Usage: $0 {staging|production|rollback|status|cleanup} [version]"
    echo
    echo "Commands:"
    echo "  staging     Deploy to staging environment"
    echo "  production  Deploy to production environment"
    echo "  rollback    Rollback to previous deployment"
    echo "  status      Show current deployment status"
    echo "  cleanup     Clean up old resources"
    echo
    echo "Examples:"
    echo "  $0 staging"
    echo "  $0 production 1.0.0"
    echo "  $0 rollback"
    echo "  $0 status"
    exit 1
}

# Check if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

# Run main function
main
