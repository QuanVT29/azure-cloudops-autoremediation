# Provision the Azure Kubernetes Service (AKS) cluster with Azure CNI and CSI Secret Store

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.project_name}-${var.environment}-sea"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.compute.name
  dns_prefix          = "aks-${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version

  # Zero-Trust Identity: User-Assigned Managed Identity from Layer 1
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.cloudops.id]
  }

  # System Node Pool attached directly to snet-aks
  default_node_pool {
    name                 = "systempool"
    node_count           = var.node_count
    vm_size              = var.node_vm_size
    vnet_subnet_id       = data.azurerm_subnet.aks.id
    os_disk_size_gb      = 32
    os_disk_type         = "Managed"
    type                 = "VirtualMachineScaleSets"
    enable_auto_scaling  = false
    orchestrator_version = var.kubernetes_version

    node_labels = {
      "nodepool" = "system"
      "workload" = "banking"
    }

    tags = var.common_tags
  }

  # Azure CNI Networking: Direct VNet Pod routing to Private Endpoints
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    dns_service_ip     = "10.100.0.10"
    service_cidr       = "10.100.0.0/16"
    load_balancer_sku  = "standard"
  }

  # Secrets Store CSI Driver Add-on (Key Vault Integration)
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "5m"
  }

  # Modern Identity Integrations for Pods
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.common_tags
}