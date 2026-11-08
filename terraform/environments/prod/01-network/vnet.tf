# Azure Virtual Network (Regional boundary spanning all Availability Zones)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}-${var.environment}-sea"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.network.name
  address_space       = var.vnet_address_space

  tags = var.common_tags
}

# Subnet 1: Container Orchestration & Workloads (AKS)
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefixes["aks"]]
}

# Subnet 2: Stateful PaaS Private Endpoints (SQL, Redis, Key Vault)
resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefixes["data"]]

  # Enables NSG policy enforcement on private endpoint interfaces
  private_endpoint_network_policies = "Enabled"
}

# Subnet 3: Ephemeral Management & Bastion Jumpbox
resource "azurerm_subnet" "mgmt" {
  name                 = "snet-mgmt"
  resource_group_name  = data.azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefixes["mgmt"]]
}