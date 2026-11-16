# Provider configuration and Data Sources for Layer 5 Operations

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Data Sources: Existing Resource Groups, AKS Cluster, and Layer 4 LAW
data "azurerm_resource_group" "operations" {
  name = var.operations_resource_group_name
}

data "azurerm_resource_group" "compute" {
  name = var.compute_resource_group_name
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.compute.name
}

data "azurerm_log_analytics_workspace" "law" {
  name                = var.log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.operations.name
}