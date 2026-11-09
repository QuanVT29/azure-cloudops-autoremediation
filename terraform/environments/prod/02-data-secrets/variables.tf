# Purpose: Input variable definitions for Layer 3 (Stateful Data & Secrets)

variable "environment" {
  type        = string
  description = "Target deployment environment"
  default     = "prod"
}

variable "project_name" {
  type        = string
  description = "Project workload identifier"
  default     = "banking-ops"
}

variable "location" {
  type        = string
  description = "Target Azure Region"
  default     = "southeastasia"
}

variable "data_resource_group_name" {
  type        = string
  description = "Target Resource Group for Data & Secrets provisioned in Layer 1"
  default     = "rg-banking-ops-prod-data-sea"
}

variable "network_resource_group_name" {
  type        = string
  description = "Network Resource Group provisioned in Layer 1"
  default     = "rg-banking-ops-prod-network-sea"
}

variable "operations_resource_group_name" {
  type        = string
  description = "Operations Resource Group provisioned in Layer 1"
  default     = "rg-banking-ops-prod-operations-sea"
}

variable "vnet_name" {
  type        = string
  description = "Virtual Network name provisioned in Layer 2"
  default     = "vnet-banking-ops-prod-sea"
}

variable "admin_client_ip" {
  type        = string
  description = "Public IP address of the local machine executing Terraform (without CIDR mask) to allow Key Vault secret writes"
}

variable "common_tags" {
  type        = map(string)
  description = "Standard enterprise governance tags"
  default = {
    Project           = "FPT-CloudOps-Remediation"
    Workload          = "CoreBanking"
    ManagedBy         = "Terraform"
    Environment       = "Production"
    ArchitectureLayer = "Layer3-DataSecrets"
  }
}