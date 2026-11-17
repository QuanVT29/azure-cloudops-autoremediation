### Live Verification Matrix (Monitoring & Incident Response)

| Scenario | Trigger Mechanism | Automated Response | Verified Result | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **Telemetry & APM** | Live Banking Traffic | Container Insights + App Insights + KQL ingestion | Real-time visibility (`0.5GB/day` cap) | [View Command Center](./docs/incident-showcase.md#1-observability-command-center-full-stack-telemetry) |
| **P1: API Outage** | `Trigger P1 Outage (HTTP 500)` | KQL Alert (`Sev1`) $\rightarrow$ ServiceNow Ticket $\rightarrow$ Runbook Restart | **MTTR: 42s** (Zero downtime) | [View P1 HTTP 500 Demo](./docs/incident-showcase.md#2-incident-scenario-1-p1-critical-api-outage-http-500) |
| **P1: Memory Crash** | `Trigger OOM Crash` | `OOMKilling` detection $\rightarrow$ HA failover $\rightarrow$ Pod replacement | **2/2 Ready** restored | [View P1 OOM Demo](./docs/incident-showcase.md#3-incident-scenario-2-p1-container-oom-crash-crashloopbackoff) |
| **P2: SLA Latency** | `Trigger High Latency (>3.5s)` | KQL Alert (`Sev2`) $\rightarrow$ ServiceNow Ticket $\rightarrow$ L2 DBA Triage | Smart triage (No blind restart) | [View P2 Latency Demo](./docs/incident-showcase.md#4-incident-scenario-3-p2-performance-sla-breach-35s-latency) |

* **Day-2 Operational Runbooks:** [KQL Diagnostic Playbook](./kql-diagnostic-playbook.md) | [L1/L2 NOC Runbook SOP](./docs/runbook-sop.md) | [Sample P1 Post-Mortem RCA](./docs/rca-incident-sample.md)
