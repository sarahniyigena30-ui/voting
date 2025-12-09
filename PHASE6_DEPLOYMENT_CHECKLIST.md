# Phase 6 Deployment Checklist

## Pre-Deployment Checks

### [ ] Infrastructure Preparation
- [ ] Kubernetes cluster is running and accessible
- [ ] kubectl is installed and configured
- [ ] Current context points to correct cluster: `kubectl config current-context`
- [ ] Namespace exists or can be created: `kubectl get ns voting-system`
- [ ] Node resources are sufficient for min replicas (3 nodes with 2+ cores, 4+ Gi RAM)

### [ ] Docker Image Preparation
- [ ] Latest image pushed to GHCR: `ghcr.io/sarahniyigena30-ui/voting:latest`
- [ ] Latest image pushed to Docker Hub (optional): `docker.io/<username>/voting-system:latest`
- [ ] Image size acceptable (<500MB): `docker inspect <image> | grep Size`
- [ ] Image passes security scan: `trivy image <image>`

### [ ] Application Readiness
- [ ] All tests passing: `npm test` (9/9 tests)
- [ ] Health endpoint working: `curl http://localhost:3000/health`
- [ ] API endpoints responding: `curl http://localhost:3000/votes`
- [ ] Metrics endpoint working: `curl http://localhost:3000/metrics`
- [ ] No critical bugs in issue tracker

### [ ] Kubernetes Resources
- [ ] Deployment manifest reviewed: `kubernetes/deployment.yaml`
- [ ] Service manifest reviewed: `kubernetes/service.yaml`
- [ ] HPA manifest reviewed: `kubernetes/hpa.yaml`
- [ ] Resource requests/limits appropriate (100m/500m CPU, 128Mi/512Mi memory)
- [ ] Health probe endpoints configured correctly
- [ ] Image pull policy set to Always: `imagePullPolicy: Always`

---

## Deployment Execution (Rolling Update)

### [ ] Stage 1: Pre-Deployment
```bash
# Verify cluster connectivity
kubectl cluster-info

# Check node resources
kubectl top nodes

# View current deployments
kubectl get deployments -n voting-system
```

### [ ] Stage 2: Create Namespace
```bash
kubectl create namespace voting-system --dry-run=client -o yaml | kubectl apply -f -
kubectl get namespace voting-system
```

### [ ] Stage 3: Apply Deployment
```bash
# Apply all configurations at once
kubectl apply -f kubernetes/deployment.yaml

# Or separately
kubectl apply -f kubernetes/deployment.yaml  # Contains namespace, deployment, service
kubectl apply -f kubernetes/hpa.yaml         # Apply HPA
```

### [ ] Stage 4: Monitor Rollout
```bash
# Watch deployment progress (new terminal)
kubectl rollout status deployment/voting-app -n voting-system --timeout=5m

# In another terminal, watch pods
kubectl get pods -n voting-system -l app=voting-app -w

# View events
kubectl get events -n voting-system --sort-by='.lastTimestamp'
```

### [ ] Stage 5: Verify Deployment
- [ ] All 3 pods are running: `kubectl get pods -n voting-system`
- [ ] Pods are ready: `kubectl get pods -n voting-system -o wide`
- [ ] Service has endpoints: `kubectl get endpoints voting-app -n voting-system`
- [ ] HPA is active: `kubectl get hpa -n voting-system`

### [ ] Stage 6: Test Service
```bash
# Get service external IP (may take 1-2 minutes)
kubectl get svc voting-app -n voting-system

# Test health endpoint
curl http://<external-ip>/health

# Test API
curl http://<external-ip>/votes

# Create test vote
curl -X POST http://<external-ip>/votes \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Vote","content":"Testing production"}'
```

### [ ] Stage 7: Monitor Health
- [ ] Pod restart count is 0: `kubectl get pods -n voting-system`
- [ ] No pending pods: `kubectl get pods -n voting-system | grep Pending`
- [ ] All readiness probes passing: `kubectl get pods -n voting-system -o json | grep ready`
- [ ] CPU/Memory usage reasonable: `kubectl top pods -n voting-system`

---

## Deployment Execution (Blue-Green)

### [ ] Setup Blue Deployment
```bash
# Use blue-green manifest (already has Blue setup)
kubectl apply -f kubernetes/deployment-blue-green.yaml

# Verify Blue is running
kubectl get pods -n voting-system -l version=blue

# Get Blue service endpoint
kubectl get svc voting-app-blue -n voting-system
```

### [ ] Deploy Green Version
```bash
# Deploy Green with new image
./scripts/blue-green-deploy.sh deploy-green ghcr.io/sarahniyigena30-ui/voting:v1.1.0

# Verify Green is running
./scripts/blue-green-deploy.sh status
```

### [ ] Test Green Deployment
```bash
# Run smoke tests
./scripts/blue-green-deploy.sh test-green

# Or manually test
kubectl port-forward -n voting-system svc/voting-app-green 8080:3000 &
curl http://localhost:8080/health
curl http://localhost:8080/votes
```

### [ ] Switch Traffic to Green
```bash
# Switch production traffic
./scripts/blue-green-deploy.sh switch-to-green

# Verify traffic switched
./scripts/blue-green-deploy.sh status
```

### [ ] Monitor Green in Production
```bash
# Monitor for at least 1 hour
./scripts/blue-green-deploy.sh monitor

# Watch metrics
kubectl top pods -n voting-system -l version=green -w

# Stream logs
./scripts/blue-green-deploy.sh logs-green
```

### [ ] Cleanup Old Blue (After 1 hour stable)
```bash
# Delete old Blue deployment
./scripts/blue-green-deploy.sh cleanup-green

# Verify Green is now the only production deployment
kubectl get deployments -n voting-system
```

---

## Post-Deployment Validation

### [ ] Functional Testing
- [ ] Create vote: `curl -X POST http://<ip>/votes -d '{"title":"Test"}'`
- [ ] List votes: `curl http://<ip>/votes`
- [ ] Get single vote: `curl http://<ip>/votes/1`
- [ ] Update vote: `curl -X PUT http://<ip>/votes/1 -d '{"title":"Updated"}'`
- [ ] Delete vote: `curl -X DELETE http://<ip>/votes/1`

### [ ] Performance Testing
```bash
# Simple load test
ab -n 1000 -c 10 http://<ip>/votes

# Or use Apache JMeter / k6
k6 run load-test.js
```

### [ ] Security Validation
- [ ] Pod security policy applied: `kubectl get pods -n voting-system -o json | grep securityContext`
- [ ] Network policies (if applicable): `kubectl get networkpolicies -n voting-system`
- [ ] Image scanning complete: `trivy image ghcr.io/.../voting`
- [ ] No hardcoded secrets in container: `docker inspect <image> | grep ENV`

### [ ] Monitoring & Alerts
- [ ] Prometheus scraping metrics: `kubectl logs -n prometheus prometheus-0`
- [ ] Grafana dashboards loading: `kubectl port-forward -n monitoring svc/grafana 3000:3000`
- [ ] Alert rules configured: `kubectl get prometheusrule -n voting-system`
- [ ] Slack notifications enabled: Check GitHub Actions workflow secrets

### [ ] Documentation
- [ ] Deployment documented in PHASE6_DEPLOYMENT.md
- [ ] Runbook created for common issues
- [ ] Team trained on rollback procedures
- [ ] Incident response plan reviewed

---

## Troubleshooting Checklist

### Pod Won't Start
```bash
# Check pod status
kubectl describe pod <pod-name> -n voting-system

# View logs
kubectl logs <pod-name> -n voting-system

# Check image pull
kubectl get events -n voting-system | grep ImagePull
```

### Service Not Accessible
```bash
# Check service
kubectl get svc voting-app -n voting-system

# Check endpoints
kubectl get endpoints voting-app -n voting-system

# Check network policies
kubectl get networkpolicies -n voting-system
```

### High Resource Usage
```bash
# Check resource usage
kubectl top pods -n voting-system --sort-by=memory
kubectl top pods -n voting-system --sort-by=cpu

# Check pod limits
kubectl describe deployment voting-app -n voting-system | grep -A 5 "Limits"
```

### Deployment Stuck
```bash
# Check rollout status
kubectl rollout status deployment/voting-app -n voting-system

# View events
kubectl get events -n voting-system --sort-by='.lastTimestamp'

# Rollback if needed
kubectl rollout undo deployment/voting-app -n voting-system
```

---

## Rollback Procedure

### Rolling Update Rollback
```bash
# View history
kubectl rollout history deployment/voting-app -n voting-system

# Rollback to previous
kubectl rollout undo deployment/voting-app -n voting-system

# Rollback to specific revision
kubectl rollout undo deployment/voting-app -n voting-system --to-revision=2

# Verify rollback
kubectl rollout status deployment/voting-app -n voting-system
```

### Blue-Green Rollback (Instant)
```bash
# Switch traffic back to Blue
./scripts/blue-green-deploy.sh switch-to-blue

# Verify
./scripts/blue-green-deploy.sh status

# Delete failed Green
kubectl delete deployment voting-app-green -n voting-system
```

---

## Deployment Completion Sign-Off

- [ ] All deployment steps completed successfully
- [ ] All validation tests passed
- [ ] Performance metrics acceptable
- [ ] No critical errors in logs
- [ ] Monitoring and alerts working
- [ ] Team notified of deployment
- [ ] Documentation updated
- [ ] Deployment logged in change management

**Deployed By:** ___________________  
**Date:** ___________________  
**Version:** ___________________  
**Approved By:** ___________________

---

## Monitoring Schedule (First 24 Hours)

| Time | Action |
|------|--------|
| 0:00 | Deployment complete, begin monitoring |
| 0:15 | Check pod metrics (CPU/Memory) |
| 0:30 | Verify no pod restarts |
| 1:00 | Load test and performance check |
| 2:00 | Review error logs |
| 4:00 | Check for memory leaks |
| 8:00 | Verify HPA scaling works |
| 12:00 | Mid-day health check |
| 24:00 | Final validation, mark stable |

---

## Resources

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Rolling Updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Blue-Green Deployments](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Troubleshooting Deployments](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-application/)
