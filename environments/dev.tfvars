
# ===================
# Project Configuration
# ===================
project_name = "aks-terraform"
environment  = "dev"
location     = "eastus"

# ===================
# Kubernetes Configuration
# ===================
kubernetes_version = "1.28"

# ===================
# Networking
# ===================
vnet_address_space = ["10.0.0.0/16"]
aks_subnet_prefix  = ["10.0.1.0/24"]

# ===================
# System Node Pool
# ===================
system_node_pool = {
  name                = "system"
  node_count          = 2
  vm_size             = "Standard_D2s_v3"
  os_disk_size_gb     = 30
  availability_zones  = ["1", "2"]
  enable_auto_scaling = true
  min_count           = 2
  max_count           = 5
  max_pods            = 30
}

# ===================
# Monitoring & Logging
# ===================
log_retention_days = 30

# ===================
# RBAC - Azure AD Integration
# ===================
admin_group_object_ids = []  # Add your Azure AD group object IDs here if needed

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

# ===================
# Auto Scaler Profile
# ===================
auto_scaler_profile = {
  balance_similar_node_groups      = true
  max_graceful_termination_sec     = 600
  scale_down_delay_after_add       = "10m"
  scale_down_unneeded              = "10m"
  scale_down_utilization_threshold = 0.5
  scan_interval                    = "10s"
  skip_nodes_with_local_storage    = false
}

# ===================
# Cost Optimization (Dev-specific)
# ===================
# Enable automatic stop/start for dev (requires additional configuration)
# auto_stop_enabled = true
# auto_stop_schedule = "0 20 * * 1-5"  # Stop at 8 PM on weekdays
# auto_start_schedule = "0 8 * * 1-5"  # Start at 8 AM on weekdays
