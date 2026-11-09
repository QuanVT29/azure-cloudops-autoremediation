# Purpose: Expose technical identifiers and private connection parameters

output "key_vault_id" {
  description = "Resource ID of the provisioned Azure Key Vault"
  value       = azurerm_key_vault.vault.id
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = azurerm_key_vault.vault.name
}

output "key_vault_uri" {
  description = "Vault URI endpoint consumed by the AKS CSI Secret Store Driver"
  value       = azurerm_key_vault.vault.vault_uri
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL server"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Database name for core banking transactions"
  value       = azurerm_mssql_database.core_db.name
}

output "private_endpoints_ip" {
  description = "Internal IP addresses allocated in snet-data"
  value = {
    key_vault = azurerm_private_endpoint.vault.private_service_connection[0].private_ip_address
    sql       = azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address
  }
}