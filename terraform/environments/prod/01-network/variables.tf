variable "environment" {
  type        = string
  description = "Target deployment environment prefix"
  default     = "prod"
}

variable "project_name" {
  type        = string
  description = "Logical project identifier"
  default     = "banking-ops"
}

variable "location" {
  type        = string
  description = "Target Azure region"
  default     = "southeastasia"
}

variable "network_resource_group_name" {
  type        = string
  description = "Name of the network resource group provisioned in Module 1"
  default     = "rg-banking-ops-prod-network-sea"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "CIDR block allocated for the core Virtual Network"
  default     = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
  type        = map(string)
  description = "CIDR allocations for dedicated micro-segmented subnets"
  default = {
    aks  = "10.0.1.0/24"
    data = "10.0.2.0/24"
    mgmt = "10.0.3.0/24"
  }
}


variable "admin_username" {
  type        = string
  description = "Administrative user account name for the Jumpbox VM"
  default     = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key string for Jumpbox key-pair authentication"
}

variable "common_tags" {
  type        = map(string)
  description = "Standard enterprise metadata tags"
  default = {
    Project           = "FPT-CloudOps-Remediation"
    Workload          = "CoreBanking"
    ManagedBy         = "Terraform"
    Environment       = "Production"
    ArchitectureLayer = "Layer2-Networking"
  }
}