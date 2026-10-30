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
