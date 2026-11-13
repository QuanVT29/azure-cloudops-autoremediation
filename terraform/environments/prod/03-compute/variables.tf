# Purpose: Declare input variables for the AKS Cluster and Node Pool specifications

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

variable "compute_resource_group_name" {
  type        = string
  description = "Compute Resource Group provisioned in Layer 1"
  default     = "rg-banking-ops-prod-compute-sea"
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

variable "data_resource_group_name" {
  type        = string
  description = "Data Resource Group provisioned in Layer 1"
  default     = "rg-banking-ops-prod-data-sea"
}

variable "vnet_name" {
  type        = string
  description = "VNet Name provisioned in Layer 2"
  default     = "vnet-banking-ops-prod-sea"
}

variable "key_vault_name" {
  type        = string
  description = "Name of the Azure Key Vault provisioned in Layer 3"
}

variable "kubernetes_version" {
  type        = string
  description = "Target stable Kubernetes version"
  default     = "1.30"
}

variable "node_vm_size" {
  type        = string
  description = "Azure VM SKU for the AKS node pool (using unrestricted 2-vCPU SKU in Singapore)"
  default     = "Standard_DC2ds_v3"
}

variable "node_count" {
  type        = number
  description = "Fixed node count for the system node pool (FinOps optimized)"
  default     = 1
}

variable "common_tags" {
  type        = map(string)
  description = "Standard metadata tags"
  default = {
    Project           = "FPT-CloudOps-Remediation"
    Workload          = "CoreBanking"
    ManagedBy         = "Terraform"
    Environment       = "Production"
    ArchitectureLayer = "Layer3-ComputeWorkloads"
  }
}