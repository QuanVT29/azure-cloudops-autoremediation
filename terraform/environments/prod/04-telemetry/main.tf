# Provision Log Analytics Workspace, Container Insights, App Insights, and Diagnostic Settings for AKS and Key Vault (Layer 4)

# 1. Central Log Analytics Workspace (KQL Query Engine)
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project_name}-${var.environment}-sea"
  location            = data.azurerm_resource_group.operations.location
  resource_group_name = data.azurerm_resource_group.operations.name
  sku                 = "PerGB2018"
  retention_in_days   = var.law_retention_days
  daily_quota_gb      = var.law_daily_quota_gb

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Layer       = "Layer4-Observability"
    FinOpsCap   = "${var.law_daily_quota_gb}GB-Daily"
  }
}

# 2. Container Insights Solution for Kubernetes Telemetry
resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = data.azurerm_resource_group.operations.location
  resource_group_name   = data.azurerm_resource_group.operations.name
  workspace_resource_id = azurerm_log_analytics_workspace.law.id
  workspace_name        = azurerm_log_analytics_workspace.law.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Layer       = "Layer4-Observability"
  }
}

# 3. Application Insights (Workspace-Based APM & Distributed Tracing)
resource "azurerm_application_insights" "appinsights" {
  name                = "appi-${var.project_name}-${var.environment}-sea"
  location            = data.azurerm_resource_group.operations.location
  resource_group_name = data.azurerm_resource_group.operations.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  retention_in_days   = var.law_retention_days

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Layer       = "Layer4-Observability"
  }
}

# 4. Diagnostic Settings: Stream AKS Control Plane Logs & Metrics to LAW
resource "azurerm_monitor_diagnostic_setting" "aks_diag" {
  name                       = "diag-aks-to-law"
  target_resource_id         = data.azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# 5. Diagnostic Settings: Stream Key Vault Zero-Trust Audit Logs to LAW
resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  name                       = "diag-keyvault-to-law"
  target_resource_id         = data.azurerm_key_vault.vault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}