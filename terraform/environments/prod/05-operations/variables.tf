# Input variables for Layer 5 Alerting, ITSM Logic App & Auto-Healing

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
  description = "Primary Azure region for operations and automation resources"
  type        = string
  default     = "southeastasia"
}

variable "operations_resource_group_name" {
  description = "Resource group hosting observability and automation resources"
  type        = string
  default     = "rg-banking-ops-prod-operations-sea"
}

variable "compute_resource_group_name" {
  description = "Resource group hosting the AKS cluster"
  type        = string
  default     = "rg-banking-ops-prod-compute-sea"
}

variable "aks_cluster_name" {
  description = "Name of the target AKS cluster to monitor and auto-remediate"
  type        = string
  default     = "aks-banking-ops-prod-sea"
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace provisioned in 04-telemetry"
  type        = string
  default     = "law-banking-ops-prod-sea"
}

variable "alert_notification_email" {
  description = "SRE On-Call email address for P1/P2 Azure Monitor alert notifications"
  type        = string
}

variable "servicenow_incident_api_url" {
  description = "ServiceNow PDI REST API endpoint for automated ITSM incident creation"
  type        = string
  default     = "https://dev481553.service-now.com/api/now/table/incident"
}


variable "servicenow_username" {
  description = "ServiceNow PDI admin username"
  type        = string
  default     = "admin"
}

variable "servicenow_password" {
  description = "ServiceNow PDI admin password"
  type        = string
  sensitive   = true 
}