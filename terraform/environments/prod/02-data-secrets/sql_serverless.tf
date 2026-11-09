# Purpose: Provision Zero-Public Azure SQL Server & Serverless Database

# Cryptographically strong random password for SQL Administrator
resource "random_password" "sql_admin_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Azure SQL Logical Server (Strict Zero-Public PaaS)
resource "azurerm_mssql_server" "sql" {
  name                          = "sql-${var.project_name}-${var.environment}-${random_string.kv_suffix.result}"
  resource_group_name           = data.azurerm_resource_group.data.name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = "bankingadmin"
  administrator_login_password  = random_password.sql_admin_password.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false # Blocks all direct public internet access

  tags = var.common_tags
}

# Azure SQL Serverless Database (FinOps Optimized)
resource "azurerm_mssql_database" "core_db" {
  name                        = "sqldb-${var.project_name}-${var.environment}-core"
  server_id                   = azurerm_mssql_server.sql.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                 = 32
  sku_name                    = "GP_S_Gen5_1" # General Purpose Serverless Gen5 (1 vCore Max)
  min_capacity                = 0.5           # Scales down to 0.5 vCore under low load
  auto_pause_delay_in_minutes = 60            # Automatically pauses compute after 1hr idle ($0 compute)

  storage_account_type = "Local" # Lowest storage redundancy cost (LRS)

  tags = var.common_tags
}


# Private Endpoint: Project Azure SQL TDS interface into snet-data (10.0.2.x)
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.environment}-sea"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.data.name
  subnet_id           = data.azurerm_subnet.data.id

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "pdz-group-sql"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.sql.id]
  }

  tags = var.common_tags
}