# Root Cause Analysis (RCA) & P1 Post-Mortem Report

| Incident ID | INC0010482 (ServiceNow PDI) | Severity | **P1 – Critical** |
| :--- | :--- | :--- | :--- |
| **Incident Title** | Core Banking API HTTP 500 Pipeline Failure & Pod OOM Memory Exhaustion | **Environment** | Production (`southeastasia`) |
| **Affected Service** | `banking-app` (`aks-banking-ops-prod-sea`) | **Incident Commander** | Võ Tá Minh Quân (CloudOps / SRE) |
| **Detection Method** | Azure Monitor Scheduled Query Alert (`alert-p1-banking-http500-outage`) | **Total MTTR** | **42 seconds** (Target: `< 60s`) |

---

## 1. Executive Summary

On **November 17, 2026**, the Core Banking API (`banking-app`) deployed on Azure Kubernetes Service (`aks-banking-ops-prod-sea`) experienced a simulated P1 transaction pipeline failure (`CORE_BANKING_PIPELINE_FAILURE` / HTTP 500) followed by rapid container memory exhaustion (`OOMKilled`) on replica `banking-app-5897c48658-9x48p`.

Because the deployment is configured with two replicas behind an Azure Standard Load Balancer and protected by an autonomous remediation pipeline, **end-user availability remained uninterrupted** via the healthy sibling pod (`banking-app-5897c48658-nkgzh`). Azure Monitor detected the error stream, automatically logged a P1 Incident in ServiceNow via Azure Logic Apps, and invoked the PowerShell Runbook `Remediate-AksBankingPods` to replace the degraded container within **42 seconds**.

---

## 2. Impact Assessment

* **Customer / End-User Impact:** Minimal. Transient HTTP 500 errors occurred only on targeted fault-injection requests (`3` failed API calls). Standard settlement traffic continued routing to the healthy replica.
* **Data Plane Integrity:** **Zero data loss.** Azure SQL Serverless (`10.0.2.4`) and In-Cluster Redis (`redis-service:6379`) remained healthy throughout the event.
* **Security Posture:** **No breach.** Key Vault (`kv-bank-prod-hrpig3`) and CSI Secrets Store volumes remained isolated inside `snet-data` / `snet-aks`.

---

## 3. Incident Timeline (All Times UTC)

| Timestamp (UTC) | Event Description | System / Actor |
| :--- | :--- | :--- |
| **08:10:02** | Fault injection scenario initiated (`POST /api/fault/500` & `POST /api/fault/oom`), emitting `CHAOS_EVENT_P1` to stdout. | SRE Chaos Simulator |
| **08:10:04** | Container memory allocation breached the `512Mi` cgroup limit; Linux kernel invoked `OOMKiller` (Exit Code `137`). | AKS Node (`vmss000000`) |
| **08:11:15** | Container Insights (`ama-logs`) ingested `CHAOS_EVENT_P1` records into Log Analytics Workspace `law-banking-ops-prod-sea`. | Azure Monitor Agent |
| **08:12:00** | Scheduled Query Rule `alert-p1-banking-http500-outage` evaluated count $\ge 1$ and transitioned to **Fired (Sev1)**. | Azure Monitor |
| **08:12:02** | Action Group `ag-banking-ops-prod-sea` dispatched parallel webhooks to Logic App and Automation Account. | Azure Monitor Action Group |
| **08:12:04** | Logic App `logic-banking-ops-prod-itsm-sea` authenticated to ServiceNow Table API and created **`INC0010482`**. | Azure Logic App |
| **08:12:06** | Runbook `Remediate-AksBankingPods` authenticated via System-Assigned Managed Identity and invoked `Invoke-AzAksRunCommand`. | Azure Automation |
| **08:12:31** | Kubernetes executed `kubectl rollout restart deployment/banking-app` (`maxUnavailable=1, maxSurge=0`). | AKS Control Plane |
| **08:12:44** | Replacement pod passed `/healthz` readiness probe (`2/2 Ready`) and `/api/verify-connections` confirmed Private Link connectivity. | Kubernetes Readiness Probe |

---

## 4. Root Cause Analysis (5 Whys)

1. **Why did the Core Banking API return HTTP 500 and terminate?**  
   Because an unbounded in-memory byte array allocation (`_memory_leak_store`) was triggered on the FastAPI worker process during chaos testing, exhausting the container's `512Mi` memory limit.
2. **Why did the second replica briefly remain in `Pending` state during recovery?**  
   Enabling the Container Insights (`monitoring`) add-on consumed additional CPU reservations on the single `Standard_DC2ds_v3` (2 vCPU) FinOps node, leaving insufficient allocatable CPU for a `100m` pod request.
3. **Why did the service avoid a total outage during the pod crash?**  
   The Kubernetes Deployment maintained `replicas: 2` with a rolling update policy of `maxUnavailable: 1, maxSurge: 0`, ensuring at least one pod remained active on the single node at all times.
4. **Why was manual engineer intervention unnecessary?**  
   The Azure Automation Account's System-Assigned Managed Identity held `Azure Kubernetes Service Cluster Admin Role`, enabling the PowerShell Runbook to trigger a remote rolling restart immediately upon receiving the Azure Monitor Webhook.

---

## 5. Corrective & Preventive Action Items

| Action ID | Remediation Task | Owner | Status |
| :--- | :--- | :--- | :--- |
| **CAPA-01** | Right-size pod CPU/Memory requests in `03-banking-app.yaml` (`50m` CPU / `96Mi` RAM) to coexist cleanly with Container Insights agents on single-node FinOps clusters. | CloudOps / SRE | **Completed** |
| **CAPA-02** | Enforce strict container memory limits (`512Mi`) and automated Liveness/Readiness probes (`/healthz`) across all microservices. | Platform Team | **Completed** |
| **CAPA-03** | Integrate `docs/kql-diagnostic-playbook.md` and `docs/runbook-sop.md` into ServiceNow incident runbook links for L1 NOC triage. | SRE Operations | **Completed** |
| **CAPA-04** | Configure Horizontal Pod Autoscaler (HPA) and multi-node user pools when transitioning from FinOps lab budget (`$5`) to full production load. | Cloud Architect | **Planned (Phase 2)** |
