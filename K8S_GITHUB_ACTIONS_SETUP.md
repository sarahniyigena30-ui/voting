# Kubernetes GitHub Actions Setup Guide

This guide explains how to configure your GitHub repository for automatic Kubernetes deployments.

## Prerequisites

- A Kubernetes cluster (local, EKS, GKE, AKS, or on-premises)
- `kubectl` CLI configured with access to your cluster
- GitHub repository with GitHub Actions enabled

## Step 1: Create kubeconfig for CI/CD

### For Local/Self-Managed Kubernetes

```bash
# Display your current kubeconfig
cat ~/.kube/config

# Or create a service account for CI/CD
kubectl create serviceaccount github-actions -n voting-system
kubectl create clusterrolebinding github-actions-admin --clusterrole=cluster-admin --serviceaccount=voting-system:github-actions

# Get the token
kubectl get secret $(kubectl get secret -n voting-system | grep github-actions-token | awk '{print $1}') -n voting-system -o jsonpath='{.data.token}' | base64 --decode

# Get the certificate
kubectl config view --raw
```

### For AWS EKS

```bash
# Create an IAM user for CI/CD
aws iam create-user --user-name github-actions-voting

# Attach policy
aws iam attach-user-policy --user-name github-actions-voting --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

# Generate access keys
aws iam create-access-key --user-name github-actions-voting

# Create kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

### For Google GKE

```bash
# Create service account
gcloud iam service-accounts create github-actions-voting

# Grant permissions
gcloud projects add-iam-policy-binding <project-id> \
  --member=serviceAccount:github-actions-voting@<project-id>.iam.gserviceaccount.com \
  --role=roles/container.developer

# Get kubeconfig
gcloud container clusters get-credentials <cluster-name> --zone <zone> --project <project-id>
```

### For Azure AKS

```bash
# Get credentials
az aks get-credentials --resource-group <group> --name <cluster-name>

# Create service principal
az ad sp create-for-rbac --role Contributor --scopes /subscriptions/<subscription-id>
```

## Step 2: Encode kubeconfig

```bash
# Encode your kubeconfig in base64
cat ~/.kube/config | base64 | tr -d '\n'

# Copy the output for the next step
```

## Step 3: Add GitHub Secret

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `KUBE_CONFIG`
5. Value: Paste the base64-encoded kubeconfig from Step 2
6. Click **Add secret**

## Step 4: Verify Workflow

The CI/CD workflow will now:

1. **Build** - Create Docker image
2. **Test** - Run unit and integration tests
3. **Push** - Push image to GHCR
4. **Deploy** - Apply Kubernetes manifests

Check workflow status:
- Go to **Actions** tab in your repository
- View workflow runs and logs

## Step 5: Monitor Deployment

```bash
# Watch deployment progress
kubectl rollout status deployment/voting-app -n voting-system

# View pod logs
kubectl logs -f deployment/voting-app -n voting-system

# Check service status
kubectl get svc -n voting-system
```

## Troubleshooting

### Workflow fails with "Connection refused"

**Cause**: `KUBE_CONFIG` secret not set or invalid

**Solution**:
```bash
# Verify kubeconfig
cat ~/.kube/config | base64

# Update GitHub secret with new value
```

### Permission denied error

**Cause**: Service account lacks permissions

**Solution**:
```bash
# Grant cluster-admin role
kubectl create clusterrolebinding github-admin --clusterrole=cluster-admin --serviceaccount=voting-system:github-actions
```

### Image pull errors

**Cause**: GHCR authentication missing in cluster

**Solution**:
```bash
# Create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token> \
  -n voting-system

# Update deployment to use secret
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "ghcr-secret"}]}' -n voting-system
```

## Workflow Events

The pipeline automatically triggers on:
- **Push to main branch** - Full deployment
- **Push to develop branch** - Staging deployment (if configured)
- **Pull requests** - Tests only
- **Manual trigger** - `workflow_dispatch`

## Manual Deployment

If needed, deploy manually:

```bash
# Update image
kubectl set image deployment/voting-app \
  voting-app=ghcr.io/sarahniyigena30-ui/voting/voting-system:latest \
  -n voting-system

# Rollout status
kubectl rollout status deployment/voting-app -n voting-system
```

## Security Best Practices

1. **Use separate service accounts** for different environments
2. **Limit permissions** to only what's needed
3. **Rotate kubeconfig** regularly
4. **Use RBAC** for fine-grained access control
5. **Enable audit logging** for all deployments
6. **Use network policies** to restrict traffic

## Example: Multiple Environments

### Staging Deployment

```bash
# Create staging secret
gh secret set KUBE_CONFIG_STAGING --body "$(cat ~/.kube/config-staging | base64)"

# Update workflow to use staging config on develop branch
```

### Production Deployment

```bash
# Use different service account for production
kubectl create serviceaccount github-actions-prod -n voting-system

# Grant limited permissions for production
kubectl create role voting-app-deployer \
  --verb=get,list,watch,create,update,patch \
  --resource=deployments,services \
  -n voting-system

# Bind role
kubectl create rolebinding github-actions-prod \
  --role=voting-app-deployer \
  --serviceaccount=voting-system:github-actions-prod \
  -n voting-system
```

## Automated Rollback

Add to workflow if deployment fails:

```yaml
- name: Rollback on failure
  if: failure()
  run: |
    kubectl rollout undo deployment/voting-app -n voting-system
    kubectl rollout status deployment/voting-app -n voting-system --timeout=5m
```

## Support

For issues:
1. Check GitHub Actions logs
2. Verify `KUBE_CONFIG` secret is set
3. Test kubectl access locally: `kubectl get pods -n voting-system`
4. Check cluster events: `kubectl get events -n voting-system`
