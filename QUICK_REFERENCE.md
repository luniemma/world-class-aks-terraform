# AKS Terraform - Quick Reference Card

## 🚀 Quick Start Commands

```bash
# Setup
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
make init
make plan ENV=dev
make apply ENV=dev

# Access cluster
make kubeconfig
kubectl get nodes
```

## 📁 Project Structure

```
aks-terraform/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Outputs
├── terraform.tfvars.example   # Example config
├── Makefile                   # Common commands
├── modules/
│   ├── networking/            # VNet, NSG
│   └── aks/                   # AKS cluster
├── environments/
│   └── prod.tfvars           # Production config
├── scripts/
│   └── aks-helper.sh         # Helper script
└── .github/workflows/
    └── terraform.yml         # CI/CD pipeline
```

## 🔑 Essential Configuration

### terraform.tfvars
```hcl
project_name = "myproject"
environment  = "dev"
location     = "eastus"

admin_group_object_ids = [
  "YOUR_ADMIN_GROUP_OBJECT_ID"
]

common_tags = {
  Project     = "MyProject"
  Environment = "Dev"
  ManagedBy   = "Terraform"
}
```

## 📝 Common Makefile Commands

```bash
make init             # Initialize Terraform
make validate         # Validate config
make plan             # Generate plan
make apply            # Deploy infrastructure
make destroy          # Destroy infrastructure
make kubeconfig       # Get cluster credentials
make security-scan    # Run security checks
make cost-estimate    # Estimate costs
```

## 🔧 Terraform Commands

```bash
# Initialize
terraform init

# Plan with specific environment
terraform plan -var-file=environments/prod.tfvars

# Apply
terraform apply tfplan

# Show outputs
terraform output

# Destroy
terraform destroy -var-file=environments/prod.tfvars
```

## ☸️ Kubectl Commands

```bash
# Get credentials
az aks get-credentials \
  --resource-group <rg-name> \
  --name <cluster-name>

# Basic commands
kubectl get nodes
kubectl get pods -n kube-system
kubectl cluster-info
kubectl top nodes

# Deployments
kubectl create namespace demo
kubectl create deployment nginx --image=nginx -n demo
kubectl expose deployment nginx --port=80 --type=LoadBalancer -n demo
```

## 🔒 Security Features

✅ Private cluster (API server not public)  
✅ Azure AD integration with RBAC  
✅ Managed identities (no service principals)  
✅ Network policies enabled  
✅ Microsoft Defender for Containers  
✅ Azure Policy enforcement  
✅ Key Vault integration  
✅ Diagnostic logging  
✅ Auto-patching enabled  

## 📊 Default Configuration

- **Nodes**: 2 (autoscales 2-4)
- **VM Size**: Standard_D2s_v3
- **OS Disk**: 128 GB
- **Network**: Azure CNI
- **Kubernetes**: 1.28.3
- **SKU Tier**: Standard

## 🌐 Network Details

- **VNet**: 10.0.0.0/16
- **AKS Subnet**: 10.0.1.0/24
- **Service CIDR**: 172.16.0.0/16
- **DNS Service IP**: 172.16.0.10

## 📈 Monitoring

```bash
# Azure Monitor Logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "ContainerLog | limit 100"

# Kubectl logs
kubectl logs -f -n <namespace> <pod-name>

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

## 🆘 Troubleshooting

### Can't access cluster?
```bash
# Re-authenticate
az login
az aks get-credentials --resource-group <rg> --name <cluster> --overwrite-existing
```

### Nodes not ready?
```bash
kubectl get nodes -o wide
kubectl describe node <node-name>
kubectl get pods -n kube-system
```

### Terraform errors?
```bash
terraform validate
terraform fmt -recursive
TF_LOG=DEBUG terraform apply
```

## 💰 Cost Estimates

**Development (2 nodes)**
- Compute: ~$140-160/month
- Log Analytics: ~$2-10/month
- **Total**: ~$150-170/month

**Production (4 nodes, larger VMs)**
- Compute: ~$560-640/month
- Log Analytics: ~$10-30/month
- **Total**: ~$600-700/month

## 🔄 CI/CD Integration

GitHub Actions workflow included at:
`.github/workflows/terraform.yml`

Required secrets:
- `AZURE_CREDENTIALS`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

## 📚 Documentation Files

- `README.md` - Main documentation
- `DEPLOYMENT_GUIDE.md` - Step-by-step deployment
- `SECURITY_CHECKLIST.md` - Security validation
- `terraform.tfvars.example` - Configuration template

## 🔗 Useful Links

- [Azure AKS Docs](https://docs.microsoft.com/azure/aks/)
- [Terraform AKS Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Azure Security Baseline](https://docs.microsoft.com/security/benchmark/azure/baselines/aks-security-baseline)

## 💡 Pro Tips

1. **Always use private cluster in production**
2. **Configure Azure AD admin groups**
3. **Enable autoscaling for cost optimization**
4. **Use remote state in Azure Storage**
5. **Test in dev before applying to prod**
6. **Regular backups with Velero**
7. **Monitor costs in Azure Portal**
8. **Keep Kubernetes version up to date**
9. **Use network policies for pod security**
10. **Review Azure Advisor recommendations**

---

**Need help?** Run `./scripts/aks-helper.sh` for interactive menu
