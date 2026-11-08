# Static Public IP for administrative Jumpbox access
resource "azurerm_public_ip" "jumpbox" {
  name                = "pip-${var.project_name}-${var.environment}-jumpbox"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.common_tags
}

# Network Interface Card (NIC) stationed in snet-mgmt
resource "azurerm_network_interface" "jumpbox" {
  name                = "nic-${var.project_name}-${var.environment}-jumpbox"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.network.name

  ip_configuration {
    name                          = "ipconfig-primary"
    subnet_id                     = azurerm_subnet.mgmt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }

  tags = var.common_tags
}

# Attach Jumpbox NIC to Application Security Group
resource "azurerm_network_interface_application_security_group_association" "jumpbox" {
  network_interface_id          = azurerm_network_interface.jumpbox.id
  application_security_group_id = azurerm_application_security_group.jumpbox.id
}

# Low-cost B1s Linux Jumpbox Virtual Machine
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                  = "vm-${var.project_name}-${var.environment}-jumpbox"
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.network.name
  size                  = "Standard_DC1ds_v3"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = var.common_tags
}