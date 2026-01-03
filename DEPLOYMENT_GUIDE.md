# AKS Terraform Deployment Guide

## 📚 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [Deployment Steps](#deployment-steps)
5. [Post-Deployment](#post-deployment)
6. [Common Operations](#common-operations)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
Install the following tools before starting:

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform (version 1.6.0+)
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installations
az --version
terraform version
kubectl version --client
```

### Azure Account Setup

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify subscription
az account show
```

### Service Principal (for CI/CD)

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "terraform-aks-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Save the output - you'll need these values:
# - appId (AZURE_CLIENT_ID)
# - password (AZURE_CLIENT_SECRET)
# - tenant (AZURE_TENANT_ID)
```

---

## Initial Setup

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd aks-terraform
```

### 2. Configure Backend (Production)

Create storage account for Terraform state:

```bash
# Variables
RESOURCE_GROUP_NAME="terraform-state-rg"
STORAGE_ACCOUNT_NAME="tfstateaks$(openssl rand -hex 4)"
CONTAINER_NAME="tfstate"
LOCATION="eastus"

# Create resource group
az group create \
  --name $RESOURCE_GROUP_NAME \
  --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --query '[0].value' -o tsv)

echo "Storage Account Name: $STORAGE_ACCOUNT_NAME"
echo "Storage Account Key: $ACCOUNT_KEY"
```

Update `main.tf` backend configuration:

```hcl
backend "azurerm" {
  resource_group_name  = "terraform-state-rg"
  storage_account_name = "YOUR_STORAGE_ACCOUNT_NAME"
  container_name       = "tfstate"
  key                  = "aks/terraform.tfstate"
}
```

### 3. Create Azure AD Admin Group

```bash
# Create admin group
az ad group create \
  --display-name "AKS-Cluster-Admins" \
  --mail-nickname "aks-admins"

# Get Object ID
ADMIN_GROUP_ID=$(az ad group show \
  --group "AKS-Cluster-Admins" \
  --query id -o tsv)

echo "Admin Group Object ID: $ADMIN_GROUP_ID"

# Add yourself to the group
USER_ID=$(az ad signed-in-user show --query id -o tsv)
az ad group member add \
  --group "AKS-Cluster-Admins" \
  --member-id $USER_ID
```

---

## Configuration

### 1. Configure Variables

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Minimum Required Configuration:**

```hcl
project_name = "myproject"
environment  = "dev"
location     = "eastus"

# Add your admin group object ID
admin_group_object_ids = [
  "YOUR_ADMIN_GROUP_OBJECT_ID"
]

# Network configuration
vnet_address_space = ["10.0.0.0/16"]
aks_subnet_prefix  = "10.0.1.0/24"

# Tags
common_tags = {
  Project     = "MyProject"
  Environment = "Development"
  ManagedBy   = "Terraform"
  Owner       = "Platform-Team"
}
```

### 2. Validate Configuration

```bash
# Format files
terraform fmt -recursive

# Validate configuration
terraform validate

# Check for security issues (optional)
make security-scan
```

---

## Deployment Steps

### Option 1: Using Makefile (Recommended)

```bash
# Initialize
make init

# Plan deployment
make plan ENV=dev

# Apply deployment
make apply ENV=dev
```

### Option 2: Manual Terraform Commands

```bash
# Initialize
terraform init

# Plan
terraform plan -var-file=terraform.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

### Deployment Timeline
- **Initialization**: ~30 seconds
- **Planning**: ~1-2 minutes
- **Apply**: ~10-15 minutes

### What Gets Created?
1. Resource Group
2. Virtual Network & Subnet
3. Network Security Group
4. Log Analytics Workspace
5. AKS Cluster (with 2 nodes)
6. User Assigned Identity
7. Diagnostic Settings
8. Azure Monitor integration
9. Microsoft Defender for Containers
10. Azure Policy add-on

---

## Post-Deployment

### 1. Get Cluster Credentials

```bash
# Using Makefile
make kubeconfig

# Or manually
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --overwrite-existing
```

### 2. Verify Cluster Access

```bash
# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Cluster info
kubectl cluster-info
```

### 3. Deploy Sample Application

```bash
# Create namespace
kubectl create namespace demo

# Deploy nginx
kubectl create deployment nginx --image=nginx -n demo

# Expose service
kubectl expose deployment nginx --port=80 --type=LoadBalancer -n demo

# Wait for external IP
kubectl get service -n demo -w
```

### 4. Setup Monitoring (Optional)

```bash
# Use helper script
./scripts/aks-helper.sh

# Select option 6: Setup monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Visit http://localhost:3000 (admin/admin)
```

### 5. Install Ingress Controller (Optional)

```bash
# NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

---

## Common Operations

### View Cluster Information

```bash
# Get all outputs
terraform output

# Specific outputs
terraform output aks_cluster_name
terraform output resource_group_name
terraform output aks_fqdn
```

### Scale Node Pool

```bash
# Get current scale
kubectl get nodes

# Scale using Azure CLI
az aks nodepool scale \
  --resource-group $(terraform output -raw resource_group_name) \
  --cluster-name $(terraform output -raw aks_cluster_name) \
  --name system \
  --node-count 3
```

### Upgrade Cluster

```bash
# Check available versions
az aks get-upgrades \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --output table

# Update terraform.tfvars
# kubernetes_version = "1.29.0"

# Apply upgrade
make plan ENV=dev
make apply ENV=dev
```

### View Logs

```bash
# Azure Monitor Logs
az monitor log-analytics query \
  --workspace $(terraform output -raw log_analytics_workspace_id) \
  --analytics-query "ContainerLog | limit 100"

# Kubectl logs
kubectl logs -n kube-system <pod-name>
```

### Backup Cluster Configuration

```bash
# Install Velero
kubectl apply -f https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz

# Configure backup
# See: https://velero.io/docs/
```

---

## Troubleshooting

### Common Issues

#### 1. Authentication Errors

```bash
# Re-login to Azure
az login

# Verify subscription
az account show

# Re-get cluster credentials
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --overwrite-existing
```

#### 2. Nodes Not Ready

```bash
# Check node status
kubectl get nodes -o wide

# Describe node
kubectl describe node <node-name>

# Check system pods
kubectl get pods -n kube-system

# Check events
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

#### 3. Deployment Failures

```bash
# Check Terraform logs
TF_LOG=DEBUG terraform apply

# Validate configuration
terraform validate

# Check Azure activity log
az monitor activity-log list \
  --resource-group <rg-name> \
  --max-events 20
```

#### 4. Network Connectivity Issues

```bash
# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Test pod-to-pod connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Check network policies
kubectl get networkpolicies --all-namespaces
```

#### 5. Private Cluster Access

If you can't access the private cluster:

```bash
# Option 1: Use Azure Bastion
# Create VM in same VNet
az vm create \
  --resource-group <rg-name> \
  --name jumpbox \
  --image UbuntuLTS \
  --vnet-name <vnet-name> \
  --subnet <subnet-name>

# Option 2: Use VPN Gateway
# Setup Point-to-Site VPN
# See: https://docs.microsoft.com/azure/vpn-gateway/

# Option 3: Use run-command (if enabled)
az aks command invoke \
  --resource-group <rg-name> \
  --name <cluster-name> \
  --command "kubectl get nodes"
```

### Useful Commands

```bash
# Check resource consumption
kubectl top nodes
kubectl top pods --all-namespaces

# Get cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check API server logs
kubectl logs -n kube-system -l component=kube-apiserver

# Describe all resources in namespace
kubectl describe all -n <namespace>

# Export resource definitions
kubectl get <resource> <name> -o yaml > resource.yaml
```

### Getting Help

1. **Azure Support**: [Azure Portal](https://portal.azure.com) → Support
2. **AKS Documentation**: https://docs.microsoft.com/azure/aks/
3. **Terraform Provider Issues**: https://github.com/hashicorp/terraform-provider-azurerm/issues
4. **Kubernetes Documentation**: https://kubernetes.io/docs/

---

## Security Checklist

Before going to production, verify:

- [ ] Private cluster enabled
- [ ] Azure AD integration configured
- [ ] Admin group assigned
- [ ] Network policies enabled
- [ ] Microsoft Defender enabled
- [ ] Azure Policy enabled
- [ ] Secrets in Key Vault
- [ ] Log Analytics configured
- [ ] Diagnostic logs enabled
- [ ] Run command disabled
- [ ] Automated backups configured
- [ ] Disaster recovery tested

See [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) for complete list.

---

## Cost Management

### Monitor Costs

```bash
# View cost analysis
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31

# Set budget alerts in Azure Portal
# Cost Management + Billing → Budgets
```

### Optimize Costs

1. Use autoscaling (already configured)
2. Right-size VMs based on actual usage
3. Use Azure Hybrid Benefit if applicable
4. Consider spot instances for dev/test
5. Delete unused resources
6. Use Azure Advisor recommendations

---

## Next Steps

1. **Configure CI/CD**: Setup GitHub Actions or Azure DevOps
2. **Implement GitOps**: Use ArgoCD or Flux
3. **Setup Service Mesh**: Istio or Linkerd (optional)
4. **Configure Backup**: Velero or Azure Backup
5. **Implement Monitoring**: Prometheus/Grafana stack
6. **Setup Logging**: ELK or Azure Monitor
7. **Security Scanning**: Aqua, Twistlock, or Prisma Cloud
8. **Policy Enforcement**: OPA Gatekeeper or Kyverno

---

## Support & Contributing

For questions or issues:
1. Check the [README.md](README.md)
2. Review [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md)
3. Check Azure documentation
4. Open an issue in your repository

---

**Last Updated**: December 2024
**Terraform Version**: 1.6.0+
**AKS Version**: 1.28.3
