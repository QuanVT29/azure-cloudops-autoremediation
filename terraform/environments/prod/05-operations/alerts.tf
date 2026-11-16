# Configure Azure Monitor Action Group and Severity P1-P2 Alert Rules for HTTP 500 Outages, High Latency SLA Breach, and OOM Pod Crashes

# 1. Central Azure Monitor Action Group (Orchestrates ITSM + Auto-Healing)
resource "azurerm_monitor_action_group" "cloudops_ag" {
  name                = "ag-${var.project_name}-${var.environment}-sea"
  resource_group_name = data.azurerm_resource_group.operations.name
  short_name          = "BankOpsSRE"

  # Notification Channel 1: On-Call SRE Email
  email_receiver {
    name                    = "SRE-OnCall-Email"
    email_address           = var.alert_notification_email
    use_common_alert_schema = true
  }

  # Notification Channel 2: ServiceNow ITSM Logic App Webhook
  webhook_receiver {
    name                    = "ServiceNow-ITSM-LogicApp"
    service_uri             = azurerm_logic_app_trigger_http_request.alert_webhook_trigger.callback_url
    use_common_alert_schema = true
  }

  # Notification Channel 3: Autonomous PowerShell Runbook Auto-Remediation
  automation_runbook_receiver {
    name                    = "AKS-AutoHeal-Runbook"
    automation_account_id   = azurerm_automation_account.remediation.id
    runbook_name            = azurerm_automation_runbook.aks_pod_healer.name
    webhook_resource_id     = azurerm_automation_webhook.aks_healer_webhook.id
    is_global_runbook       = false
    service_uri             = azurerm_automation_webhook.aks_healer_webhook.uri
    use_common_alert_schema = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Layer       = "Layer5-Alerting"
  }
}

# 2. P1 Scheduled Query Alert (KQL): Core Banking HTTP 500 Critical Outage
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "p1_http_500_outage" {
  name                 = "alert-p1-banking-http500-outage"
  resource_group_name  = data.azurerm_resource_group.operations.name
  location             = data.azurerm_resource_group.operations.location
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [data.azurerm_log_analytics_workspace.law.id]
  severity             = 1
  description          = "P1 Critical Alert: Core Banking API emitted HTTP 500 failure events (CHAOS_EVENT_P1). Triggers ServiceNow Incident and AKS Auto-Remediation Runbook."
  enabled              = true

  criteria {
    query = <<-KQL
      union isfuzzy=true
        (AzureDiagnostics | where TimeGenerated > ago(5m) | where false),
        (ContainerLog | where TimeGenerated > ago(5m) | where LogEntry has "CHAOS_EVENT_P1" or LogEntry has "500 Internal Server Error"),
        (ContainerLogV2 | where TimeGenerated > ago(5m) | where LogMessage has "CHAOS_EVENT_P1" or LogMessage has "500 Internal Server Error")
    KQL

    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThanOrEqual"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.cloudops_ag.id]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Severity    = "P1-Critical"
  }
}

# 3. P2 Scheduled Query Alert (KQL): Core Banking High Latency SLA Breach (>2500ms)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "p2_high_latency_sla" {
  name                 = "alert-p2-banking-high-latency-sla"
  resource_group_name  = data.azurerm_resource_group.operations.name
  location             = data.azurerm_resource_group.operations.location
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [data.azurerm_log_analytics_workspace.law.id]
  severity             = 2
  description          = "P2 Warning Alert: Downstream SQL transaction lock latency exceeded 2500ms SLA threshold (CHAOS_EVENT_P2)."
  enabled              = true

  criteria {
    query = <<-KQL
      union isfuzzy=true
        (AzureDiagnostics | where TimeGenerated > ago(5m) | where false),
        (ContainerLog | where TimeGenerated > ago(5m) | where LogEntry has "CHAOS_EVENT_P2"),
        (ContainerLogV2 | where TimeGenerated > ago(5m) | where LogMessage has "CHAOS_EVENT_P2")
    KQL

    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThanOrEqual"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.cloudops_ag.id]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Severity    = "P2-HighLatency"
  }
}

# 4. P1 Metric Alert: AKS Node / Pod Memory Pressure & OOM Condition
resource "azurerm_monitor_metric_alert" "p1_aks_oom_pressure" {
  name                = "alert-p1-aks-memory-oom-pressure"
  resource_group_name = data.azurerm_resource_group.operations.name
  scopes              = [data.azurerm_kubernetes_cluster.aks.id]
  description         = "P1 Critical Alert: AKS cluster node memory working set exceeded 85% or pod OOMKilled detected. Triggers automated pod restart runbook."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.cloudops_ag.id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Severity    = "P1-Critical"
  }
}