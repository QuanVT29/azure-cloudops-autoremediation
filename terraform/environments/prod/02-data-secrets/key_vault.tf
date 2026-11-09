# Purpose: Provision Azure Key Vault with RBAC authorization and Private Endpoint

# Random suffix to guarantee globally unique Key Vault naming (3-24 alphanumerics)
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "vault" {
  name                       = "kv-bank-${var.environment}-${random_string.kv_suffix.result}"
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.data.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Set to false for safe lab destruction
  enable_rbac_authorization  = true  # Modern Zero-Trust RBAC model

  # Network ACLs: Restrict public access while allowing Terraform runner IP
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = [var.admin_client_ip]
  }

  tags = var.common_tags
}

# RBAC Role Assignment: Grant Key Vault Administrator to Current Deployer
# Essential to allow Terraform to write secrets during pipeline execution
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}


# RBAC Role Assignment: Grant Key Vault Secrets User to Central Managed Identity
# Enables AKS Pods to fetch secrets via CSI Driver without static credentials
resource "azurerm_role_assignment" "workload_kv_reader" {
  scope                = azurerm_key_vault.vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_user_assigned_identity.cloudops.principal_id
}


# Private Endpoint: Project Key Vault interface into snet-data
resource "azurerm_private_endpoint" "vault" {
  name                = "pe-keyvault-${var.environment}-sea"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.data.name
  subnet_id           = data.azurerm_subnet.data.id

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.vault.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "pdz-group-vault"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.vault.id]
  }

  tags = var.common_tags
}