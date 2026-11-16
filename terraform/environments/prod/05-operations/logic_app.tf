# Provision Azure Logic App (Consumption) to ingest Azure Monitor Common Alert Schema payloads and create ITSM Incidents in ServiceNow PDI


# 1. Logic App Consumption Workflow
resource "azurerm_logic_app_workflow" "servicenow_itsm" {
  name                = "logic-${var.project_name}-${var.environment}-itsm-sea"
  location            = data.azurerm_resource_group.operations.location
  resource_group_name = data.azurerm_resource_group.operations.name

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Layer       = "Layer5-ITSM-ServiceNow"
  }
}

# 2. HTTP Request Trigger (Receives Azure Monitor Common Alert Schema JSON)
resource "azurerm_logic_app_trigger_http_request" "alert_webhook_trigger" {
  name         = "When_Azure_Monitor_Alert_Fires"
  logic_app_id = azurerm_logic_app_workflow.servicenow_itsm.id

  schema = jsonencode({
    type = "object"
    properties = {
      schemaId = { type = "string" }
      data = {
        type = "object"
        properties = {
          essentials = {
            type = "object"
            properties = {
              alertId           = { type = "string" }
              alertRule         = { type = "string" }
              severity          = { type = "string" }
              signalType        = { type = "string" }
              monitorCondition  = { type = "string" }
              monitoringService = { type = "string" }
              firedDateTime     = { type = "string" }
              description       = { type = "string" }
              alertTargetIDs    = { type = "array" }
            }
          }
        }
      }
    }
  })
}

# 3. HTTP Action: Dispatch Incident Creation Payload to ServiceNow PDI REST API
resource "azurerm_logic_app_action_http" "create_servicenow_incident" {
  name         = "Create_ServiceNow_ITSM_Incident"
  logic_app_id = azurerm_logic_app_workflow.servicenow_itsm.id
  method       = "POST"
  uri          = var.servicenow_incident_api_url

  headers = {
    "Content-Type" = "application/json"
    "Accept"       = "application/json"
    "Authorization" = "Basic ${base64encode("${var.servicenow_username}:${var.servicenow_password}")}"
  }

  body = jsonencode({
    short_description = "Azure CloudOps Alert: @{triggerBody()?['data']?['essentials']?['alertRule']}"
    description       = "Automated ITSM Incident created by Azure Logic App. Severity: @{triggerBody()?['data']?['essentials']?['severity']} | Condition: @{triggerBody()?['data']?['essentials']?['monitorCondition']} | Details: @{triggerBody()?['data']?['essentials']?['description']}"
    urgency           = "1"
    impact            = "1"
    category          = "Cloud Infrastructure"
    subcategory       = "AKS Core Banking"
  })
}