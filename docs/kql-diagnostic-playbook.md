# KQL Diagnostic Playbook & Root Cause Triage Catalog

**Platform:** Enterprise Core Banking Platform (Azure AKS & Zero-Trust Data Plane)  
**Target Workspace:** `law-banking-ops-prod-sea` (`rg-banking-ops-prod-operations-sea`)  
**Telemetry Sources:** Container Insights (`ContainerLogV2` / `ContainerLog`), AKS Control Plane Diagnostics, Azure Key Vault Audit Logs, and Application Insights.

---

## 1. Application-Level Fault & Error Triage (Core Banking API)

### 1.1. Detect P1 Critical HTTP 500 Pipeline Failures (`CHAOS_EVENT_P1`)
**Use Case:** Identify which AKS pod emitted HTTP 500 errors and verify whether the P1 alert threshold was breached.

```kql
union isfuzzy=true
    (ContainerLogV2
    | where TimeGenerated > ago(30m)
    | where PodNamespace == "default" and ContainerName == "banking-api"
    | where LogMessage has "CHAOS_EVENT_P1" or LogMessage has "500 Internal Server Error"
    | project TimeGenerated, PodName, LogLevel = "ERROR", Message = LogMessage),
    (ContainerLog
    | where TimeGenerated > ago(30m)
    | where LogEntry has "CHAOS_EVENT_P1" or LogEntry has "500 Internal Server Error"
    | project TimeGenerated, PodName = Computer, LogLevel = "ERROR", Message = LogEntry)
| order by TimeGenerated desc
```

### 1.2. Track Downstream SQL Lock & High Latency SLA Breaches (>2500ms)
**Use Case:** Investigate P2 warnings where transaction processing exceeded the 2500ms SLA threshold (`CHAOS_EVENT_P2`).

```kql
union isfuzzy=true
    (ContainerLogV2
    | where TimeGenerated > ago(1h)
    | where LogMessage has "CHAOS_EVENT_P2" or LogMessage has "3500ms"
    | project TimeGenerated, PodName, Message = LogMessage),
    (ContainerLog
    | where TimeGenerated > ago(1h)
    | where LogEntry has "CHAOS_EVENT_P2" or LogEntry has "3500ms"
    | project TimeGenerated, PodName = Computer, Message = LogEntry)
| summarize IncidentCount = count(), FirstSeen = min(TimeGenerated), LastSeen = max(TimeGenerated) by PodName
```

### 1.3. Audit Real-Time Wire Settlement Transactions
**Use Case:** Trace simulated SWIFT/ACH wire settlements processed by `banking-app` pods and cached in In-Cluster Redis.

```kql
union isfuzzy=true
    (ContainerLogV2
    | where TimeGenerated > ago(1h)
    | where LogMessage has "Processed new transaction"
    | project TimeGenerated, PodName, TransactionLog = LogMessage),
    (ContainerLog
    | where TimeGenerated > ago(1h)
    | where LogEntry has "Processed new transaction"
    | project TimeGenerated, PodName = Computer, TransactionLog = LogEntry)
| order by TimeGenerated desc
| take 50
```

---

## 2. Kubernetes Infrastructure & Pod Stability Triage

### 2.1. Identify OOMKilled, CrashLoopBackOff, and FailedScheduling Events
**Use Case:** Diagnose sudden pod terminations caused by memory exhaustion (`CHAOS_EVENT_OOM`) or single-node CPU scheduling bottlenecks.

```kql
KubeEvents
| where TimeGenerated > ago(1h)
| where Namespace == "default"
| where Reason in ("OOMKilling", "BackOff", "FailedScheduling", "Unhealthy", "Killing")
| project TimeGenerated, Name, Reason, Message, Count
| order by TimeGenerated desc
```

### 2.2. Monitor Pod Restart Velocity & Container Inventory
**Use Case:** Confirm whether the Autonomous Runbook (`Remediate-AksBankingPods`) successfully rolled out healthy replacement pods.

```kql
KubePodInventory
| where TimeGenerated > ago(30m)
| where Namespace == "default" and Name startswith "banking-app"
| summarize
    LatestStatus = arg_max(TimeGenerated, PodStatus, ContainerStatus, ContainerRestartCount, PodIp, Computer)
    by Name
| project Name, PodStatus, ContainerStatus, ContainerRestartCount, PodIp, Node = Computer, LastHeartbeat = TimeGenerated
```

### 2.3. AKS System Node Memory & CPU Saturation (`Standard_DC2ds_v3`)
**Use Case:** Correlate pod-level memory spikes against the 85% node memory working-set threshold configured in `alert-p1-aks-memory-oom-pressure`.

```kql
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "K8SNode"
| where CounterName in ("memoryWorkingSetBytes", "cpuUsageNanoCores")
| summarize AvgValue = avg(CounterValue), MaxValue = max(CounterValue) by bin(TimeGenerated, 1m), Computer, CounterName
| order by TimeGenerated desc
```

---

## 3. Zero-Trust Security & Control Plane Audit Triage

### 3.1. Audit Secretless Key Vault CSI Driver Access (`kv-bank-prod-*`)
**Use Case:** Verify that only the authorized AKS CSI Secrets Provider Managed Identity (`id-banking-ops-prod-sea` / CSI identity) is retrieving `sql-connection-string` and `redis-connection-string`, and detect any `403 Forbidden` unauthorized access attempts.

```kql
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName in ("SecretGet", "SecretList")
| project TimeGenerated, Resource, OperationName, ResultType, ResultSignature, CallerIPAddress, identity_claim_appid_g
| order by TimeGenerated desc
```

### 3.2. Track AKS Control Plane Remote Remediation Executions (`Invoke-AzAksRunCommand`)
**Use Case:** Audit when the Azure Automation Account (`aa-banking-ops-prod-sea`) authenticated via System-Assigned Managed Identity and executed `kubectl rollout restart`.

```kql
AzureDiagnostics
| where TimeGenerated > ago(2h)
| where Category == "kube-audit-admin"
| where log_s has "deployments" and log_s has "banking-app"
| project TimeGenerated, Category, log_s
| order by TimeGenerated desc
```

---

## 4. FinOps Observability Guardrail Verification

### 4.1. Daily Ingestion Volume vs. 0.5 GB FinOps Cap
**Use Case:** Ensure daily telemetry ingestion remains well below the `0.5 GB/day` quota configured on `law-banking-ops-prod-sea`.

```kql
Usage
| where TimeGenerated > ago(7d)
| where IsBillable == true
| summarize TotalIngestedMB = round(sum(Quantity), 2) by bin(TimeGenerated, 1d), DataType
| order by TimeGenerated desc, TotalIngestedMB desc
```
