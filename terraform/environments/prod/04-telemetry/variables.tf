# Input variables for Layer 4 Full-Stack Observability

variable "project_name" {
  description = "Workload identifier prefix for naming convention"
  type        = string
  default     = "banking-ops"
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Primary Azure region for telemetry resources"
  type        = string
  default     = "southeastasia"
}

variable "operations_resource_group_name" {
  description = "Resource group hosting observability resources"
  type        = string
  default     = "rg-banking-ops-prod-operations-sea"
}

variable "compute_resource_group_name" {
  description = "Resource group hosting the AKS cluster"
  type        = string
  default     = "rg-banking-ops-prod-compute-sea"
}

variable "data_resource_group_name" {
  description = "Resource group hosting Azure SQL and Key Vault"
  type        = string
  default     = "rg-banking-ops-prod-data-sea"
}

variable "aks_cluster_name" {
  description = "Name of the target AKS cluster"
  type        = string
  default     = "aks-banking-ops-prod-sea"
}

variable "key_vault_name" {
  description = "Name of the existing Azure Key Vault from Layer 3"
  type        = string
}

variable "law_daily_quota_gb" {
  description = "FinOps safeguard: Maximum daily ingestion cap (in GB) for Log Analytics"
  type        = number
  default     = 0.5
}

variable "law_retention_days" {
  description = "Number of days to retain logs in Log Analytics Workspace"
  type        = number
  default     = 30
}