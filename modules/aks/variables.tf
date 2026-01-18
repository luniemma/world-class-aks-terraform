#
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in default pool"
  type        = number
}

variable "node_vm_size" {
  description = "VM size for nodes"
  type        = string
}

variable "node_os_disk_size_gb" {
  description = "OS disk size for nodes"
  type        = number
}

variable "vnet_subnet_id" {
  description = "Subnet ID for AKS"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "admin_group_object_ids" {
  description = "Azure AD admin group object IDs"
  type        = list(string)
}

variable "enable_private_cluster" {
  description = "Enable private cluster"
  type        = bool
}

variable "network_plugin" {
  description = "Network plugin"
  type        = string
}

variable "network_policy" {
  description = "Network policy"
  type        = string
}

variable "common_tags" {
  description = "Common tags for resources"
  type        = map(string)
}

variable "sku_tier" {
  description = "AKS SKU tier (Free, Standard, or Premium)"
  type        = string
  default     = "Standard"
}

# =============================================================================
# SECURITY VARIABLES (for Checkov compliance)
# =============================================================================

variable "os_disk_type" {
  description = "OS disk type: Managed or Ephemeral. Ephemeral recommended for prod (CKV_AZURE_226)"
  type        = string
  default     = "Managed"
}

variable "only_critical_addons_enabled" {
  description = "Only run critical system pods on system nodes (CKV_AZURE_232). Requires user node pool."
  type        = bool
  default     = false
}

variable "enable_host_encryption" {
  description = "Enable encryption at host for temp disks/caches (CKV_AZURE_227). Requires subscription feature."
  type        = bool
  default     = false
}

variable "disk_encryption_set_id" {
  description = "Disk encryption set ID for OS/data disk encryption (CKV_AZURE_117). Set null to skip."
  type        = string
  default     = null
}
