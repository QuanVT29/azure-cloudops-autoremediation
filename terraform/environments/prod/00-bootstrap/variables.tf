variable "environment" {
  type        = string
  description = "Target deployment environment naming prefix"
  default     = "prod"
}

variable "project_name" {
  type        = string
  description = "Logical project designation"
  default     = "banking-ops"
}

variable "location" {
  type        = string
  description = "Primary Azure region for all regional infrastructure"
  default     = "southeastasia"
}

variable "budget_amount" {
  type        = number
  description = "Maximum monthly spending limit threshold in USD"
  default     = 5.0
}

variable "budget_notification_emails" {
  type        = list(string)
  description = "Email addresses designated to receive automated cost guardrail alerts"
}

variable "common_tags" {
  type        = map(string)
  description = "Mandatory governance metadata tags applied across all resources"
  default = {
    Project     = "FPT-CloudOps-Remediation"
    Workload    = "CoreBanking"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}