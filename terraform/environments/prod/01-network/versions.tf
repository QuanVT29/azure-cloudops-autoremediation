terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0, < 4.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}


provider "azurerm" {
  features {}
}

# Fetch subscription metadata
data "azurerm_subscription" "current" {}

# Fetch target network resource group created in Module 1 (Layer 1)
data "azurerm_resource_group" "network" {
  name = var.network_resource_group_name
}