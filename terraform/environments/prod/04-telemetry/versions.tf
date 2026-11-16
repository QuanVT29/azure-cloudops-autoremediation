# Provider configuration and cross-layer Data Sources for Layer 4


terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117.0"
    }
  }
}

provider "azurerm" {
  features {}
}


# Data Sources: Existing Resource Groups, AKS Cluster, and Key Vault
data "azurerm_resource_group" "operations" {
  name = var.operations_resource_group_name
}

data "azurerm_resource_group" "compute" {
  name = var.compute_resource_group_name
}

data "azurerm_resource_group" "data" {
  name = var.data_resource_group_name
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.compute.name
}

data "azurerm_key_vault" "vault" {
  name                = var.key_vault_name
  resource_group_name = data.azurerm_resource_group.data.name
}