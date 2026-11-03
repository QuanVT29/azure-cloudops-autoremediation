# Central User-Assigned Managed Identity for Cloud-Ops Workloads
resource "azurerm_user_assigned_identity" "cloudops_identity" {
  name                = "id-${var.project_name}-${var.environment}-sea"
  resource_group_name = azurerm_resource_group.operations.name
  location            = var.location

  tags = merge(var.common_tags, {
    IdentityType = "UserAssigned"
    Purpose      = "SecretlessAutomation"
  })
}

# Grant Monitoring Contributor Role at the Subscription Scope
resource "azurerm_role_assignment" "monitoring_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_user_assigned_identity.cloudops_identity.principal_id
}

# Grant Reader Role at the Subscription Scope to inspect metrics/telemetry
resource "azurerm_role_assignment" "reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.cloudops_identity.principal_id
}