# Built-in Policy: "Allowed locations" (ID: e56962a6-4747-49cd-b67b-bf7b01975c4c)
data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

# Enforce Geographic Confinement strictly on the Operations Resource Group
resource "azurerm_resource_group_policy_assignment" "enforce_location_ops" {
  name                 = "enforce-sea-ops"
  resource_group_id    = azurerm_resource_group.operations.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  description          = "Restricts resource deployments strictly to Southeast Asia"
  display_name         = "Enforce Southeast Asia Only (Operations RG)"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = [var.location]
    }
  })
}

# Enforce Geographic Confinement on the Compute Resource Group
resource "azurerm_resource_group_policy_assignment" "enforce_location_compute" {
  name                 = "enforce-sea-compute"
  resource_group_id    = azurerm_resource_group.compute.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  description          = "Restricts resource deployments strictly to Southeast Asia"
  display_name         = "Enforce Southeast Asia Only (Compute RG)"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = [var.location]
    }
  })
}