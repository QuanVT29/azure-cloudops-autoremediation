output "vnet_id" {
  description = "The Resource ID of the core Virtual Network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "The Name of the core Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_ids" {
  description = "Map of all provisioned subnet IDs"
  value = {
    aks  = azurerm_subnet.aks.id
    data = azurerm_subnet.data.id
    mgmt = azurerm_subnet.mgmt.id
  }
}

output "jumpbox_public_ip" {
  description = "Whitelisted Public IP address of the Linux Jumpbox"
  value       = azurerm_public_ip.jumpbox.ip_address
}

output "private_dns_zone_ids" {
  description = "Resource IDs for linked Private DNS Zones"
  value = {
    sql   = azurerm_private_dns_zone.sql.id
    redis = azurerm_private_dns_zone.redis.id
    vault = azurerm_private_dns_zone.vault.id
  }
}