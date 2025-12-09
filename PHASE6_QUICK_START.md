# Phase 6: Deployment Quick Start Guide

## 🚀 Quick Overview

You now have everything needed for production deployments:

```
┌─────────────────────────────────────────────────────────────────┐
│                    VOTING SYSTEM DEPLOYMENT                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. CI/CD Pipeline (GitHub Actions)                            │
│     ├─ Code Quality & Security Checks                          │
│     ├─ Unit & Integration Tests                                │
│     ├─ Build & Push to GHCR + Docker Hub                       │
│     └─ Notify Slack on every stage                             │
│                                                                 │
│  2. Kubernetes Deployment (This Phase)                         │
│     ├─ Rolling Update (gradual, automatic rollback)            │
│     ├─ Blue-Green (instant switch, manual rollback)            │
│     ├─ Auto-scaling (3-10 replicas based on load)              │
│     └─ Health checks & monitoring                              │
│                                                                 │
│  3. Resource Management                                        │
│     ├─ CPU: 100m request / 500m limit per pod                 │
│     ├─ Memory: 128Mi request / 512Mi limit per pod            │
│     ├─ Calculated for 1000-2000 RPS peak capacity            │
│     └─ Infrastructure cost: ~$250-360/month                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Choose Your Deployment Strategy

### Strategy 1: Rolling Update (Recommended for most cases)

```
Time 0:  [Old] [Old] [Old]
Time 1:  [Old] [Old] [Old] [New]        ← maxSurge=1
Time 2:  [Old] [Old] [New] [New]
Time 3:  [Old] [New] [New] [New]
Time 4:  [New] [New] [New]               ✅ Complete

Duration: ~4-5 minutes
Complexity: Low
Best for: Regular updates, low-risk changes
```

**How to use:**
```bash
# 1. Update image in deployment
kubectl set image deployment/voting-app voting-app=<new-image> \
  -n voting-system --record

# 2. Monitor progress
kubectl rollout status deployment/voting-app -n voting-system

# 3. If issues arise - rollback in 10 seconds
kubectl rollout undo deployment/voting-app -n voting-system
```

---

### Strategy 2: Blue-Green (For critical updates)

```
Before:
  Blue (Production):   [Pod] [Pod] [Pod]  ← Traffic here
  Green (Staging):     Idle

After Deploy Green:
  Blue (Production):   [Pod] [Pod] [Pod]  ← Traffic still here
  Green (New):         [Pod] [Pod] [Pod]  ← Ready for testing

After Switch:
  Blue (Old):          [Pod] [Pod] [Pod]  ← Idle (quick rollback)
  Green (Production):  [Pod] [Pod] [Pod]  ← Traffic now here

After Cleanup (1 hour later):
  Green (Production):  [Pod] [Pod] [Pod]  ← Only this runs
```

**How to use:**
```bash
# 1. Deploy and test Green
./scripts/blue-green-deploy.sh deploy-green ghcr.io/.../voting:v1.1.0
./scripts/blue-green-deploy.sh test-green

# 2. Switch traffic
./scripts/blue-green-deploy.sh switch-to-green

# 3. Monitor for 1 hour...

# 4. Cleanup old Blue
./scripts/blue-green-deploy.sh cleanup-green

# Emergency rollback (any time):
./scripts/blue-green-deploy.sh switch-to-blue
```

---

## 🔧 Step-by-Step Deployment

### Prerequisites
```bash
# 1. Verify cluster
kubectl cluster-info
kubectl get nodes                          # Should show 3+ nodes with 2+ cores

# 2. Verify image
docker push ghcr.io/<user>/voting:latest  # Already done by CI/CD
docker push docker.io/<user>/voting:latest # Already done by CI/CD

# 3. Verify application
npm test                                   # Should show 9/9 passing
curl http://localhost:3000/health         # Should return OK
```

### Deployment (Rolling Update)
```bash
# Step 1: Apply deployment
kubectl apply -f kubernetes/deployment.yaml

# Step 2: Monitor (open new terminal)
watch kubectl get pods -n voting-system

# Step 3: Wait for completion
kubectl rollout status deployment/voting-app -n voting-system

# Step 4: Verify
kubectl get pods -n voting-system                      # All 3 should be Running
kubectl get svc voting-app -n voting-system            # Should have EXTERNAL-IP
curl http://<EXTERNAL-IP>/health                       # Should return OK
```

### Deployment (Blue-Green)
```bash
# Step 1: Deploy Green with blue-green manifest
kubectl apply -f kubernetes/deployment-blue-green.yaml

# Step 2: Check status
./scripts/blue-green-deploy.sh status

# Step 3: Deploy new image to Green
./scripts/blue-green-deploy.sh deploy-green ghcr.io/.../voting:v1.1.0

# Step 4: Test Green
./scripts/blue-green-deploy.sh test-green

# Step 5: Switch to Green
./scripts/blue-green-deploy.sh switch-to-green

# Step 6: Monitor for 1 hour (watch logs, metrics, errors)
./scripts/blue-green-deploy.sh monitor

# Step 7: Delete old Blue
./scripts/blue-green-deploy.sh cleanup-green
```

---

## 📊 Resource Calculator

### See what you need
```bash
./scripts/calculate-resources.sh full

# Output shows:
# - CPU requirements per pod: 100m request / 500m limit
# - Memory per pod: 128Mi request / 512Mi limit
# - Cluster totals for 3-10 replicas
# - Recommended node sizes
# - Cost estimation
```

### Quick reference
```
Per Pod:
  CPU Request:    100m (minimum guaranteed)
  CPU Limit:      500m (maximum allowed)
  Memory Request: 128Mi
  Memory Limit:   512Mi

Cluster (3-10 replicas):
  Min CPU: 300m (0.3 cores) @ 3 pods
  Max CPU: 1000m (1.0 core) @ 10 pods
  Min RAM: 384Mi @ 3 pods
  Max RAM: 1280Mi @ 10 pods
```

---

## ✅ Deployment Checklist

Before deploying, follow the comprehensive checklist:

```bash
# See PHASE6_DEPLOYMENT_CHECKLIST.md
# Covers:
# ✓ Pre-deployment infrastructure checks
# ✓ Kubernetes resources validation
# ✓ Application readiness verification
# ✓ Step-by-step deployment execution
# ✓ Post-deployment testing
# ✓ Troubleshooting procedures
# ✓ Rollback procedures
```

---

## 🩹 Quick Troubleshooting

### Pod won't start?
```bash
# See what's wrong
kubectl describe pod <pod-name> -n voting-system
kubectl logs <pod-name> -n voting-system

# Common issues:
# - Image pull failed: Check image exists and is public/accessible
# - CrashLoopBackOff: Check application logs for startup errors
# - Pending: Check node resources are available
```

### Service not accessible?
```bash
# Check service
kubectl get svc voting-app -n voting-system            # Should have EXTERNAL-IP
kubectl get endpoints voting-app -n voting-system      # Should have IPs

# If no EXTERNAL-IP after 2 minutes:
# - Using LoadBalancer on cloud (AWS/GCP/Azure) - may take 5-10 min
# - Using on-premise/local K8s - need to configure LoadBalancer
# - Workaround: kubectl port-forward svc/voting-app 8080:80
```

### High resource usage?
```bash
# Check what's using resources
kubectl top pods -n voting-system --sort-by=memory
kubectl top pods -n voting-system --sort-by=cpu

# If memory usage high:
# - Check for memory leaks: kubectl logs <pod> | grep -i leak
# - Increase pod memory limit in deployment
# - Restart pod: kubectl delete pod <pod-name> -n voting-system

# If CPU usage high:
# - Check application code for inefficiencies
# - Increase pod CPU limit
# - HPA should scale automatically
```

### Need to rollback?
```bash
# Rolling Update: Fast rollback
kubectl rollout undo deployment/voting-app -n voting-system

# Blue-Green: Instant rollback
./scripts/blue-green-deploy.sh switch-to-blue
```

---

## 📈 Monitoring After Deployment

### First 5 minutes (Pod startup)
```bash
# Watch pods start
kubectl get pods -n voting-system -w

# Should see:
# - Creating (a few seconds)
# - ContainerCreating (few seconds)
# - Running (ready to receive traffic)
```

### First hour (Initial stability)
```bash
# Monitor resource usage
kubectl top pods -n voting-system -w

# Monitor for restarts
kubectl get pods -n voting-system               # Restart count should be 0

# Check logs for errors
kubectl logs -n voting-system -l app=voting-app --all-containers=true
```

### Ongoing (After 1 hour)
```bash
# Check HPA is scaling correctly
kubectl get hpa -n voting-system -w            # Replicas should match load

# Monitor error rate
# Check Prometheus metrics or application dashboard
# Should see < 0.1% error rate

# Monitor response times
# Check application performance metrics
# Should see p95 latency < 200ms

# Check for pod evictions
kubectl get events -n voting-system | grep -i evict
```

---

## 🎯 Success Criteria

Deployment is successful when:

✅ All 3 pods running
```bash
kubectl get pods -n voting-system | grep voting-app | wc -l  # Should show 3
```

✅ Service has external IP
```bash
kubectl get svc voting-app -n voting-system | grep voting-app  # Should have IP
```

✅ Health checks passing
```bash
curl http://<EXTERNAL-IP>/health                # {"status":"ok"}
```

✅ API working
```bash
curl http://<EXTERNAL-IP>/votes                 # Should return votes
```

✅ No pod restarts
```bash
kubectl get pods -n voting-system | grep voting-app         # RESTARTS = 0
```

✅ CPU/Memory usage reasonable
```bash
kubectl top pods -n voting-system | grep voting-app         # < 200m CPU, < 300Mi memory
```

---

## 📚 Documentation

### For detailed information, see:

| Document | Purpose |
|----------|---------|
| `PHASE6_DEPLOYMENT.md` | Complete deployment guide with examples |
| `PHASE6_DEPLOYMENT_CHECKLIST.md` | Step-by-step checklist for safe deployments |
| `PHASE6_SUMMARY.md` | Overview and quick reference |
| `kubernetes/deployment-blue-green.yaml` | Blue-green manifests |
| `scripts/blue-green-deploy.sh` | Automated deployment tool |
| `scripts/calculate-resources.sh` | Resource planning tool |

---

## 🚀 Ready to Deploy?

### 1. Choose your strategy
- Rolling Update (simple, recommended)
- Blue-Green (advanced, instant switch)

### 2. Follow the checklist
Open `PHASE6_DEPLOYMENT_CHECKLIST.md` and work through it step-by-step

### 3. Execute deployment
Use the procedures in this quick start guide

### 4. Monitor & verify
Use the monitoring commands to ensure success

### 5. On issues
Reference troubleshooting section above or see `PHASE6_DEPLOYMENT.md`

---

## Questions?

1. **Resource questions?** → Run `./scripts/calculate-resources.sh`
2. **Deployment help?** → See `PHASE6_DEPLOYMENT.md`
3. **Issues?** → Check `PHASE6_DEPLOYMENT_CHECKLIST.md` troubleshooting section
4. **Blue-green help?** → Run `./scripts/blue-green-deploy.sh help`

---

**You're all set for production deployment! 🎉**

The voting system is ready to be deployed to Kubernetes with zero downtime, automatic rollback, and comprehensive monitoring.
