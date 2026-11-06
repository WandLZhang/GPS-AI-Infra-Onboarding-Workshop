# XPK (Accelerated Processing Kit) — Quick GPU & TPU Clusters with DWS Support

> A comprehensive guide to using XPK for rapidly creating GKE clusters and running AI/ML workloads on GPU and TPU accelerators, with Dynamic Workload Scheduler (DWS) flex-start integration for cost-effective, time-flexible provisioning.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [When to Use XPK with DWS](#2-when-to-use-xpk-with-dws)
3. [Supported Accelerators & Consumption Models](#3-supported-accelerators--consumption-models)
4. [Prerequisites](#4-prerequisites)
5. [Installation](#5-installation)
6. [Cluster Creation with DWS Flex-Start](#6-cluster-creation-with-dws-flex-start)
7. [Submitting DWS Workloads](#7-submitting-dws-workloads)
8. [How XPK DWS Works Under the Hood](#8-how-xpk-dws-works-under-the-hood)
9. [Workload Management](#9-workload-management)
10. [Storage Integration](#10-storage-integration)
11. [XPK vs. Cluster Toolkit Decision Guide](#11-xpk-vs-cluster-toolkit-decision-guide)
12. [Best Practices](#12-best-practices)
13. [Troubleshooting](#13-troubleshooting)
14. [References](#14-references)

---

## 1. Overview

**[XPK (Accelerated Processing Kit)](https://github.com/AI-Hypercomputer/xpk)** is a Python command-line interface that simplifies cluster creation and workload execution on Google Kubernetes Engine (GKE). XPK generates preconfigured, training-optimized clusters and allows easy workload scheduling **without any Kubernetes expertise**.

### What XPK Does

| Capability | Detail |
|---|---|
| **One-command clusters** | `xpk cluster create` provisions a fully configured GKE cluster with GPU/TPU node pools |
| **One-command workloads** | `xpk workload create` submits training jobs — no YAML manifests or kubectl needed |
| **Zero K8s knowledge required** | XPK abstracts away Kueue, JobSet, node selectors, tolerations, and scheduling |
| **Auto-installs dependencies** | Kueue, JobSet, CoreDNS, and Crane are automatically installed |
| **DWS flex-start built-in** | Use `--flex` flag to enable DWS queued provisioning for up to 53% cost savings |
| **Multi-accelerator support** | TPUs (v4 through Ironwood/tpu7x) and GPUs (A100 through A4X) |
| **Workload queuing** | Built-in priority levels and preemption via Kueue |

### When to Use XPK

XPK is **recommended for quick creation of GKE clusters for proofs-of-concept and testing**. It is ideal when workload execution is your primary focus and you want to minimize infrastructure setup time.

```
┌───────────────────────────────────────────────────────────────────────────┐
│              Methods for Creating AI-Optimized GKE Clusters              │
│                                                                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐   │
│  │ Cluster Toolkit  │  │      XPK        │  │   Manual (gcloud CLI)   │   │
│  │                  │  │                 │  │                         │   │
│  │ Production-ready │  │ Quick PoC &     │  │ Maximum flexibility     │   │
│  │ Best practices   │  │ testing         │  │ Existing clusters       │   │
│  │ Full stack       │  │ Workload-first  │  │ Custom configurations   │   │
│  │ Terraform-based  │  │ Python CLI      │  │ Incremental changes     │   │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘   │
│                             ▲ USE XPK                                     │
│                             │ when speed and                              │
│                             │ simplicity matter                           │
└───────────────────────────────────────────────────────────────────────────┘
```

### Key Concept: Decoupled Provisioning and Workloads

XPK decouples **provisioning capacity** from **running jobs**:

- **Clusters** represent the physical resources you have available (provisioned VMs).
- **Workloads** represent training jobs — at any time some are completed, others running, and some queued waiting for resources.

The ideal workflow:
1. Provision a cluster for all your ML hardware.
2. Submit jobs as needed without re-provisioning.
3. Queued jobs run with minimal start times (Docker containers + pre-compilation).
4. Completed workloads return hardware to the shared pool for other developers.

---

## 2. When to Use XPK with DWS

### Ideal Workloads for XPK + DWS

XPK with DWS flex-start (`--flex`) is best suited for workloads that are **time-flexible, cost-sensitive, and experimental** in nature. The DWS flex-start mode queues your GPU/TPU request and provisions resources when capacity becomes available — at **up to 53% discount** compared to on-demand pricing.

| Workload Type | Why XPK + DWS Is a Good Fit |
|---|---|
| **Proof-of-concept training** | Rapidly spin up a cluster to validate a training approach without committing to reserved capacity |
| **Model fine-tuning** | Fine-tune foundation models on a few GPUs/TPUs for hours to days at a discounted rate |
| **Hyperparameter sweeps** | Submit multiple workloads with different configs; Kueue queues and schedules them automatically |
| **Benchmarking & NCCL testing** | Test GPU/TPU network performance before committing to production infrastructure |
| **Research & experimentation** | Iterate quickly on model architectures, data pipelines, or training frameworks |
| **Nightly/overnight batch jobs** | Submit jobs in the evening; DWS provisions when capacity is available overnight |
| **Small-to-medium distributed training** | 1–64 GPUs/TPUs for up to 7 days, where waiting for capacity is acceptable |
| **Team onboarding & demos** | Get new team members hands-on with GPU/TPU hardware without reservation commitments |

### Workload Characteristics That Suit DWS Flex-Start

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Is XPK + DWS Right for Your Workload?                │
│                                                                         │
│  ✅ GOOD FIT                          ❌ NOT IDEAL                      │
│  ─────────                            ────────────                      │
│  • Time-flexible (can wait            • Must start immediately          │
│    for capacity)                      • Runs longer than 7 days         │
│  • Runs up to 7 days                  • Production-critical with SLAs   │
│  • Cost-sensitive                     • Requires custom K8s configs     │
│  • PoC / testing / research           • Multi-tenant production cluster │
│  • Can checkpoint & restart           • Needs guaranteed start time     │
│  • Single-team, single-purpose        • Complex multi-framework         │
│    cluster                              pipelines                       │
│  • Quick iteration cycle              • Regulatory compliance needs     │
│                                         fine-grained control            │
└─────────────────────────────────────────────────────────────────────────┘
```

### Decision Flow

```
                    Is this a proof-of-concept,
                    test, or experimental workload?
                               │
                    ┌──────────┴──────────┐
                   Yes                    No
                    │                      │
              Is the workload         Consider Cluster
              time-flexible?          Toolkit (production)
                    │                 or Vertex AI (serverless)
             ┌──────┴──────┐
            Yes            No
             │              │
        Do you have      Use reservation-
        reserved         bound XPK cluster
        capacity?        (--reservation)
             │
      ┌──────┴──────┐
     Yes            No
      │              │
  Use XPK with    Use XPK with
  --reservation   --flex (DWS)
                  Up to 53% discount
                  7-day max duration
```

---

## 3. Supported Accelerators & Consumption Models

### TPU Accelerators

| Accelerator | XPK Type | DWS Flex-Start | Reservation | Spot | On-Demand |
|---|---|:---:|:---:|:---:|:---:|
| **Ironwood (TPU7x)** | `tpu7x-<topology>` | ✅ | ✅ | — | — |
| **Trillium (v6e)** | `v6e-<topology>` | ✅ | ✅ | ✅ | ✅ |
| **TPU v5p** | `v5p-<topology>` | ✅ | ✅ | ✅ | ✅ |
| **TPU v5e** | `v5e-<topology>` | ✅ | ✅ | ✅ | ✅ |
| **TPU v4** | `v4-<topology>` | ✅ | ✅ | ✅ | ✅ |

### GPU Accelerators

| Accelerator | XPK Device Type | DWS Flex-Start | Reservation | Spot | On-Demand |
|---|---|:---:|:---:|:---:|:---:|
| **A4X (GB200)** | `gb200` | — | ✅ (required) | — | — |
| **A4 (B200)** | `b200-8` | ✅ | ✅ | ✅ | — |
| **A3 Ultra (H200)** | `h200-141gb-8` | ✅ | ✅ | ✅ | — |
| **A3 Mega (H100)** | `h100-mega-80gb-8` | ✅ | ✅ | ✅ | ✅ |
| **A3 High (H100)** | `h100` | ✅ | ✅ | ✅ | ✅ |
| **A100** | `A100` | ✅ | ✅ | ✅ | ✅ |

### Consumption Model Flags

| Flag | Consumption Model | Pricing | Availability |
|---|---|---|---|
| `--reservation=$NAME` | Reserved capacity | CUD or on-demand rate | Guaranteed |
| `--on-demand` | On-demand | Full price | If available |
| `--flex` | DWS flex-start | **Up to 53% discount** | Queued until available |
| `--spot` | Spot / Preemptible | Up to 91% discount | Best-effort, preemptible |

---

## 4. Prerequisites

### Required Tools

| Tool | Purpose | Install |
|---|---|---|
| `gcloud` CLI | Google Cloud operations | [Install](https://cloud.google.com/sdk/docs/install) |
| `python3` (3.10+) | Run XPK CLI | Pre-installed on most systems |
| `pip` | Install XPK package | Included with Python |
| `docker` | Build workload containers | [Install](https://docs.docker.com/engine/install/) |
| `kubectl` | Kubernetes management (auto-installed by XPK) | `gcloud components install kubectl` |

> **Recommendation**: Use **Cloud Shell** or a **Cloud Workstation** — most dependencies are pre-installed.

### Required IAM Roles

Ensure the account running XPK has the following roles. See the full list in the [XPK permissions doc](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/permissions.md).

| Role | Purpose |
|---|---|
| `roles/container.admin` | GKE cluster and node pool management |
| `roles/compute.admin` | VPC, subnet, and VM management |
| `roles/storage.admin` | GCS bucket operations |
| `roles/iam.serviceAccountAdmin` | Service account management |
| `roles/iam.serviceAccountUser` | Act as service accounts |

### Required APIs

```bash
gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    storage.googleapis.com \
    iam.googleapis.com \
    --project=$PROJECT_ID
```

### Quota Verification

```bash
# Check GPU/TPU quota in your target region
gcloud compute regions describe $REGION \
    --format="yaml(quotas)" \
    --project=$PROJECT_ID

# For DWS flex-start, check active resize requests quota
gcloud compute project-info describe \
    --format="yaml(quotas)" \
    --project=$PROJECT_ID
```


---

## 5. Installation

### Option A: Install from PyPI (Recommended)

```bash
# Create and activate a virtual environment
python3 -m venv ~/xpk-env
source ~/xpk-env/bin/activate

# Install XPK
pip install xpk

# Verify installation
xpk --help
```

### Option B: Install from Source

```bash
# Set up virtual environment
VENV_DIR=~/venvp3
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# Clone the repository (use the latest tagged release)
XPK_TAG=v0.8.0  # Check https://github.com/AI-Hypercomputer/xpk/releases for latest
git clone --branch $XPK_TAG https://github.com/AI-Hypercomputer/xpk.git
cd xpk

# Install required packages
make install && export PATH=$PATH:$PWD/bin

# Verify installation
xpk --help
```

### Configure Docker (for custom workload images)

```bash
gcloud auth configure-docker
sudo usermod -aG docker $USER
# Relaunch terminal after this command
docker run hello-world  # Test Docker
```

---

## 6. Cluster Creation with DWS Flex-Start

### Environment Setup

```bash
export PROJECT_ID="your-project-id"
export ZONE="us-central1-c"         # Zone with your target accelerator
export CLUSTER_NAME="xpk-dws-test"
```

### TPU Cluster with DWS Flex-Start

Create a GKE cluster with TPU node pools using DWS flex-start provisioning:

```bash
xpk cluster create \
    --cluster $CLUSTER_NAME \
    --project $PROJECT_ID \
    --zone $ZONE \
    --tpu-type=v5litepod-16 \
    --num-slices=4 \
    --flex
```

| Flag | Description |
|---|---|
| `--tpu-type` | TPU type and topology (e.g., `v5litepod-16`, `tpu7x-2x2x2`) |
| `--num-slices` | Number of TPU slice node pools |
| `--flex` | **Enable DWS flex-start** — nodes are provisioned when capacity is available |

### Ironwood (TPU7x) Cluster with DWS Flex-Start

Ironwood clusters require network configuration for optimal performance:

```bash
# Set up network with 8,896 MTU for optimal TPU performance
export NETWORK_NAME="xpk-tpu7x-net"
export SUBNET_NAME="xpk-tpu7x-subnet"
export IP_RANGE="10.0.0.0/24"
export REGION=${ZONE%-*}

gcloud compute networks create $NETWORK_NAME \
    --mtu=8896 --project=$PROJECT_ID \
    --subnet-mode=custom --bgp-routing-mode=regional

gcloud compute networks subnets create $SUBNET_NAME \
    --project=$PROJECT_ID \
    --network=$NETWORK_NAME --region=$REGION --range=$IP_RANGE

gcloud compute firewall-rules create ${NETWORK_NAME}-privatefirewall \
    --network=$NETWORK_NAME \
    --allow tcp,icmp,udp --project=$PROJECT_ID

# Create the cluster
export ACCELERATOR_TYPE="tpu7x-2x2x2"
export CLUSTER_ARGUMENTS="--network=${NETWORK_NAME} --subnetwork=${SUBNET_NAME}"

xpk cluster create \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --cluster $CLUSTER_NAME \
    --cluster-cpu-machine-type=n1-standard-8 \
    --tpu-type=$ACCELERATOR_TYPE \
    --flex \
    --custom-cluster-arguments="$CLUSTER_ARGUMENTS"
```

> **Important**: After creating an Ironwood cluster, add a maintenance exclusion to prevent upgrades:
> ```bash
> gcloud container clusters update $CLUSTER_NAME \
>     --region=$REGION --project=$PROJECT_ID \
>     --add-maintenance-exclusion-name="no-upgrade-next-month" \
>     --add-maintenance-exclusion-start="2026-04-01T00:00:00Z" \
>     --add-maintenance-exclusion-end="2026-05-01T00:00:00Z" \
>     --add-maintenance-exclusion-scope="no_upgrades"
> ```

### GPU Cluster with DWS Flex-Start

Create a GKE cluster with GPU node pools (A3 Mega, A3 Ultra, or A4) using DWS:

```bash
# A3 Ultra (H200) example
xpk cluster create \
    --cluster $CLUSTER_NAME \
    --device-type h200-141gb-8 \
    --zone $ZONE \
    --project $PROJECT_ID \
    --num-nodes=8 \
    --flex
```

```bash
# A4 (B200) example
xpk cluster create \
    --cluster $CLUSTER_NAME \
    --device-type b200-8 \
    --zone $ZONE \
    --project $PROJECT_ID \
    --num-nodes=4 \
    --flex
```

| Flag | Description |
|---|---|
| `--device-type` | GPU device type (e.g., `h200-141gb-8`, `b200-8`, `h100-mega-80gb-8`) |
| `--num-nodes` | Number of GPU worker nodes |
| `--flex` | **Enable DWS flex-start** |

### Other Consumption Models (for comparison)

```bash
# Reservation-bound (guaranteed capacity)
xpk cluster create \
    --cluster $CLUSTER_NAME \
    --tpu-type=v5litepod-16 \
    --num-slices=4 \
    --reservation=$RESERVATION_ID

# On-demand (full price, if available)
xpk cluster create \
    --cluster $CLUSTER_NAME \
    --tpu-type=v5litepod-16 \
    --num-slices=4 \
    --on-demand

# Spot (cheapest, preemptible)
xpk cluster create \
    --cluster $CLUSTER_NAME \
    --tpu-type=v5litepod-16 \
    --num-slices=4 \
    --spot
```

### Verify Cluster Creation

```bash
# List clusters
xpk cluster list --zone $ZONE --project $PROJECT_ID

# Describe cluster details
xpk cluster describe --cluster $CLUSTER_NAME

# XPK provides a Google Cloud console URL — save it for monitoring:
# https://console.cloud.google.com/kubernetes/clusters/details/<zone>/<cluster>/details?project=<project>
```

---

## 7. Submitting DWS Workloads

### Basic TPU Workload with DWS

```bash
xpk workload create \
    --workload xpk-dws-training \
    --command "echo 'Hello from DWS-provisioned TPU'" \
    --cluster $CLUSTER_NAME \
    --tpu-type=v5litepod-16 \
    --project $PROJECT_ID \
    --flex
```

> **Note**: The `--flex` flag on `workload create` tells Kueue to use DWS queued provisioning for this workload. The cluster must also have been created with `--flex`.

### GPU Workload with DWS

```bash
xpk workload create \
    --workload gpu-dws-training \
    --command "python3 train.py" \
    --cluster $CLUSTER_NAME \
    --device-type h200-141gb-8 \
    --num-nodes=4 \
    --zone $ZONE \
    --project $PROJECT_ID
```

### Training with a Custom Docker Image

```bash
xpk workload create \
    --workload my-training-job \
    --docker-image gcr.io/$PROJECT_ID/my-training-image:latest \
    --command "python3 -m train --epochs=10 --batch_size=64" \
    --cluster $CLUSTER_NAME \
    --tpu-type=v5litepod-16 \
    --project $PROJECT_ID \
    --flex
```

### Training with a Local Docker Image (Base Image Pattern)

XPK can build a workload image by copying your local directory into a base image:

```bash
xpk workload create \
    --workload maxtext-training \
    --base-docker-image maxtext_base_image \
    --command "python3 -m MaxText.train MaxText/configs/base.yml \
        base_output_directory=gs://my-bucket/output \
        dataset_type=synthetic \
        per_device_batch_size=2 \
        steps=100" \
    --cluster $CLUSTER_NAME \
    --tpu-type=tpu7x-2x2x2 \
    --zone $ZONE \
    --project $PROJECT_ID
```

### Setting Workload Priority

XPK supports five priority levels that control queuing order and preemption:

```bash
xpk workload create \
    --workload high-priority-training \
    --command "python3 train.py" \
    --cluster $CLUSTER_NAME \
    --tpu-type=v5litepod-16 \
    --priority=high \
    --flex
```

| Priority | Queuing Behavior |
|---|---|
| `very-low` | Last in queue; preempted by all higher priorities |
| `low` | Preempted by medium, high, very-high |
| `medium` | Default; balanced queuing |
| `high` | Preempts low and very-low workloads |
| `very-high` | First in queue; preempts all lower priorities |

### Setting Max Restarts for Resilience

For longer-running jobs, set `--max-restarts` to handle hardware failures:

```bash
xpk workload create \
    --workload production-finetune \
    --command "python3 train.py --checkpoint_dir=gs://my-bucket/checkpoints" \
    --cluster $CLUSTER_NAME \
    --tpu-type=v5litepod-16 \
    --max-restarts=50 \
    --flex
```

> **Important**: Ensure your training code implements **checkpointing** when using `--max-restarts`. Jobs can be interrupted by hardware failures or DWS run duration limits.

---

## 8. How XPK DWS Works Under the Hood

When you use XPK with `--flex`, here's what happens behind the scenes:

```
┌─────────────────────────────────────────────────────────────────────────┐
│              XPK + DWS Flex-Start Architecture                          │
│                                                                         │
│  User Commands                        What XPK Creates                  │
│  ─────────────                        ────────────────                  │
│                                                                         │
│  xpk cluster create    ──────►  GKE Cluster with:                       │
│  --flex                          • System node pool                     │
│                                  • GPU/TPU node pool:                   │
│                                    - queued provisioning enabled         │
│                                    - reservation-affinity: none          │
│                                    - auto-repair: disabled               │
│                                    - autoscaling: 0 to max nodes         │
│                                  • Kueue controller (auto-installed)     │
│                                  • JobSet controller (auto-installed)    │
│                                  • DWS queue resources:                  │
│                                    - ResourceFlavor                      │
│                                    - AdmissionCheck                      │
│                                    - ProvisioningRequestConfig           │
│                                    - ClusterQueue + LocalQueue           │
│                                                                         │
│  xpk workload create   ──────►  Job/JobSet with:                        │
│  --flex                          • kueue queue-name label                │
│                                  • suspend: true                         │
│                                  • DWS maxRunDuration annotation         │
│                                  • Correct nodeSelector + tolerations    │
│                                                                         │
│                         ──────►  DWS Provisioning Flow:                  │
│                                  1. Kueue admits the workload            │
│                                  2. AdmissionCheck triggers              │
│                                     ProvisioningRequest                  │
│                                  3. GKE cluster autoscaler creates       │
│                                     DWS resize request                   │
│                                  4. DWS queues until capacity available  │
│                                  5. All nodes provisioned at once        │
│                                  6. Job runs on provisioned nodes        │
│                                  7. Nodes released when job completes    │
└─────────────────────────────────────────────────────────────────────────┘
```

### What XPK Abstracts Away

Without XPK, setting up DWS on GKE requires:

| Step | Without XPK (Manual) | With XPK |
|---|---|---|
| Create GKE cluster | `gcloud container clusters create` with many flags | `xpk cluster create` |
| Create DWS node pool | `gcloud container node-pools create` with `--enable-queued-provisioning`, `--reservation-affinity=none`, etc. | Handled automatically with `--flex` |
| Install Kueue | `kubectl apply` Kueue manifests | Auto-installed |
| Install JobSet | `kubectl apply` JobSet manifests | Auto-installed |
| Create Kueue resources | Write and apply ResourceFlavor, AdmissionCheck, ProvisioningRequestConfig, ClusterQueue, LocalQueue YAML | Auto-configured |
| Submit workload | Write Job/JobSet YAML with labels, annotations, nodeSelectors, tolerations | `xpk workload create` |
| Monitor workload | `kubectl get workloads`, `kubectl get provisioningrequests` | `xpk workload list` |

> XPK reduces **~100+ lines of YAML and 6+ manual commands** to a single `xpk workload create --flex` command.

---

## 9. Workload Management

### List Workloads

```bash
xpk workload list --cluster $CLUSTER_NAME
```

Example output:

```
Jobset Name                  Created Time         Priority  VMs Needed  VMs Running  VMs Done  Status    Status Message
my-training-job-1            2026-04-01T10:00:00Z medium    4           4            <none>    Admitted  Admitted by ClusterQueue
my-training-job-2            2026-04-01T10:05:00Z medium    4           <none>       <none>    Admitted  Waiting for DWS capacity
my-finetune-completed        2026-04-01T08:00:00Z high      2           2            2         Finished  JobSet finished successfully
```

### Filter Workloads

```bash
# Filter by status
xpk workload list --cluster $CLUSTER_NAME --filter-by-status=RUNNING
xpk workload list --cluster $CLUSTER_NAME --filter-by-status=QUEUED

# Filter by job name
xpk workload list --cluster $CLUSTER_NAME --filter-by-job=$USER
```

Available status filters: `EVERYTHING`, `FINISHED`, `RUNNING`, `QUEUED`, `FAILED`, `SUCCESSFUL`

### Wait for Workload Completion

```bash
# Wait indefinitely for a workload to finish
xpk workload list --cluster $CLUSTER_NAME \
    --wait-for-job-completion=my-training-job

# Wait with a timeout (in seconds)
xpk workload list --cluster $CLUSTER_NAME \
    --wait-for-job-completion=my-training-job \
    --timeout=3600
```

| Return Code | Meaning |
|---|---|
| `0` | Workload finished successfully |
| `124` | Timeout reached before workload finished |
| `125` | Workload finished but did not complete successfully |
| `1` | Other failure |

### Delete Workloads

```bash
# Delete a specific workload
xpk workload delete --workload my-training-job --cluster $CLUSTER_NAME

# Delete all workloads in a cluster (prompts for confirmation)
xpk workload delete --cluster $CLUSTER_NAME

# Delete workloads matching a filter
xpk workload delete --cluster $CLUSTER_NAME --filter-by-status=FAILED
xpk workload delete --cluster $CLUSTER_NAME --filter-by-job=$USER
```

### Delete Cluster

```bash
xpk cluster delete --cluster $CLUSTER_NAME
```

---

## 10. Storage Integration

XPK supports multiple Google Cloud storage solutions that can be attached to clusters and made available to workloads.

| Storage Type | Use Case | Documentation |
|---|---|---|
| **Cloud Storage FUSE (GCSFuse)** | Access GCS buckets as a file system — best for checkpoints, datasets | [XPK Storage Docs](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/storage.md#fuse) |
| **Filestore** | Managed NFS — good for shared model weights, training data | [XPK Storage Docs](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/storage.md#filestore) |
| **Parallelstore** | High-performance parallel file system for large-scale training | [XPK Storage Docs](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/storage.md#parallelstore) |
| **Block Storage (PD/Hyperdisk)** | Persistent Disk or Hyperdisk for per-node storage | [XPK Storage Docs](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/storage.md#block-storage-persistent-disk-hyperdisk) |
| **Managed Lustre** | High-throughput parallel file system for data-intensive AI/ML | [GKE Lustre + XPK Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/xpk-lustre-tpu) |

### Example: Filestore with DWS Flex-Start (Ironwood)

```bash
# Create Filestore storage
export STORAGE_NAME="training-filestore"
xpk storage create $STORAGE_NAME \
    --type=gcpfilestore \
    --auto-mount=false \
    --mount-point=/data-fs \
    --readonly=false \
    --size=1024 \
    --tier=BASIC_HDD \
    --vol=default \
    --project=$PROJECT_ID \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE

# Attach storage to cluster
xpk storage attach $STORAGE_NAME \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --type=gcpfilestore \
    --auto-mount=true \
    --vol=default \
    --mount-point=/data-fs \
    --readonly=false

# Run workload with storage
xpk workload create \
    --workload training-with-storage \
    --command "python3 train.py --output_dir=/data-fs/output" \
    --cluster $CLUSTER_NAME \
    --tpu-type=$ACCELERATOR_TYPE \
    --zone $ZONE \
    --project $PROJECT_ID
```

---

## 11. XPK vs. Cluster Toolkit Decision Guide

| Criterion | XPK | Cluster Toolkit |
|---|---|---|
| **Target use case** | PoC, testing, experimentation | Production deployments |
| **Setup complexity** | Low (single CLI command) | Medium (YAML blueprints + Terraform) |
| **Kubernetes expertise needed** | None | Some (for customization) |
| **Infrastructure-as-code** | No (imperative CLI) | Yes (Terraform + declarative YAML) |
| **DWS flex-start support** | ✅ `--flex` flag | ✅ Blueprint configuration |
| **GPUDirect RDMA** | Auto-configured for supported GPUs | Auto-configured via blueprint |
| **Kueue integration** | Auto-installed | Auto-installed via blueprint |
| **Custom networking** | Limited (`--custom-cluster-arguments`) | Full control (VPC, RDMA, subnets) |
| **Multi-team/tenant support** | Limited (single queue) | Full (multiple queues, quotas, namespaces) |
| **State management** | None (GKE API state) | Terraform state in GCS |
| **Cluster Health Scanner** | Not available | Available via blueprint |
| **Reservation + DWS fallback** | Not supported | Supported via Kueue multi-flavor ClusterQueue |
| **Recommended for** | Individual developers, small teams, rapid iteration | Platform teams, shared clusters, production ML |

### When to Graduate from XPK to Cluster Toolkit

Consider migrating to Cluster Toolkit when:

1. **Moving to production** — Your PoC is validated and you need production-grade infrastructure
2. **Multi-team sharing** — Multiple teams need to share a cluster with fair-queuing and quotas
3. **Custom networking requirements** — You need fine-grained control over VPC, RDMA, and firewall rules
4. **Reservation + DWS fallback** — You want to try reserved capacity first and fall back to DWS
5. **Infrastructure-as-code** — You need versioned, reviewable infrastructure changes
6. **Compliance requirements** — You need Assured Workloads, Organization Policy, or audit-ready configs

> **Tip**: XPK's `cluster adapt` command can configure an existing cluster (created via gcloud or Cluster Toolkit) to work with XPK workload commands. This enables a gradual migration path.

---

## 12. Best Practices

### Cluster Configuration

| Best Practice | Detail |
|---|---|
| **Use unique cluster names** | Each cluster must have a unique name per project (6–30 chars) |
| **Set `--cluster-cpu-machine-type`** | Use `n1-standard-8` or larger to ensure system pods have sufficient resources |
| **Add maintenance exclusions** | Prevent GKE auto-upgrades from disrupting running DWS workloads |
| **Cache images for faster starts** | Use `xpk cluster cacheimage` to pre-pull Docker images on nodes |

### DWS Flex-Start Workloads

| Best Practice | Detail |
|---|---|
| **Always checkpoint** | DWS VMs are deleted when the run duration expires; checkpoint frequently to GCS or Filestore |
| **Use `--max-restarts`** | Set to a high value (e.g., 50) for long-running jobs to handle hardware failures |
| **Right-size run duration** | Shorter DWS requests may be fulfilled faster — don't request 7 days if you need 6 hours |
| **Use priority levels** | Set `--priority=high` for important jobs; lower-priority jobs queue behind them |
| **Submit multiple small jobs** | Instead of one large job, submit multiple smaller jobs to improve scheduling flexibility |

### Cost Optimization

| Strategy | Detail |
|---|---|
| **Use `--flex` for non-urgent work** | Up to 53% discount vs. on-demand pricing |
| **Cancel unused workloads** | Delete queued workloads you no longer need to free up `ACTIVE_RESIZE_REQUESTS` quota |
| **Delete clusters when done** | `xpk cluster delete` to avoid paying for idle system nodes |
| **Multi-zone submission** | If not zone-bound, create clusters in multiple zones to increase chances of DWS fulfillment |

### Workload Design

| Best Practice | Detail |
|---|---|
| **Use Docker images** | Pre-install all dependencies in your Docker image for faster job start times |
| **Keep commands simple** | Use `--command` for the training entrypoint; put complex logic in your Docker image |
| **Test with small configs first** | Use `--num-slices=1` or `--num-nodes=1` to validate your workload before scaling up |
| **Use synthetic datasets initially** | Validate end-to-end flow without needing large real datasets |

---

## 13. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|---|---|---|
| **Cluster create fails with CPU quota error** | Zone doesn't support the default CPU machine type | Use `--cluster-cpu-machine-type=n1-standard-8` (switch between `n1`, `n2`, `e2` types) |
| **DWS workload stays queued indefinitely** | No GPU/TPU capacity available in the zone | Wait for capacity; consider trying a different zone or reduce `--num-slices`/`--num-nodes` |
| **Workload fails immediately** | Docker image missing dependencies or command errors | Test your Docker image locally first; check pod logs with `kubectl logs` |
| **"Invalid machine type" error** | Machine type not available in zone | Verify accelerator availability: `gcloud compute accelerator-types list --filter="zone:$ZONE"` |
| **Kueue/JobSet installation fails** | Transient network error during cluster create | Re-run `xpk cluster create` with the same `--cluster` name — XPK is idempotent |
| **Workload exceeds 7-day limit** | DWS flex-start max duration | Implement checkpointing and submit a new workload to continue from the last checkpoint |
| **Nodes not joining cluster** | GKE version too old for flex-start | Ensure GKE version is 1.32.2-gke.1652000 or later for flex-start support |

### Debugging Commands

```bash
# Get cluster credentials for kubectl access
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone $ZONE --project $PROJECT_ID

# Check node status
kubectl get nodes

# Check Kueue workloads
kubectl get workloads -A

# Check DWS provisioning requests
kubectl get provisioningrequests -A

# View Kueue controller logs
kubectl logs -n kueue-system -l control-plane=controller-manager --tail=100

# Check pod status for a specific workload
kubectl get pods -l jobset.sigs.k8s.io/jobset-name=my-workload

# View pod logs
kubectl logs <pod-name>
```

---

## 14. References

### XPK Documentation

- [XPK GitHub Repository](https://github.com/AI-Hypercomputer/xpk)
- [XPK Installation Guide](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/installation.md)
- [XPK Permissions](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/permissions.md)
- [XPK Cluster Usage](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/clusters.md)
- [XPK Workload Usage](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/workloads.md)
- [XPK Storage Guide](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/storage.md)
- [XPK GPU Guide](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/gpu.md)
- [XPK Troubleshooting](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/troubleshooting.md)

### XPK Recipes (Ironwood / TPU7x)

- [Ironwood with Reservation + GCS Bucket](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/tpu7x/recipes/reservation_gcs_bucket_recipe.md)
- [Ironwood with Flex-Start + Filestore](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/tpu7x/recipes/flex_filestore_recipe.md)
- [Ironwood with Flex-Start + Lustre](https://github.com/AI-Hypercomputer/xpk/blob/main/docs/usage/tpu7x/recipes/flex_lustre_recipe.md)

### Google Cloud Documentation

- [GKE TPU Guide — XPK Section](https://cloud.google.com/kubernetes-engine/docs/how-to/tpus)
- [GKE AI Hypercompute — XPK Section](https://cloud.google.com/ai-hypercomputer/docs/create/gke-ai-hypercompute)
- [XPK + Managed Lustre on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/xpk-lustre-tpu)
- [Flex-Start Training on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-training)
- [DWS Queued Provisioning on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest)
- [About Flex-Start VMs](https://cloud.google.com/kubernetes-engine/docs/concepts/dws)
- [DWS Pricing](https://cloud.google.com/products/dws/pricing)

### Related Sections in This Repository

- [DWS Concepts](../dws/) — Dynamic Workload Scheduler concepts, pricing, compliance
- [Deployment Methods Overview](../) — Compare all deployment methods
- [Cluster Toolkit Guide](../cluster-toolkit/) — Production-ready GKE clusters with DWS support
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket for training data

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. XPK is recommended for proofs-of-concept and testing — for production deployments, consider using [Cluster Toolkit](../cluster-toolkit/). Always follow your organization's security policies, verify accelerator availability in your target zones, and review [DWS pricing](https://cloud.google.com/products/dws/pricing) before deploying workloads.
