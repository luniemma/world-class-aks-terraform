# User Assigned Identity for AKS
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.project_name}-${var.environment}-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.common_tags
}

# Role Assignment for Network Contributor on subnet
resource "azurerm_role_assignment" "aks_network" {
  scope                = var.vnet_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                      = "${var.project_name}-${var.environment}-aks"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = "${var.project_name}-${var.environment}-aks"
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = "Standard"
  private_cluster_enabled   = var.enable_private_cluster
  automatic_channel_upgrade = "patch"
  node_resource_group       = "${var.resource_group_name}-nodes"

  # Default node pool configuration
  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    os_disk_size_gb     = var.node_os_disk_size_gb
    vnet_subnet_id      = var.vnet_subnet_id
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = var.node_count
    max_count           = var.node_count + 2
    max_pods            = 110
    os_disk_type        = "Managed"
    
    # Security settings
    only_critical_addons_enabled = false
    
    upgrade_settings {
      max_surge = "33%"
    }

    tags = merge(
      var.common_tags,
      {
        NodePool = "system"
      }
    )
  }

  # Identity configuration - using User Assigned Identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Network profile
  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    
    # Service and pod CIDR (non-overlapping with VNet)
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  # Azure AD integration with RBAC
  azure_active_directory_role_based_access_control {
    managed                = true
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  # Monitoring with Azure Monitor
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Microsoft Defender for Containers
  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Key Vault Secrets Provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Azure Policy Add-on
  azure_policy_enabled = true

  # Security features
  local_account_disabled            = true
  role_based_access_control_enabled = true
  run_command_enabled               = false

  # Workload identity for pod authentication
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = true
    expander                         = "random"
    max_graceful_termination_sec     = 600
    max_node_provisioning_time       = "15m"
    max_unready_nodes                = 3
    max_unready_percentage           = 45
    new_pod_scale_up_delay           = "10s"
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scan_interval                    = "10s"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = 0.5
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }

  tags = var.common_tags

  depends_on = [
    azurerm_role_assignment.aks_network
  ]

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# Diagnostic settings for AKS
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.project_name}-${var.environment}-aks-diag"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  enabled_log {
    category = "cloud-controller-manager"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
