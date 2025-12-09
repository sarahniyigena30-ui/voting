#!/bin/bash

##############################################################################
# Blue-Green Deployment Management Script
# Manages traffic switching between Blue (current) and Green (new) deployments
##############################################################################

set -e

NAMESPACE="voting-system"
SERVICE_NAME="voting-app-service"
BLUE_DEPLOYMENT="voting-app-blue"
GREEN_DEPLOYMENT="voting-app-green"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

##############################################################################
# Helper Functions
##############################################################################

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

##############################################################################
# Core Functions
##############################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
        exit 1
    fi
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "Namespace '$NAMESPACE' not found."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

get_current_version() {
    local version=$(kubectl get service $SERVICE_NAME -n $NAMESPACE \
        -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "unknown")
    echo "$version"
}

get_deployment_status() {
    local deployment=$1
    local ready=$(kubectl get deployment $deployment -n $NAMESPACE \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired=$(kubectl get deployment $deployment -n $NAMESPACE \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    echo "${ready}/${desired}"
}

##############################################################################
# Main Commands
##############################################################################

cmd_status() {
    log_info "Current Deployment Status"
    echo ""
    
    local current_version=$(get_current_version)
    log_info "Traffic routed to: ${BLUE}${current_version}${NC}"
    echo ""
    
    log_info "Blue Deployment Status:"
    local blue_status=$(get_deployment_status $BLUE_DEPLOYMENT)
    echo "  Ready Pods: $blue_status"
    kubectl get pods -n $NAMESPACE -l app=voting-app,version=blue \
        --no-headers 2>/dev/null | head -5 || true
    echo ""
    
    log_info "Green Deployment Status:"
    local green_status=$(get_deployment_status $GREEN_DEPLOYMENT)
    echo "  Ready Pods: $green_status"
    kubectl get pods -n $NAMESPACE -l app=voting-app,version=green \
        --no-headers 2>/dev/null | head -5 || true
    echo ""
}

cmd_deploy_green() {
    local image=$1
    
    if [ -z "$image" ]; then
        log_error "Image URL required"
        echo "Usage: $0 deploy-green <image-url>"
        echo "Example: $0 deploy-green ghcr.io/user/voting:v1.1.0"
        exit 1
    fi
    
    log_info "Deploying Green version with image: $image"
    
    # Update Green deployment with new image
    kubectl set image deployment/$GREEN_DEPLOYMENT \
        voting-app=$image \
        -n $NAMESPACE --record
    
    log_info "Waiting for Green deployment to be ready (timeout: 5 minutes)..."
    if kubectl rollout status deployment/$GREEN_DEPLOYMENT \
        -n $NAMESPACE --timeout=300s; then
        log_success "Green deployment is ready"
    else
        log_error "Green deployment failed to become ready"
        exit 1
    fi
}

cmd_test_green() {
    log_info "Testing Green deployment..."
    
    local green_pod=$(kubectl get pods -n $NAMESPACE \
        -l app=voting-app,version=green \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$green_pod" ]; then
        log_error "No Green pods found"
        exit 1
    fi
    
    log_info "Testing pod: $green_pod"
    
    # Health check
    log_info "Running health check..."
    kubectl exec $green_pod -n $NAMESPACE -- \
        wget -q -O- http://localhost:3000/health || {
        log_error "Health check failed"
        exit 1
    }
    log_success "Health check passed"
    
    # API check
    log_info "Running API check..."
    kubectl exec $green_pod -n $NAMESPACE -- \
        wget -q -O- http://localhost:3000/votes || {
        log_error "API check failed"
        exit 1
    }
    log_success "API check passed"
    
    log_success "All tests passed"
}

cmd_switch_to_green() {
    local current=$(get_current_version)
    
    if [ "$current" = "green" ]; then
        log_warning "Traffic already routed to Green"
        return 0
    fi
    
    log_info "Switching traffic from Blue to Green..."
    
    kubectl patch service $SERVICE_NAME -n $NAMESPACE \
        -p '{"spec":{"selector":{"version":"green"}}}'
    
    log_success "Traffic switched to Green"
    
    # Verify
    local new_version=$(get_current_version)
    if [ "$new_version" = "green" ]; then
        log_success "Verified: Traffic now routed to $new_version"
    else
        log_error "Verification failed: Expected 'green', got '$new_version'"
        exit 1
    fi
}

cmd_switch_to_blue() {
    local current=$(get_current_version)
    
    if [ "$current" = "blue" ]; then
        log_warning "Traffic already routed to Blue"
        return 0
    fi
    
    log_info "Switching traffic from Green back to Blue (ROLLBACK)..."
    
    kubectl patch service $SERVICE_NAME -n $NAMESPACE \
        -p '{"spec":{"selector":{"version":"blue"}}}'
    
    log_success "Traffic switched back to Blue"
    
    # Verify
    local new_version=$(get_current_version)
    if [ "$new_version" = "blue" ]; then
        log_success "Verified: Traffic now routed to $new_version"
    else
        log_error "Verification failed: Expected 'blue', got '$new_version'"
        exit 1
    fi
}

cmd_cleanup_green() {
    log_warning "Deleting old Green deployment (permanent)..."
    read -p "Are you sure? This cannot be undone. (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    kubectl delete deployment $GREEN_DEPLOYMENT -n $NAMESPACE
    log_success "Green deployment deleted"
}

cmd_monitor() {
    log_info "Monitoring deployments (press Ctrl+C to stop)..."
    echo ""
    
    watch -n 5 "
        echo '=== Service Status ===';
        kubectl get svc $SERVICE_NAME -n $NAMESPACE;
        echo '';
        echo '=== Blue Deployment ===';
        kubectl get deployment $BLUE_DEPLOYMENT -n $NAMESPACE;
        echo '';
        echo '=== Green Deployment ===';
        kubectl get deployment $GREEN_DEPLOYMENT -n $NAMESPACE;
        echo '';
        echo '=== Pods ===';
        kubectl get pods -n $NAMESPACE -l app=voting-app;
    "
}

cmd_logs_blue() {
    log_info "Streaming logs from Blue deployment..."
    kubectl logs -f -n $NAMESPACE \
        -l app=voting-app,version=blue \
        --max-log-requests=10
}

cmd_logs_green() {
    log_info "Streaming logs from Green deployment..."
    kubectl logs -f -n $NAMESPACE \
        -l app=voting-app,version=green \
        --max-log-requests=10
}

##############################################################################
# Usage
##############################################################################

usage() {
    cat << EOF
${BLUE}Blue-Green Deployment Management${NC}

Usage: $0 <command> [options]

Commands:
  status              Show current deployment status
  deploy-green IMG    Deploy Green version with specified image
                      Example: deploy-green ghcr.io/user/voting:v1.1.0
  test-green          Run smoke tests on Green deployment
  switch-to-green     Switch traffic to Green (production)
  switch-to-blue      Switch traffic back to Blue (rollback)
  cleanup-green       Delete Green deployment after successful switch
  monitor             Watch deployments in real-time
  logs-blue           Stream logs from Blue deployment
  logs-green          Stream logs from Green deployment

Workflow Example:
  1. $0 status                           # Check current status
  2. $0 deploy-green ghcr.io/.../v1.1.0 # Deploy new version
  3. $0 test-green                       # Validate new version
  4. $0 switch-to-green                  # Switch traffic
  5. Monitor for 1 hour...
  6. $0 cleanup-green                    # Remove old version

EOF
    exit 1
}

##############################################################################
# Main
##############################################################################

main() {
    if [ $# -eq 0 ]; then
        usage
    fi
    
    check_prerequisites
    
    case "$1" in
        status)
            cmd_status
            ;;
        deploy-green)
            cmd_deploy_green "$2"
            ;;
        test-green)
            cmd_test_green
            ;;
        switch-to-green)
            cmd_switch_to_green
            ;;
        switch-to-blue)
            cmd_switch_to_blue
            ;;
        cleanup-green)
            cmd_cleanup_green
            ;;
        monitor)
            cmd_monitor
            ;;
        logs-blue)
            cmd_logs_blue
            ;;
        logs-green)
            cmd_logs_green
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            usage
            ;;
    esac
}

main "$@"
