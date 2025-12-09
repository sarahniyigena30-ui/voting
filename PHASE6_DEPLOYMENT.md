# Phase 6: Deployment Configuration

## Overview
This phase implements a production-ready CD pipeline with Kubernetes deployment, rolling updates, blue-green deployment strategy, and resource optimization.

## Table of Contents
1. [Deployment Architecture](#deployment-architecture)
2. [Rolling Update Strategy](#rolling-update-strategy)
3. [Blue-Green Deployment](#blue-green-deployment)
4. [Resource Requirements](#resource-requirements)
5. [Deployment Procedures](#deployment-procedures)
6. [Monitoring & Health Checks](#monitoring--health-checks)

---

## Deployment Architecture

### Current Setup
- **Container Registry**: GitHub Container Registry (GHCR) + Docker Hub
- **Orchestration**: Kubernetes 1.20+
- **Namespace**: `voting-system`
- **Load Balancing**: LoadBalancer Service
- **Auto-scaling**: HPA (3-10 replicas)

### Environment Specifications

| Component | Value |
|-----------|-------|
| **K8s Version** | 1.20+ |
| **Container Runtime** | Docker/containerd |
| **Ingress Controller** | nginx-ingress (optional) |
| **Storage** | emptyDir (stateless) |
| **Monitoring** | Prometheus + Grafana |
| **Logging** | Fluent Bit / Logstash |

---

## Rolling Update Strategy

### What is Rolling Update?
Rolling updates gradually replace old pods with new ones, ensuring zero downtime during deployments.

### Configuration Details

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1              # Allow 1 extra pod during update
    maxUnavailable: 0        # Never allow unavailable pods
```

### How It Works

**Example: 3 replicas → 4 replicas → 3 replicas (new version)**

```
Time 0:   [Pod-Old-1] [Pod-Old-2] [Pod-Old-3]
Time 1:   [Pod-Old-1] [Pod-Old-2] [Pod-Old-3] [Pod-New-1] ← maxSurge=1
Time 2:   [Pod-Old-1] [Pod-Old-2] [Pod-New-1] [Pod-New-2]
Time 3:   [Pod-Old-1] [Pod-New-1] [Pod-New-2] [Pod-New-3]
Time 4:   [Pod-New-1] [Pod-New-2] [Pod-New-3] ✅ Complete
```

### Benefits
- ✅ **Zero Downtime**: Always have minimum replicas available
- ✅ **Automatic Rollback**: Old ReplicaSet kept for quick rollback
- ✅ **Health Checks**: Validates new pods before removing old ones
- ✅ **Gradual Rollout**: Issues detected early with fewer users affected

### Deployment Command
```bash
kubectl apply -f kubernetes/deployment.yaml
kubectl rollout status deployment/voting-app -n voting-system
```

---

## Blue-Green Deployment

### What is Blue-Green Deployment?
Two identical production environments: "Blue" (current) and "Green" (new). Switch traffic between them after validation.

### Advantages Over Rolling Update
- ✅ Instant traffic switch (no gradual transition)
- ✅ Easy rollback (switch traffic back to Blue)
- ✅ Full environment validation before traffic switch
- ✅ Better for stateful applications

### Implementation Strategy

#### 1. Blue Deployment (Current Production)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: voting-app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: voting-app
      version: blue
  template:
    metadata:
      labels:
        app: voting-app
        version: blue
    spec:
      containers:
      - name: voting-app
        image: ghcr.io/.../voting:v1.0.0
```

#### 2. Green Deployment (New Version)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: voting-app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: voting-app
      version: green
  template:
    metadata:
      labels:
        app: voting-app
        version: green
    spec:
      containers:
      - name: voting-app
        image: ghcr.io/.../voting:v1.1.0
```

#### 3. Service Routes to Blue (Initially)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: voting-app-service
spec:
  selector:
    app: voting-app
    version: blue  # ← Routes to Blue initially
  ports:
  - port: 80
    targetPort: 3000
```

#### 4. Switch to Green (After Validation)
```bash
# Deploy Green version
kubectl apply -f kubernetes/deployment-green.yaml

# Wait for Green to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/voting-app-green -n voting-system

# Run smoke tests against Green
./scripts/smoke-tests.sh green

# Switch traffic to Green
kubectl patch service voting-app-service -p \
  '{"spec":{"selector":{"version":"green"}}}'

# Keep Blue running for quick rollback
# Only delete Blue after monitoring shows no issues (e.g., 1 hour)
```

#### 5. Rollback to Blue (If Issues)
```bash
# Instant rollback - switch traffic back
kubectl patch service voting-app-service -p \
  '{"spec":{"selector":{"version":"blue"}}}'

# Delete Green deployment
kubectl delete deployment voting-app-green -n voting-system
```

### Blue-Green vs Rolling Update

| Aspect | Rolling Update | Blue-Green |
|--------|---|---|
| **Downtime** | 0 | 0 |
| **Rollback Speed** | Minutes | Seconds |
| **Resource Usage** | Normal | 2x during transition |
| **Validation** | Per-pod | Full environment |
| **Complexity** | Simple | Moderate |
| **Use Case** | General apps | Critical services |

---

## Resource Requirements

### Current Pod Specification

```yaml
resources:
  requests:
    cpu: 100m          # Guaranteed minimum
    memory: 128Mi      # Guaranteed minimum
  limits:
    cpu: 500m          # Hard cap
    memory: 512Mi      # Hard cap
```

### Resource Calculation

#### 1. CPU Requirements

**Baseline Measurement** (from benchmark tests):
- **Idle**: 20-30m
- **Normal Load**: 80-120m
- **Peak Load**: 300-450m

**Formula**:
```
Request = (Normal Load + 50% buffer)
Limit = Peak Load × 1.2
```

**Calculation**:
- Request: 100m (80m base + 20m buffer)
- Limit: 500m (400m peak + 100m headroom)

#### 2. Memory Requirements

**Baseline Measurement**:
- **Idle**: 60-80Mi
- **Normal Load**: 100-150Mi
- **Peak Load**: 400-500Mi

**Formula**:
```
Request = (Normal Load + 30% buffer)
Limit = Peak Load × 1.1
```

**Calculation**:
- Request: 128Mi (100m base + 28Mi buffer)
- Limit: 512Mi (450Mi peak + 62Mi headroom)

#### 3. Per-Replica Resources

| Metric | Request | Limit | Notes |
|--------|---------|-------|-------|
| **CPU** | 100m | 500m | 1 core = 1000m |
| **Memory** | 128Mi | 512Mi | Lightweight Node.js app |
| **Disk** | 10Mi | 100Mi | Logs + temp files |

#### 4. Cluster Resource Calculation

**For 3-10 replicas (3 min, 10 max)**:

```
Minimum Cluster (3 replicas):
- Total CPU Request: 3 × 100m = 300m (0.3 cores)
- Total Memory Request: 3 × 128Mi = 384Mi
- Node Size: 2 cores, 2Gi RAM (1 node sufficient)

Maximum Cluster (10 replicas):
- Total CPU Request: 10 × 100m = 1000m (1 core)
- Total Memory Request: 10 × 128Mi = 1280Mi
- Node Size: 4 cores, 4Gi RAM (2-3 nodes recommended)
```

### Node Size Recommendations

| Cluster Size | Node Type | CPU | Memory | Network |
|---|---|---|---|---|
| **Development** | Single | 2-4 cores | 4-8Gi | 100Mbps |
| **Staging** | Medium | 4-8 cores | 8-16Gi | 1Gbps |
| **Production** | Large | 8-16 cores | 32-64Gi | 10Gbps |

### Resource Quality of Service (QoS)

Your pods are `Burstable` (requests < limits):
```
QoS Class: Burstable
- Guaranteed = Burstable = Best-effort order for eviction
- During node pressure, evicted after Best-effort pods
- Preferred for stateless applications
```

---

## Deployment Procedures

### Prerequisites
```bash
# 1. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# 2. Configure kubeconfig
export KUBECONFIG=~/.kube/config
# Or for managed services: aws eks update-kubeconfig, gcloud container clusters get-credentials

# 3. Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### Deployment Steps

#### Step 1: Create Namespace
```bash
kubectl create namespace voting-system --dry-run=client -o yaml | kubectl apply -f -
```

#### Step 2: Deploy Application (Rolling Update)
```bash
# Apply deployment configuration
kubectl apply -f kubernetes/deployment.yaml

# Wait for rollout to complete
kubectl rollout status deployment/voting-app -n voting-system --timeout=5m

# Verify pods are running
kubectl get pods -n voting-system -l app=voting-app
```

#### Step 3: Deploy Blue-Green (Alternative)
```bash
# Deploy Blue (current production)
kubectl apply -f kubernetes/deployment-blue.yaml

# Deploy Green (new version)
kubectl apply -f kubernetes/deployment-green.yaml

# Wait for Green to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/voting-app-green -n voting-system

# Verify both are running
kubectl get pods -n voting-system \
  -l app=voting-app

# Test Green internally
kubectl port-forward -n voting-system \
  svc/voting-app-green 8080:80 &
curl http://localhost:8080/health

# Switch traffic
kubectl patch service voting-app-service -n voting-system \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Monitor for 1 hour, then delete Blue
sleep 3600
kubectl delete deployment voting-app-blue -n voting-system
```

#### Step 4: Apply HPA
```bash
kubectl apply -f kubernetes/hpa.yaml

# Verify HPA
kubectl get hpa -n voting-system
kubectl describe hpa voting-app-hpa -n voting-system
```

#### Step 5: Monitor Deployment
```bash
# Watch pod status
kubectl get pods -n voting-system -w

# View deployment events
kubectl describe deployment voting-app -n voting-system

# Check pod logs
kubectl logs -n voting-system -l app=voting-app --tail=50 -f
```

### Rollout Operations

#### View Deployment History
```bash
kubectl rollout history deployment/voting-app -n voting-system
kubectl rollout history deployment/voting-app -n voting-system \
  --revision=2
```

#### Rollback to Previous Version
```bash
# Quick rollback
kubectl rollout undo deployment/voting-app -n voting-system

# Rollback to specific revision
kubectl rollout undo deployment/voting-app -n voting-system --to-revision=2
```

#### Pause/Resume Rollout
```bash
# Pause a rolling update
kubectl rollout pause deployment/voting-app -n voting-system

# Resume the rollout
kubectl rollout resume deployment/voting-app -n voting-system
```

---

## Monitoring & Health Checks

### Liveness Probe
- **Purpose**: Restart unhealthy containers
- **Endpoint**: `GET /health`
- **Check Interval**: Every 10s
- **Failure Threshold**: 3 consecutive failures
- **Action**: Kill and restart pod

### Readiness Probe
- **Purpose**: Remove unavailable pods from service
- **Endpoint**: `GET /health`
- **Check Interval**: Every 5s
- **Failure Threshold**: 2 consecutive failures
- **Action**: Remove from load balancer

### Health Check Response
```javascript
// GET /health
{
  "status": "ok",
  "uptime": 3600,
  "timestamp": "2025-12-09T10:00:00Z"
}
```

### Monitoring Metrics

#### Application Metrics (Prometheus)
```
voting_app_requests_total{method="POST"}
voting_app_request_duration_seconds{endpoint="/votes"}
voting_app_errors_total
voting_app_memory_bytes
voting_app_cpu_percent
```

#### Kubernetes Metrics
```bash
# View resource usage
kubectl top pods -n voting-system
kubectl top nodes

# Check HPA status
kubectl get hpa -n voting-system -w
```

### Alerts & Thresholds

| Alert | Threshold | Action |
|-------|-----------|--------|
| **Pod CrashLoop** | 5+ restarts/hour | Review logs, update image |
| **High Memory** | > 450Mi | Scale up or optimize code |
| **High CPU** | > 400m | Scale up or optimize queries |
| **Deployment Failed** | Rollout stuck > 10m | Rollback to previous version |
| **Low Availability** | < 3 healthy pods | Investigate node issues |

---

## Troubleshooting

### Pod won't start
```bash
kubectl describe pod <pod-name> -n voting-system
kubectl logs <pod-name> -n voting-system --previous
```

### High resource usage
```bash
# Find resource-hungry pods
kubectl top pods -n voting-system --sort-by=memory
kubectl top pods -n voting-system --sort-by=cpu
```

### Deployment stuck
```bash
# Check rollout status
kubectl rollout status deployment/voting-app -n voting-system

# View events
kubectl get events -n voting-system --sort-by='.lastTimestamp'

# Rollback if necessary
kubectl rollout undo deployment/voting-app -n voting-system
```

### Service not accessible
```bash
# Check service
kubectl get svc -n voting-system
kubectl describe svc voting-app -n voting-system

# Check endpoints
kubectl get endpoints -n voting-system
```

---

## Next Steps

1. ✅ Deploy to Kubernetes cluster
2. ✅ Configure monitoring (Prometheus + Grafana)
3. ✅ Set up log aggregation
4. ✅ Implement backup strategy for persistent data
5. ✅ Create runbooks for common issues
6. ✅ Document disaster recovery procedures

## References

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Rolling Updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Blue-Green Deployment Pattern](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Health Checks](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
