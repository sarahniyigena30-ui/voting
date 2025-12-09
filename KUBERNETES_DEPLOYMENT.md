# Kubernetes Deployment Guide

This guide explains how to deploy the Voting System to Kubernetes.

## Prerequisites

- Kubernetes cluster (1.20+)
- `kubectl` CLI configured with cluster access
- Docker images pushed to a container registry (GHCR, Docker Hub, etc.)

## Quick Start

### 1. Create Namespace

```bash
kubectl create namespace voting-system
```

### 2. Deploy Application

```bash
kubectl apply -f kubernetes/deployment.yaml -n voting-system
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods -n voting-system

# Check services
kubectl get svc -n voting-system

# View logs
kubectl logs -f deployment/voting-app -n voting-system
```

### 4. Access Application

```bash
# Port forward to localhost
kubectl port-forward -n voting-system svc/voting-app 3000:3000

# Access at http://localhost:3000
```

## Kubernetes Manifests

### Deployment (`kubernetes/deployment.yaml`)

Defines:
- **Pod specifications** with resource limits
- **Liveness probe** for health checks
- **Readiness probe** for traffic routing
- **Environment variables** for configuration
- **Volume mounts** for persistent data

### Service (`kubernetes/service.yaml`)

Provides:
- **LoadBalancer** service type for external access
- **Port mapping** (3000:3000)
- **Selector** to route traffic to voting-app pods

### HPA (`kubernetes/hpa.yaml`)

Enables:
- **Auto-scaling** based on CPU usage
- **Min/max replicas** configuration
- **Target CPU utilization** (70%)

## Configuration

### Environment Variables

Edit `kubernetes/deployment.yaml` to configure:

```yaml
env:
  - name: PORT
    value: "3000"
  - name: NODE_ENV
    value: "production"
```

### Resource Limits

Configure CPU and memory limits:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## GitHub Actions Integration

To enable automatic Kubernetes deployment from GitHub Actions:

### 1. Create kubeconfig

```bash
# On your local machine with kubectl configured
cat ~/.kube/config | base64 | tr -d '\n'
```

### 2. Add GitHub Secret

1. Go to Repository Settings → Secrets and Variables → Actions
2. Create new secret: `KUBE_CONFIG`
3. Paste the base64-encoded kubeconfig

### 3. Workflow Trigger

The CI/CD workflow will automatically:
- Build Docker image
- Run tests
- Push to GHCR
- Deploy to Kubernetes (if KUBE_CONFIG is set)

## Scaling

### Manual Scaling

```bash
# Scale to 5 replicas
kubectl scale deployment voting-app --replicas=5 -n voting-system
```

### Auto-scaling

```bash
# Apply HPA configuration
kubectl apply -f kubernetes/hpa.yaml -n voting-system

# Check HPA status
kubectl get hpa -n voting-system
```

## Monitoring

### View Pod Status

```bash
kubectl get pods -n voting-system -o wide
kubectl describe pod <pod-name> -n voting-system
```

### View Logs

```bash
# Current logs
kubectl logs deployment/voting-app -n voting-system

# Follow logs
kubectl logs -f deployment/voting-app -n voting-system

# Last 100 lines
kubectl logs --tail=100 deployment/voting-app -n voting-system
```

### Check Health

```bash
# Check readiness
kubectl get pods -n voting-system -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")]}'

# Test endpoint
kubectl exec -it <pod-name> -n voting-system -- curl http://localhost:3000/health
```

## Troubleshooting

### Pod Won't Start

```bash
# Check events
kubectl describe pod <pod-name> -n voting-system

# Check logs
kubectl logs <pod-name> -n voting-system
```

### Cannot Pull Image

```bash
# Check image pull secrets
kubectl get secrets -n voting-system

# Verify image exists in registry
docker pull <image-url>
```

### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints -n voting-system

# Test from pod
kubectl exec -it <pod-name> -n voting-system -- curl http://localhost:3000
```

## Production Checklist

- [ ] Resource requests/limits configured
- [ ] Probes (liveness/readiness) configured
- [ ] PVC for persistent storage (if needed)
- [ ] Network policies configured
- [ ] RBAC roles/bindings set up
- [ ] Monitoring and logging configured
- [ ] Auto-scaling policies configured
- [ ] Backup strategy in place

## Cleanup

```bash
# Delete everything in namespace
kubectl delete namespace voting-system

# Or delete specific resources
kubectl delete deployment voting-app -n voting-system
kubectl delete service voting-app -n voting-system
```

## Advanced Configuration

### Using ConfigMaps

```bash
kubectl create configmap voting-config --from-literal=PORT=3000 -n voting-system
```

### Using Secrets

```bash
kubectl create secret generic voting-secrets --from-literal=api-key=secret123 -n voting-system
```

### HTTPS/TLS

```bash
# Create ingress with TLS
kubectl apply -f kubernetes/ingress.yaml -n voting-system
```

## Support

For issues:
1. Check logs: `kubectl logs deployment/voting-app -n voting-system`
2. Describe resources: `kubectl describe deployment voting-app -n voting-system`
3. Check events: `kubectl get events -n voting-system`
