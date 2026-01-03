output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "aks_node_resource_group" {
  description = "Auto-generated resource group for AKS nodes"
  value       = module.aks.node_resource_group
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity"
  value       = module.aks.kubelet_identity_object_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.networking.aks_subnet_id
}

# Sensitive outputs - use with caution
output "kube_config" {
  description = "Kubernetes configuration for kubectl access"
  value       = module.aks.kube_config
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw kubeconfig for cluster access"
  value       = module.aks.kube_config_raw
  sensitive   = true
}
