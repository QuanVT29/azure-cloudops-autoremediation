# Purpose: Store database and in-cluster caching secrets into Key Vault

# 1. SQL Administrator Password
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin_password.result
  key_vault_id = azurerm_key_vault.vault.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# 2. SQL Server Fully Qualified Domain Name
resource "azurerm_key_vault_secret" "sql_server_fqdn" {
  name         = "sql-server-fqdn"
  value        = azurerm_mssql_server.sql.fully_qualified_domain_name
  key_vault_id = azurerm_key_vault.vault.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# 3. Formatted Core Banking SQL Connection String
resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.core_db.name};Persist Security Info=False;User ID=${azurerm_mssql_server.sql.administrator_login};Password=${random_password.sql_admin_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.vault.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# 4. Redis Primary Access Key (In-Cluster Secret Token)
resource "azurerm_key_vault_secret" "redis_primary_key" {
  name         = "redis-primary-key"
  value        = "internal-cluster-cache-token"
  key_vault_id = azurerm_key_vault.vault.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# 5. Formatted In-Cluster Redis Connection String (K8s Service DNS)
resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "redis-connection-string"
  value        = "redis://redis-service.default.svc.cluster.local:6379"
  key_vault_id = azurerm_key_vault.vault.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}