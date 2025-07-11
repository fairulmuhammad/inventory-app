#!/bin/bash

# =============================================================================
# TechNova Inventory Management System - Canary Deployment Script
# Description: Blue-Green and Canary deployment strategies
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
APP_NAME="inventory-service"
CANARY_NAMESPACE="technova-inventory-canary"
TRAFFIC_SPLIT_RATIO=10  # Percentage of traffic to canary
CANARY_DURATION=300     # Duration in seconds to run canary
SUCCESS_THRESHOLD=95    # Success rate threshold percentage

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to create canary deployment
create_canary_deployment() {
    local new_image=${1}
    
    print_status "Creating canary deployment with image: ${new_image}"
    
    # Create canary namespace
    kubectl create namespace "${CANARY_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Copy production deployment to canary
    kubectl get deployment "${APP_NAME}" -n "${NAMESPACE}" -o yaml | \
        sed "s/namespace: ${NAMESPACE}/namespace: ${CANARY_NAMESPACE}/g" | \
        sed "s/name: ${APP_NAME}/name: ${APP_NAME}-canary/g" | \
        sed "s/app: ${APP_NAME}/app: ${APP_NAME}-canary/g" | \
        sed "s/replicas: [0-9]*/replicas: 1/g" | \
        kubectl apply -f -
    
    # Update canary with new image
    kubectl set image deployment/${APP_NAME}-canary \
        inventory-service="${new_image}" \
        -n "${CANARY_NAMESPACE}"
    
    # Create canary service
    kubectl get service "${APP_NAME}" -n "${NAMESPACE}" -o yaml | \
        sed "s/namespace: ${NAMESPACE}/namespace: ${CANARY_NAMESPACE}/g" | \
        sed "s/name: ${APP_NAME}/name: ${APP_NAME}-canary/g" | \
        sed "s/app: ${APP_NAME}/app: ${APP_NAME}-canary/g" | \
        kubectl apply -f -
    
    # Wait for canary to be ready
    kubectl rollout status deployment/${APP_NAME}-canary -n "${CANARY_NAMESPACE}" --timeout=300s
    
    print_success "Canary deployment created successfully"
}

# Function to configure traffic splitting (requires Istio or similar)
configure_traffic_split() {
    local canary_weight=${1:-10}
    local stable_weight=$((100 - canary_weight))
    
    print_status "Configuring traffic split: ${stable_weight}% stable, ${canary_weight}% canary"
    
    # Create VirtualService for traffic splitting (Istio example)
    cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${APP_NAME}-vs
  namespace: ${NAMESPACE}
spec:
  hosts:
  - ${APP_NAME}
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: ${APP_NAME}-canary.${CANARY_NAMESPACE}.svc.cluster.local
        port:
          number: 80
  - route:
    - destination:
        host: ${APP_NAME}
        port:
          number: 80
      weight: ${stable_weight}
    - destination:
        host: ${APP_NAME}-canary.${CANARY_NAMESPACE}.svc.cluster.local
        port:
          number: 80
      weight: ${canary_weight}
EOF
    
    print_success "Traffic splitting configured"
}

# Function to monitor canary metrics
monitor_canary() {
    local duration=${1:-300}
    local check_interval=30
    local iterations=$((duration / check_interval))
    
    print_status "Monitoring canary deployment for ${duration} seconds..."
    
    local success_count=0
    local total_checks=0
    
    for ((i=1; i<=iterations; i++)); do
        print_status "Check ${i}/${iterations} - Monitoring canary health..."
        
        # Check canary pod health
        local canary_pods_ready=$(kubectl get pods -n "${CANARY_NAMESPACE}" \
            -l app="${APP_NAME}-canary" \
            --field-selector=status.phase=Running --no-headers | wc -l)
        
        if [[ "${canary_pods_ready}" -gt 0 ]]; then
            # Test canary endpoint
            if kubectl run canary-test --rm -i --restart=Never --image=curlimages/curl:latest \
                -- curl -f -s "http://${APP_NAME}-canary.${CANARY_NAMESPACE}:80/health" >/dev/null 2>&1; then
                success_count=$((success_count + 1))
                print_success "Canary health check passed (${success_count}/${total_checks})"
            else
                print_warning "Canary health check failed"
            fi
        else
            print_error "No canary pods are ready"
        fi
        
        total_checks=$((total_checks + 1))
        
        # Calculate success rate
        local success_rate=0
        if [[ "${total_checks}" -gt 0 ]]; then
            success_rate=$(( (success_count * 100) / total_checks ))
        fi
        
        print_status "Current success rate: ${success_rate}% (threshold: ${SUCCESS_THRESHOLD}%)"
        
        # Early termination if success rate is too low
        if [[ "${total_checks}" -ge 5 && "${success_rate}" -lt "${SUCCESS_THRESHOLD}" ]]; then
            print_error "Canary success rate (${success_rate}%) below threshold (${SUCCESS_THRESHOLD}%)"
            return 1
        fi
        
        sleep "${check_interval}"
    done
    
    # Final success rate check
    local final_success_rate=$(( (success_count * 100) / total_checks ))
    
    if [[ "${final_success_rate}" -ge "${SUCCESS_THRESHOLD}" ]]; then
        print_success "Canary monitoring completed successfully (${final_success_rate}% success rate)"
        return 0
    else
        print_error "Canary monitoring failed (${final_success_rate}% success rate)"
        return 1
    fi
}

# Function to promote canary to production
promote_canary() {
    local new_image=${1}
    
    print_status "Promoting canary to production..."
    
    # Update production deployment with new image
    kubectl set image deployment/${APP_NAME} \
        inventory-service="${new_image}" \
        -n "${NAMESPACE}"
    
    # Wait for production rollout
    kubectl rollout status deployment/${APP_NAME} -n "${NAMESPACE}" --timeout=300s
    
    # Remove traffic splitting
    kubectl delete virtualservice "${APP_NAME}-vs" -n "${NAMESPACE}" --ignore-not-found=true
    
    print_success "Canary promoted to production successfully"
}

# Function to rollback canary
rollback_canary() {
    print_status "Rolling back canary deployment..."
    
    # Remove traffic splitting
    kubectl delete virtualservice "${APP_NAME}-vs" -n "${NAMESPACE}" --ignore-not-found=true
    
    # Clean up canary resources
    kubectl delete namespace "${CANARY_NAMESPACE}" --ignore-not-found=true
    
    print_success "Canary rollback completed"
}

# Function to run blue-green deployment
blue_green_deployment() {
    local new_image=${1}
    local green_namespace="technova-inventory-green"
    
    print_status "Starting blue-green deployment with image: ${new_image}"
    
    # Create green environment
    kubectl create namespace "${green_namespace}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy to green environment
    kubectl get deployment "${APP_NAME}" -n "${NAMESPACE}" -o yaml | \
        sed "s/namespace: ${NAMESPACE}/namespace: ${green_namespace}/g" | \
        kubectl apply -f -
    
    # Update green with new image
    kubectl set image deployment/${APP_NAME} \
        inventory-service="${new_image}" \
        -n "${green_namespace}"
    
    # Wait for green to be ready
    kubectl rollout status deployment/${APP_NAME} -n "${green_namespace}" --timeout=300s
    
    # Test green environment
    print_status "Testing green environment..."
    
    # Port forward for testing
    kubectl port-forward -n "${green_namespace}" deployment/${APP_NAME} 8080:5000 &
    local port_forward_pid=$!
    
    sleep 5
    
    # Test green environment
    if curl -f -s "http://localhost:8080/health" >/dev/null; then
        print_success "Green environment health check passed"
        
        # Switch traffic to green (update service selector)
        kubectl patch service "${APP_NAME}" -n "${NAMESPACE}" \
            -p '{"spec":{"selector":{"version":"green"}}}'
        
        # Label green pods
        kubectl patch deployment "${APP_NAME}" -n "${green_namespace}" \
            -p '{"spec":{"template":{"metadata":{"labels":{"version":"green"}}}}}'
        
        # Move green deployment to blue namespace
        kubectl get deployment "${APP_NAME}" -n "${green_namespace}" -o yaml | \
            sed "s/namespace: ${green_namespace}/namespace: ${NAMESPACE}/g" | \
            kubectl apply -f -
        
        # Clean up old blue and green namespace
        kubectl delete deployment "${APP_NAME}" -n "${NAMESPACE}" --ignore-not-found=true || true
        kubectl delete namespace "${green_namespace}" --ignore-not-found=true
        
        print_success "Blue-green deployment completed successfully"
    else
        print_error "Green environment health check failed"
        kill "${port_forward_pid}" 2>/dev/null || true
        kubectl delete namespace "${green_namespace}" --ignore-not-found=true
        return 1
    fi
    
    kill "${port_forward_pid}" 2>/dev/null || true
}

# Function to run automated canary deployment
automated_canary() {
    local new_image=${1}
    
    print_status "Starting automated canary deployment..."
    
    # Step 1: Create canary
    if ! create_canary_deployment "${new_image}"; then
        print_error "Failed to create canary deployment"
        return 1
    fi
    
    # Step 2: Configure traffic split
    configure_traffic_split "${TRAFFIC_SPLIT_RATIO}"
    
    # Step 3: Monitor canary
    if monitor_canary "${CANARY_DURATION}"; then
        # Step 4: Promote canary
        promote_canary "${new_image}"
        
        # Step 5: Cleanup canary resources
        kubectl delete namespace "${CANARY_NAMESPACE}" --ignore-not-found=true
        
        print_success "Automated canary deployment completed successfully"
    else
        # Rollback on failure
        print_error "Canary monitoring failed, rolling back..."
        rollback_canary
        return 1
    fi
}

# Function to show deployment comparison
show_comparison() {
    echo ""
    echo "=== Production Environment ==="
    kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}" -o wide
    echo ""
    kubectl get deployment "${APP_NAME}" -n "${NAMESPACE}" -o wide
    
    echo ""
    echo "=== Canary Environment ==="
    kubectl get pods -n "${CANARY_NAMESPACE}" -l app="${APP_NAME}-canary" -o wide 2>/dev/null || echo "No canary deployment found"
    echo ""
    kubectl get deployment "${APP_NAME}-canary" -n "${CANARY_NAMESPACE}" -o wide 2>/dev/null || echo "No canary deployment found"
    
    echo ""
    echo "=== Traffic Configuration ==="
    kubectl get virtualservice "${APP_NAME}-vs" -n "${NAMESPACE}" -o yaml 2>/dev/null || echo "No traffic splitting configured"
}

# Main function
main() {
    local strategy=${1:-"canary"}
    local image=${2:-""}
    
    if [[ -z "${image}" ]]; then
        print_error "Image parameter is required"
        echo "Usage: $0 {canary|blue-green|promote|rollback|status} <image>"
        exit 1
    fi
    
    case "${strategy}" in
        "canary")
            automated_canary "${image}"
            ;;
        "blue-green")
            blue_green_deployment "${image}"
            ;;
        "promote")
            promote_canary "${image}"
            ;;
        "rollback")
            rollback_canary
            ;;
        "status")
            show_comparison
            ;;
        "monitor")
            monitor_canary "${3:-300}"
            ;;
        *)
            echo "Usage: $0 {canary|blue-green|promote|rollback|status|monitor} <image> [duration]"
            echo ""
            echo "Strategies:"
            echo "  canary <image>         - Automated canary deployment"
            echo "  blue-green <image>     - Blue-green deployment"
            echo "  promote <image>        - Promote canary to production"
            echo "  rollback               - Rollback canary deployment"
            echo "  status                 - Show deployment status"
            echo "  monitor [duration]     - Monitor existing canary"
            echo ""
            echo "Examples:"
            echo "  $0 canary technova/inventory-service:v1.2.0"
            echo "  $0 blue-green technova/inventory-service:v1.3.0"
            echo "  $0 monitor 600"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
