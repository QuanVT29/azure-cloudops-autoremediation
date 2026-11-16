# Define provider versions and load contextual resources from Layers 1, 2, and 3

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0, < 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "azurerm" {
  features {}
}

# Current account identity context
data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

# Layer 1 Resource Groups
data "azurerm_resource_group" "compute" {
  name = var.compute_resource_group_name
}

data "azurerm_resource_group" "network" {
  name = var.network_resource_group_name
}

data "azurerm_resource_group" "operations" {
  name = var.operations_resource_group_name
}

data "azurerm_resource_group" "data" {
  name = var.data_resource_group_name
}

# Central Managed Identity from Layer 1
data "azurerm_user_assigned_identity" "cloudops" {
  name                = "id-${var.project_name}-${var.environment}-sea"
  resource_group_name = data.azurerm_resource_group.operations.name
}

# Subnet snet-aks from Layer 2
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

# Key Vault reference from Layer 3
data "terraform_remote_state" "data_secrets" {
  backend = "local"

  config = {
    path = "${path.module}/../02-data-secrets/terraform.tfstate"
  }
}

data "azurerm_key_vault" "vault" {
  name                = data.terraform_remote_state.data_secrets.outputs.key_vault_name
  resource_group_name = data.azurerm_resource_group.data.name
}