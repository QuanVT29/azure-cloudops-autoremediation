# Layer 2: Core Networking & Jumpbox Boundary
resource "azurerm_resource_group" "network" {
  name     = "rg-${var.project_name}-${var.environment}-network-sea"
  location = var.location
  tags = merge(var.common_tags, {
    ArchitectureLayer = "Layer2-Networking"
  })
}

# Layer 3: Secured Data, Redis & Secrets Boundary
resource "azurerm_resource_group" "data" {
  name     = "rg-${var.project_name}-${var.environment}-data-sea"
  location = var.location
  tags = merge(var.common_tags, {
    ArchitectureLayer = "Layer3-DataSecrets"
  })
}

# Layer 3 & 4: Compute & Container Workloads Boundary
resource "azurerm_resource_group" "compute" {
  name     = "rg-${var.project_name}-${var.environment}-compute-sea"
  location = var.location
  tags = merge(var.common_tags, {
    ArchitectureLayer = "Layer3-ComputeWorkloads"
  })
}

# Layer 4 & 5: Centralized Observability, Automation & ITSM Boundary
resource "azurerm_resource_group" "operations" {
  name     = "rg-${var.project_name}-${var.environment}-operations-sea"
  location = var.location
  tags = merge(var.common_tags, {
    ArchitectureLayer = "Layer5-OperationsITSM"
  })
}