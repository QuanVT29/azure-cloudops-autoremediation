# Export Layer 5 Operations & Auto-Remediation identifiers

output "action_group_id" {
  description = "Resource ID of the Azure Monitor Action Group"
  value       = azurerm_monitor_action_group.cloudops_ag.id
}

output "automation_account_name" {
  description = "Name of the Azure Automation Account for Auto-Remediation"
  value       = azurerm_automation_account.remediation.name
}

output "automation_runbook_name" {
  description = "Name of the deployed PowerShell Auto-Healing Runbook"
  value       = azurerm_automation_runbook.aks_pod_healer.name
}

output "logic_app_itsm_trigger_url" {
  description = "Callback URL of the ServiceNow ITSM Logic App HTTP Trigger"
  value       = azurerm_logic_app_trigger_http_request.alert_webhook_trigger.callback_url
  sensitive   = true
}

output "manual_runbook_trigger_command" {
  description = "Azure CLI command to manually test the AKS Auto-Healing Runbook"
  value       = "az automation runbook start --resource-group ${data.azurerm_resource_group.operations.name} --automation-account-name ${azurerm_automation_account.remediation.name} --name ${azurerm_automation_runbook.aks_pod_healer.name}"
}