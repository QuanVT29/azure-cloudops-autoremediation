# Export Layer 4 Telemetry identifiers for Layer 5 Operations

output "log_analytics_workspace_id" {
  description = "Resource ID of the Central Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Central Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation Key for Application Insights"
  value       = azurerm_application_insights.appinsights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection String for Application Insights APM"
  value       = azurerm_application_insights.appinsights.connection_string
  sensitive   = true
}

output "enable_aks_container_insights_command" {
  description = "CLI command to attach AKS monitoring addon to the Log Analytics Workspace"
  value       = "az aks enable-addons --resource-group ${data.azurerm_resource_group.compute.name} --name ${data.azurerm_kubernetes_cluster.aks.name} --addons monitoring --workspace-resource-id ${azurerm_log_analytics_workspace.law.id}"
}