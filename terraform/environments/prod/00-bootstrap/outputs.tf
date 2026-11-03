output "subscription_id" {
  description = "Target Azure Subscription ID"
  value       = data.azurerm_subscription.current.subscription_id
}

output "resource_group_names" {
  description = "Map of all provisioned core architectural resource groups"
  value = {
    network    = azurerm_resource_group.network.name
    data       = azurerm_resource_group.data.name
    compute    = azurerm_resource_group.compute.name
    operations = azurerm_resource_group.operations.name
  }
}

output "resource_group_ids" {
  description = "Map of resource group identifiers for role and diagnostic scoping"
  value = {
    network    = azurerm_resource_group.network.id
    data       = azurerm_resource_group.data.id
    compute    = azurerm_resource_group.compute.id
    operations = azurerm_resource_group.operations.id
  }
}

output "managed_identity_id" {
  description = "Resource ID of the User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.cloudops_identity.id
}

output "managed_identity_client_id" {
  description = "Client ID (Application ID) used for token acquisition via IMDS"
  value       = azurerm_user_assigned_identity.cloudops_identity.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID (Object ID) used for role assignments in downstream modules"
  value       = azurerm_user_assigned_identity.cloudops_identity.principal_id
}