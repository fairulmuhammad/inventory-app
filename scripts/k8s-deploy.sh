#!/bin/bash

# =============================================================================
# TechNova Inventory Management System - Kubernetes Deployment & Rollback Script
# Description: Advanced deployment automation with rollback capabilities
# =============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="technova-inventory"
DEPLOYMENT_NAME="inventory-service"
SERVICE_NAME="inventory-service"
ROLLBACK_HISTORY_LIMIT=5
BACKUP_DIR="k8s-backups"
TIMEOUT=300

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking Kubernetes deployment prerequisites..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create backup
create_backup() {
    local backup_timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_file="${BACKUP_DIR}/${DEPLOYMENT_NAME}-${backup_timestamp}.yaml"
    
    print_status "Creating backup of current deployment..."
    
    mkdir -p "${BACKUP_DIR}"
    
    # Backup current deployment
    kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o yaml > "${backup_file}" 2>/dev/null || true
    
    # Backup service
    kubectl get service "${SERVICE_NAME}" -n "${NAMESPACE}" -o yaml >> "${backup_file}" 2>/dev/null || true
    
    # Backup HPA
    kubectl get hpa "${DEPLOYMENT_NAME}-hpa" -n "${NAMESPACE}" -o yaml >> "${backup_file}" 2>/dev/null || true
    
    print_success "Backup created: ${backup_file}"
    echo "${backup_file}"
}

# Function to deploy application
deploy_application() {
    local image_tag=${1:-"latest"}
    
    print_status "Deploying inventory service with image tag: ${image_tag}"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply configurations in order
    print_status "Applying Kubernetes configurations..."
    
    # Apply base deployment
    kubectl apply -f k8s/deployment.yaml
    
    # Apply autoscaling configuration
    kubectl apply -f k8s/autoscaling.yaml
    
    # Apply monitoring if exists
    if [[ -f "k8s/monitoring.yaml" ]]; then
        kubectl apply -f k8s/monitoring.yaml
    fi
    
    # Update image if specified
    if [[ "${image_tag}" != "latest" ]]; then
        kubectl set image deployment/${DEPLOYMENT_NAME} \
            inventory-service=technova/inventory-service:${image_tag} \
            -n "${NAMESPACE}"
    fi
    
    print_success "Deployment configuration applied"
}

# Function to wait for deployment
wait_for_deployment() {
    print_status "Waiting for deployment to be ready..."
    
    if kubectl rollout status deployment/${DEPLOYMENT_NAME} -n "${NAMESPACE}" --timeout=${TIMEOUT}s; then
        print_success "Deployment completed successfully"
        return 0
    else
        print_error "Deployment failed or timed out"
        return 1
    fi
}

# Function to verify deployment health
verify_deployment() {
    print_status "Verifying deployment health..."
    
    # Check if pods are running
    local ready_pods=$(kubectl get pods -n "${NAMESPACE}" -l app="${DEPLOYMENT_NAME}" \
        --field-selector=status.phase=Running --no-headers | wc -l)
    
    local total_pods=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.replicas}')
    
    if [[ "${ready_pods}" -eq "${total_pods}" ]]; then
        print_success "All ${total_pods} pods are running and ready"
    else
        print_warning "Only ${ready_pods}/${total_pods} pods are ready"
    fi
    
    # Check service endpoints
    local endpoints=$(kubectl get endpoints "${SERVICE_NAME}" -n "${NAMESPACE}" \
        -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)
    
    if [[ "${endpoints}" -gt 0 ]]; then
        print_success "Service has ${endpoints} ready endpoints"
    else
        print_error "Service has no ready endpoints"
        return 1
    fi
    
    # Test health endpoint if available
    print_status "Testing application health endpoint..."
    kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl:latest \
        -- curl -f "http://${SERVICE_NAME}.${NAMESPACE}:80/health" \
        >/dev/null 2>&1 && print_success "Health check passed" || print_warning "Health check failed"
    
    return 0
}

# Function to rollback deployment
rollback_deployment() {
    local revision=${1:-""}
    
    print_status "Initiating deployment rollback..."
    
    if [[ -n "${revision}" ]]; then
        print_status "Rolling back to revision: ${revision}"
        kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n "${NAMESPACE}" --to-revision="${revision}"
    else
        print_status "Rolling back to previous revision"
        kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n "${NAMESPACE}"
    fi
    
    # Wait for rollback to complete
    if wait_for_deployment; then
        print_success "Rollback completed successfully"
        verify_deployment
    else
        print_error "Rollback failed"
        return 1
    fi
}

# Function to scale deployment
scale_deployment() {
    local replicas=${1:-3}
    
    print_status "Scaling deployment to ${replicas} replicas..."
    
    kubectl scale deployment/${DEPLOYMENT_NAME} -n "${NAMESPACE}" --replicas="${replicas}"
    
    if wait_for_deployment; then
        print_success "Scaling completed successfully"
    else
        print_error "Scaling failed"
        return 1
    fi
}

# Function to show deployment status
show_status() {
    print_status "Current deployment status:"
    
    echo ""
    echo "=== Deployment Status ==="
    kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o wide
    
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -n "${NAMESPACE}" -l app="${DEPLOYMENT_NAME}" -o wide
    
    echo ""
    echo "=== Service Status ==="
    kubectl get service "${SERVICE_NAME}" -n "${NAMESPACE}" -o wide
    
    echo ""
    echo "=== HPA Status ==="
    kubectl get hpa "${DEPLOYMENT_NAME}-hpa" -n "${NAMESPACE}" -o wide 2>/dev/null || echo "HPA not found"
    
    echo ""
    echo "=== Rollout History ==="
    kubectl rollout history deployment/${DEPLOYMENT_NAME} -n "${NAMESPACE}"
    
    echo ""
    echo "=== Resource Usage ==="
    kubectl top pods -n "${NAMESPACE}" -l app="${DEPLOYMENT_NAME}" 2>/dev/null || echo "Metrics not available"
}

# Function to run chaos engineering tests
chaos_test() {
    print_status "Running chaos engineering tests..."
    
    # Kill random pod
    local random_pod=$(kubectl get pods -n "${NAMESPACE}" -l app="${DEPLOYMENT_NAME}" \
        -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -n "${random_pod}" ]]; then
        print_status "Killing pod: ${random_pod}"
        kubectl delete pod "${random_pod}" -n "${NAMESPACE}"
        
        sleep 5
        
        # Verify recovery
        if wait_for_deployment; then
            print_success "Chaos test passed: System recovered from pod failure"
        else
            print_error "Chaos test failed: System did not recover properly"
        fi
    fi
}

# Function to load test
load_test() {
    local duration=${1:-60}
    local concurrency=${2:-10}
    
    print_status "Running load test for ${duration}s with ${concurrency} concurrent users..."
    
    # Get service URL
    local service_url="http://$(kubectl get service "${SERVICE_NAME}" -n "${NAMESPACE}" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "${SERVICE_NAME}.${NAMESPACE}")"
    
    # Run load test using kubectl run
    kubectl run load-test --rm -i --restart=Never --image=williamyeh/wrk:latest \
        -- wrk -t${concurrency} -c${concurrency} -d${duration}s --timeout=10s \
        "${service_url}/items" || print_warning "Load test command failed"
    
    print_status "Monitoring HPA during load test..."
    kubectl get hpa "${DEPLOYMENT_NAME}-hpa" -n "${NAMESPACE}" --watch --timeout=60s || true
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up deployment..."
    
    kubectl delete -f k8s/ --ignore-not-found=true
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
    
    print_success "Cleanup completed"
}

# Main function
main() {
    local action=${1:-"deploy"}
    local arg2=${2:-""}
    local arg3=${3:-""}
    
    case "${action}" in
        "deploy")
            check_prerequisites
            local backup_file=$(create_backup)
            deploy_application "${arg2}"
            if wait_for_deployment && verify_deployment; then
                print_success "Deployment completed successfully"
                show_status
            else
                print_error "Deployment failed, initiating rollback..."
                rollback_deployment
                exit 1
            fi
            ;;
        "rollback")
            check_prerequisites
            rollback_deployment "${arg2}"
            ;;
        "scale")
            check_prerequisites
            scale_deployment "${arg2}"
            ;;
        "status")
            show_status
            ;;
        "chaos")
            check_prerequisites
            chaos_test
            ;;
        "load-test")
            check_prerequisites
            load_test "${arg2}" "${arg3}"
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            echo "Usage: $0 {deploy|rollback|scale|status|chaos|load-test|cleanup} [args...]"
            echo ""
            echo "Commands:"
            echo "  deploy [image_tag]     - Deploy application with optional image tag"
            echo "  rollback [revision]    - Rollback to previous or specific revision"
            echo "  scale [replicas]       - Scale deployment to specified number of replicas"
            echo "  status                 - Show current deployment status"
            echo "  chaos                  - Run chaos engineering test"
            echo "  load-test [duration] [concurrency] - Run load test"
            echo "  cleanup                - Remove all deployed resources"
            echo ""
            echo "Examples:"
            echo "  $0 deploy v1.2.0"
            echo "  $0 rollback 3"
            echo "  $0 scale 5"
            echo "  $0 load-test 120 20"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
