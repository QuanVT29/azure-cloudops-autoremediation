# 1. Private DNS Zone for Azure SQL Database
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.network.name
  tags                = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "link-sql-to-vnet"
  resource_group_name   = data.azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# 2. Private DNS Zone for Azure Cache for Redis
resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = data.azurerm_resource_group.network.name
  tags                = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "link-redis-to-vnet"
  resource_group_name   = data.azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# 3. Private DNS Zone for Azure Key Vault
resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.network.name
  tags                = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                  = "link-vault-to-vnet"
  resource_group_name   = data.azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}