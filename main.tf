terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }

  # Backend configuration for remote state
  # Uncomment and configure for production use
# Backend with workspace support - each environment gets its own state
backend "azurerm" {
  resource_group_name  = "terraform-state-rg"
  storage_account_name = "tfstateaksproject"
  container_name       = "tfstate"
  key                  = "aks.tfstate"
    use_azuread_auth     = true # ⭐ ADD THIS LINE
  }


}
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }

  }
}

provider "azuread" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location

  tags = merge(
    var.common_tags,
    {
      ManagedBy = "Terraform"
    }
  )
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.common_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_name        = var.project_name
  environment         = var.environment
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_address_space  = var.vnet_address_space
  aks_subnet_prefix   = var.aks_subnet_prefix
  common_tags         = var.common_tags
}

# AKS Module
module "aks" {
  source = "./modules/aks"

  project_name               = var.project_name
  environment                = var.environment
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  kubernetes_version         = var.kubernetes_version
  node_count                 = var.node_count
  node_vm_size               = var.node_vm_size
  node_os_disk_size_gb       = var.node_os_disk_size_gb
  vnet_subnet_id             = module.networking.aks_subnet_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  admin_group_object_ids     = var.admin_group_object_ids
  enable_private_cluster     = var.enable_private_cluster
  network_plugin             = var.network_plugin
  network_policy             = var.network_policy
  common_tags                = var.common_tags

  depends_on                   = [module.networking]
  os_disk_type                 = var.os_disk_type
  only_critical_addons_enabled = var.only_critical_addons_enabled
  enable_host_encryption       = var.enable_host_encryption
  disk_encryption_set_id       = var.disk_encryption_set_id
}
