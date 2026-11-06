# Run: Where GPU & TPU Workloads Run on Google Cloud

> Choose where to run your AI/ML workloads on Google Cloud, from plain Compute Engine VMs to fully managed Slurm and serverless Vertex AI. How you get the GPUs or TPUs (Flex-start, Calendar mode, Spot, reservations) is in [get capacity](../3-get-capacity/).

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Where you can run](#where-you-can-run)
3. [Deployment Methods at a Glance](#deployment-methods-at-a-glance)
4. [Decision Framework](#decision-framework)
5. [Workload × Deployment Method Matrix](#workload--deployment-method-matrix)

---

## Overview

Deploying GPU/TPU workloads on Google Cloud involves two independent decisions:

1. **How do you acquire capacity?** — On-demand, reservations, Dynamic Workload Scheduler (DWS) Flex-start and Calendar mode, or Spot. [Get capacity](../3-get-capacity/) compares the options.

2. **Where do you deploy?** — This is the deployment method — the platform and tooling you use to run your workload. Each method integrates with DWS and other capacity models differently.

These are **orthogonal concerns**. You can use DWS flex-start through Compute Engine, GKE (via Cluster Toolkit or XPK), Cluster Director (managed Slurm), or Vertex AI. The capacity model and deployment surface are independent choices.

---

## Where you can run

| Folder | Platform | Best For |
|---|---|---|
| [slurm](./slurm/) | Cluster Director (managed Slurm), and Cluster Toolkit Slurm blueprints | Teams that already submit work with `sbatch`, HPC and MPI codes |
| [kubernetes](./kubernetes/) | GKE Autopilot and Standard, with [Cluster Toolkit](./kubernetes/cluster-toolkit/) and [XPK](./kubernetes/xpk/) to build clusters | Containers, queued batch jobs and model serving on one cluster |
| [vms](./vms/) | Compute Engine VMs, with Flex-start through managed instance group (MIG) resize requests | Plain VMs with no orchestrator |
| [vertex-ai](./vertex-ai/) | Vertex AI custom training | A managed training job with no cluster |
| [notebooks](./notebooks/) | Colab Enterprise | Interactive GPU notebooks, prototyping |
| [classroom](./classroom/) | GKE Autopilot with a Kueue queue, or workstations built for a class | A class or team that shares accelerators |

[checkpointing.md](./checkpointing.md) applies to all of them: save training state so an interruption costs minutes, not days.

---

## Deployment Methods at a Glance

| Method | Platform | Best For | DWS Support | Guide |
|---|---|---|---|---|
| **[GKE (Autopilot & Standard)](kubernetes/)** | GKE (gcloud / Terraform) | Understanding GKE modes, direct GPU deployment, DWS flex-start | Flex-start, Queued Provisioning | [→ kubernetes/](kubernetes/) |
| **[Compute Engine](vms/)** | Compute Engine (MIGs) | Raw VM control, no K8s overhead, batch training | Flex-start | [→ vms/](vms/) |
| **[Cluster Toolkit](kubernetes/cluster-toolkit/)** | GKE (Terraform) | Production GKE clusters, full infra control, IaC | Flex-start, Reservation fallback | [→ kubernetes/cluster-toolkit/](kubernetes/cluster-toolkit/) |
| **[XPK](kubernetes/xpk/)** | GKE (Python CLI) | Rapid PoC, testing, experimentation | Flex-start | [→ kubernetes/xpk/](kubernetes/xpk/) |
| **[Cluster Director](slurm/)** | Managed Slurm | Slurm-native teams, HPC workloads, console-first | Flex-start, Calendar Mode | [→ slurm/](slurm/) |
| **[Vertex AI](vertex-ai/)** | Vertex AI (Managed) | Serverless training, zero infra management | FLEX_START | [→ vertex-ai/](vertex-ai/) |
| **[Colab Enterprise](notebooks/)** | Vertex AI (Notebooks) | Interactive GPU notebooks, prototyping, develop→deploy | Via Reservations | [→ notebooks/](notebooks/) |

---

## Decision Framework

### Step 1: Choose Your Capacity Model

Follow [Choose an option](../3-get-capacity/README.md#choose-an-option) in get capacity.

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

| Workload Type | Compute Engine | Cluster Toolkit | XPK | Cluster Director | Vertex AI | Colab Enterprise |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Small model fine-tuning** (<8 GPUs, <24h) | ✅✅ | ✅✅ | ✅✅ | ✅✅ | ✅✅✅ | ✅✅ |
| **Medium pre-training** (8–64 GPUs, 1–7 days) | ✅✅ | ✅✅✅ | ✅✅ | ✅✅✅ | ✅✅ | — |
| **Large distributed training** (64+ GPUs, multi-day) | ✅ | ✅✅ | ✅ | ✅✅✅ | ✅ | — |
| **Inference / serving** | ✅ | ✅✅✅ | ✅ | — | — | — |
| **Hyperparameter tuning** (many small jobs) | ✅ | ✅✅ | ✅✅ | ✅✅ | ✅✅✅ | ✅ |
| **Recurring scheduled workloads** | — | ✅✅ | ✅ | ✅✅ | ✅ | ✅✅ |
| **Multi-framework ML pipeline** | — | ✅✅✅ | ✅ | ✅✅ | — | — |
| **HPC / MPI workloads** | ✅ | ✅ | — | ✅✅✅ | — | — |
| **Quick PoC / experimentation** | ✅ | ✅ | ✅✅✅ | ✅ | ✅✅✅ | ✅✅✅ |
| **Interactive notebook development** | — | — | — | — | — | ✅✅✅ |

> **Legend**: ✅✅✅ = ideal fit, ✅✅ = good fit, ✅ = works, — = not recommended

For runs with fixed dates on any of these platforms, book [Calendar mode](../3-get-capacity/calendar-mode/) capacity first.

### Decision Criteria Comparison

| Criterion | Compute Engine | Cluster Toolkit | XPK | Cluster Director | Vertex AI | Colab Enterprise |
|---|---|---|---|---|---|---|
| **Infra management** | Medium (MIGs) | High (Terraform) | Low (CLI) | Low (managed) | None (serverless) | None (managed) |
| **K8s required** | ❌ | ✅ | ✅ (abstracted) | ❌ | ❌ | ❌ |
| **Guaranteed start** | ❌ | ❌ | ❌ | Calendar Mode only | ❌ | Via reservations |
| **DWS discount** | Up to 53% | Up to 53% | Up to 53% | Up to 53% | DWS + mgmt fees | ❌ (on-demand) |
| **Max run duration** | 7 days (flex) | 7 days (flex) | 7 days (flex) | 7 days (flex) | 7 days | 18h (auto-delete) |
| **Job orchestration** | Manual | Kueue (automatic) | Kueue (automatic) | Slurm (automatic) | Vertex AI (automatic) | Scheduled runs |
| **IaC support** | ❌ | ✅ Terraform | ❌ | ❌ | ❌ | ✅ Terraform |
| **Reservation fallback** | ❌ | ✅ Kueue pattern | ❌ | Separate partitions | ❌ | Specific reservation |
| **Interactive notebooks** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Accelerators** | All GPUs/TPUs | All GPUs/TPUs | All GPUs/TPUs | All GPUs/TPUs | L4–H200 | V100, T4, A100, L4 |

---

> **Next steps**: Choose a [capacity option](../3-get-capacity/) and a platform from the folders above. Working recipes to copy are in [examples](../8-examples/).
