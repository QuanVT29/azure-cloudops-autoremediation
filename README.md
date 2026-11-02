# Autonomous Cloud Operations & Auto-Remediation Platform

[![Azure](https://img.shields.io/badge/Cloud-Microsoft%20Azure-0078D4?logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20100%25-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Orchestration-AKS%20v1.30+-326CE5?logo=kubernetes&logoColor=white)](https://azure.microsoft.com/services/kubernetes-service/)
[![ServiceNow](https://img.shields.io/badge/ITSM-ServiceNow%20PDI-81B5A1?logo=servicenow&logoColor=white)](https://developer.servicenow.com/)
[![FinOps](https://img.shields.io/badge/FinOps-Guardrails%20%245%20Alert-green)](#finops--cost-optimization)

An enterprise-grade, autonomous Cloud Operations and site-reliability platform designed for high-availability core banking workloads (committed **SLA 99.99%**). 

The infrastructure is provisioned **100% via Modular Terraform** across a 5-layer decoupled architecture, featuring automated distributed telemetry, ITIL incident management via **ServiceNow**, and self-healing closed loops (**Auto-Remediation**) achieving a verified **MTTR of under 60 seconds**.

---

## Architecture Blueprint

The platform implements a resilient, zero-trust cloud architecture spanning 5 distinct operational layers:

![](azure-cloudops-autoremediation/images/azure-architecture.png)


<br>



---

## Layer-by-Layer Architectural Specifications

### Layer 1: Governance & Zero-Trust Identity
* **Resource Partitioning:** Structured resource grouping (`rg-network`, `rg-compute`, `rg-data`, `rg-operations`) enabling granular lifecycle control and non-destructive rolling updates.
* **Secretless Identity:** All inter-service communications authenticate via **User-Assigned Managed Identity** requesting short-lived JWT tokens from Azure IMDS (`169.254.169.254`), eliminating static credentials.
* **FinOps Guardrails:** Automated deployment gate enforced via Azure Policy (restricting workloads to `southeastasia` and blocking unapproved VM SKUs) coupled with multi-stage Budget consumption alerts ($2.50, $4.00, $5.00).

### Layer 2: Core Networking & Access Control
* **VNet Architecture:** `10.0.0.0/16` space micro-segmented into dedicated subnets (`snet-aks`, `snet-data`, `snet-mgmt`).
* **Ingress Lockdown:** Inbound management ports are restricted at the perimeter via Network Security Groups (NSGs) and Application Security Groups (ASGs).
* **Bastion Jumpbox:** An ephemeral Linux `Standard_B1s` instance acts as the administrative jumping point; only authorized public IP addresses are permitted on Port 22.

### Layer 3: Secured Secrets & State Storage
* **Azure Key Vault:** Provisioned with Azure RBAC authorization model, purge protection, and soft delete enabled.
* **CSI Secrets Store Driver:** Automatically mounts application secrets and connection strings into container pods as in-memory volumes, preventing disk spills and plain-text exposure in YAML manifests.
* **State Persistence:** Ephemeral caching handled by **Azure Cache for Redis (C0)**, while relational transactional data is secured inside **Azure SQL Database Serverless** configured with automated pause (after 60 mins idle) to optimize credit retention.

### Layer 4: Full-Stack Observability & Telemetry
* **Centralized Data Plane:** Multi-source ingestion via **Log Analytics Workspace (LAW)** receiving system metrics, AKS diagnostic streams, and audit trails.
* **Distributed Tracing:** Auto-instrumented **Application Insights** mapping the end-to-end dependency chain: `Browser Ingress -> Banking Pod -> Redis Cache -> SQL Serverless`.
* **KQL Analytical Queries:** Customized Kusto queries extracting high-priority fault signals (`ContainerLogV2`, `KubeEvents`, `AppRequests`).

### Layer 5: Closed-Loop Auto-Remediation & ITSM Integration
* **Multi-Tier Alerting Matrix:** Categorized into four standard severity tiers (P1: Critical Outage, P2: Dependency Latency, P3: Infrastructure Strain, P4: Audit/Info).
* **Automated ITSM Synchronization:** **Azure Logic Apps** intercepts Webhook alerts from Azure Action Groups, serializes context metrics, and initiates standard Incident tickets (`INC00xxxxx`) on **ServiceNow (PDI)** via Table API.
* **Auto-Healing Engine:** **Azure Automation Account** executes an authenticated PowerShell Runbook utilizing its Managed Identity to issue non-disruptive `kubectl rollout restart` calls directly to the AKS API server, achieving MTTR < 60 seconds without manual L1 triage.

---


<br>

## Repository & Project Directory Structure

```text
.
├── .github/
│   └── workflows/
│       ├── terraform-lint.yml          # TFLint & Checkov security analysis
│       └── terraform-plan.yml          # Automated IaC validation pipeline
├── docs/
│   ├── architecture-diagram.png        # High-resolution architectural blueprint
│   ├── kql-diagnostic-playbook.md      # Comprehensive KQL queries & RCA triage catalog
│   ├── runbook-sop.md                  # Standard Operating Procedures for L1/L2 NOC engineers
│   └── rca-incident-sample.md          # Sample Root Cause Analysis (P1 Post-Mortem report)
├── app/
│   ├── src/
│   │   ├── app.py                      # Lightweight mock banking API (FastAPI)
│   │   └── requirements.txt            # App dependencies (App Insights, Redis, MSSQL)
│   ├── manifests/
│   │   ├── deployment.yaml             # Kubernetes Deployment & SecretProviderClass
│   │   └── service.yaml                # ClusterIP & Ingress configuration
│   └── Dockerfile                      # Hardened container image definition
├── scripts/
│   ├── chaos-test.sh                   # Fault-injection CLI testing toolkit
│   └── setup-servicenow-pdi.sh         # Automated Table API test payload generator
└── terraform/
    ├── environments/
    │   └── prod/
    │       ├── 00-bootstrap/           # TFState Storage, Resource Groups, Budget Alerts
    │       ├── 01-network/             # VNet, Subnets, NSGs, Jumpbox VM
    │       ├── 02-data-secrets/        # Azure SQL Serverless, Redis C0, Key Vault
    │       ├── 03-compute/             # AKS Cluster, Managed Identity, CSI Driver
    │       ├── 04-telemetry/           # Log Analytics Workspace, Application Insights
    │       └── 05-operations/          # Alert Rules, Action Groups, Runbooks, Logic App
    └── modules/
        ├── networking/
        ├── database/
        ├── aks/
        ├── monitoring/
        └── automation/
```


<br>


## Prerequisites & Tooling

Ensure the following client binaries are installed and properly authenticated:

- Azure CLI (>= 2.60.0)

- Terraform (>= 1.8.0)

- kubectl (>= 1.30.0)

- curl & jq (for test execution and JSON parsing)

- An active ServiceNow Personal Developer Instance (PDI) account

Verify authentication context:

``
az account show --query "{SubscriptionId:id, TenantId:tenantId, State:state}" -o table
``

<br>



## Deployment Workflow (Progressive Layering)

To respect resource dependencies and state isolation, execute the modules sequentially:

```
# Clone the repository
git clone [https://github.com/](https://github.com/)<your-username>/azure-cloudops-autoremediation.git
cd azure-cloudops-autoremediation/terraform/environments/prod

# 1. Provision Governance, State Backend & Budget Guardrails
cd 00-bootstrap
terraform init && terraform apply -auto-approve

# 2. Deploy Network Fabric, Security Groups & Jumpbox
cd ../01-network
terraform init && terraform apply -auto-approve

# 3. Deploy Data Stores, Cache & Secrets Engine
cd ../02-data-secrets
terraform init && terraform apply -auto-approve

# 4. Provision Kubernetes Cluster (AKS) & Workload Identity
cd ../03-compute
terraform init && terraform apply -auto-approve

# 5. Enable Telemetry, LAW & Application Insights
cd ../04-telemetry
terraform init && terraform apply -auto-approve

# 6. Deploy Alerting Rules, Logic Apps & Auto-Healing Runbooks
cd ../05-operations
terraform init && terraform apply -auto-approve
```


<br>


## Chaos Engineering & Fault-Injection Verification

The platform includes an automated CLI testing script (scripts/chaos-test.sh) to evaluate telemetry response, alert triggering, and auto-remediation efficiency.

### Scenario 1: Critical Outage Simulation (HTTP 5xx Rate > 15% - Alert P1)

Forces bulk execution of non-recoverable transaction failures against the mock banking service:

```
# Execute 30 concurrent HTTP 500 requests
for i in {1..30}; do 
  curl -s -o /dev/null -w "Transaction Status: %{http_code}\n" http://<INGRESS_IP>/api/fault/500
  sleep 0.1
done
```

- Observed System Reaction:

1. AppRequests log frequency updates in Log Analytics Workspace.

2. Application Insights marks the target microservice red on the Application Map.

3. Azure Monitor triggers the Severity 1 (P1) Metric Alert.

4. Logic App executes and opens an Incident in ServiceNow (Short Description: [P1 Alert] Core Banking 5xx Rate Exceeded Threshold).

<br>


### Scenario 2: Memory Exhaustion & CrashLoopBackOff (Alert P1 + Runbook Trigger)

Simulates an unmanaged memory leak forcing the Kubernetes OOM-killer to eliminate the application container:
```
# Inject memory leak payload
curl -X POST http://<INGRESS_IP>/api/fault/oom
```

- Observed System Reaction:

1. Pod enters OOMKilled followed by CrashLoopBackOff state (kubectl get pods -w).

2. Container Insights logs error within KubeEvents.

3. Action Group dispatches a Webhook payload to the Azure Automation Account.

4. PowerShell Runbook performs an authorized zero-downtime rollout restart.

5. Result: New pod instance transitions to Running (1/1) in ~42 seconds (MTTR < 60s benchmark achieved).


<br>

### Scenario 3: Relational Query Latency Degradation (Alert P2)

Executes an unindexed locking transaction to simulate high query wait times on Azure SQL:

```
curl -X POST http://<INGRESS_IP>/api/fault/slow-dependency
```

- Observed System Reaction:

1. End-to-end transaction latency spikes above 2500ms.

2. Application Map reflects elevated dependency response times between the Web App Pod and the SQL Private Endpoint.

3. Severity 2 Alert registers on Azure Monitor, initiating an automated investigation ticket to the DBA queue on ServiceNow.


<br>


## Operational KQL Diagnostics (Quick Triage)

Below are the primary operational queries executed in Log Analytics Workspace for rapid triage during incidents:

### 1. Identify Crashing / Unhealthy Kubernetes Pods

```
KubeEvents
| where TimeGenerated > ago(30m)
| where Reason in ("Failed", "BackOff", "Unhealthy", "OOMKilled")
| project TimeGenerated, Namespace = ObjectNamespace, PodName = ObjectName, Reason, Message
| order by TimeGenerated desc
```

### 2. High 5xx HTTP Error Rate Aggregation

```
AppRequests
| where TimeGenerated > ago(1h)
| where toint(ResultCode) >= 500
| summarize ErrorCount = count() by bin(TimeGenerated, 5m), OperationName, ResultCode
| order by ErrorCount desc
```
Detailed Operational Playbook: For the full catalog of diagnostic queries—including dependency latency tracking, time-series anomaly detection, and cluster-wide resource exhaustion—refer to the comprehensive Operational KQL Diagnostic Playbook.


<br>


## ITSM Integration Workflow (ServiceNow Developer PDI)

```
[Azure Monitor Action Group]
             │ (Webhook HTTP POST Payload)
             ▼
[Azure Logic App: workflow-servicenow-bridge]
  ├── Action 1: Parse JSON Schema (AlertName, Severity, Dimensions, FiredDateTime)
  ├── Action 2: Map Urgency/Impact based on Alert Severity (P1 -> 1-Critical, P2 -> 2-High)
  └── Action 3: HTTP POST /api/now/table/incident
             │ (Basic Auth / PDI REST Endpoint)
             ▼
[ServiceNow Incident Board]
  ├── Ticket ID: INC0010482
  ├── State: New / In-Progress
  ├── Assignment Group: Cloud Operations NOC
  └── Work Notes: "Automated trigger from Azure Monitor. Root cause telemetry captured."
```

<br>


## Clean-Up & Destruction

To release all provisioned cloud resources and stop compute metering, execute the destruction pipeline in reverse order:

```
cd terraform/environments/prod

# Purge operations, workloads and compute first
cd 05-operations && terraform destroy -auto-approve
cd ../04-telemetry && terraform destroy -auto-approve
cd ../03-compute && terraform destroy -auto-approve
cd ../02-data-secrets && terraform destroy -auto-approve
cd ../01-network && terraform destroy -auto-approve
cd ../00-bootstrap && terraform destroy -auto-approve
```


<br>

## Author & Engineering Ownership

Engineer: Vo Ta Minh Quan (QuanVT29)

Target Role: Azure Cloud Operations / DevSecOps Engineer

Contact: www.linkedin.com/in/quân-vt-243752337

