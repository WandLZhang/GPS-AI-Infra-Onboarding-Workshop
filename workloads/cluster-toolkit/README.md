# Cluster Toolkit — AI-Optimized GKE Clusters with DWS Support

> Create production-ready, AI-optimized GKE clusters using Google Cloud Cluster Toolkit. Includes step-by-step guides for reservation-bound, DWS flex-start, and Spot provisioning models.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [What Cluster Toolkit Provisions](#2-what-cluster-toolkit-provisions)
3. [Supported Machine Types & Consumption Models](#3-supported-machine-types--consumption-models)
4. [Prerequisites](#4-prerequisites)
5. [Choosing a Consumption Model](#5-choosing-a-consumption-model)
6. [Create a Cluster with Reservation-Bound Provisioning](#6-create-a-cluster-with-reservation-bound-provisioning)
7. [Create a Cluster with DWS Flex-Start](#7-create-a-cluster-with-dws-flex-start)
8. [DWS Integration Details](#8-dws-integration-details)
9. [Submitting Workloads to a DWS Cluster](#9-submitting-workloads-to-a-dws-cluster)
10. [Cluster Health Scanner (CHS)](#10-cluster-health-scanner-chs)
11. [Cleanup](#11-cleanup)
12. [Troubleshooting](#12-troubleshooting)
13. [Best Practices](#13-best-practices)
14. [References](#14-references)

---

## 1. Overview

**[Cluster Toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit)** is a Google Cloud open-source tool that enables you to quickly deploy production-ready, AI-optimized GKE clusters with best-practice defaults. It uses declarative YAML **blueprints** that describe the complete cluster infrastructure — networking, service accounts, GKE cluster, GPU node pools, workload management — and deploys them via Terraform.

### Why Cluster Toolkit?

| Capability | Benefit |
|---|---|
| **One-command deployment** | `gcluster deploy` provisions the entire stack — VPC, RDMA network, cluster, node pools, Kueue |
| **Best-practice defaults** | Blueprints encode Google's recommended settings for GPU networking, drivers, and scheduling |
| **GPUDirect RDMA enabled** | Automatically configures multi-NIC networking for GPU-to-GPU communication |
| **Multiple consumption models** | Supports reservation-bound, DWS flex-start, and Spot provisioning via blueprint configuration |
| **Kueue integration** | Optionally installs and configures Kueue for DWS queued provisioning |
| **Terraform state management** | Uses GCS backend for collaborative, versioned infrastructure management |
| **Production-ready** | Recommended for production deployments (vs. XPK, which targets proofs-of-concept) |

### Where Cluster Toolkit Fits

```
┌───────────────────────────────────────────────────────────────────────────┐
│              Methods for Creating AI-Optimized GKE Clusters              │
│                                                                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐   │
│  │ Cluster Toolkit  │  │     XPK         │  │   Manual (gcloud CLI)   │   │
│  │                  │  │                 │  │                         │   │
│  │ Production-ready │  │ Quick PoC &     │  │ Maximum flexibility     │   │
│  │ Best practices   │  │ testing         │  │ Existing clusters       │   │
│  │ Full stack       │  │ Workload-first  │  │ Custom configurations   │   │
│  │ Terraform-based  │  │ Python CLI      │  │ Incremental changes     │   │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘   │
│       ▲ RECOMMENDED         Good for                Good for             │
│       │ for new clusters    experimentation          expanding existing   │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 2. What Cluster Toolkit Provisions

A single `gcluster deploy` command creates the following resources:

```
┌─────────────────────────────────────────────────────────────────┐
│                  Cluster Toolkit Blueprint                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Networking                                              │   │
│  │  ├── Primary VPC + Subnet (cluster networking)           │   │
│  │  └── GPU RDMA VPC + Subnets (GPUDirect RoCE traffic)     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  IAM & Service Accounts                                  │   │
│  │  └── Dedicated service accounts for cluster & node pools │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  GKE Cluster                                             │   │
│  │  ├── System Node Pool (cluster services)                 │   │
│  │  ├── GPU Node Pool (A4X Max/A4X/A4/A3 Ultra/A3 Mega)    │   │
│  │  │   ├── GPUDirect RDMA multi-NIC enabled                │   │
│  │  │   ├── Consumption model (reservation/flex-start/spot) │   │
│  │  │   └── Appropriate GPU driver auto-installed           │   │
│  │  └── Authorized Networks (IP allowlisting)               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Workload Management                                     │   │
│  │  ├── Kueue (job queuing & scheduling)                    │   │
│  │  ├── JobSet controller                                   │   │
│  │  └── DWS ProvisioningRequest integration (if flex-start) │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Storage (for benchmarking)                              │   │
│  │  ├── GCS Bucket                                          │   │
│  │  ├── Network storage (Filestore / Parallelstore)         │   │
│  │  └── Persistent Volumes                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Supported Machine Types & Consumption Models

### Machine Types & Blueprint Mapping

| Machine Type | GPU | GPUs/VM | Blueprint Directory | Min GKE Version |
|---|---|---|---|---|
| **A4X Max** | NVIDIA GB300 | 8 | `examples/gke-a4x-max-bm/` | 1.34.3-gke.1318000+ (1.34) or 1.35.0-gke.2745000+ (1.35) |
| **A4X** | NVIDIA GB200 | 8 | `examples/gke-a4x/` | 1.32.8-gke.1108000+ (1.32) or 1.33.4-gke.1036000+ (1.33) |
| **A4** | NVIDIA B200 | 8 | `examples/gke-a4/` | 1.32.1-gke.1729000+ |
| **A3 Ultra** | NVIDIA H200 | 8 | `examples/gke-a3-ultragpu/` | 1.31.4-gke.1183000+ (RDMA) |
| **A3 Mega** | NVIDIA H100 | 8 | `examples/gke-a3-megagpu/` | 1.28+ |
| **A3 High** | NVIDIA H100 | 8 | `examples/gke-a3-highgpu/` | 1.28+ |

### Consumption Model Support

| Consumption Model | A4X Max | A4X | A4 | A3 Ultra | A3 Mega | A3 High |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Reservation-bound** | ✅ (required) | ✅ (required) | ✅ | ✅ | ✅ | ✅ |
| **DWS Flex-start** | ❌ | ❌ | ✅ (Preview) | ✅ (Preview) | ✅ | ✅ |
| **Spot** | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |

> **Note**: A4X Max and A4X require reservation-bound provisioning. DWS flex-start is not supported for these machine types.

---

## 4. Prerequisites

### Required Tools

| Tool | Purpose | Install |
|---|---|---|
| `gcloud` CLI | Google Cloud operations | [Install](https://cloud.google.com/sdk/docs/install) |
| `git` | Clone Cluster Toolkit repo | Pre-installed on Cloud Shell |
| `make` | Build `gcluster` binary | Pre-installed on Cloud Shell |
| `go` (1.21+) | Compile Cluster Toolkit | Pre-installed on Cloud Shell |
| `terraform` | Infrastructure provisioning | [Install](https://developer.hashicorp.com/terraform/install) |
| `kubectl` | Kubernetes management | `gcloud components install kubectl` |

> **Recommendation**: Use **Cloud Shell** — all dependencies are pre-installed.

### Required IAM Roles

| Role | Purpose |
|---|---|
| `roles/container.admin` | GKE cluster and node pool management |
| `roles/compute.admin` | VPC, subnet, and VM management |
| `roles/storage.admin` | GCS bucket for Terraform state |
| `roles/resourcemanager.projectIamAdmin` | Service account IAM bindings |
| `roles/iam.serviceAccountAdmin` | Create service accounts |
| `roles/iam.serviceAccountUser` | Act as service accounts |
| `roles/serviceusage.serviceUsageConsumer` | Enable APIs |
| `roles/iam.roleAdmin` | Create custom roles |
| `roles/secretmanager.secretVersionManager` | Secret management |

### Required APIs

```bash
gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    storage.googleapis.com \
    iam.googleapis.com \
    secretmanager.googleapis.com \
    --project=$PROJECT_ID
```

### Quota Verification

Before creating a cluster, verify you have sufficient quota:

```bash
# Check GPU quota in your target region
gcloud compute regions describe $REGION \
    --format="yaml(quotas)" \
    --project=$PROJECT_ID

# For DWS flex-start, also check active resize requests quota
gcloud compute project-info describe \
    --format="yaml(quotas)" \
    --project=$PROJECT_ID
```


---

## 5. Choosing a Consumption Model

```
                    Do you have reserved capacity
                    (CUD, on-demand reservation)?
                               │
                    ┌──────────┴──────────┐
                   Yes                    No
                    │                      │
              Reservation-bound       Is your workload
              (Section 6)             fault-tolerant?
                                           │
                                ┌──────────┴──────────┐
                               Yes                     No
                                │                       │
                          Can you tolerate          DWS Flex-start
                          preemption?               (Section 7)
                                │                   Up to 53% discount
                         ┌──────┴──────┐            7-day max duration
                        Yes            No
                         │              │
                       Spot         DWS Flex-start
                       Cheapest     (Section 7)
                       Preemptible
```

| Criterion | Reservation-Bound | DWS Flex-Start | Spot |
|---|---|---|---|
| **Availability** | Guaranteed (reserved) | Queued until available | Best-effort |
| **Pricing** | CUD or on-demand rate | Up to 53% discount | Up to 91% discount |
| **Max duration** | Unlimited | 7 days | Unlimited (but preemptible) |
| **Preemption risk** | None | None (during run) | High |
| **Best for** | Production training | Cost-sensitive batch training | Fault-tolerant / checkpointed |
| **A4X Max / A4X** | ✅ Required | ❌ Not supported | ❌ Not supported |

> For a comprehensive guide to all DWS consumption options (including Compute Engine MIG resize and Vertex AI), see the [DWS Concepts Guide](../dws/).

---

## 6. Create a Cluster with Reservation-Bound Provisioning

This example uses **A3 Ultra (H200)** with reserved capacity. The same pattern applies to A4X Max, A4X, A4, A3 Mega, and A3 High — just use the corresponding blueprint directory.

### Step 1: Set Environment Variables

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export DEPLOYMENT_NAME="my-a3ultra-cluster"     # 6-30 chars, unique per project
export BUCKET_NAME="my-cluster-toolkit-state"
export RESERVATION_NAME="my-gpu-reservation"
export NODE_COUNT=8
```

### Step 2: Clone and Build Cluster Toolkit

```bash
cd ~
git clone https://github.com/GoogleCloudPlatform/cluster-toolkit.git
cd cluster-toolkit && git checkout main && make
```

### Step 3: Create Terraform State Bucket

```bash
gcloud storage buckets create gs://$BUCKET_NAME \
    --default-storage-class=STANDARD \
    --project=$PROJECT_ID \
    --location=$REGION \
    --uniform-bucket-level-access

gcloud storage buckets update gs://$BUCKET_NAME --versioning
```

### Step 4: Configure the Blueprint

Edit the deployment file `examples/gke-a3-ultragpu/gke-a3-ultragpu-deployment.yaml`:

```yaml
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: my-cluster-toolkit-state       # BUCKET_NAME

vars:
  deployment_name: my-a3ultra-cluster       # DEPLOYMENT_NAME
  project_id: your-project-id              # PROJECT_ID
  region: us-central1                      # REGION
  zone: us-central1-a                      # ZONE — must match reservation zone
  static_node_count: 8                     # NODE_COUNT
  authorized_cidr: 10.0.0.0/8             # IP_ADDRESS/SUFFIX — your allowed CIDR

  reservation:
    type: SPECIFIC                         # Targets a specific reservation
    values:
      - my-gpu-reservation                 # RESERVATION_NAME

  # Boot disk sizes (adjust based on use case)
  system_node_pool_disk_size_gb: 100
  a3ultra_node_pool_disk_size_gb: 100
```

> **Tip**: To target a specific block within a reservation, use the format:
> `RESERVATION_NAME/reservationBlocks/BLOCK_NAME`

To modify advanced settings (GKE version, networking, Kueue), edit the main blueprint file:
`examples/gke-a3-ultragpu/gke-a3-ultragpu.yaml`

### Step 5: Authenticate

```bash
gcloud auth application-default login
```

### Step 6: Deploy

```bash
cd ~/cluster-toolkit
./gcluster deploy -d \
    examples/gke-a3-ultragpu/gke-a3-ultragpu-deployment.yaml \
    examples/gke-a3-ultragpu/gke-a3-ultragpu.yaml
```

When prompted, select **(A)pply** to deploy the blueprint.

### What Gets Created

The blueprint creates:
- VPC networks (primary + GPU RDMA)
- Service accounts with appropriate IAM bindings
- GKE cluster with system node pool
- A3 Ultra GPU node pool with GPUDirect RDMA
- Kueue and JobSet controllers
- GCS bucket, network storage, and persistent volumes (for benchmarking)

### Step 7: Verify

```bash
# Get cluster credentials
gcloud container clusters get-credentials $DEPLOYMENT_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID

# Verify nodes
kubectl get nodes -l cloud.google.com/gke-accelerator=nvidia-h200-141gb

# Verify Kueue installation
kubectl get pods -n kueue-system
```

---

## 7. Create a Cluster with DWS Flex-Start

DWS flex-start enables you to create GPU node pools that provision capacity through Dynamic Workload Scheduler — queuing your request and provisioning VMs when capacity becomes available, at up to **53% discount**.

This section walks through converting a reservation-bound blueprint to use DWS flex-start with queued provisioning, using **A4 (B200)** as the example. The same modifications apply to **A3 Ultra**.

> **Requires**: GKE version **1.32.2-gke.1652000** or later.

### Step 1: Set Environment Variables

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export DEPLOYMENT_NAME="my-a4-dws-cluster"    # 6-30 chars, unique per project
export BUCKET_NAME="my-cluster-toolkit-state"
export GPU_NOMINAL_QUOTA=80                    # Max GPUs Kueue will admit
```

### Step 2: Clone, Build, and Create State Bucket

```bash
cd ~
git clone https://github.com/GoogleCloudPlatform/cluster-toolkit.git
cd cluster-toolkit && git checkout main && make

gcloud storage buckets create gs://$BUCKET_NAME \
    --default-storage-class=STANDARD \
    --project=$PROJECT_ID \
    --location=$REGION \
    --uniform-bucket-level-access
gcloud storage buckets update gs://$BUCKET_NAME --versioning
```

### Step 3: Modify the Deployment File

Edit `examples/gke-a4/gke-a4-deployment.yaml`:

```yaml
terraform_backend_defaults:
  type: gcs
  configuration:
    bucket: my-cluster-toolkit-state       # BUCKET_NAME

vars:
  deployment_name: my-a4-dws-cluster        # DEPLOYMENT_NAME
  project_id: your-project-id              # PROJECT_ID
  region: us-central1                      # REGION
  zone: us-central1-a                      # ZONE

  # ── DWS Flex-Start Configuration ──
  # REMOVE: static_node_count
  # REMOVE: reservation block
  enable_flex_start: true                   # Enable DWS flex-start
  enable_queued_provisioning: true          # Enable queued provisioning with Kueue
  gpu_nominal_quota: 80                     # Max GPUs ClusterQueue will admit

  authorized_cidr: 10.0.0.0/8             # IP_ADDRESS/SUFFIX

  # Boot disk sizes
  system_node_pool_disk_size_gb: 100
  a4_node_pool_disk_size_gb: 100
```

**Key changes from reservation-bound:**
| Change | Reservation-Bound | DWS Flex-Start |
|---|---|---|
| `static_node_count` | Set to node count | **Remove** |
| `reservation` block | Specify reservation name | **Remove entirely** |
| `enable_flex_start` | Not present | **Add: `true`** |
| `enable_queued_provisioning` | Not present | **Add: `true`** |
| `gpu_nominal_quota` | Not present | **Add: desired max GPU count** |

### Step 4: Modify the Main Blueprint

Edit `examples/gke-a4/gke-a4.yaml` with the following changes:

#### 4a. Update the `vars` block

```yaml
vars:
  # ...
  version_prefix: "1.32."                   # Must be 1.32 or higher for flex-start
  enable_flex_start: true
  enable_queued_provisioning: true
  gpu_nominal_quota: $(vars.gpu_nominal_quota)
  # REMOVE: static_node_count
  # REMOVE: reservation block
  # REMOVE: kueue_configuration_path (will be replaced below)
```

#### 4b. Update the GPU node pool (`id: a4-pool`)

Replace the `reservation_affinity` block and remove `static_node_count`:

```yaml
  - id: a4-pool
    # ...
    settings:
      # REMOVE: static_node_count: $(vars.static_node_count)
      # REMOVE: reservation_affinity block

      # ADD the following:
      enable_flex_start: $(vars.enable_flex_start)
      auto_repair: false
      enable_queued_provisioning: $(vars.enable_queued_provisioning)
      autoscaling_total_min_nodes: 0
```

#### 4c. Update the Kueue configuration (`id: workload-manager-install`)

```yaml
  - id: workload-manager-install
    # ...
    settings:
      kueue:
        install: true
        config_path: $(vars.kueue_configuration_path)
        config_template_vars:
          num_gpus: $(vars.gpu_nominal_quota)
```

#### 4d. Update the job template

Under `id: job-template`, replace the `node_count` variable with `2`.

### Step 5: Create the Kueue DWS Configuration Template

Replace the contents of the `kueue-configuration.yaml.tftpl` file in the blueprint directory with:

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "default-flavor"
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: AdmissionCheck
metadata:
  name: dws-prov
spec:
  controllerName: kueue.x-k8s.io/provisioning-request
  parameters:
    apiGroup: kueue.x-k8s.io
    kind: ProvisioningRequestConfig
    name: dws-config
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ProvisioningRequestConfig
metadata:
  name: dws-config
spec:
  provisioningClassName: queued-provisioning.gke.io
  managedResources:
    - nvidia.com/gpu
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "dws-cluster-queue"
spec:
  namespaceSelector: {}
  resourceGroups:
    - coveredResources: ["nvidia.com/gpu"]
      flavors:
        - name: "default-flavor"
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: ${num_gpus}
  admissionChecks:
    - dws-prov
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: "default"
  name: "dws-local-queue"
spec:
  clusterQueue: "dws-cluster-queue"
---
```

### Step 6: Deploy

```bash
gcloud auth application-default login

cd ~/cluster-toolkit
./gcluster deploy -d \
    examples/gke-a4/gke-a4-deployment.yaml \
    examples/gke-a4/gke-a4.yaml
```

When prompted, select **(A)pply**.

### Step 7: Verify DWS Setup

```bash
# Get cluster credentials
gcloud container clusters get-credentials $DEPLOYMENT_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID

# Verify Kueue is running
kubectl get pods -n kueue-system

# Verify DWS Kueue resources
kubectl get clusterqueues
kubectl get localqueues -A
kubectl get admissionchecks
kubectl get provisioningrequestconfigs
```

Expected output for ClusterQueue:

```
NAME                COHORT   PENDING WORKLOADS   ADMITTED WORKLOADS
dws-cluster-queue            0                   0
```

---

## 8. DWS Integration Details

### How Cluster Toolkit Enables DWS

When you set `enable_flex_start: true` and `enable_queued_provisioning: true`, Cluster Toolkit configures the following end-to-end DWS pipeline:

```
┌─────────────────────────────────────────────────────────────────────┐
│                DWS Pipeline in Cluster Toolkit                      │
│                                                                     │
│  Blueprint Config                     GKE Resources Created         │
│  ─────────────────                    ─────────────────────         │
│                                                                     │
│  enable_flex_start: true  ──────►  Node Pool with:                  │
│                                    • queued provisioning enabled     │
│                                    • reservation-affinity: none     │
│                                    • auto-repair: disabled          │
│                                    • autoscaling min nodes: 0       │
│                                                                     │
│  Kueue config template   ──────►  Kueue Resources:                  │
│  (kueue-configuration              • ResourceFlavor                 │
│   .yaml.tftpl)                     • AdmissionCheck (dws-prov)      │
│                                    • ProvisioningRequestConfig      │
│                                    • ClusterQueue + LocalQueue      │
│                                                                     │
│  Job submitted with      ──────►  DWS Workflow:                     │
│  queue label                       1. Kueue admits job              │
│                                    2. AdmissionCheck triggers       │
│                                       ProvisioningRequest           │
│                                    3. GKE creates DWS resize        │
│                                       request to cluster autoscaler │
│                                    4. DWS provisions nodes when     │
│                                       capacity is available         │
│                                    5. Job runs on provisioned nodes │
└─────────────────────────────────────────────────────────────────────┘
```

### Kueue Resources Explained

| Resource | Purpose |
|---|---|
| **ResourceFlavor** (`default-flavor`) | Defines the type of resources available; maps to the DWS node pool |
| **AdmissionCheck** (`dws-prov`) | Gates job admission on successful GPU provisioning via DWS |
| **ProvisioningRequestConfig** (`dws-config`) | Configures the provisioning class (`queued-provisioning.gke.io`) and managed resources (`nvidia.com/gpu`) |
| **ClusterQueue** (`dws-cluster-queue`) | Cluster-wide queue with `nominalQuota` limiting total admitted GPUs; attached to the DWS admission check |
| **LocalQueue** (`dws-local-queue`) | Namespace-scoped queue (in `default`) that routes jobs to the ClusterQueue |

### Understanding `nominalQuota`

The `nominalQuota` in the ClusterQueue controls how many GPUs Kueue will admit simultaneously:

```yaml
resources:
  - name: "nvidia.com/gpu"
    nominalQuota: 80    # Kueue admits jobs until total GPU requests reach 80
```

- Set this to the **maximum number of GPUs** you want DWS to provision concurrently.
- Jobs exceeding this quota are held in the queue until running jobs complete.
- This prevents submitting more DWS resize requests than your `ACTIVE_RESIZE_REQUESTS` quota allows (default: 100 per project).

---

## 9. Submitting Workloads to a DWS Cluster

### Basic Job Example

```yaml
# dws-training-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dws-training-job
  namespace: default
  labels:
    kueue.x-k8s.io/queue-name: dws-local-queue    # Route to DWS queue
  annotations:
    provreq.kueue.x-k8s.io/maxRunDurationSeconds: "86400"  # 24h max run
spec:
  parallelism: 1
  completions: 1
  suspend: true          # Required: Kueue manages scheduling
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-b200
      tolerations:
        - key: "nvidia.com/gpu"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: training
          image: your-registry/training-image:latest
          resources:
            requests:
              cpu: "4"
              memory: "16Gi"
              nvidia.com/gpu: 8
            limits:
              nvidia.com/gpu: 8
      restartPolicy: Never
```

```bash
kubectl create -f dws-training-job.yaml
```

### Multi-Node JobSet Example

```yaml
# dws-distributed-training.yaml
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: distributed-training
  namespace: default
  labels:
    kueue.x-k8s.io/queue-name: dws-local-queue
  annotations:
    provreq.kueue.x-k8s.io/maxRunDurationSeconds: "172800"  # 48h max run
spec:
  replicatedJobs:
    - name: workers
      replicas: 4
      template:
        spec:
          parallelism: 1
          completions: 1
          suspend: true
          template:
            spec:
              nodeSelector:
                cloud.google.com/gke-accelerator: nvidia-b200
              tolerations:
                - key: "nvidia.com/gpu"
                  operator: "Exists"
                  effect: "NoSchedule"
              containers:
                - name: worker
                  image: your-registry/distributed-training:latest
                  resources:
                    requests:
                      nvidia.com/gpu: 8
                    limits:
                      nvidia.com/gpu: 8
              restartPolicy: Never
```

### Key Job Configuration Notes

| Setting | Value | Why |
|---|---|---|
| `suspend: true` | Required | Kueue manages job scheduling — without this, the job bypasses the queue |
| `kueue.x-k8s.io/queue-name` label | `dws-local-queue` | Routes the job through the DWS provisioning pipeline |
| `maxRunDurationSeconds` annotation | Up to `604800` (7 days) | Sets how long DWS VMs will run before being deleted |
| `nodeSelector` | Matches GPU accelerator | Ensures pods land on the correct GPU node pool |

### Monitor Provisioning

```bash
# Watch job status
kubectl get jobs -w

# Check Kueue workload status
kubectl get workloads -A

# Check provisioning requests
kubectl get provisioningrequests -A

# View detailed provisioning status
kubectl describe provisioningrequest <name> -n <namespace>
```

---

## 10. Cluster Health Scanner (CHS)

Cluster Health Scanner runs automated GPU health checks to verify that your cluster's GPUs are functioning correctly before running workloads.

### Enable CHS in the Blueprint

Add the following to the `vars` block in the deployment YAML:

```yaml
vars:
  # ... existing vars ...
  enable_periodic_health_checks: true
  # Optional: customize schedule (default: Sunday 12:00 AM PST)
  # health_check_schedule: "0 0 * * 0"     # cron format
```

### Cron Format Reference

```
* * * * *
│ │ │ │ │
│ │ │ │ └── day of week (0-6, Sunday=0)
│ │ │ └──── month (1-12)
│ │ └────── day of month (1-31)
│ └──────── hour (0-23)
└────────── minute (0-59)
```

**Examples:**
- `0 0 * * 0` — Every Sunday at midnight
- `0 6 * * 1-5` — Every weekday at 6 AM
- `0 */12 * * *` — Every 12 hours

---

## 11. Cleanup

To avoid recurring charges, destroy all resources provisioned by Cluster Toolkit:

```bash
cd ~/cluster-toolkit
./gcluster destroy $DEPLOYMENT_NAME/
```

This deletes:
- GKE cluster and all node pools
- VPC networks (primary + RDMA)
- Service accounts
- Storage resources created by the blueprint

> **Note**: The Terraform state bucket is **not** deleted automatically. Delete it manually if no longer needed:
> ```bash
> gcloud storage rm -r gs://$BUCKET_NAME
> ```

---

## 12. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|---|---|---|
| **Kueue/JobSet installation fails** | Transient deployment error | Redeploy with `-w` flag: `./gcluster deploy -w -d ...` |
| **Blueprint deploy fails with VPC conflict** | Duplicate VPC/subnet names | Ensure all VPC and subnet names are unique per project |
| **DWS job stays pending** | No GPU capacity available | Check `kubectl get provisioningrequests -A` for status; DWS queues until capacity is available |
| **ProvisioningRequest failed** | Quota exceeded or invalid config | Check `kubectl describe provisioningrequest <name>`; verify GPU quota and `ACTIVE_RESIZE_REQUESTS` quota |
| **Nodes not joining cluster** | GKE version too old for flex-start | Ensure GKE version is 1.32.2-gke.1652000 or later |
| **GPUDirect RDMA not working** | Wrong node image or GKE version | Verify Container-Optimized OS node image and minimum RDMA version |
| **GPU driver mismatch** | Incorrect GPU driver version | A4 requires R570+, A3 Ultra requires R550+; check with `kubectl describe node` |

### Useful Debug Commands

```bash
# Check cluster status
gcloud container clusters describe $DEPLOYMENT_NAME \
    --zone=$ZONE --project=$PROJECT_ID

# Check node pool configuration
gcloud container node-pools describe <pool-name> \
    --cluster=$DEPLOYMENT_NAME \
    --zone=$ZONE --project=$PROJECT_ID

# Check Kueue controller logs
kubectl logs -n kueue-system -l control-plane=controller-manager --tail=100

# Check DWS provisioning status
kubectl get provisioningrequests -A -o wide

# Check workload admission status
kubectl get workloads -A -o wide

# Inspect node GPU info
kubectl describe node <node-name> | grep -A5 "Allocatable"
```

---

## 13. Best Practices

### Blueprint Configuration

| Best Practice | Detail |
|---|---|
| **Use unique deployment names** | Each deployment within a project must have a unique name (6–30 chars) |
| **Use unique VPC/subnet names** | Multiple clusters in the same project require distinct network names |
| **Store Terraform state remotely** | Always use a GCS bucket with versioning for the Terraform backend |
| **Pin GKE versions** | Use `version_prefix` to control the GKE version; test upgrades in a staging cluster first |

### DWS-Specific

| Best Practice | Detail |
|---|---|
| **Always checkpoint** | DWS VMs are deleted at the end of `maxRunDurationSeconds`; checkpoint frequently to GCS or Persistent Disk |
| **Right-size `maxRunDurationSeconds`** | Shorter durations may be fulfilled faster; don't request 7 days if you need 6 hours |
| **Set `nominalQuota` appropriately** | Match your `ACTIVE_RESIZE_REQUESTS` project quota (default: 100) |
| **Disable node auto-repair** | Auto-repair removes all workloads from a node; use `auto_repair: false` for DWS node pools |
| **Use `suspend: true` on all jobs** | Required for Kueue to manage DWS provisioning; without it, jobs bypass the queue |

### Data Residency (Public Sector)

| Best Practice | Detail |
|---|---|
| **Specify zones explicitly** | DWS provisions VMs only in the zone you specify — no cross-region movement |
| **Verify GPU availability** | Not all US zones have all GPU types; check before planning |
| **Use Assured Workloads** | For FedRAMP High, DoD IL4/IL5 — automatically enforces resource location constraints |
| **Align storage and compute regions** | Keep GCS buckets and Filestore in the same region as your GPU cluster |

> For detailed data residency and compliance guidance, see the [DWS Guide — Data Residency & Compliance](../dws/#5-data-residency--compliance-considerations).

### Cost Optimization

| Strategy | Detail |
|---|---|
| **Reservation + DWS fallback** | For GKE clusters, use Kueue's multi-flavor ClusterQueue to try reservations first, fall back to DWS. See [DWS Guide — GKE Integration](../dws/#3-how-dws-integrates-with-gke) |
| **Multi-zone submission** | If not zone-bound, create separate DWS clusters or node pools in multiple zones |
| **Cancel unused requests** | Monitor pending provisioning requests and cancel any you no longer need |

---

## 14. References

### Cluster Toolkit

- [Cluster Toolkit GitHub Repository](https://github.com/GoogleCloudPlatform/cluster-toolkit)
- [Cluster Toolkit Documentation](https://cloud.google.com/cluster-toolkit/docs/overview)
- [Install Dependencies](https://cloud.google.com/cluster-toolkit/docs/setup/install-dependencies)
- [Create AI-Optimized GKE Cluster (Official Guide)](https://cloud.google.com/ai-hypercomputer/docs/create/gke-ai-hypercompute)

### Blueprint References

| Machine Type | Blueprint | Deployment Config |
|---|---|---|
| A4X Max | [`gke-a4x-max-bm.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a4x-max-bm/gke-a4x-max-bm.yaml) | [`gke-a4x-max-bm-deployment.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a4x-max-bm/gke-a4x-max-bm-deployment.yaml) |
| A4X | [`gke-a4x.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a4x/gke-a4x.yaml) | [`gke-a4x-deployment.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a4x/gke-a4x-deployment.yaml) |
| A4 | [`gke-a4.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a4/gke-a4.yaml) | [`gke-a4-deployment.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a4/gke-a4-deployment.yaml) |
| A3 Ultra | [`gke-a3-ultragpu.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a3-ultragpu/gke-a3-ultragpu.yaml) | [`gke-a3-ultragpu-deployment.yaml`](https://github.com/GoogleCloudPlatform/cluster-toolkit/blob/main/examples/gke-a3-ultragpu/gke-a3-ultragpu-deployment.yaml) |

### DWS & Workload Scheduling

- [DWS Concepts Guide](../dws/) — Full DWS documentation with all consumption options
- [About GPU Obtainability with Flex-Start](https://cloud.google.com/kubernetes-engine/docs/concepts/dws)
- [Deploy GPUs with DWS on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest)
- [Flex-Start Training on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-training)
- [Kueue Documentation](https://kueue.sigs.k8s.io/)

### GKE AI Hypercompute

- [AI Hypercomputer Documentation](https://cloud.google.com/ai-hypercomputer/docs)
- [Cluster Management Capabilities](https://cloud.google.com/ai-hypercomputer/docs/cluster-capabilities)
- [Consumption Models](https://cloud.google.com/ai-hypercomputer/docs/consumption-models)
- [Schedule GKE Workloads with TAS](https://cloud.google.com/ai-hypercomputer/docs/workloads/schedule-gke-workloads-tas)
- [GPU Recipes (Benchmarks)](https://github.com/AI-Hypercomputer/gpu-recipes)

### Related Sections in This Repository

- [DWS Concepts](../dws/) — Dynamic Workload Scheduler concepts, pricing, compliance
- [Deployment Methods Overview](../) — Compare all deployment methods
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket
- [Zero Trust IAP Access](../../02-core-infrastructure/zero-trust-iap-access/README.md) — Securing cluster access

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies, verify GPU availability in your target zones, and review DWS pricing before deploying in production environments. Blueprint configurations may change — always refer to the [official Cluster Toolkit repository](https://github.com/GoogleCloudPlatform/cluster-toolkit) for the latest blueprints.
