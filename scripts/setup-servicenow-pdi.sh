#!/usr/bin/env bash
# Purpose: Automated Table API & Logic App Common Alert Schema payload generator
# Usage:   ./scripts/setup-servicenow-pdi.sh [LOGIC_APP_CALLBACK_URL]
set -euo pipefail

WEBHOOK_URL="${1:-}"

if [[ -z "$WEBHOOK_URL" ]]; then
  echo "[INFO] Fetching Logic App Callback URL from Terraform 05-operations state..."
  WEBHOOK_URL=$(terraform -chdir=terraform/environments/prod/05-operations output -raw logic_app_itsm_trigger_url 2>/dev/null || true)
fi

if [[ -z "$WEBHOOK_URL" ]]; then
  echo "[ERROR] Logic App Trigger URL not provided and not found in Terraform output."
  echo "Usage: $0 <LOGIC_APP_CALLBACK_URL>"
  exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ALERT_ID="alert-sim-$(date +%s)"

read -r -d '' PAYLOAD <<EOF || true
{
  "schemaId": "azureMonitorCommonAlertSchema",
  "data": {
    "essentials": {
      "alertId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.AlertsManagement/alerts/${ALERT_ID}",
      "alertRule": "alert-p1-banking-http500-outage",
      "severity": "Sev1",
      "signalType": "Log",
      "monitorCondition": "Fired",
      "monitoringService": "Log Alerts V2",
      "alertTargetIDs": [
        "/subscriptions/93bff653-3d53-4224-8fe9-6c02e7b6a5ce/resourcegroups/rg-banking-ops-prod-compute-sea/providers/microsoft.containerservice/managedclusters/aks-banking-ops-prod-sea"
      ],
      "firedDateTime": "${TIMESTAMP}",
      "description": "P1 Critical Alert: Core Banking API emitted HTTP 500 failure events (CHAOS_EVENT_P1). Automated ServiceNow Incident & Runbook remediation triggered."
    }
  }
}
EOF

echo "[ITSM TEST] Dispatching simulated P1 Common Alert Schema payload to Logic App..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "[RESULT] Logic App HTTP Response Code: ${HTTP_STATUS} (Expected: 200 or 202)"