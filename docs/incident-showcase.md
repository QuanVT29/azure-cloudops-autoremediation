### Live Verification Matrix (Monitoring & Incident Response)

| Scenario | Trigger Mechanism | Automated Response | Verified Result | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **Telemetry & APM** | Live Banking Traffic | Container Insights + App Insights + KQL ingestion | Real-time visibility (`0.5GB/day` cap) | [View Command Center](./docs/incident-showcase.md#1-observability-command-center-full-stack-telemetry) |
| **P1: API Outage** | `Trigger P1 Outage (HTTP 500)` | KQL Alert (`Sev1`) $\rightarrow$ ServiceNow Ticket $\rightarrow$ Runbook Restart | **MTTR: 42s** (Zero downtime) | [View P1 HTTP 500 Demo](./docs/incident-showcase.md#2-incident-scenario-1-p1-critical-api-outage-http-500) |
| **P1: Memory Crash** | `Trigger OOM Crash` | `OOMKilling` detection $\rightarrow$ HA failover $\rightarrow$ Pod replacement | **2/2 Ready** restored | [View P1 OOM Demo](./docs/incident-showcase.md#3-incident-scenario-2-p1-container-oom-crash-crashloopbackoff) |
| **P2: SLA Latency** | `Trigger High Latency (>3.5s)` | KQL Alert (`Sev2`) $\rightarrow$ ServiceNow Ticket $\rightarrow$ L2 DBA Triage | Smart triage (No blind restart) | [View P2 Latency Demo](./docs/incident-showcase.md#4-incident-scenario-3-p2-performance-sla-breach-35s-latency) |

* **Day-2 Operational Runbooks:** [KQL Diagnostic Playbook](./kql-diagnostic-playbook.md) | [L1/L2 NOC Runbook SOP](./runbook-sop.md) | [Sample P1 Post-Mortem RCA](./rca-incident-sample.md)


<br>

# Live Demo Walkthrough: Observability & Autonomous Incident Response

This walkthrough demonstrates the end-to-end **Closed-Loop Incident Management** lifecycle on the Core Banking Platform (`aks-banking-ops-prod-sea`):

```text
Chaos Fault Injection ──▶ Log Analytics (KQL) ──▶ Azure Monitor Alert (P1/P2) ──▶ ServiceNow ITSM Ticket + PowerShell Auto-Healing (<60s MTTR)
```

---

## 1. Observability Command Center (Full-Stack Telemetry)

Before injecting faults, full-stack telemetry is verified across **Log Analytics Workspace (`law-banking-ops-prod-sea`)**, **Container Insights**, and **Application Insights (`appi-banking-ops-prod-sea`)** to ensure zero blind spots across AKS pods and downstream data dependencies.

![Observability Command Center](./images/01-observability-command-center.png)
> **📸 Screenshot Note (`01-observability-command-center.png`):** *Chụp màn hình Azure Portal tại `law-banking-ops-prod-sea` (mục **Logs** hiển thị các bảng `ContainerLogV2`, `KubeEvents` hoặc biểu đồ **Application Map** trong Application Insights).*

---



<br>

## 2. Incident Scenario #1: P1 Critical API Outage (HTTP 500)

* **Objective:** Simulate a severe transaction pipeline failure (`HTTP 500`) and verify automated detection, ServiceNow incident logging, and autonomous pod recovery in under 60 seconds.
* **Trigger:** Click **`Trigger P1 Outage (HTTP 500)`** on the SRE Chaos Simulator (or run `./scripts/chaos-test.sh 500 5`).

### Step 2.1: Fault Injection & KQL Detection
The FastAPI worker emits `CHAOS_EVENT_P1` error logs, which are ingested into Log Analytics and matched by the scheduled KQL alert rule `alert-p1-banking-http500-outage`.

![P1 Fault Injection and KQL Query](./images/demo/02a-p1-chaos-kql.png)
> **📸 Screenshot Note (`02a-p1-chaos-kql.png`):** *Chụp ghép hoặc chụp màn hình khung **Live SRE Telemetry Console** trên Web báo lỗi đỏ `[HTTP 500]` cùng kết quả truy vấn KQL tìm thấy `CHAOS_EVENT_P1` trong Log Analytics.*

### Step 2.2: Azure Monitor Alert & Automated ServiceNow ITSM Ticket
Action Group `ag-banking-ops-prod-sea` triggers Logic App `logic-banking-ops-prod-itsm-sea`, automatically creating a **Sev1 Incident** in ServiceNow PDI via the Table API.

![Azure Monitor Alert and ServiceNow Ticket](./images/demo/02b-p1-alert-servicenow.png)
> **📸 Screenshot Note (`02b-p1-alert-servicenow.png`):** *Chụp trạng thái **Fired** của `alert-p1-banking-http500-outage` (hoặc Logic App **Runs history** xanh) kèm phiếu sự cố **Incident** mới tạo trên giao diện ServiceNow.*

### Step 2.3: Autonomous Pod Recovery (`<60s MTTR`)
Simultaneously, Azure Automation Runbook **`Remediate-AksBankingPods`** authenticates via System-Assigned Managed Identity and executes `kubectl rollout restart deployment/banking-app`.

![Runbook Execution and Pod Replacement](./images/demo/02c-p1-runbook-recovery.png)
> **📸 Screenshot Note (`02c-p1-runbook-recovery.png`):** *Chụp tab **Output** của Job `Remediate-AksBankingPods` báo `[SUCCESS] Auto-Remediation completed` kèm góc trên bên phải Web Dashboard hiển thị tên **Pod mới** sau khi Refresh.*

---


<br>

## 3. Incident Scenario #2: P1 Container OOM Crash (`CrashLoopBackOff`)

* **Objective:** Validate High Availability (HA) continuity and self-healing when a container exceeds its `512Mi` memory limit and is terminated by the Linux `OOMKiller` (Exit Code `137`).
* **Trigger:** Click **`Trigger OOM Crash (CrashLoopBackOff)`** on the Web Dashboard (or run `./scripts/chaos-test.sh oom`).
* **Result:** Traffic seamlessly fails over to the healthy replica (`maxUnavailable: 1, maxSurge: 0`), while `alert-p1-aks-memory-oom-pressure` triggers automated pod replacement back to **`Ready: 2/2`**.

![P1 OOM Crash and HA Recovery](./images/demo/03-p1-oom-recovery.png)
> **📸 Screenshot Note (`03-p1-oom-recovery.png`):** *Chụp terminal `kubectl get pods -l app=banking-app` (hoặc Azure Portal **Workloads**) cho thấy Pod cũ bị `OOMKilled` và tự động hồi phục về trạng thái `2/2 Running`.*

---


<br>

## 4. Incident Scenario #3: P2 Performance SLA Breach (`>3.5s` Latency)

* **Objective:** Demonstrate intelligent SRE triage differentiation—distinguishing performance degradation (`P2`) from hard outages (`P1`).
* **Trigger:** Click **`Trigger High Latency (>3.5s)`** on the Web Dashboard (or run `./scripts/chaos-test.sh latency 3`).
* **Result:** Alert rule `alert-p2-banking-high-latency-sla` detects `CHAOS_EVENT_P2` (`3500ms > 2500ms` SLA threshold) and logs a **Sev2 ServiceNow Incident** for L2 DBA/Application investigation **without** blindly restarting healthy pods.

![P2 High Latency Triage](./images/demo/04-p2-latency-triage.png)
> **📸 Screenshot Note (`04-p2-latency-triage.png`):** *Chụp màn hình dòng log cảnh báo `3500ms` trên Web Console / KQL query kèm phiếu **Sev2** trên ServiceNow (hoặc email cảnh báo P2).*

---

<br>

## 5. Standard Operating Procedures & Post-Mortem Artifacts

* **[KQL Diagnostic Playbook](./kql-diagnostic-playbook.md):** Ready-to-run KQL queries for container errors, `OOMKilled` events, and Key Vault CSI audit logs.
* **[L1/L2 NOC Runbook SOP](./runbook-sop.md):** Escalation matrix, automated verification steps, and manual CLI fallback procedures.
* **[Sample P1 Post-Mortem RCA](./rca-incident-sample.md):** Full incident timeline, 5-Whys root cause analysis, and preventive CAPA items.
