# ===================
# Project Configuration
# ===================
project_name = "aksdev" # ⭐ FIXED: max 10 chars, no hyphens 
environment  = "dev"
location     = "eastus"

# ===================
# Kubernetes Configuration
# ===================
kubernetes_version = "1.33.0" # ⭐ FIXED: added .0 for X.Y.Z format

# ===================
# Networking
# ===================
vnet_address_space = ["10.0.0.0/16"]
aks_subnet_prefix  = "10.0.1.0/24" # ⭐ FIXED: string not array

# ===================
# Node Configuration
# ===================
node_count           = 2
node_vm_size         = "Standard_D2s_v3"
node_os_disk_size_gb = 30

# ===================
# Monitoring & Logging
# ===================
log_retention_days = 30

# ===================
# RBAC - Azure AD Integration
# ===================
admin_group_object_ids = []
grant_deployer_cluster_admin = true
# ===================
# Network Settings
# ===================
enable_private_cluster = false
network_plugin         = "azure"
network_policy         = "azure"

# ===================
# Common Tags
# ===================
common_tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
  Project     = "AKS-Terraform"
  CostCenter  = "Engineering"
  Owner       = "Platform-Team"
}

# Security settings (relaxed for dev)
# os_disk_type                 = "Managed"
# enable_host_encryption       = false
# only_critical_addons_enabled = false
# disk_encryption_set_id       = null # Or null if not using