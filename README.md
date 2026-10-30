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

## Repository & Project Directory Structure

```text
.
├── .github/
│   └── workflows/
│       ├── terraform-lint.yml          # TFLint & Checkov security analysis
│       └── terraform-plan.yml          # Automated IaC validation pipeline
├── docs/
│   ├── architecture-diagram.png        # High-resolution architectural blueprint
│   ├── runbook-sop.md                  # Standard Operating Procedures for L1/L2
│   └── rca-incident-sample.md          # Sample Root Cause Analysis (P1 Post-Mortem)
├── app/
│   ├── src/
│   │   ├── app.py                      # Lightweight mock banking API (FastAPI)
│   │   └── requirements.txt            # App dependencies (App Insights, Redis, MSSQL)
│   ├── manifests/
│   │   ├── deployment.yaml             # Kubernetes Deployment & SecretProviderClass
│   │   └── service.yaml                # ClusterIP & Ingress configuration
│   └── Dockerfile                      # Distroless, hardened container image
├── scripts/
│   ├── chaos-test.sh                   # Fault-injection CLI testing toolkit
│   └── setup-servicenow-pdi.sh         # Automated table API test payload generator
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



