# Provision Azure Automation Account, System Managed Identity RBAC on AKS, PowerShell Auto-Healing Runbook, and Webhook Trigger (Layer 5)


# 1. Azure Automation Account with System-Assigned Managed Identity
resource "azurerm_automation_account" "remediation" {
  name                = "aa-${var.project_name}-${var.environment}-sea"
  location            = data.azurerm_resource_group.operations.location
  resource_group_name = data.azurerm_resource_group.operations.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Layer       = "Layer5-AutoRemediation"
  }
}

# 2. RBAC: Grant Automation Account Identity permission to execute AKS Run Command
resource "azurerm_role_assignment" "automation_aks_contributor" {
  scope                = data.azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.remediation.identity[0].principal_id
}

resource "azurerm_role_assignment" "automation_aks_cluster_admin" {
  scope                = data.azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = azurerm_automation_account.remediation.identity[0].principal_id
}

# 3. PowerShell Runbook for Autonomous Pod Rollout Restart (<60s MTTR)
resource "azurerm_automation_runbook" "aks_pod_healer" {
  name                    = "Remediate-AksBankingPods"
  location                = data.azurerm_resource_group.operations.location
  resource_group_name     = data.azurerm_resource_group.operations.name
  automation_account_name = azurerm_automation_account.remediation.name
  log_verbose             = true
  log_progress            = true
  description             = "Autonomous SRE Runbook to restart degraded Core Banking pods on AKS (<60s MTTR)."
  runbook_type            = "PowerShell"

  content = file("${path.module}/../../../../scripts/remediate-aks-pods.ps1")

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Layer       = "Layer5-AutoRemediation"
  }
}

# 4. Time window calculation for Webhook validity (1 year from deployment)
resource "time_static" "webhook_expiry" {}

locals {
  webhook_expiry_time = timeadd(time_static.webhook_expiry.rfc3339, "8760h")
}

# 5. Automation Webhook to connect Azure Monitor Action Group -> PowerShell Runbook
resource "azurerm_automation_webhook" "aks_healer_webhook" {
  name                    = "wh-aks-banking-autoheal"
  resource_group_name     = data.azurerm_resource_group.operations.name
  automation_account_name = azurerm_automation_account.remediation.name
  expiry_time             = local.webhook_expiry_time
  enabled                 = true
  runbook_name            = azurerm_automation_runbook.aks_pod_healer.name
}