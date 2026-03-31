# Cluster Director — Managed Slurm Clusters for AI/ML/HPC on Google Cloud

> A comprehensive guide to using Cluster Director to deploy and manage fully managed Slurm clusters with GPU accelerators, DWS flex-start provisioning, custom images, and topology-aware scheduling — with comparisons to DIY Slurm and Cluster Toolkit approaches.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [DWS Capabilities in Cluster Director](#2-dws-capabilities-in-cluster-director)
3. [Cluster Director vs. DIY Slurm Setup](#3-cluster-director-vs-diy-slurm-setup)
4. [Cluster Director vs. Cluster Toolkit](#4-cluster-director-vs-cluster-toolkit)
5. [Cluster Director vs. GKE-Based Approaches](#5-cluster-director-vs-gke-based-approaches)
6. [Creating Custom Images for Cluster Director](#6-creating-custom-images-for-cluster-director)
7. [APIs and Programmatic Access](#7-apis-and-programmatic-access)
8. [Slurm Architecture in Cluster Director](#8-slurm-architecture-in-cluster-director)
9. [Quickstart: Create a Cluster with DWS Flex-Start](#9-quickstart-create-a-cluster-with-dws-flex-start)
10. [Limitations](#10-limitations)
11. [Best Practices](#11-best-practices)
12. [References](#12-references)

---

## 1. Overview

**[Cluster Director](https://cloud.google.com/cluster-director/docs)** is a Google Cloud managed service that simplifies deploying and managing complete AI, ML, and HPC clusters. It provides a fully managed [Slurm](https://slurm.schedmd.com/documentation.html) environment — including fault-tolerant controller nodes, login nodes, and GPU compute nodes — deployed through the Google Cloud Console, `gcloud` CLI, or REST API.

### What Cluster Director Does

| Capability | Benefit |
|---|---|
| **Fully managed Slurm** | Cluster Director automatically deploys and configures Slurm controller (HA), login nodes, and compute nodes — no manual Slurm installation |
| **Console-first experience** | Create and manage clusters through the Google Cloud Console with step-by-step UI guidance |
| **Multiple consumption models** | Supports reservations, DWS Flex-start (up to 53% discount), Calendar Mode, Spot, and On-demand |
| **Pre-configured OS images** | Nodes boot with NVIDIA drivers, CUDA, Slurm, NCCL, GPUDirect RDMA libraries pre-installed |
| **Topology-aware scheduling** | Slurm leverages physical topology information for optimal workload placement and minimal network latency |
| **Integrated storage** | Built-in support for Filestore, Google Cloud Managed Lustre, and Cloud Storage (GCSFuse) |
| **Advanced maintenance controls** | Manage host events, schedule maintenance windows, and report faulty hosts |
| **GPU health checks** | Slurm prolog scripts automatically check GPU health before starting jobs |
| **Monitoring & logging** | Ops Agent pre-installed for Cloud Monitoring and Cloud Logging integration |

### Where Cluster Director Fits

```
┌──────────────────────────────────────────────────────────────────────────────┐
│           Methods for Running AI/ML Workloads on Google Cloud               │
│                                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌───────────┐  │
│  │ Cluster        │  │ Cluster        │  │ XPK            │  │ Vertex AI │  │
│  │ Director       │  │ Toolkit        │  │                │  │           │  │
│  │                │  │                │  │                │  │           │  │
│  │ Managed Slurm  │  │ IaC (Terraform)│  │ Quick PoC      │  │ Serverless│  │
│  │ Console + CLI  │  │ GKE or Slurm   │  │ GKE + Kueue    │  │ Training  │  │
│  │ GPU clusters   │  │ Production     │  │ Python CLI     │  │ Zero mgmt│  │
│  └────────────────┘  └────────────────┘  └────────────────┘  └───────────┘  │
│       ▲ BEST FOR          Good for           Good for          Good for     │
│       │ Slurm-native      production         experimentation   data         │
│       │ teams, HPC        GKE or Slurm       & testing         scientists   │
│       │ workloads         deployments                                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Supported GPU Machine Types

| Machine Series | GPU | GPUs/VM | GPU Memory | Consumption Options |
|---|---|---|---|---|
| **A4X Max** (bare metal) | NVIDIA GB300 | 4 | 1,116 GB HBM3e | Reservation only |
| **A4X** | NVIDIA GB200 | 4 | 744 GB HBM3e | Reservation only |
| **A4** | NVIDIA B200 | 8 | 1,440 GB HBM3e | Reservation, Flex-start, Spot |
| **A3 Ultra** | NVIDIA H200 | 8 | 1,128 GB HBM3e | Reservation, Flex-start, Spot |
| **A3 Mega** | NVIDIA H100 | 8 | 640 GB HBM3 | Reservation, Flex-start, Spot |
| **N2** (CPU-only) | None | — | — | Spot, On-demand |

### TPU Support (All Capacity Mode)

Cluster Director also supports TPUs via **All Capacity Mode** for Trillium (TPU v6e) and Ironwood (TPU7x). In All Capacity mode, you get full visibility into hardware topology, utilization, and health, with dedicated physically co-located capacity. See the [TPU Cluster Director overview](https://cloud.google.com/tpu/docs/all-capacity-overview) for details.

---

## 2. DWS Capabilities in Cluster Director

Cluster Director integrates with **Dynamic Workload Scheduler (DWS)** through multiple consumption options. Each option determines how you access compute resources, their availability, lifespan, and pricing.

### Consumption Options Comparison

| Option | Supported Machines | Max Lifespan | Capacity Assurance | Pricing | Resource Allocation |
|---|---|---|---|---|---|
| **Future Reservations (blocks)** | A4X Max, A4X, A4, A3 Ultra, A3 Mega | Unlimited (year+ with CUD) | Very high | Up to 53% discount + CUD | Dense |
| **Calendar Mode** | A4, A3 Ultra, A3 Mega | 90 days | Very high | Up to 53% discount (DWS) | Dense |
| **Flex-start (DWS)** | A4, A3 Ultra, A3 Mega | **7 days** | Best-effort | **Up to 53% discount** (DWS) | Dense |
| **Spot** | A4, A3 Ultra, A3 Mega, N2 | Unlimited (preemptible) | Best-effort | Up to 91% discount | Best-effort |
| **On-demand** | N2 | Unlimited | Best-effort | Standard pricing | Best-effort |

### How DWS Flex-Start Works in Cluster Director

When you create a cluster with Flex-start, Cluster Director submits a DWS request for your GPU VMs. The request is queued until capacity becomes available, at which point all requested VMs are provisioned simultaneously with dense allocation for minimal network latency.

```
┌─────────────────────────────────────────────────────────────────────────┐
│             DWS Flex-Start Flow in Cluster Director                     │
│                                                                         │
│  1. You create a cluster   ──────►  Cluster Director creates:           │
│     with Flex-start VMs             • Login node (N2, immediate)        │
│     via Console / gcloud            • Controller node (HA, managed)     │
│                                     • DWS resize request for GPU VMs   │
│                                                                         │
│  2. Cluster state: Ready   ──────►  Login node is available for SSH     │
│     (login node created)            You CAN connect but CANNOT run      │
│                                     GPU jobs yet                        │
│                                                                         │
│  3. DWS queues request     ──────►  Waits for GPU capacity in your zone │
│     (state: ACCEPTED)               Dense allocation guaranteed         │
│                                                                         │
│  4. Capacity available     ──────►  All GPU VMs created at once         │
│     (state: SUCCEEDED)              Slurm compute nodes join cluster    │
│                                     You can now run GPU jobs             │
│                                                                         │
│  5. Run duration expires   ──────►  Flex-start VMs are deleted          │
│     (up to 7 days)                  (checkpoint your work!)             │
└─────────────────────────────────────────────────────────────────────────┘
```

### Decision Flowchart: Choosing a Consumption Option

```
                    Do you need high assurance
                    for GPU VMs?
                           │
                ┌──────────┴──────────┐
               Yes                    No
                │                      │
        Do you need capacity      Is your workload
        for more than 90 days?    fault-tolerant?
                │                      │
         ┌──────┴──────┐        ┌──────┴──────┐
        Yes            No      Yes            No
         │              │       │              │
    Future          Do you     Spot         Do you want
    Reservations    want       (up to 91%   GPU VMs?
    (blocks +       reserved   discount)         │
    CUD)            capacity?               ┌────┴────┐
                        │                  Yes        No
                 ┌──────┴──────┐            │          │
                Yes            No       Flex-start   On-demand
                 │              │       (DWS, up     (N2 only,
            Calendar         Flex-start  to 53%      standard
            Mode             (DWS)       discount)   pricing)
            (up to 90 days)  (up to 7 days)
```

### Key DWS Benefits in Cluster Director

| Benefit | Detail |
|---|---|
| **Up to 53% discount** | Flex-start and Calendar Mode pricing is significantly cheaper than on-demand |
| **Dense allocation** | All DWS consumption options allocate VMs close together for minimal network latency |
| **All-at-once provisioning** | DWS provisions all requested VMs simultaneously — no partial allocations |
| **Zero Slurm configuration** | Unlike DWS on GKE (which requires Kueue setup), Cluster Director manages everything |
| **Automatic GPU health checks** | Slurm prolog scripts verify GPU health before job execution |
| **Topology-aware scheduling** | Slurm uses physical topology info for optimal workload placement |

---

## 3. Cluster Director vs. DIY Slurm Setup

Setting up a Slurm cluster manually on Google Cloud requires extensive configuration of VMs, networking, drivers, Slurm services, shared storage, and monitoring. Cluster Director automates all of this.

### What Cluster Director Automates (vs. DIY)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DIY Slurm Setup on Google Cloud                          │
│                                                                             │
│  You must manually:                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ 1. Provision VMs  │  │ 2. Configure     │  │ 3. Install & configure   │  │
│  │ (MIGs or          │  │    networking    │  │    Slurm (slurmctld,     │  │
│  │  individual VMs)  │  │    (VPC, RDMA,   │  │    slurmd, MUNGE,       │  │
│  │                   │  │    firewall)     │  │    MariaDB, etc.)        │  │
│  └───────────────────┘  └──────────────────┘  └──────────────────────────┘  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ 4. Install NVIDIA │  │ 5. Configure     │  │ 6. Set up shared        │  │
│  │    drivers, CUDA, │  │    topology-     │  │    storage (NFS,        │  │
│  │    NCCL, RDMA     │  │    aware sched.  │  │    Lustre, GCS)         │  │
│  └───────────────────┘  └──────────────────┘  └──────────────────────────┘  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ 7. Configure HA   │  │ 8. Set up        │  │ 9. Manage maintenance,  │  │
│  │    for Slurm      │  │    monitoring &  │  │    upgrades, & faulty   │  │
│  │    controller     │  │    logging       │  │    host reporting       │  │
│  └───────────────────┘  └──────────────────┘  └──────────────────────────┘  │
│                                                                             │
│  Estimated time: Days to weeks for production-quality setup                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    Cluster Director                                         │
│                                                                             │
│  You do:                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 1. Go to Console → Cluster Director → Create cluster                │   │
│  │ 2. Select GPU type, consumption option, storage, and click Create   │   │
│  │    (or use gcloud alpha cluster-director clusters create ...)       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Cluster Director handles everything else automatically.                    │
│  Estimated time: Minutes (login node) to hours (GPU VMs via Flex-start)     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Comparison

| Criterion | Cluster Director (Managed) | DIY Slurm on GCE |
|---|---|---|
| **Setup complexity** | Low — Console UI or single `gcloud` command | Very High — manual VM provisioning, Slurm compilation/install, networking, drivers |
| **Time to deploy** | Minutes (login) + DWS wait (GPU VMs) | Days to weeks for a production setup |
| **Slurm installation** | Automatic (Slurm 25.05 pre-installed) | Manual — compile from source or install packages, configure `slurm.conf`, set up MUNGE, MariaDB |
| **Controller HA** | Automatic fault-tolerant configuration | Manual — set up backup controller, shared state, failover |
| **NVIDIA drivers & CUDA** | Pre-installed in OS images (driver 570/580, CUDA 12/13) | Manual — download, install, configure, test drivers |
| **GPUDirect RDMA** | Pre-configured with ibverbs-utils, rdma-core | Manual — install RDMA libraries, configure multi-NIC networking |
| **Topology-aware scheduling** | Built-in — Slurm uses physical topology data | Manual — configure `topology.conf`, gather topology data from API |
| **GPU health checks** | Automatic Slurm prolog scripts drain unhealthy nodes | Manual — write and deploy prolog scripts |
| **Container runtime** | NVIDIA enroot + pyxis pre-installed | Manual — install enroot, pyxis, configure Slurm integration |
| **Shared storage** | Integrated Filestore, Managed Lustre, Cloud Storage | Manual — provision NFS/Lustre, configure mount points, autofs |
| **Monitoring & logging** | Ops Agent pre-installed, Cloud Monitoring integration | Manual — install and configure monitoring agents |
| **DWS integration** | Native — select Flex-start in Console | Manual — create MIG resize requests, manage DWS lifecycle |
| **Maintenance management** | Managed host event notifications and controls | Manual — monitor host events, handle migrations |
| **Faulty host reporting** | Built-in via Cluster Director UI/API | Manual — use Compute Engine API to report faulty hosts |
| **Scaling** | Static + dynamic node counts per partition | Manual — configure Slurm's `ResumeProgram`/`SuspendProgram`, write scripts for Compute Engine API |
| **Cost** | Service cost + compute/storage resources | Compute/storage resources only (but significant operational overhead) |

### When DIY Slurm Still Makes Sense

| Scenario | Why DIY |
|---|---|
| **Unsupported machine types** | Cluster Director supports A4X Max, A4X, A4, A3 Ultra, A3 Mega, and N2 only |
| **Non-Google Cloud environments** | DIY Slurm works on any infrastructure (on-prem, other clouds) |
| **Extreme Slurm customization** | Need custom Slurm plugins, non-standard accounting, or heavily modified `slurm.conf` |
| **Existing Slurm cluster migration** | If you have an on-prem Slurm cluster with complex configs, a managed service may not replicate all settings |
| **Multi-cloud Slurm federation** | Federating Slurm across multiple clouds requires manual control |

---

## 4. Cluster Director vs. Cluster Toolkit

Both Cluster Director and Cluster Toolkit can deploy Slurm clusters on Google Cloud, but they represent fundamentally different deployment models: **managed service** vs. **infrastructure-as-code tool**.

### Key Differences

| Criterion | Cluster Director | Cluster Toolkit (Slurm) |
|---|---|---|
| **Type** | Managed Google Cloud service | Open-source IaC tool (Terraform-based) |
| **Deployment** | Console UI, `gcloud` CLI, REST API | `gcluster deploy` with YAML blueprints + Terraform |
| **Slurm management** | Fully managed (controller HA, auto-configuration) | Self-managed (you own the Terraform state and Slurm config) |
| **State management** | Google Cloud manages cluster state | You manage Terraform state (GCS backend) |
| **OS images** | Pre-built from `clusterdirector-public-images` project | Built during deployment by Cluster Toolkit |
| **GKE support** | ❌ Slurm only | ✅ Both GKE and Slurm blueprints |
| **DWS Flex-start** | ✅ Console-native | ✅ Blueprint configuration |
| **DWS Calendar Mode** | ✅ | ✅ |
| **Reservations** | ✅ | ✅ |
| **Spot VMs** | ✅ | ✅ |
| **Cluster Health Scanner** | ❌ Not available | ✅ Available via blueprint |
| **Custom networking** | Create new or use existing VPC | Full control (VPC, RDMA subnets, firewall rules) |
| **Custom Slurm config** | Limited (prolog/epilog scripts, startup scripts) | Full control (`slurm.conf`, partitions, accounting) |
| **Kueue integration** | ❌ (Slurm-native queuing) | ✅ (for GKE blueprints) |
| **Multi-cluster management** | Console-based cluster list/view | Manual Terraform management per cluster |
| **Infrastructure-as-code** | ❌ (API-driven, not IaC) | ✅ (Terraform blueprints, version-controlled) |
| **Recommended for** | Teams wanting managed Slurm with minimal ops | Teams needing full infrastructure control or GKE |

### Relationship Between Cluster Director and Cluster Toolkit

Cluster Director and Cluster Toolkit are closely related:

- **Cluster Director's OS images are built by Cluster Toolkit** — the pre-configured images in the `clusterdirector-public-images` project are extensions of Ubuntu LTS images created using Cluster Toolkit's image-building process.
- **Both support the same GPU machine types** (A4X Max, A4X, A4, A3 Ultra, A3 Mega) and the same consumption options (reservations, Flex-start, Spot).
- **Cluster Toolkit is the underlying technology** — Cluster Director wraps Cluster Toolkit's Slurm capabilities in a managed service layer.

```
┌───────────────────────────────────────────────────────────────────┐
│                  Relationship Diagram                              │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                  Cluster Director                          │   │
│  │                  (Managed Service)                         │   │
│  │                                                            │   │
│  │  • Console UI / gcloud / REST API                         │   │
│  │  • Managed Slurm controller (HA)                          │   │
│  │  • Automated OS image selection                           │   │
│  │  • Integrated storage provisioning                        │   │
│  │  • Host event management                                  │   │
│  │                                                            │   │
│  │  ┌──────────────────────────────────────────────────────┐ │   │
│  │  │           Built on Cluster Toolkit                    │ │   │
│  │  │                                                      │ │   │
│  │  │  • OS images built by Cluster Toolkit                │ │   │
│  │  │  • Slurm configuration patterns from blueprints      │ │   │
│  │  │  • Networking best practices encoded                 │ │   │
│  │  └──────────────────────────────────────────────────────┘ │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                  Cluster Toolkit                            │   │
│  │                  (Open-Source IaC)                          │   │
│  │                                                            │   │
│  │  • YAML blueprints + Terraform                            │   │
│  │  • Full infrastructure control                            │   │
│  │  • GKE and Slurm cluster support                          │   │
│  │  • Custom Slurm configuration                             │   │
│  │  • Terraform state management                             │   │
│  └────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

### When to Choose Each

| Scenario | Cluster Director | Cluster Toolkit |
|---|---|---|
| **Quick Slurm cluster for training** | ✅ Best — minutes to deploy via Console | Good — requires blueprint setup |
| **Production Slurm with full control** | Good — managed but less customizable | ✅ Best — full IaC control |
| **GKE-based workloads** | ❌ Slurm only | ✅ Best — GKE blueprints available |
| **Teams without infrastructure expertise** | ✅ Best — no Terraform or K8s knowledge needed | Requires Terraform knowledge |
| **Regulated environments (FedRAMP, DoD)** | Good — managed service with data residency | ✅ Best — full infrastructure control with Assured Workloads |
| **Multi-cluster management** | ✅ Good — Console UI for all clusters | Manual — separate Terraform per cluster |
| **Custom Slurm plugins or config** | Limited | ✅ Best — full `slurm.conf` control |
| **Hybrid Slurm + GKE environment** | ❌ Not supported | ✅ Supported — separate blueprints |

---

## 5. Cluster Director vs. GKE-Based Approaches

Cluster Director uses **Slurm** as its orchestrator, while GKE-based approaches (Cluster Toolkit for GKE, XPK) use **Kubernetes**. This is a fundamental architectural difference.

### Slurm vs. Kubernetes for AI/ML Workloads

| Criterion | Cluster Director (Slurm) | GKE-Based (Cluster Toolkit / XPK) |
|---|---|---|
| **Orchestrator** | Slurm (industry-standard for HPC) | Kubernetes (GKE) + Kueue |
| **Job submission** | `sbatch`, `srun`, `salloc` | `kubectl apply`, `xpk workload create` |
| **Job types** | Batch scripts, interactive sessions, MPI jobs | Kubernetes Jobs, JobSets, PyTorchJob, RayJob |
| **Container runtime** | NVIDIA enroot + pyxis | Docker/containerd |
| **Multi-framework support** | Any — runs native binaries or containers | Any — via container images |
| **Workload queuing** | Slurm's built-in scheduler | Kueue (Kubernetes-native) |
| **SSH access to nodes** | ✅ Direct SSH to login/compute nodes | Limited — access via `kubectl exec` |
| **Familiar to HPC teams** | ✅ Standard HPC workflow | Requires Kubernetes knowledge |
| **Familiar to ML/DevOps teams** | Requires Slurm knowledge | ✅ Standard cloud-native workflow |
| **DWS Flex-start** | ✅ Native via consumption options | ✅ Via queued provisioning + Kueue |
| **Multi-tenant isolation** | Slurm accounts, partitions, QOS | Kubernetes namespaces, RBAC, Kueue quotas |
| **Ecosystem** | Slurm plugins, MUNGE, OpenMPI | Kubernetes ecosystem (Helm, Operators, etc.) |

### When to Choose Slurm (Cluster Director)

- Your team has **existing Slurm expertise** and workflows
- You need **SSH access** to compute nodes for debugging
- You run **MPI-based workloads** that are designed for Slurm
- You want a **traditional HPC environment** on Google Cloud
- You need **interactive job sessions** (`salloc`, `srun`)

### When to Choose GKE (Cluster Toolkit / XPK)

- Your team has **Kubernetes expertise**
- You need **multi-framework ML pipelines** (PyTorchJob, TFJob, RayJob)
- You want **reservation + DWS fallback** patterns via Kueue
- You need to run **inference serving** alongside training
- You want **infrastructure-as-code** with GitOps workflows

---

## 6. Creating Custom Images for Cluster Director

### Default OS Images

Cluster Director provides pre-configured OS images from the `clusterdirector-public-images` project. These images are built by Cluster Toolkit and include all necessary software for Slurm-based AI/ML/HPC workloads.

| Machine Series | OS Version | Default Image Family |
|---|---|---|
| **A4X** | Ubuntu 24.04 LTS, NVIDIA driver 580, CUDA 13 | `a4x-ubuntu-2404-arm64-nvidia-580-slurm-2505-v20251118` |
| **A4, A3 Ultra, N2** | Ubuntu 22.04 LTS, NVIDIA driver 570, CUDA 12 | `common-ubuntu-2204-amd64-nvidia-570-slurm-2505-v20250918` (default) |
| **A4, A3 Ultra, N2** | Ubuntu 22.04 LTS, NVIDIA driver 580, CUDA 13 | `common-ubuntu-2204-amd64-nvidia-580-slurm-2505-v20251113` |
| **A3 Mega** | Ubuntu 22.04 LTS, NVIDIA driver 570, CUDA 12 | `a3m-ubuntu-2204-amd64-nvidia-570-slurm-2505-v20250918` (default) |

> **Image project**: `projects/clusterdirector-public-images/global/images/family/<family-name>`

### Included Software Stack

All Cluster Director OS images include the following pre-installed software:

```
┌────────────────────────────────────────────────────────────────────────┐
│              Cluster Director OS Image Software Stack                  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Operating System                                                │  │
│  │  Ubuntu 22.04 LTS (amd64) or Ubuntu 24.04 LTS (arm64 for A4X)  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌────────────────────┐  ┌────────────────────┐  ┌─────────────────┐  │
│  │  Orchestration      │  │  GPU Drivers       │  │  Networking     │  │
│  │                    │  │                    │  │                 │  │
│  │  • Slurm 25.05    │  │  • NVIDIA 570/580  │  │  • ibverbs-utils│  │
│  │  • MUNGE (auth)   │  │  • CUDA 12/13      │  │  • rdma-core    │  │
│  │  • MariaDB (state)│  │                    │  │  • GPUDirect    │  │
│  └────────────────────┘  └────────────────────┘  │    RDMA         │  │
│                                                   └─────────────────┘  │
│  ┌────────────────────┐  ┌────────────────────┐  ┌─────────────────┐  │
│  │  Containers        │  │  Parallel Computing│  │  Google Cloud   │  │
│  │                    │  │                    │  │  Integrations   │  │
│  │  • NVIDIA enroot  │  │  • Open MPI        │  │                 │  │
│  │  • NVIDIA pyxis   │  │  • PMIx            │  │  • Ops Agent    │  │
│  │                    │  │                    │  │  • GCSFuse      │  │
│  └────────────────────┘  └────────────────────┘  └─────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### How to Create Custom Images

There are three approaches to customizing your Cluster Director environment, from simplest to most involved:

#### Approach 1: Startup Scripts (Simplest — No Image Build)

For lightweight customizations (installing a few packages, setting environment variables, mounting storage), use **startup scripts** directly on nodesets. Startup scripts run at boot time on each compute node.

When creating a cluster in the Console:
1. In the **Partitions** section, expand **Advanced nodeset settings**
2. Add a startup script in the **Startup script** field

When creating a cluster via `gcloud` CLI, specify startup scripts in your JSON config file.

```bash
#!/bin/bash
# Example startup script for a Cluster Director nodeset
set -euo pipefail

MARKER="/var/log/custom-setup-v1-complete"
if [ -f "$MARKER" ]; then
    echo "Custom setup already completed. Skipping."
    exit 0
fi

# Install additional Python packages
source /opt/ml-env/bin/activate 2>/dev/null || true
pip install transformers datasets accelerate wandb

# Install additional system packages
apt-get update && apt-get install -y htop tmux screen

# Custom environment variables
cat >> /etc/profile.d/custom-env.sh << 'EOF'
export NCCL_DEBUG=INFO
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
EOF

echo "Custom setup completed at $(date)" > "$MARKER"
```

> **Best for**: Installing a handful of packages, setting environment variables, small configs.  
> **Limitation**: Runs on every boot; heavy installs slow down VM startup.

#### Approach 2: Custom OS Images with Packer (Recommended for Heavy Customizations)

For significant customizations — installing your own Slurm plugins, proprietary ML frameworks, custom NCCL builds, or organization-specific software — build a **custom OS image** using Packer that extends the Cluster Director base image.

**Step 1: Start from the Cluster Director base image**

Use the appropriate Cluster Director public image as your source image in Packer:

```hcl
packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.1.6"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

locals {
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "googlecompute" "cluster_director_custom" {
  project_id = var.project_id
  zone       = var.zone

  # ── Start from the Cluster Director base image ──
  source_image_family     = "common-ubuntu-2204-amd64-nvidia-570-slurm-2505-v20250918"
  source_image_project_id = ["clusterdirector-public-images"]

  machine_type = "n2-standard-8"

  # Output image settings
  image_name        = "cluster-director-custom-${local.image_date}"
  image_family      = "cluster-director-custom"
  image_description = "Custom Cluster Director image with proprietary ML stack"
  image_labels = {
    "built-by"    = "packer"
    "base"        = "cluster-director"
    "slurm"       = "25-05"
  }

  disk_size    = 200
  disk_type    = "pd-ssd"
  ssh_username = "packer"
  ssh_timeout  = "15m"

  metadata = {
    "enable-oslogin" = "FALSE"
  }
}

build {
  sources = ["source.googlecompute.cluster_director_custom"]

  # ── Install custom ML frameworks ──
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3-venv",
      "python3 -m venv /opt/custom-ml-env",
      "source /opt/custom-ml-env/bin/activate",
      "pip install --upgrade pip",
      "pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124",
      "pip install transformers datasets accelerate deepspeed",
    ]
  }

  # ── Install custom Slurm plugins or prolog scripts ──
  provisioner "file" {
    source      = "slurm-plugins/"
    destination = "/tmp/slurm-plugins"
  }

  provisioner "shell" {
    inline = [
      "sudo cp -r /tmp/slurm-plugins/* /usr/local/lib/slurm/",
      "sudo rm -rf /tmp/slurm-plugins",
    ]
  }

  # ── Install proprietary or organization-specific software ──
  provisioner "shell" {
    inline = [
      "# Example: install a custom API client",
      "pip install your-org-api-client==2.0.0",
      "# Example: install custom monitoring agent",
      "sudo dpkg -i /tmp/custom-monitoring-agent.deb || true",
    ]
  }

  # ── Cleanup ──
  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/* /tmp/*",
    ]
  }

  post-processor "manifest" {
    output     = "manifest-cluster-director-custom.json"
    strip_path = true
  }
}
```

**Step 2: Build the image**

```bash
packer init custom-image.pkr.hcl
packer build -var="project_id=$PROJECT_ID" custom-image.pkr.hcl
```

**Step 3: Use the custom image in Cluster Director**

When creating a cluster:

- **Console**: In the **Partitions** section, expand a nodeset and select your custom image in the **Source image** field.
- **gcloud CLI**: Specify the image in the nodeset configuration within your JSON config file.
- **REST API**: Include the image reference in the `computeInstance` section of the nodeset.

> For detailed Packer templates and CI/CD integration with Cloud Build, see the [Packer Guide](../../02-core-infrastructure/disk-images/packer/README.md).

**Step 3a: Build from Cluster Toolkit (advanced)**

For the most control, you can also build custom images using Cluster Toolkit directly, mirroring how Cluster Director's own images are built:

```bash
cd ~/cluster-toolkit
# Modify an existing Slurm image blueprint to add your custom software
# Then build with:
./gcluster deploy -d your-custom-image-deployment.yaml your-custom-image-blueprint.yaml
```

#### Approach 3: Containerized Workloads with Enroot + Pyxis

Since Cluster Director includes **NVIDIA enroot** (container runtime) and **pyxis** (Slurm integration), you can run containerized workloads without building custom OS images at all. Package your custom software, APIs, and ML frameworks into a Docker/OCI container image and run it via Slurm:

```bash
# Submit a containerized job using enroot + pyxis
srun --container-image=nvcr.io/nvidia/pytorch:24.07-py3 \
     --container-mounts=/data:/data \
     python /data/train.py

# Or in a batch script
sbatch << 'EOF'
#!/bin/bash
#SBATCH --job-name=training
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --container-image=gcr.io/your-project/your-custom-image:latest
#SBATCH --container-mounts=/home:/home,/data:/data

python -m torch.distributed.launch --nproc_per_node=8 train.py
EOF
```

> **Best for**: Teams that already use containers, want image portability, or need different software stacks per job.

### Trusted Image Policy

If your organization enforces a trusted image policy (`constraints/compute.trustedImageProjects`), you must ensure that:

1. The `clusterdirector-public-images` project is in the allowed list (for default images)
2. Your custom image project is in the allowed list (for custom images)

```bash
# Check your organization's trusted image policy
gcloud resource-manager org-policies describe \
    constraints/compute.trustedImageProjects \
    --project=$PROJECT_ID
```

---

## 7. APIs and Programmatic Access

Cluster Director provides multiple interfaces for automation and integration.

### Hypercompute Cluster API

The primary API for Cluster Director operations:

```bash
# Enable the API
gcloud services enable hypercomputecluster.googleapis.com --project=$PROJECT_ID
```

### gcloud CLI (Alpha)

```bash
# Create a cluster
gcloud alpha cluster-director clusters create CLUSTER_NAME \
    --location=REGION \
    --config=cluster-config.json

# List clusters
gcloud alpha cluster-director clusters list \
    --location=REGION

# Describe a cluster
gcloud alpha cluster-director clusters describe CLUSTER_NAME \
    --location=REGION

# Delete a cluster
gcloud alpha cluster-director clusters delete CLUSTER_NAME \
    --location=REGION
```

### REST API

```bash
# Create a cluster
curl -X POST \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json; charset=utf-8" \
     -d @cluster-config.json \
     "https://hypercomputecluster.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clusters?clusterId=CLUSTER_NAME"

# List clusters
curl -X GET \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     "https://hypercomputecluster.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clusters"

# Get cluster details
curl -X GET \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     "https://hypercomputecluster.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clusters/$CLUSTER_NAME"

# Delete a cluster
curl -X DELETE \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     "https://hypercomputecluster.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/clusters/$CLUSTER_NAME"
```

### Required IAM Roles

| Role | Purpose |
|---|---|
| `roles/hypercomputecluster.editor` | Create and manage clusters |
| `roles/compute.instanceAdmin.v1` | Create and manage VMs in a cluster |
| `roles/iam.serviceAccountUser` | Act as service accounts (on Compute Engine default SA) |
| `roles/compute.osLogin` | SSH into login nodes |
| `roles/iap.tunnelResourceAccessor` | Connect via IAP tunnel |
| `roles/logging.logWriter` | Write logs (on Compute Engine default SA) |
| `roles/monitoring.metricWriter` | Write metrics (on Compute Engine default SA) |
| `roles/storage.objectViewer` | Read from Cloud Storage (on Compute Engine default SA) |

### Required APIs

```bash
gcloud services enable \
    hypercomputecluster.googleapis.com \
    compute.googleapis.com \
    file.googleapis.com \
    managedlustre.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com \
    --project=$PROJECT_ID
```

---

## 8. Slurm Architecture in Cluster Director

### Cluster Components

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Cluster Director Slurm Cluster                      │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Controller Node (Managed by Cluster Director)                   │  │
│  │                                                                  │  │
│  │  • slurmctld (primary + backup for HA)                          │  │
│  │  • MUNGE (authentication)                                       │  │
│  │  • MariaDB (accounting & state)                                 │  │
│  │  • NOT directly accessible — Cluster Director manages it        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              │                                         │
│                  ┌───────────┴───────────┐                             │
│                  │                       │                              │
│  ┌───────────────▼──────────┐  ┌────────▼──────────────────────────┐  │
│  │  Login Node(s)            │  │  Compute Nodes                    │  │
│  │  (N2 standard, ≤32 vCPU) │  │  (GPU: A4X/A4/A3 Ultra/A3 Mega)  │  │
│  │                          │  │                                    │  │
│  │  • SSH entry point       │  │  Organized into Partitions:        │  │
│  │  • Submit jobs (sbatch)  │  │  ┌─────────────────────────────┐  │  │
│  │  • Check status (squeue) │  │  │ Partition "gpu-a3mega"      │  │  │
│  │  • Manage workflows      │  │  │  ├── Nodeset "ns-reserved"  │  │  │
│  │  • Access shared storage │  │  │  │   (reservation-bound)    │  │  │
│  │                          │  │  │  └── Nodeset "ns-flex"      │  │  │
│  │                          │  │  │      (Flex-start / DWS)     │  │  │
│  │                          │  │  └─────────────────────────────┘  │  │
│  │                          │  │  ┌─────────────────────────────┐  │  │
│  │                          │  │  │ Partition "gpu-a4"          │  │  │
│  │                          │  │  │  └── Nodeset "ns-a4-spot"  │  │  │
│  │                          │  │  │      (Spot VMs)             │  │  │
│  │                          │  │  └─────────────────────────────┘  │  │
│  └──────────────────────────┘  └────────────────────────────────────┘  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Shared Storage                                                  │  │
│  │                                                                  │  │
│  │  • Filestore (NFS — /home, shared data)                         │  │
│  │  • Google Cloud Managed Lustre (high-throughput parallel I/O)    │  │
│  │  • Cloud Storage via GCSFuse (checkpoints, datasets)            │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Node Types

| Node Type | Purpose | Machine Types | Accessibility |
|---|---|---|---|
| **Controller** | Slurm control plane (slurmctld, MUNGE, MariaDB) — manages resources, schedules jobs | Managed internally | ❌ Not directly accessible |
| **Login** | SSH entry point for users — submit/manage jobs, access shared storage | N2 standard (≤32 vCPU) | ✅ SSH via Console or IAP |
| **Compute** | Execute workloads — organized in partitions and nodesets | A4X Max, A4X, A4, A3 Ultra, A3 Mega, N2 | ✅ via Slurm (`srun`) |

### Partitions and Nodesets

- **Partitions**: Logical groupings of compute resources. Each partition can have different priority, limits, and access controls.
- **Nodesets**: Within a partition, a nodeset defines a group of compute nodes with the same machine type, image, and consumption option.
- **Static nodes**: Always running — provides a baseline of available compute.
- **Dynamic nodes**: Scale up/down based on demand — Slurm creates VMs when jobs are submitted and deletes them when idle.

### Topology-Aware Scheduling

Cluster Director uses Slurm's topology-aware scheduling to place workloads on physically close nodes:

- **A4X clusters**: Use [block topology](https://slurm.schedmd.com/topology.html#block) aligned with NVLink domains
  - `--segment=SIZE`: Group nodes into segments (1–18 nodes)
  - `--exclusive=topo`: Reserve an entire sub-block for a job
- **A4, A3 Ultra, A3 Mega clusters**: Dense co-location via reservation block placement

### GPU Health Checks

Before starting any job, Slurm runs a **prolog script** that checks the health of each node's GPUs. If a GPU fails the health check, Slurm automatically **drains** the node, preventing jobs from running on unhealthy hardware.

---

## 9. Quickstart: Create a Cluster with DWS Flex-Start

This quickstart creates a Slurm cluster with two A3 Mega Flex-start VMs.

### Prerequisites

```bash
# Enable required APIs
gcloud services enable \
    hypercomputecluster.googleapis.com \
    compute.googleapis.com \
    file.googleapis.com \
    managedlustre.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com \
    --project=$PROJECT_ID

# Verify IAM roles (you need these on your user account)
# - roles/hypercomputecluster.editor
# - roles/compute.instanceAdmin.v1
# - roles/compute.osLogin
# - roles/iap.tunnelResourceAccessor

# Verify IAM roles (you need these on the Compute Engine default SA)
# - roles/iam.serviceAccountUser
# - roles/logging.logWriter
# - roles/monitoring.metricWriter
# - roles/storage.objectViewer
```

### Create the Cluster (Console)

1. Go to **[Cluster Director](https://console.cloud.google.com/cluster-director/overview)** in the Google Cloud Console
2. Click **Create a cluster**
3. Click **Step-by-step configuration**
4. Enter a cluster name (e.g., `cluster000`)
5. In the **Compute** section, click **Configure resources**:
   - **GPU type**: Select `NVIDIA H100 80GB MEGA`
   - **Number of instances**: `2`
   - **Consumption options**: Click **Use Flex-start**
   - **Region**: `us-central1`, **Zone**: `us-central1-a`
   - Click **Done**
6. In **Storage**, click **Add storage configuration**:
   - Select the **Managed Lustre** tab
   - Click **Done**
7. Click **Create**

### Create the Cluster (gcloud CLI)

```bash
gcloud alpha cluster-director clusters create cluster000 \
    --location=us-central1 \
    --config=cluster-config.json
```

Example `cluster-config.json`:

```json
{
  "name": "cluster000",
  "networkResources": {
    "net001": {
      "config": {
        "newNetwork": {
          "network": "projects/PROJECT_ID/global/networks/net001"
        }
      }
    }
  },
  "storageResources": {
    "fs001": {
      "config": {
        "newFilestore": {
          "filestore": "projects/PROJECT_ID/locations/us-central1-a/instances/fs001",
          "fileShares": {
            "capacityGb": "1024",
            "fileShare": "homeshare"
          },
          "tier": "ZONAL",
          "protocol": "NFSV3"
        }
      }
    }
  },
  "computeResources": {
    "gpu001": {
      "config": {
        "newDwsFlexInstances": {
          "zone": "us-central1-a",
          "machineType": "a3-megagpu-8g",
          "count": 2,
          "maxRunDuration": "604800s"
        }
      }
    }
  },
  "orchestrator": {
    "slurm": {
      "loginNodes": {
        "count": "1",
        "zone": "us-central1-a",
        "machineType": "n2-standard-4"
      },
      "nodeSets": [
        {
          "id": "ns001",
          "computeId": "gpu001",
          "storageConfigs": [
            {
              "id": "fs001",
              "localMount": "/home"
            }
          ],
          "staticNodeCount": "2",
          "maxDynamicNodeCount": "0"
        }
      ],
      "partitions": [
        {
          "id": "gpu",
          "nodeSetIds": ["ns001"]
        }
      ],
      "defaultPartition": "gpu"
    }
  }
}
```

### Connect and Run Jobs

```bash
# SSH into the login node (via Console or gcloud)
gcloud compute ssh cluster000-login-001 --zone=us-central1-a --tunnel-through-iap

# Verify Slurm is running
sinfo

# Submit a test job
srun hostname

# Submit a batch job
sbatch --wrap="sleep 30"

# Check job status
squeue

# View accounting data
sacct
```

### Clean Up

```bash
# Delete the cluster and all associated resources
gcloud alpha cluster-director clusters delete cluster000 \
    --location=us-central1
```

---

## 10. Limitations

### Cluster-Level Limitations

| Limitation | Detail |
|---|---|
| **Regional scope** | Clusters are regional resources — all compute, storage, and subnetworks must be in the same region |
| **Cluster name** | Maximum 10 characters, lowercase letters and numbers only (`a-z`, `0-9`) |
| **Controller node access** | You cannot directly SSH into or configure the Slurm controller node — it is fully managed |
| **Login node machine types** | Login nodes are limited to N2 standard machine types with ≤32 vCPUs |
| **Slurm-only orchestrator** | No GKE/Kubernetes support — Cluster Director is Slurm-only |
| **gcloud CLI maturity** | Commands are currently in alpha (`gcloud alpha cluster-director`) — may change |

### Compute Limitations

| Limitation | Detail |
|---|---|
| **One compute config per nodeset** | Each nodeset can only reference one compute resource configuration |
| **A4X VM count** | Total VMs per A4X nodeset must be a multiple of 18 (static + dynamic count) |
| **A4X sub-block sharing** | Remaining A4X capacity in a nodeset cannot be shared with other nodesets |
| **A4X/A4X Max consumption** | A4X Max and A4X require reservation-bound provisioning only — no Flex-start or Spot |
| **Supported GPU machine types** | Limited to A4X Max, A4X, A4, A3 Ultra, A3 Mega (no A3 High, A3 Edge, A2, G2, etc.) |
| **CPU machine types** | Limited to N2 series only (no C2, C3, N1, E2, etc.) |

### DWS / Consumption Option Limitations

| Limitation | Detail |
|---|---|
| **Flex-start max duration** | 7 days maximum — VMs are deleted at the end of run duration |
| **Flex-start capacity** | Best-effort — no guarantee of when VMs will be provisioned |
| **Calendar Mode max** | Up to 80 VMs for up to 90 days |
| **Calendar Mode lead time** | ≥87 hours for GPUs before start time |
| **Calendar Mode cancellation** | Cannot cancel or modify after submission — you commit to pay at start time |
| **Spot preemption** | Spot VMs can be preempted at any time to reclaim capacity |
| **Spot / On-demand allocation** | Dense allocation is best-effort (not guaranteed like reservations/Flex-start) |

### Storage Limitations

| Limitation | Detail |
|---|---|
| **New Cloud Storage buckets** | Limited to Standard storage class or Autoclass only |
| **Storage region** | Must be in the same region as the cluster |

### Customization Limitations

| Limitation | Detail |
|---|---|
| **Slurm configuration** | Cannot directly edit `slurm.conf` — limited to prolog/epilog scripts, startup scripts, and image selection |
| **Custom Slurm plugins** | Must be baked into a custom OS image — cannot install at runtime |
| **Custom images** | Must maintain compatibility with Cluster Director's managed Slurm environment (Slurm 25.05, MUNGE, etc.) |
| **Trusted image policy** | If org has a trusted image policy, `clusterdirector-public-images` must be in the allowed list |

### Feature Limitations (vs. Alternatives)

| Limitation | Detail |
|---|---|
| **No GKE integration** | Cannot create GKE node pools or run Kubernetes workloads — use Cluster Toolkit for GKE |
| **No Cluster Health Scanner** | CHS is available in Cluster Toolkit GKE blueprints but not in Cluster Director |
| **No Kueue** | Cluster Director uses Slurm's native scheduler — Kueue is GKE-only |
| **No reservation + DWS fallback** | Cannot automatically fall back from reservation to DWS — use separate partitions |
| **No infrastructure-as-code** | Cluster Director is API-driven, not Terraform-based — use Cluster Toolkit for IaC |

---

## 11. Best Practices

### Cluster Design

| Best Practice | Detail |
|---|---|
| **Use partitions to separate workload types** | Create separate partitions for different GPU types, consumption options, or teams |
| **Mix static and dynamic nodes** | Use static nodes for baseline capacity and dynamic nodes for burst scaling |
| **Choose the right consumption option** | Flex-start for cost-sensitive batch; reservations for guaranteed capacity; Spot for fault-tolerant workloads |
| **Use Filestore or Managed Lustre for /home** | Shared storage ensures job scripts and data are accessible from all nodes |

### DWS Flex-Start Workloads

| Best Practice | Detail |
|---|---|
| **Always checkpoint** | Flex-start VMs are deleted at the end of run duration — checkpoint frequently to GCS, Filestore, or Lustre |
| **Right-size run duration** | Shorter durations may be fulfilled faster — don't request 7 days if you need 6 hours |
| **Design for all-at-once** | DWS provisions all VMs simultaneously — ensure your workload can start with all nodes available |
| **Plan for wait time** | Flex-start provisioning is best-effort — your login node will be ready immediately, but GPU VMs may take time |

### Custom Images

| Best Practice | Detail |
|---|---|
| **Start from Cluster Director base images** | Extend `clusterdirector-public-images` to ensure Slurm compatibility |
| **Use Packer for reproducibility** | Automate image builds with Packer and Cloud Build for consistent, versioned images |
| **Use startup scripts for light customizations** | Avoid full image rebuilds for small changes like environment variables or pip packages |
| **Use containers (enroot + pyxis) for portability** | Package workload-specific software in containers instead of OS images |
| **Test images before production** | Validate custom images in a small test cluster before deploying at scale |
| **Version your images** | Include version numbers in image names and use image families for rolling updates |

### Security

| Best Practice | Detail |
|---|---|
| **Use IAP for SSH** | Connect to login nodes via IAP tunnel — no public IP required |
| **Enable OS Login** | Use identity-based authentication instead of SSH keys |
| **Don't store secrets in images** | Use Secret Manager and retrieve secrets at runtime |
| **Use trusted image policies** | Enforce `constraints/compute.trustedImageProjects` to prevent unauthorized images |
| **Verify quota before cluster creation** | Insufficient quota causes cluster creation failures |

### Data Residency (Public Sector)

| Best Practice | Detail |
|---|---|
| **Specify zones explicitly** | All consumption options provision VMs only in your specified zone |
| **Use Assured Workloads** | For FedRAMP High, DoD IL4/IL5 — automatically enforces resource location constraints |
| **Align storage and compute regions** | Keep Filestore, Lustre, and GCS in the same region as your GPU cluster |
| **Verify GPU availability in compliant zones** | Not all US zones have all GPU types |

---

## 12. References

### Cluster Director Documentation

- [Cluster Director Overview](https://cloud.google.com/cluster-director/docs)
- [Supported Compute Resources](https://cloud.google.com/cluster-director/docs/compute)
- [Slurm Orchestration in Cluster Director](https://cloud.google.com/cluster-director/docs/orchestration)
- [Choose a Consumption Option](https://cloud.google.com/cluster-director/docs/choose-consumption-option)
- [Quickstart: Create a Slurm Cluster](https://cloud.google.com/cluster-director/docs/create/quickstart)
- [Create an AI-Optimized Cluster from Template](https://cloud.google.com/cluster-director/docs/create/cluster-from-template)
- [Create a Custom Cluster](https://cloud.google.com/cluster-director/docs/create/custom-cluster)
- [Cluster Creation Process Overview](https://cloud.google.com/cluster-director/docs/create/process-overview)
- [Supported Networking Services](https://cloud.google.com/cluster-director/docs/networking)
- [Capacity and Quota Overview](https://cloud.google.com/cluster-director/docs/obtain-capacity)
- [Reserve Capacity](https://cloud.google.com/cluster-director/docs/reserve-capacity)
- [REST API Reference](https://cloud.google.com/cluster-director/docs/reference/rest/v1/projects.locations.clusters)

### TPU Cluster Director

- [TPU Cluster Director Overview (All Capacity Mode)](https://cloud.google.com/tpu/docs/all-capacity-overview)

### Cluster Management Capabilities

- [Cluster Management Overview](https://cloud.google.com/ai-hypercomputer/docs/cluster-capabilities)
- [View Compute Instance Topology](https://cloud.google.com/ai-hypercomputer/docs/manage/vms-topology)
- [Manage Host Events](https://cloud.google.com/ai-hypercomputer/docs/manage/host-events)
- [Report Faulty Hosts](https://cloud.google.com/ai-hypercomputer/docs/manage/report-faulty-host)
- [VM Health Degradation Prediction](https://cloud.google.com/ai-hypercomputer/docs/workloads/enable-node-health-prediction)

### DWS & Capacity

- [DWS Pricing](https://cloud.google.com/products/dws/pricing)
- [Future Reservations (Calendar Mode)](https://cloud.google.com/compute/docs/instances/future-reservations-calendar-mode-overview)
- [About Flex-Start VMs](https://cloud.google.com/compute/docs/instances/about-flex-start-vms)
- [Spot VMs Overview](https://cloud.google.com/compute/docs/instances/spot)

### GPU & Zone References

- [GPU Regions and Zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)
- [Accelerator-Optimized Machine Families](https://cloud.google.com/compute/docs/accelerator-optimized-machines)

### Related Sections in This Repository

- [DWS Concepts](../dws/) — Dynamic Workload Scheduler concepts, pricing, compliance
- [Deployment Methods Overview](../) — Compare all deployment methods
- [Cluster Toolkit Guide](../cluster-toolkit/) — Production-ready GKE clusters with Cluster Toolkit
- [XPK Guide](../xpk/) — Quick GKE clusters for PoC and testing
- [Disk Images & Packer](../../02-core-infrastructure/disk-images/README.md) — VM image creation methods
- [Packer Guide](../../02-core-infrastructure/disk-images/packer/README.md) — Automated image building with Packer
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket
- [Zero Trust IAP Access](../../02-core-infrastructure/zero-trust-iap-access/README.md) — Securing cluster access

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Cluster Director is currently available as a managed service — features and APIs may evolve. Always follow your organization's security policies, verify GPU availability in your target zones, and review [DWS pricing](https://cloud.google.com/products/dws/pricing) before deploying clusters. The `gcloud alpha cluster-director` commands are in alpha and may change without notice.
