# Purpose: Define provider constraints and dynamic data sources from Layer 1 & 2

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "random" {}

# Context of the current deployment client
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Data references from Layer 1 (rg-data and rg-operations)
data "azurerm_resource_group" "data" {
  name = var.data_resource_group_name
}

data "azurerm_resource_group" "network" {
  name = var.network_resource_group_name
}

data "azurerm_resource_group" "operations" {
  name = var.operations_resource_group_name
}

# Data reference for Central Managed Identity provisioned in Layer 1
data "azurerm_user_assigned_identity" "cloudops" {
  name                = "id-${var.project_name}-${var.environment}-sea"
  resource_group_name = data.azurerm_resource_group.operations.name
}

# Network Data references from Layer 2
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "data" {
  name                 = "snet-data"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

# Private DNS Zones created in Layer 2
data "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.network.name
}