# AI Infrastructure Onboarding — Google Public Sector

> A comprehensive, hands-on guide and artifact repository to demonstrate Google Cloud AI infrastructure capabilities to Public Sector customers.

---

## 📋 Overview

This repository provides **ready-to-use scripts, templates, and documentation** that cover the full lifecycle of standing up AI/ML infrastructure on Google Cloud — from requesting quota and making reservations, through deploying workloads on GKE AI Hypercompute, to monitoring TPU health and performance.

Each section maps to a key phase of the onboarding journey:

| # | Phase | Description |
|---|-------|-------------|
| 1 | [Foundational Tools & Access](./01-foundational-tools/) | Agentic Coders, Quota Requests, Reservations |
| 2 | [Core Infrastructure Setup](./02-core-infrastructure/) | Networking (IAP, no-public-IP), Disk Images (Packer), Storage (GCSFuse, Rapid Cache, Rapid Bucket, GDrive Sync), Data Pipeline (BigQuery, Dataflow, BigQuery DataFrames) |
| 3 | [Deploying Workloads & Scheduling](./03-deploying-workloads/) | DWS, GKE (Autopilot & Standard), Vertex AI, Colab Enterprise, GKE AI Hypercompute, Cluster Director, XPK |
| 4 | [Monitoring & Observability](./04-monitoring-observability/) | AI workload monitoring, TPU Observability, dashboards |

Additionally, a [Terraform module](./terraform/) is provided to bootstrap foundational infrastructure (VPC, IAP, firewall rules, service accounts).

---

## 🚀 Quick Start

### Prerequisites

| Tool | Install |
|------|---------|
| `gcloud` CLI | [Install](https://cloud.google.com/sdk/docs/install) |
| `terraform` | [Install](https://developer.hashicorp.com/terraform/install) |
| `kubectl` | `gcloud components install kubectl` |
| `packer` | [Install](https://developer.hashicorp.com/packer/install) |
| `jq` | `apt-get install jq` |

### 1. Clone this repository

```bash
git clone https://github.com/<your-org>/ai-infra-onboarding.git
cd ai-infra-onboarding
```

### 2. Authenticate with Google Cloud

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_PROJECT_ID>
```

### 3. Follow the sections in order

Start with [01-foundational-tools/](./01-foundational-tools/) and work through each section sequentially. Each directory contains its own `README.md` with step-by-step instructions.

---

## 🗂️ Repository Structure

```
ai-infra-onboarding/
├── README.md                          # This file
├── LICENSE
├── .gitignore
│
├── 01-foundational-tools/             
│   ├── agentic-coder-setup/           # Cline, Claude Code, Gemini CLI setup
│   ├── quota-management/              # Quota request & check scripts
│   └── reservations/                  # On-demand, future, auto-reserve scripts
│
├── 02-core-infrastructure/            # VMs, Networking, Storage, Data Pipeline
│   ├── networking/                    # IAP setup, no-public-IP configs
│   ├── disk-images/                   # Packer templates & Cloud Build
│   ├── storage/                       # GCSFuse, Rapid Cache, Rapid Bucket, GDrive sync
│   └── data-pipeline/                 # BigQuery, Dataflow, BigQuery DataFrames for AI/ML
│
├── 03-deploying-workloads/            # Workload scheduling & platforms
│   ├── dws/                           # Dynamic Workload Scheduling
│   ├── gke/                           # GKE Autopilot & Standard (GPU deployment, DWS)
│   ├── vertex-ai/                     # Vertex AI serverless training (FLEX_START)
│   ├── colab-enterprise/              # GPU-accelerated notebooks, reservations, DWS patterns
│   ├── gke-ai-hypercompute/           # GKE, Cluster Toolkit, MIGs, DWS Flex
│   └── xpk/                           # Accelerated Processing Kit
│
├── 04-monitoring-observability/       # Monitoring & dashboards
│   ├── tpu-observability/             # TPU health, JobSet monitoring
│   └── dashboards/                    # Cloud Monitoring dashboard JSON
│
└── terraform/                         # Base infrastructure Terraform module
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## 🔑 Key Concepts

### Quota & Reservations
Before deploying any GPU/TPU workloads, you must have sufficient **resource-level quotas** (vCPUs, GPUs, machine types) AND a separate **reservation count quota**. See the [Quota Management](./01-foundational-tools/quota-management/) section for scripts that automate checking and requesting quota increases.

### Dynamic Workload Scheduling (DWS)
DWS enables Google Cloud to schedule workloads when capacity becomes available. This is crucial for high-demand accelerators like A3/H100. See [DWS](./03-deploying-workloads/dws/) for console and CLI guides.

### GKE AI Hypercompute
The recommended platform for large-scale AI training and inference. This repo includes artifacts for Cluster Toolkit, MIG + DWS Resize, and Flex Start training. See [GKE AI Hypercompute](./03-deploying-workloads/gke-ai-hypercompute/).

---

## 📚 External References

- [Google Cloud AI Hypercomputer Docs](https://cloud.google.com/ai-hypercomputer/docs)
- [GKE AI Hypercompute](https://docs.cloud.google.com/ai-hypercomputer/docs/create/gke-ai-hypercompute)
- [Cluster Toolkit](https://docs.cloud.google.com/ai-hypercomputer/docs/create/gke-ai-hypercompute#use-cluster-toolkit)
- [DWS Flex Start Training on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-training)
- [Building VM Images with Packer](https://docs.cloud.google.com/build/docs/building/build-vm-images-with-packer)

---

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/new-artifact`)
3. Commit your changes (`git commit -m 'Add new artifact for ...'`)
4. Push to the branch (`git push origin feature/new-artifact`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the Apache License 2.0 — see the [LICENSE](./LICENSE) file for details.

---

> **Disclaimer:** This repository is intended for demonstration and enablement purposes. Always follow your organization's security policies and review scripts before running them in production environments.
