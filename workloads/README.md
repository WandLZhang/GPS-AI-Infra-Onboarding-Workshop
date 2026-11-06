# Deploying Workloads — GPU & TPU on Google Cloud

> Choose the right deployment method for your AI/ML workloads on Google Cloud. This section covers capacity acquisition concepts (DWS), and all deployment surfaces — from raw Compute Engine VMs to fully managed Slurm and serverless Vertex AI.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Capacity Acquisition vs. Deployment Method](#capacity-acquisition-vs-deployment-method)
3. [Deployment Methods at a Glance](#deployment-methods-at-a-glance)
4. [Decision Framework](#decision-framework)
5. [Workload × Deployment Method Matrix](#workload--deployment-method-matrix)

---

## Overview

Deploying GPU/TPU workloads on Google Cloud involves two independent decisions:

1. **How do you acquire capacity?** — This is the domain of [Dynamic Workload Scheduler (DWS)](dws/), reservations, on-demand, and [Spot](spot-capacity-advisor/). DWS is a scheduling service that queues your request and provisions resources when available, at up to 53% discount.

2. **Where do you deploy?** — This is the deployment method — the platform and tooling you use to run your workload. Each method integrates with DWS and other capacity models differently.

These are **orthogonal concerns**. You can use DWS flex-start through Compute Engine, GKE (via Cluster Toolkit or XPK), Cluster Director (managed Slurm), or Vertex AI. The capacity model and deployment surface are independent choices.

---

## Capacity Acquisition vs. Deployment Method

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   CAPACITY ACQUISITION (How you get GPUs/TPUs)                             │
│   ─────────────────────────────────────────────                            │
│   • On-Demand          — Immediate, full price, if available               │
│   • Reservations       — Guaranteed, committed, long-term                  │
│   • DWS Flex-start     — Queued, up to 53% discount, up to 7 days         │
│   • Calendar Mode      — Guaranteed start time, committed cost             │
│   • Spot               — Cheapest, preemptible, no guarantee              │
│                                                                             │
│   See: dws/README.md for full DWS concepts                                │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   DEPLOYMENT METHODS (Where you run workloads)                             │
│   ─────────────────────────────────────────────                            │
│   • Compute Engine     — Raw VMs via MIG resize requests                   │
│   • Calendar Mode      — Future reservations with guaranteed start         │
│   • GKE (Autopilot)    — Managed GKE clusters, Google manages nodes       │
│   • GKE (Standard)     — Full-control GKE clusters, you manage nodes      │
│   • Cluster Toolkit    — Production GKE clusters (Terraform blueprints)    │
│   • XPK                — Quick PoC GKE clusters (Python CLI)              │
│   • Cluster Director   — Fully managed Slurm clusters                     │
│   • Vertex AI          — Serverless training (FLEX_START)                  │
│   • Colab Enterprise   — Interactive GPU notebooks (Vertex AI)             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

> **Picking the best Spot zone / region / machine?** See [spot-capacity-advisor/](spot-capacity-advisor/) — use the Capacity Advisor for Spot API to place Spot workloads on live obtainability instead of guesswork.

---

## Deployment Methods at a Glance

| Method | Platform | Best For | DWS Support | Guide |
|---|---|---|---|---|
| **[DWS Concepts](dws/)** | — | Understanding capacity acquisition models, pricing, compliance | — | [→ dws/](dws/) |
| **[Spot Capacity Advisor](spot-capacity-advisor/)** | Compute Engine API (beta) | Picking the best zone/region/machine for Spot via live obtainability + estimated uptime | — (Spot) | [→ spot-capacity-advisor/](spot-capacity-advisor/) |
| **[GKE (Autopilot & Standard)](gke/)** | GKE (gcloud / Terraform) | Understanding GKE modes, direct GPU deployment, DWS flex-start | Flex-start, Queued Provisioning | [→ gke/](gke/) |
| **[Compute Engine](compute-engine-Managed%20Instance%20Groups/)** | Compute Engine (MIGs) | Raw VM control, no K8s overhead, batch training | Flex-start | [→ compute-engine/](compute-engine-Managed%20Instance%20Groups/) |
| **[Calendar Mode](compute-engine-future-reservations/)** | Compute Engine (Future Reservations) | Planned training with hard deadlines, guaranteed start | Calendar Mode | [→ compute-engine-future-reservations/](compute-engine-future-reservations/) |
| **[Cluster Toolkit](cluster-toolkit/)** | GKE (Terraform) | Production GKE clusters, full infra control, IaC | Flex-start, Reservation fallback | [→ cluster-toolkit/](cluster-toolkit/) |
| **[XPK](xpk/)** | GKE (Python CLI) | Rapid PoC, testing, experimentation | Flex-start | [→ xpk/](xpk/) |
| **[Cluster Director](cluster-director/)** | Managed Slurm | Slurm-native teams, HPC workloads, console-first | Flex-start, Calendar Mode | [→ cluster-director/](cluster-director/) |
| **[Vertex AI](vertex-ai/)** | Vertex AI (Managed) | Serverless training, zero infra management | FLEX_START | [→ vertex-ai/](vertex-ai/) |
| **[Colab Enterprise](colab-enterprise/)** | Vertex AI (Notebooks) | Interactive GPU notebooks, prototyping, develop→deploy | Via Reservations | [→ colab-enterprise/](colab-enterprise/) |

---

## Decision Framework

### Step 1: Choose Your Capacity Model

```
                    Do you need guaranteed capacity
                    at a specific start time?
                               │
                    ┌──────────┴──────────┐
                   Yes                    No
                    │                      │
              Calendar Mode           Is your workload
              (guaranteed start,      fault-tolerant with
              committed cost)         checkpointing?
                                          │
                                ┌─────────┴─────────┐
                               Yes                   No
                                │                     │
                          Can you tolerate        DWS Flex-start
                          preemption?             (up to 53% discount,
                                │                  7-day max)
                         ┌──────┴──────┐
                        Yes            No
                         │              │
                       Spot          DWS Flex-start
                       (up to 91%
                        discount)
```

### Step 2: Choose Your Deployment Method

```
              What orchestration model
              does your team use?
                       │
       ┌───────────────┼──────────────────┬──────────────────┐
     Slurm        Kubernetes         No preference /    Interactive
       │               │              Serverless        Notebooks
       │               │                  │                 │
  Cluster           Do you need       Vertex AI        Colab Enterprise
  Director          production-grade   (FLEX_START)     (GPU runtimes,
  (managed)         infrastructure?                     develop→deploy)
                        │
                 ┌──────┴──────┐
                Yes            No
                 │              │
           Cluster Toolkit    XPK
           (Terraform IaC)    (Quick PoC CLI)

              Want raw VMs
              without any
              orchestrator?
                   │
            Compute Engine
            (MIG Resize Requests)
```

---

## Workload × Deployment Method Matrix

| Workload Type | Compute Engine | Calendar Mode | Cluster Toolkit | XPK | Cluster Director | Vertex AI | Colab Enterprise |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Small model fine-tuning** (<8 GPUs, <24h) | ✅✅ | — | ✅✅ | ✅✅ | ✅✅ | ✅✅✅ | ✅✅ |
| **Medium pre-training** (8–64 GPUs, 1–7 days) | ✅✅ | ✅✅ | ✅✅✅ | ✅✅ | ✅✅✅ | ✅✅ | — |
| **Large distributed training** (64+ GPUs, multi-day) | ✅ | ✅✅✅ | ✅✅ | ✅ | ✅✅✅ | ✅ | — |
| **Inference / serving** | ✅ | ✅✅ | ✅✅✅ | ✅ | — | — | — |
| **Hyperparameter tuning** (many small jobs) | ✅ | — | ✅✅ | ✅✅ | ✅✅ | ✅✅✅ | ✅ |
| **Recurring scheduled workloads** | — | ✅✅✅ | ✅✅ | ✅ | ✅✅ | ✅ | ✅✅ |
| **Multi-framework ML pipeline** | — | — | ✅✅✅ | ✅ | ✅✅ | — | — |
| **HPC / MPI workloads** | ✅ | ✅ | ✅ | — | ✅✅✅ | — | — |
| **Quick PoC / experimentation** | ✅ | — | ✅ | ✅✅✅ | ✅ | ✅✅✅ | ✅✅✅ |
| **Interactive notebook development** | — | — | — | — | — | — | ✅✅✅ |

> **Legend**: ✅✅✅ = ideal fit, ✅✅ = good fit, ✅ = works, — = not recommended

### Decision Criteria Comparison

| Criterion | Compute Engine | Calendar Mode | Cluster Toolkit | XPK | Cluster Director | Vertex AI | Colab Enterprise |
|---|---|---|---|---|---|---|---|
| **Infra management** | Medium (MIGs) | Medium (reservations) | High (Terraform) | Low (CLI) | Low (managed) | None (serverless) | None (managed) |
| **K8s required** | ❌ | ❌ | ✅ | ✅ (abstracted) | ❌ | ❌ | ❌ |
| **Guaranteed start** | ❌ | ✅ | ❌ | ❌ | Calendar Mode only | ❌ | Via reservations |
| **DWS discount** | Up to 53% | DWS pricing | Up to 53% | Up to 53% | Up to 53% | DWS + mgmt fees | ❌ (on-demand) |
| **Max run duration** | 7 days (flex) | Custom | 7 days (flex) | 7 days (flex) | 7 days (flex) | 7 days | 18h (auto-delete) |
| **Job orchestration** | Manual | Manual | Kueue (automatic) | Kueue (automatic) | Slurm (automatic) | Vertex AI (automatic) | Scheduled runs |
| **IaC support** | ❌ | ❌ | ✅ Terraform | ❌ | ❌ | ❌ | ✅ Terraform |
| **Reservation fallback** | ❌ | N/A | ✅ Kueue pattern | ❌ | Separate partitions | ❌ | Specific reservation |
| **Interactive notebooks** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Accelerators** | All GPUs/TPUs | All GPUs/TPUs | All GPUs/TPUs | All GPUs/TPUs | All GPUs/TPUs | L4–H200 | V100, T4, A100, L4 |

---

> **Next steps**: Choose a [capacity model](dws/) and a deployment method from the guides linked above.
