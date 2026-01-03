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

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = list(string)
}

variable "aks_subnet_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
}

variable "common_tags" {
  description = "Common tags for resources"
  type        = map(string)
}
