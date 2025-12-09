# Phase 5: Release & Deployment - Command Reference

## Quick Commands

### Local Development

```bash
# Start application locally
npm start

# Run tests
npm test

# Build Docker image locally
docker build -t voting-system:local .

# Run Docker container
docker run -p 3000:3000 voting-system:local

# Docker compose for full stack
docker-compose up -d
docker-compose logs -f
docker-compose down
```

### Git & Versioning

```bash
# Create a release tag
git tag -a v1.0.0 -m "Release v1.0.0: Production release"

# Push tag to trigger release workflow
git push origin v1.0.0

# List all tags
git tag -l

# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push --delete origin v1.0.0

# Automatically bump patch version
npm version patch
git push origin main --follow-tags
```

### GitHub Actions

```bash
# View workflow runs
gh run list --workflow=ci-cd.yml

# View specific run details
gh run view <run-id>

# View run logs
gh run view <run-id> --log

# Cancel a running workflow
gh run cancel <run-id>

# Manually trigger workflow
gh workflow run ci-cd.yml

# Check workflow status
gh run list --status failed
```

### Kubernetes - Setup

```bash
# Create namespace
kubectl create namespace voting-system

# Apply all K8s manifests
kubectl apply -f kubernetes/deployment.yaml

# Verify deployment
kubectl get all -n voting-system

# View service endpoint
kubectl get svc -n voting-system -o wide
```

### Kubernetes - Operations

```bash
# Check pod status
kubectl get pods -n voting-system
kubectl get pods -n voting-system -o wide

# View pod logs
kubectl logs deployment/voting-app -n voting-system
kubectl logs -f deployment/voting-app -n voting-system --tail=100

# Describe pod for details
kubectl describe pod <pod-name> -n voting-system

# Execute command in pod
kubectl exec -it <pod-name> -n voting-system -- /bin/sh
kubectl exec <pod-name> -n voting-system -- curl http://localhost:3000/health

# Port forward to local
kubectl port-forward svc/voting-app 3000:80 -n voting-system

# Access via port-forward
# Then visit: http://localhost:3000
```

### Kubernetes - Scaling

```bash
# Manual scaling
kubectl scale deployment voting-app --replicas=5 -n voting-system

# View HPA status
kubectl get hpa -n voting-system
kubectl watch hpa voting-app-hpa -n voting-system

# View autoscaling events
kubectl get events -n voting-system --sort-by='.lastTimestamp'
```

### Kubernetes - Updates

```bash
# Update image
kubectl set image deployment/voting-app voting-app=ghcr.io/sarahniyigena30-ui/voting/voting-system:v1.0.0 -n voting-system

# Check rollout status
kubectl rollout status deployment/voting-app -n voting-system

# View rollout history
kubectl rollout history deployment/voting-app -n voting-system

# Rollback to previous version
kubectl rollout undo deployment/voting-app -n voting-system

# Rollback to specific revision
kubectl rollout undo deployment/voting-app --to-revision=2 -n voting-system
```

### Kubernetes - Debugging

```bash
# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes
kubectl describe node <node-name>

# Get namespace resources
kubectl api-resources -n voting-system

# Check events
kubectl get events -n voting-system

# Debug pod
kubectl debug pod/<pod-name> -n voting-system

# Copy file from pod
kubectl cp voting-system/<pod-name>:/app/votes.json ./votes-backup.json

# Check resource usage
kubectl top nodes
kubectl top pods -n voting-system
```

### Docker Registry

```bash
# View image details
docker inspect ghcr.io/sarahniyigena30-ui/voting/voting-system:latest

# List local images
docker images | grep voting

# Remove image
docker rmi voting-system:local

# Push to registry manually
docker tag voting-system:local ghcr.io/sarahniyigena30-ui/voting/voting-system:manual
docker push ghcr.io/sarahniyigena30-ui/voting/voting-system:manual

# Pull latest image
docker pull ghcr.io/sarahniyigena30-ui/voting/voting-system:latest
```

### GitHub Secrets Management

```bash
# List all secrets
gh secret list

# Set a secret
gh secret set KUBE_CONFIG < /path/to/kubeconfig

# Remove a secret
gh secret delete KUBE_CONFIG

# Check if secret exists (in script)
if gh secret list | grep -q "KUBE_CONFIG"; then
  echo "Secret exists"
fi
```

### Monitoring & Logs

```bash
# Stream application logs
kubectl logs -f deployment/voting-app -n voting-system

# Check health endpoint
kubectl port-forward svc/voting-app 3000:80 -n voting-system &
curl http://localhost:3000/health

# Get metrics
curl http://localhost:3000/metrics

# All endpoints
curl http://localhost:3000/
```

### Release Process

```bash
# Step 1: Ensure code is ready
git status

# Step 2: Create and push version tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Step 3: Monitor workflow
gh run list --workflow=ci-cd.yml

# Step 4: Verify deployment
kubectl get pods -n voting-system
kubectl logs -f deployment/voting-app -n voting-system

# Step 5: Test endpoint
curl http://localhost:3000/
```

### Cleanup

```bash
# Remove local Docker images
docker system prune -a

# Delete entire K8s namespace
kubectl delete namespace voting-system

# Clear GitHub Actions cache
gh cache delete -a

# Remove local git tags
git tag -l | xargs git tag -d
```

## Common Workflows

### Deploy a Hotfix

```bash
# Fix code
# Commit
git add .
git commit -m "fix: critical issue"

# Push to main (triggers workflow)
git push origin main

# Monitor deployment
gh run list --workflow=ci-cd.yml | head -5
```

### Rollback Deployment

```bash
# Via Kubernetes
kubectl rollout undo deployment/voting-app -n voting-system
kubectl rollout status deployment/voting-app -n voting-system

# Or redeploy previous version
git tag -l | sort -V | tail -2  # Show last 2 versions
git checkout v0.9.0              # Checkout previous
git push origin main --force     # Force push (careful!)
```

### Scale for High Traffic

```bash
# Manual immediate scaling
kubectl scale deployment voting-app --replicas=10 -n voting-system

# Or adjust HPA limits
kubectl patch hpa voting-app-hpa --patch '{"spec":{"maxReplicas":20}}' -n voting-system
```

### Emergency Access

```bash
# SSH into pod
kubectl exec -it <pod-name> -n voting-system -- /bin/sh

# Check pod files
kubectl exec <pod-name> -n voting-system -- ls -la /app

# Check votes.json data
kubectl exec <pod-name> -n voting-system -- cat /app/votes.json

# Backup votes data
kubectl exec <pod-name> -n voting-system -- cat /app/votes.json > votes-backup.json
```

## Environment Validation

```bash
# Check kubectl installation
kubectl version

# Verify cluster access
kubectl cluster-info

# Check namespace exists
kubectl get namespace voting-system

# Verify deployment exists
kubectl get deployment -n voting-system

# Test API access
kubectl port-forward svc/voting-app 3000:80 -n voting-system &
curl http://localhost:3000/votes
kill %1
```

## Performance Tuning

```bash
# Check resource usage
kubectl top pods -n voting-system
kubectl top nodes

# View requests vs limits
kubectl get pods -n voting-system -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[].resources.requests.cpu,CPU_LIM:.spec.containers[].resources.limits.cpu

# Adjust resource limits
kubectl set resources deployment voting-app -c voting-app --limits=cpu=1,memory=1Gi -n voting-system
```

## Integration Examples

### With CI/CD
```bash
# Export current state
kubectl get deployment voting-app -n voting-system -o yaml > deployment-backup.yaml

# Import state
kubectl apply -f deployment-backup.yaml
```

### With Monitoring
```bash
# Check if metrics are exposed
kubectl port-forward svc/voting-app 3000:80 -n voting-system &
curl http://localhost:3000/metrics
kill %1
```

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias k=kubectl
alias kvs='kubectl get pods -n voting-system'
alias klogs='kubectl logs -f deployment/voting-app -n voting-system'
alias kexec='kubectl exec -it'
alias kdesc='kubectl describe pod'
alias kdel='kubectl delete'
```

Then use:
```bash
k get pods -n voting-system
kvs
klogs
kexec <pod-name> -n voting-system -- /bin/sh
```

## Verification Checklist

```bash
# Before deployment
[ ] Code tested locally: npm test
[ ] Docker builds: docker build -t test .
[ ] Git committed: git status (clean)
[ ] Tags created: git tag -a v1.0.0
[ ] Tests passing: gh run view <run-id> --log

# After deployment
[ ] Pods running: kubectl get pods -n voting-system
[ ] Service accessible: curl http://localhost:3000/health
[ ] Logs clean: kubectl logs deployment/voting-app -n voting-system
[ ] No errors: kubectl get events -n voting-system
```

## Emergency Contacts

```
GitHub Actions Help: https://docs.github.com/en/actions
Kubernetes Docs: https://kubernetes.io/docs/
Docker Docs: https://docs.docker.com/
GHCR Help: https://docs.github.com/en/packages/container-registry
```
