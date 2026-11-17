# Standard Operating Procedure (SOP): Autonomous Incident Response & AKS Self-Healing

| Document ID | SOP-CLOUDOPS-005 | Version | 2.0 (Production) |
| :--- | :--- | :--- | :--- |
| **Target System** | Enterprise Core Banking Platform (`aks-banking-ops-prod-sea`) | **Audience** | L1 / L2 NOC & SRE Engineers |
| **Automation Engine** | Azure Automation (`aa-banking-ops-prod-sea`) | **ITSM Integration** | ServiceNow PDI (`logic-banking-ops-prod-itsm-sea`) |

---

## 1. Purpose & Operational Scope

This Standard Operating Procedure (SOP) defines the end-to-end triage, automated remediation, and manual fallback protocols for production incidents affecting the Core Banking Platform on Microsoft Azure (`southeastasia`).

The platform leverages an **Event-Driven Autonomous Remediation Architecture**:
1. **Detection:** Azure Monitor Scheduled Query (KQL) and Metric Alerts detect anomalies within 1–5 minutes.
2. **Orchestration:** Action Group `ag-banking-ops-prod-sea` dispatches parallel webhooks using the *Azure Monitor Common Alert Schema*.
3. **ITSM Governance:** Logic App `logic-banking-ops-prod-itsm-sea` automatically logs a tracked Incident in ServiceNow.
4. **Self-Healing:** Azure Automation Runbook `Remediate-AksBankingPods` executes a zero-downtime rolling restart on AKS (`<60s MTTR`).

---

## 2. Severity Matrix & SLA Targets

| Severity | Alert Rule Name | Trigger Condition | Automated Action | Target MTTR | Escalation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **P1 (Critical)** | `alert-p1-banking-http500-outage` | `CHAOS_EVENT_P1` or HTTP 500 count $\ge 1$ in 5m | ServiceNow Sev1 Ticket + Auto-Restart Runbook | **< 60 seconds** | Immediate Tier-2 SRE Page |
| **P1 (Critical)** | `alert-p1-aks-memory-oom-pressure` | Node memory working set $> 85\%$ or Pod `OOMKilled` | ServiceNow Sev1 Ticket + Auto-Restart Runbook | **< 60 seconds** | Immediate Tier-2 SRE Page |
| **P2 (High)** | `alert-p2-banking-high-latency-sla` | Downstream SQL lock latency $> 2500\text{ms}$ (`CHAOS_EVENT_P2`) | ServiceNow Sev2 Ticket + SRE Email Notification | **< 15 minutes** | L2 Database / App Triage |

---

## 3. L1 NOC Triage & Verification Workflow

When a P1/P2 alert arrives via Email or appears in the **ServiceNow Incident Queue**:

### Step 1: Validate ServiceNow ITSM Ticket Creation
1. Open the ServiceNow Developer Instance (PDI) **Incidents** table (`incident.list`).
2. Confirm a new ticket exists with `Category = Cloud Infrastructure`, `Subcategory = AKS Core Banking`, and `Short Description` matching `Azure CloudOps Alert: <AlertRuleName>`.
3. If the ticket is missing, inspect **Azure Portal $\rightarrow$ `logic-banking-ops-prod-itsm-sea` $\rightarrow$ Runs history** for HTTP `401` (credential mismatch) or `404` (PDI hibernating/asleep) responses.

### Step 2: Verify Autonomous Runbook Execution (`<60s MTTR`)
1. Navigate to **Azure Portal $\rightarrow$ `aa-banking-ops-prod-sea` $\rightarrow$ Process Automation $\rightarrow$ Jobs**.
2. Locate the latest job for **`Remediate-AksBankingPods`** triggered by webhook `wh-aks-banking-autoheal`.
3. Confirm the job status is **`Completed`** and verify the **Output** stream contains:
   ```text
   [AUTH] Authenticated to Azure Control Plane.
   [ACTION] Executing remote rollout restart on cluster 'aks-banking-ops-prod-sea'...
   deployment.apps/banking-app restarted
   [SUCCESS] Auto-Remediation completed (<60s MTTR target achieved).
   ```

### Step 3: Confirm Application & Data Plane Recovery
1. Query the live health and Private Link diagnostic endpoints:
   ```bash
   APP_IP=$(kubectl get svc banking-app-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   curl -s http://${APP_IP}/healthz
   curl -s http://${APP_IP}/api/verify-connections
   ```
2. **Expected Healthy State:**
   * `"status": "verified"`
   * `azure_sql_private_link.private_ip`: `"10.0.2.4"` (`tcp_1433_reachable: true`)
   * `in_cluster_redis.ping_success`: `true`
   * `csi_secret_store.mounted`: `true` (`redis-connection-string`, `sql-connection-string`)

---

## 4. L2 Manual Fallback Procedure (If Auto-Remediation Fails)

If the Automation Runbook job reports `Failed` or `Suspended`, L2 SRE engineers must execute manual recovery immediately:

### Option A: Manual Runbook Trigger via Azure CLI
```bash
az automation runbook start \
  --resource-group rg-banking-ops-prod-operations-sea \
  --automation-account-name aa-banking-ops-prod-sea \
  --name Remediate-AksBankingPods
```

### Option B: Direct Kubernetes Rollout Restart
```bash
# 1. Connect to AKS credentials
az aks get-credentials \
  --resource-group rg-banking-ops-prod-compute-sea \
  --name aks-banking-ops-prod-sea \
  --overwrite-existing

# 2. Verify pod states and inspect crash logs
kubectl get pods -n default -l app=banking-app -o wide
kubectl logs -n default -l app=banking-app --tail=50

# 3. Execute zero-downtime rolling restart (maxUnavailable=1, maxSurge=0)
kubectl rollout restart deployment/banking-app -n default
kubectl rollout status deployment/banking-app -n default
```

---

## 5. Incident Closure & Post-Mortem Criteria

Before transitioning the ServiceNow Incident state from **In Progress** to **Resolved**:
* [ ] Both replicas of `banking-app` report `1/1 Running` (`Ready: 2/2`).
* [ ] No new `CHAOS_EVENT_P1` or `OOMKilling` events appear in `law-banking-ops-prod-sea` for 10 consecutive minutes.
* [ ] Azure Monitor Alert state transitions automatically from **Fired** to **Resolved**.
* [ ] For any P1 outage lasting $> 5\text{ minutes}$, complete a Blameless RCA report using `docs/rca-incident-sample.md` within 24 hours.
