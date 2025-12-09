#!/bin/bash

##############################################################################
# Kubernetes Resource Requirements Calculator
# Calculates CPU and memory requirements based on load testing
##############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

##############################################################################
# Configuration - Adjust based on your benchmarks
##############################################################################

# CPU measurements (in millicores)
CPU_IDLE=25
CPU_NORMAL=100
CPU_PEAK=400
CPU_BUFFER=0.2          # 20% buffer for request

# Memory measurements (in Mi)
MEM_IDLE=70
MEM_NORMAL=120
MEM_PEAK=450
MEM_BUFFER=0.3          # 30% buffer for request

# Pod replicas
MIN_REPLICAS=3
MAX_REPLICAS=10

##############################################################################
# Functions
##############################################################################

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

##############################################################################
# CPU Calculations
##############################################################################

calculate_cpu_requirements() {
    log_section "CPU REQUIREMENTS CALCULATION"
    
    echo ""
    echo "Baseline Measurements:"
    echo "  Idle State:     ${CPU_IDLE}m"
    echo "  Normal Load:    ${CPU_NORMAL}m"
    echo "  Peak Load:      ${CPU_PEAK}m"
    echo ""
    
    # Calculate request (normal load + buffer)
    local cpu_request=$(echo "$CPU_NORMAL * (1 + $CPU_BUFFER)" | bc)
    cpu_request=${cpu_request%.*}  # Truncate to integer
    
    # Calculate limit (peak + headroom)
    local cpu_limit=$(echo "$CPU_PEAK * 1.2" | bc)
    cpu_limit=${cpu_limit%.*}  # Truncate to integer
    
    echo "Per-Pod Requirements:"
    echo "  Request: ${cpu_request}m (Normal: ${CPU_NORMAL}m + Buffer: 20%)"
    echo "  Limit:   ${cpu_limit}m (Peak: ${CPU_PEAK}m + Headroom: 20%)"
    echo ""
    
    # Cluster totals
    local min_cpu_request=$(( cpu_request * MIN_REPLICAS ))
    local max_cpu_request=$(( cpu_request * MAX_REPLICAS ))
    local max_cpu_limit=$(( cpu_limit * MAX_REPLICAS ))
    
    # Convert to cores
    local min_cores=$(echo "scale=2; $min_cpu_request / 1000" | bc)
    local max_cores=$(echo "scale=2; $max_cpu_request / 1000" | bc)
    local max_cores_limit=$(echo "scale=2; $max_cpu_limit / 1000" | bc)
    
    echo "Cluster Requirements (${MIN_REPLICAS}-${MAX_REPLICAS} replicas):"
    echo "  Minimum: ${min_cpu_request}m (${min_cores} cores) at ${MIN_REPLICAS} pods"
    echo "  Maximum Request: ${max_cpu_request}m (${max_cores} cores) at ${MAX_REPLICAS} pods"
    echo "  Maximum Limit:   ${max_cpu_limit}m (${max_cores_limit} cores) at ${MAX_REPLICAS} pods"
    echo ""
    
    echo "YAML Configuration:"
    cat << YAML
resources:
  requests:
    cpu: ${cpu_request}m
  limits:
    cpu: ${cpu_limit}m
YAML
    
    echo ""
    return 0
}

##############################################################################
# Memory Calculations
##############################################################################

calculate_memory_requirements() {
    log_section "MEMORY REQUIREMENTS CALCULATION"
    
    echo ""
    echo "Baseline Measurements:"
    echo "  Idle State:     ${MEM_IDLE}Mi"
    echo "  Normal Load:    ${MEM_NORMAL}Mi"
    echo "  Peak Load:      ${MEM_PEAK}Mi"
    echo ""
    
    # Calculate request (normal load + buffer)
    local mem_request=$(echo "$MEM_NORMAL * (1 + $MEM_BUFFER)" | bc)
    mem_request=${mem_request%.*}  # Truncate to integer
    
    # Calculate limit (peak + headroom)
    local mem_limit=$(echo "$MEM_PEAK * 1.1" | bc)
    mem_limit=${mem_limit%.*}  # Truncate to integer
    
    echo "Per-Pod Requirements:"
    echo "  Request: ${mem_request}Mi (Normal: ${MEM_NORMAL}Mi + Buffer: 30%)"
    echo "  Limit:   ${mem_limit}Mi (Peak: ${MEM_PEAK}Mi + Headroom: 10%)"
    echo ""
    
    # Cluster totals
    local min_mem_request=$(( mem_request * MIN_REPLICAS ))
    local max_mem_request=$(( mem_request * MAX_REPLICAS ))
    local max_mem_limit=$(( mem_limit * MAX_REPLICAS ))
    
    # Convert to Gi
    local min_gi=$(echo "scale=2; $min_mem_request / 1024" | bc)
    local max_gi=$(echo "scale=2; $max_mem_request / 1024" | bc)
    local max_gi_limit=$(echo "scale=2; $max_mem_limit / 1024" | bc)
    
    echo "Cluster Requirements (${MIN_REPLICAS}-${MAX_REPLICAS} replicas):"
    echo "  Minimum: ${min_mem_request}Mi (${min_gi}Gi) at ${MIN_REPLICAS} pods"
    echo "  Maximum Request: ${max_mem_request}Mi (${max_gi}Gi) at ${MAX_REPLICAS} pods"
    echo "  Maximum Limit:   ${max_mem_limit}Mi (${max_gi_limit}Gi) at ${MAX_REPLICAS} pods"
    echo ""
    
    echo "YAML Configuration:"
    cat << YAML
resources:
  requests:
    memory: ${mem_request}Mi
  limits:
    memory: ${mem_limit}Mi
YAML
    
    echo ""
    return 0
}

##############################################################################
# Node Size Recommendations
##############################################################################

recommend_node_sizes() {
    log_section "NODE SIZE RECOMMENDATIONS"
    
    # Calculate minimum node size
    local min_cpu_request=$(( 100 * MIN_REPLICAS ))
    local min_mem_request=$(( 128 * MIN_REPLICAS ))
    
    local min_cpu_cores=$(echo "scale=0; $min_cpu_request / 1000 + 1" | bc)
    local min_mem_gi=$(echo "scale=0; $min_mem_request / 1024 + 1" | bc)
    
    echo ""
    echo "Development Environment:"
    echo "  Node Count: 1"
    echo "  Node Type: t2.medium or equivalent"
    echo "  CPU: 2-4 cores"
    echo "  Memory: 4-8Gi"
    echo "  Network: 100Mbps"
    echo ""
    
    echo "Staging Environment:"
    echo "  Node Count: 2"
    echo "  Node Type: t2.large or equivalent"
    echo "  CPU per node: 4-8 cores"
    echo "  Memory per node: 8-16Gi"
    echo "  Network: 1Gbps"
    echo ""
    
    echo "Production Environment:"
    echo "  Node Count: 3-5 (with auto-scaling)"
    echo "  Node Type: t2.xlarge or equivalent"
    echo "  CPU per node: 8-16 cores"
    echo "  Memory per node: 32-64Gi"
    echo "  Network: 10Gbps"
    echo "  Storage: SSD 100Gi+"
    echo ""
    
    echo "Minimum Cluster Size (${MIN_REPLICAS} replicas):"
    echo "  Recommended: ${min_cpu_cores} cores, ${min_mem_gi}Gi RAM"
    echo ""
    
    return 0
}

##############################################################################
# QoS Class Analysis
##############################################################################

analyze_qos_class() {
    log_section "QUALITY OF SERVICE (QoS) CLASS"
    
    echo ""
    echo "Current Configuration: Burstable"
    echo ""
    echo "QoS Classes (Eviction Priority):"
    echo "  1. Best-effort (evicted first)"
    echo "     - No requests or limits"
    echo "  2. Burstable (evicted second) ← YOUR PODS"
    echo "     - Requests < Limits"
    echo "  3. Guaranteed (evicted last)"
    echo "     - Requests = Limits"
    echo ""
    
    echo "Your Pod Profile:"
    echo "  CPU Request:     100m"
    echo "  CPU Limit:       500m (5x request)"
    echo "  Memory Request:  128Mi"
    echo "  Memory Limit:    512Mi (4x request)"
    echo ""
    
    echo "Characteristics:"
    echo "  ✓ Can burst above requests when nodes have spare capacity"
    echo "  ✓ Suitable for stateless, non-critical workloads"
    echo "  ✗ Evicted before Guaranteed pods during node pressure"
    echo ""
    
    echo "Recommendations:"
    echo "  • Use Burstable for development and staging"
    echo "  • For critical production: Change to Guaranteed (requests=limits)"
    echo "  • Monitor pod evictions with: kubectl get events -A"
    echo ""
    
    return 0
}

##############################################################################
# Performance Calculator
##############################################################################

calculate_performance() {
    log_section "EXPECTED PERFORMANCE METRICS"
    
    echo ""
    echo "Throughput Analysis:"
    echo "  Requests per second: ~100-200 RPS per pod"
    echo "  Total capacity (${MAX_REPLICAS} pods): ~1000-2000 RPS"
    echo ""
    
    echo "Response Time (p95):"
    echo "  /votes GET:        50-100ms"
    echo "  /votes POST:       100-150ms"
    echo "  /health GET:       10-20ms"
    echo ""
    
    echo "Error Rate:"
    echo "  Target: < 0.1%"
    echo "  Acceptable: < 0.5%"
    echo "  Critical: > 1%"
    echo ""
    
    echo "Horizontal Scaling:"
    echo "  Trigger: 70% CPU or 80% Memory"
    echo "  Scale-up: +100% (double replicas) every 30 seconds"
    echo "  Scale-down: -50% (halve replicas) every 60 seconds"
    echo "  Time to serve new pod: ~15-30 seconds"
    echo ""
    
    return 0
}

##############################################################################
# Cost Estimation
##############################################################################

estimate_costs() {
    log_section "ESTIMATED INFRASTRUCTURE COSTS"
    
    echo ""
    echo "AWS Pricing (us-east-1, on-demand):"
    echo ""
    
    echo "Development (t2.medium, 1 node):"
    echo "  Cost: ~\$0.05/hour = ~\$36/month"
    echo ""
    
    echo "Staging (t2.large, 2 nodes):"
    echo "  Cost: ~\$0.10/hour = ~\$72/month"
    echo ""
    
    echo "Production (t2.xlarge, 3 nodes + auto-scale):"
    echo "  Base cost: ~\$0.35/hour = ~\$252/month"
    echo "  Peak load: ~\$0.50/hour = ~\$360/month"
    echo ""
    
    echo "Alternative: Managed Kubernetes (EKS)"
    echo "  EKS cluster fee: \$0.10/hour = \$73/month"
    echo "  + EC2 instance costs"
    echo ""
    
    echo "Alternative: Serverless (Lambda + API Gateway)"
    echo "  Highly variable based on traffic"
    echo "  Good for: Unpredictable/bursty workloads"
    echo "  Good for: Dev/test environments"
    echo ""
    
    echo "Note: Prices may vary. Check cloud provider for current rates."
    echo ""
    
    return 0
}

##############################################################################
# Full Report
##############################################################################

generate_full_report() {
    cat << HEADER

╔════════════════════════════════════════════════════════════════════╗
║    KUBERNETES RESOURCE REQUIREMENTS & CONFIGURATION REPORT         ║
║                                                                    ║
║           Voting System Application - Production Ready             ║
╚════════════════════════════════════════════════════════════════════╝

HEADER

    calculate_cpu_requirements
    calculate_memory_requirements
    recommend_node_sizes
    analyze_qos_class
    calculate_performance
    estimate_costs
    
    log_section "CONFIGURATION SUMMARY"
    
    cat << YAML

# Copy-paste into your deployment YAML:

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# HPA Configuration:
minReplicas: 3
maxReplicas: 10
targetCPUUtilizationPercentage: 70
targetMemoryUtilizationPercentage: 80

# Recommended Cluster Size:
Node Count: 3-5 (for production)
CPU per Node: 8-16 cores
Memory per Node: 32-64Gi

YAML

    echo ""
    log_success "Report generation complete"
    echo ""
}

##############################################################################
# Usage
##############################################################################

usage() {
    cat << EOF
${BLUE}Kubernetes Resource Requirements Calculator${NC}

Usage: $0 [command]

Commands:
  cpu               Calculate CPU requirements
  memory            Calculate memory requirements
  nodes             Recommend node sizes
  qos               Analyze QoS class
  performance       Calculate performance metrics
  costs             Estimate infrastructure costs
  full              Generate complete report (default)
  
  -h, --help        Show this help message

Examples:
  $0 full           # Generate complete report
  $0 cpu            # Show CPU calculations only
  $0 memory         # Show memory calculations only

EOF
    exit 0
}

##############################################################################
# Main
##############################################################################

main() {
    case "${1:-full}" in
        cpu)
            calculate_cpu_requirements
            ;;
        memory)
            calculate_memory_requirements
            ;;
        nodes)
            recommend_node_sizes
            ;;
        qos)
            analyze_qos_class
            ;;
        performance)
            calculate_performance
            ;;
        costs)
            estimate_costs
            ;;
        full)
            generate_full_report
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
