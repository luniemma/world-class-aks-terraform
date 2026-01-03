# Production Environment Configuration
project_name       = "myproject"
environment        = "prod"
location           = "eastus"
kubernetes_version = "1.28.3"

# Node Configuration - Production sizing
node_count         = 2  # Min nodes, will autoscale up to 4
node_vm_size       = "Standard_D4s_v3"  # Larger VM for production
node_os_disk_size_gb = 256

# Network Configuration
vnet_address_space = ["10.1.0.0/16"]
aks_subnet_prefix  = "10.1.1.0/24"
network_plugin     = "azure"
network_policy     = "azure"

# Security Configuration - MUST be private for production
enable_private_cluster = true

# Azure AD Admin Groups (Replace with your actual object IDs)
admin_group_object_ids = [
  # "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Production Admin Group
]

# Monitoring - Longer retention for production
log_retention_days = 90

# Tags
common_tags = {
  Project     = "AKS-Infrastructure"
  Environment = "Production"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering"
  Owner       = "Platform-Team"
  Compliance  = "Required"
  BackupPolicy = "Daily"
}
