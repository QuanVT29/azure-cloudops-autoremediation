data "http" "current_public_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  admin_source_ip = "${chomp(data.http.current_public_ip.response_body)}/32"
}

# Application Security Group to decouple firewall rules from physical IPs
resource "azurerm_application_security_group" "jumpbox" {
  name                = "asg-${var.project_name}-${var.environment}-jumpbox"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.network.name

  tags = var.common_tags
}


# 1. Management Subnet Security Group (Strict Perimeter Control)
resource "azurerm_network_security_group" "mgmt" {
  name                = "nsg-${var.project_name}-${var.environment}-mgmt"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.network.name

  # Allow administrative SSH strictly from auto-detected Operator IP
  security_rule {
    name                                       = "Allow-Admin-SSH"
    priority                                   = 110
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "22"
    source_address_prefix                      = local.admin_source_ip
    destination_application_security_group_ids = [azurerm_application_security_group.jumpbox.id]
  }

  # Hard drop rule for any other unsolicited Internet access
  security_rule {
    name                       = "Deny-Direct-Internet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.common_tags
}

resource "azurerm_subnet_network_security_group_association" "mgmt" {
  subnet_id                 = azurerm_subnet.mgmt.id
  network_security_group_id = azurerm_network_security_group.mgmt.id
}



# 2. AKS Subnet Security Group
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-${var.project_name}-${var.environment}-aks"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.network.name

  # Allow inbound HTTP/HTTPS traffic to cluster ingress
  security_rule {
    name                       = "Allow-HTTP-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.common_tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}



# 3. Data Subnet Security Group (Zero-Public Access)
resource "azurerm_network_security_group" "data" {
  name                = "nsg-${var.project_name}-${var.environment}-data"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.network.name

  # Permit internal SQL traffic only from AKS and Jumpbox
  security_rule {
    name                       = "Allow-Internal-TDS-SQL"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefixes    = [var.subnet_prefixes["aks"], var.subnet_prefixes["mgmt"]]
    destination_address_prefix = var.subnet_prefixes["data"]
  }

  # Permit internal Redis caching traffic only from AKS
  security_rule {
    name                       = "Allow-Internal-Redis"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6380"
    source_address_prefix      = var.subnet_prefixes["aks"]
    destination_address_prefix = var.subnet_prefixes["data"]
  }

  # Drop all direct external inbound traffic
  security_rule {
    name                       = "Deny-All-Internet-To-Data"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.common_tags
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}