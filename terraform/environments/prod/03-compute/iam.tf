# Configure RBAC role assignments for VNet networking and Key Vault CSI Driver

# 1. Allow AKS Control Plane Identity to manage the AKS Subnet
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = data.azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.cloudops.principal_id
}

# 2. Grant Key Vault Secrets User to the auto-generated CSI Driver Identity
resource "azurerm_role_assignment" "csi_kv_reader" {
  scope                = data.azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
}