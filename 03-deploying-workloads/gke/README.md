# Google Kubernetes Engine (GKE) — Autopilot & Standard for AI/ML Workloads

> Deploy GPU and TPU workloads on Google Kubernetes Engine using Autopilot or Standard mode. This guide covers cluster creation, GPU workload deployment, and DWS (Dynamic Workload Scheduler) integration for cost-effective, time-flexible provisioning — all from the ground up for novice users.

---

## 📋 Table of Contents

1. [What is GKE?](#1-what-is-gke)
2. [Autopilot vs Standard — Choosing Your Mode](#2-autopilot-vs-standard--choosing-your-mode)
3. [Prerequisites](#3-prerequisites)
4. [Creating a GKE Autopilot Cluster](#4-creating-a-gke-autopilot-cluster)
5. [Creating a GKE Standard Cluster](#5-creating-a-gke-standard-cluster)
6. [Deploying GPU Workloads on Autopilot](#6-deploying-gpu-workloads-on-autopilot)
7. [Deploying GPU Workloads on Standard](#7-deploying-gpu-workloads-on-standard)
8. [DWS Integration — Flex-Start on GKE](#8-dws-integration--flex-start-on-gke)
9. [DWS Integration — Flex-Start with Queued Provisioning (Kueue)](#9-dws-integration--flex-start-with-queued-provisioning-kueue)
10. [DWS Integration — Reservation + DWS Fallback Pattern](#10-dws-integration--reservation--dws-fallback-pattern)
11. [When to Use What — Decision Framework](#11-when-to-use-what--decision-framework)
12. [Best Practices](#12-best-practices)
13. [Troubleshooting](#13-troubleshooting)
14. [References](#14-references)

---

## 1. What is GKE?

**Google Kubernetes Engine (GKE)** is a managed Kubernetes service on Google Cloud that lets you run containerized applications — including AI/ML training and inference workloads — on clusters of virtual machines equipped with GPUs and TPUs.

### Why GKE for AI/ML?

If you're new to this, think of GKE as a **platform that manages the computers (nodes) your code runs on**. Instead of manually setting up individual VMs, installing drivers, and managing failures, GKE handles that infrastructure for you while you focus on your training scripts and models.

| Capability | What It Means for You |
|---|---|
| **Managed Kubernetes** | Google manages the control plane (the "brain" of the cluster); you manage your workloads |
| **GPU/TPU support** | Run workloads on NVIDIA GPUs (T4, L4, A100, H100, H200, B200) and Google TPUs |
| **Auto-scaling** | GKE adds or removes nodes based on your workload demand — no manual intervention |
| **DWS integration** | Get GPUs at up to **53% discount** by using Dynamic Workload Scheduler flex-start |
| **Job scheduling** | Kueue (a job queue system) manages which workloads run when, with priority and fairness |
| **Self-healing** | If a node fails, GKE replaces it automatically |

### How GKE Fits in the Deployment Landscape

GKE is one of several ways to deploy AI/ML workloads on Google Cloud. Other methods include raw Compute Engine VMs, managed Slurm (Cluster Director), and serverless Vertex AI. GKE sits in the middle — more managed than raw VMs, but more flexible than fully serverless options.

```
┌─────────────────────────────────────────────────────────────────────────┐
│          AI/ML Deployment Methods on Google Cloud                       │
│                                                                         │
│   More Control                                          More Managed    │
│   ◄──────────────────────────────────────────────────────────────────►  │
│                                                                         │
│   Compute Engine     GKE            Cluster Director    Vertex AI       │
│   (Raw VMs)          (Kubernetes)   (Managed Slurm)     (Serverless)    │
│                                                                         │
│   • Full VM control  • Container    • Slurm-native      • Zero infra   │
│   • Manual setup       orchestration • HPC workloads    • Submit jobs  │
│   • No scheduling    • Auto-scaling • Job scheduling    • Managed      │
│                      • DWS support  • DWS support         everything   │
│                      • GPU/TPU      • GPU/TPU                          │
│                                                                         │
│                      ▲                                                  │
│                      │ THIS GUIDE                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

### Two Modes of Operation

GKE offers two cluster modes, each with a different level of management:

| | **Autopilot** | **Standard** |
|---|---|---|
| **Who manages nodes?** | Google manages everything | You manage node pools and scaling |
| **Analogy** | Like an automatic car — you steer, Google handles the gears | Like a manual car — you control everything |

> **Google's recommendation**: Use **Autopilot** for most workloads unless you need specific configurations that Autopilot doesn't support.

---

## 2. Autopilot vs Standard — Choosing Your Mode

### Side-by-Side Comparison

| Feature | Autopilot | Standard |
|---|---|---|
| **Node management** | Fully managed by Google | You create and manage node pools |
| **Scaling** | Automatic — GKE provisions nodes when you deploy workloads | You configure autoscaling policies |
| **GPU support** | ✅ T4, L4, A100, H100, H200, B200, GB200 | ✅ All GPU types |
| **TPU support** | ✅ (varies by version) | ✅ All TPU types |
| **DWS flex-start** | ✅ Automatic via node selector | ✅ Via node pool configuration |
| **DWS queued provisioning** | ✅ (with Kueue) | ✅ (with Kueue) |
| **Pricing model** | Pay per Pod resource usage + Autopilot premium (GKE ≥1.29.4) | Pay for entire node (VM), whether or not Pods use all resources |
| **Security** | Best practices enforced by default (e.g., no privileged Pods) | You configure security policies |
| **Kubernetes expertise needed** | Low — GKE handles most configuration | Medium to High — you configure node pools, taints, etc. |
| **Custom node configurations** | Limited — Google chooses machine types | Full control — you choose machine types, disk sizes, etc. |
| **Spot/Preemptible VMs** | ✅ Spot Pods | ✅ Spot node pools |
| **Reservations** | ✅ Compute Engine reservations | ✅ Compute Engine reservations |
| **Multi-instance GPUs** | ✅ (GKE ≥1.29.3) | ✅ |
| **GPUDirect RDMA** | ❌ Not available | ✅ For A3/A4 machine types |
| **Privileged containers** | ❌ Not allowed | ✅ Allowed |
| **Best for** | Most production workloads, teams wanting simplicity | Custom configurations, GPUDirect RDMA, maximum flexibility |

### Visual Decision Tree

```
                    Do you need GPUDirect RDMA
                    for multi-node distributed training?
                               │
                    ┌──────────┴──────────┐
                   Yes                    No
                    │                      │
              Use Standard            Do you need privileged
              (GPUDirect RDMA         containers or custom
              requires manual          node configurations?
              node pool config)            │
                                ┌──────────┴──────────┐
                               Yes                    No
                                │                      │
                          Use Standard            Use Autopilot
                          (full node              (simplest path,
                          control)                Google manages
                                                  infrastructure)
```

### Cost Comparison Example

To understand the pricing difference, consider running a workload that needs 4 NVIDIA L4 GPUs:

**Autopilot** (GKE ≥1.29.4):
```
You pay for:
  • The actual GPU node hardware (Compute Engine pricing)
  • An Autopilot management premium
  • Only when your Pods are running

Benefit: No wasted resources — if your Pod uses 2 of 4 GPUs,
         you can run another Pod on the same node.
```

**Standard**:
```
You pay for:
  • The entire VM (all 4 GPUs), whether or not Pods use them
  • GKE cluster management fee

Benefit: Full control over node configuration and placement.
         Better for consistent, high-utilization workloads.
```

> **Tip for novices**: Start with **Autopilot**. It's simpler, and you can always migrate to Standard later if you need more control.

---

## 3. Prerequisites

### Required Tools

| Tool | Purpose | Install |
|---|---|---|
| `gcloud` CLI | Create clusters, manage resources | [Install Guide](https://cloud.google.com/sdk/docs/install) |
| `kubectl` | Deploy and manage workloads on Kubernetes | `gcloud components install kubectl` |
| `terraform` (optional) | Infrastructure-as-code cluster creation | [Install Guide](https://developer.hashicorp.com/terraform/install) |

> **Easiest option**: Use **[Cloud Shell](https://shell.cloud.google.com/)** — all tools are pre-installed.

### Authenticate and Set Your Project

```bash
# Step 1: Log in to Google Cloud
gcloud auth login

# Step 2: Set your project
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Step 3: Set a default region (choose one close to you or with GPU availability)
export REGION="us-central1"
gcloud config set compute/region $REGION
```

### Enable Required APIs

```bash
# These APIs must be enabled before you can create GKE clusters
gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    iam.googleapis.com \
    --project=$PROJECT_ID
```

### Required IAM Roles

Your Google Cloud account needs these roles. If you're a project owner, you already have them:

| Role | Purpose | Who Needs It |
|---|---|---|
| `roles/container.admin` | Create and manage GKE clusters | Cluster administrators |
| `roles/compute.admin` | Manage VMs, networks, GPUs | Cluster administrators |
| `roles/iam.serviceAccountUser` | Use service accounts | All users deploying workloads |

```bash
# Grant roles to a user (run as project owner)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:someone@example.com" \
    --role="roles/container.admin"
```

### Verify GPU Quota

Before creating GPU workloads, check that you have GPU quota in your target region:

```bash
# Check GPU quota (look for entries with "GPU" in the name)
gcloud compute regions describe $REGION \
    --format="yaml(quotas)" \
    --project=$PROJECT_ID | grep -i gpu
```

If your quota is 0, request an increase via the [Quota console](https://console.cloud.google.com/iam-admin/quotas).

---

## 4. Creating a GKE Autopilot Cluster

Autopilot is the simplest way to get started. Google manages the nodes — you just deploy your workloads.

### Example 1: Create an Autopilot Cluster (gcloud CLI)

```bash
# Set variables
export CLUSTER_NAME="my-autopilot-cluster"
export REGION="us-central1"
export PROJECT_ID="your-project-id"

# Create the cluster (this takes 5-10 minutes)
gcloud container clusters create-auto $CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID
```

That's it! Google creates a fully managed cluster. No node pools to configure.

### Example 2: Create an Autopilot Cluster with a Specific GKE Version

If you need a specific version (e.g., for DWS flex-start which requires ≥1.32.2):

```bash
gcloud container clusters create-auto $CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --release-channel=rapid \
    --cluster-version="1.33.0-gke.1712000"
```

> **What is a release channel?** GKE offers three channels — **Rapid** (newest features), **Regular** (balanced), and **Stable** (most tested). For AI/ML with DWS, use **Rapid** or **Regular** to get the latest GPU features.

### Example 3: Create an Autopilot Cluster (Terraform)

```hcl
# main.tf
provider "google" {
  project = "your-project-id"
  region  = "us-central1"
}

resource "google_container_cluster" "autopilot" {
  name     = "my-autopilot-cluster"
  location = "us-central1"

  # This single flag makes it Autopilot
  enable_autopilot = true

  release_channel {
    channel = "REGULAR"
  }
}
```

```bash
# Deploy with Terraform
terraform init
terraform plan
terraform apply
```

### Example 4: Create an Autopilot Cluster (Google Cloud Console)

1. Go to the [Google Cloud Console](https://console.cloud.google.com/kubernetes/add?mode=autopilot)
2. Click **Create** → **Autopilot**
3. Enter a **Name** (e.g., `my-autopilot-cluster`)
4. Select a **Region** (e.g., `us-central1`)
5. Click **Create**

### Connect to Your Cluster

After creation, connect `kubectl` to your cluster:

```bash
# Get credentials (configures kubectl)
gcloud container clusters get-credentials $CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID

# Verify connection
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://...
# GLBCDefaultBackend is running at https://...
```

### Verify Cluster Mode

```bash
# Confirm it's Autopilot
gcloud container clusters describe $CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format="value(autopilot.enabled)"

# Expected output: True
```

---

## 5. Creating a GKE Standard Cluster

Standard mode gives you full control over node pools, machine types, and scaling. This is ideal when you need GPUDirect RDMA, custom node configurations, or privileged containers.

### Example 1: Create a Basic Standard Cluster (gcloud CLI)

```bash
# Set variables
export CLUSTER_NAME="my-standard-cluster"
export REGION="us-central1"
export ZONE="us-central1-a"
export PROJECT_ID="your-project-id"

# Create a Standard cluster with a default (CPU-only) node pool
gcloud container clusters create $CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --machine-type=e2-standard-4 \
    --num-nodes=1 \
    --release-channel=regular
```

> **Why a CPU-only node pool first?** Standard clusters need at least one node pool for system services (DNS, monitoring, etc.). GPU nodes are expensive — you add them as a separate node pool.

### Example 2: Add a GPU Node Pool to a Standard Cluster

After creating the cluster, add a node pool with GPUs:

```bash
# Add an NVIDIA L4 GPU node pool
gcloud container node-pools create gpu-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --machine-type=g2-standard-8 \
    --accelerator=type=nvidia-l4,count=1 \
    --node-locations=$ZONE \
    --num-nodes=1 \
    --enable-autoscaling \
    --min-nodes=0 \
    --max-nodes=4
```

```bash
# Add an NVIDIA A100 GPU node pool
gcloud container node-pools create a100-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --machine-type=a2-highgpu-1g \
    --accelerator=type=nvidia-tesla-a100,count=1 \
    --node-locations=$ZONE \
    --num-nodes=0 \
    --enable-autoscaling \
    --min-nodes=0 \
    --max-nodes=8
```

```bash
# Add an NVIDIA H100 GPU node pool (A3 Mega — 8 GPUs per node)
gcloud container node-pools create h100-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --machine-type=a3-megagpu-8g \
    --accelerator=type=nvidia-h100-mega-80gb,count=8 \
    --node-locations=$ZONE \
    --num-nodes=0 \
    --enable-autoscaling \
    --min-nodes=0 \
    --max-nodes=4
```

### Example 3: Create a Standard Cluster (Terraform)

```hcl
# main.tf
provider "google" {
  project = "your-project-id"
  region  = "us-central1"
}

# Standard cluster with a small system node pool
resource "google_container_cluster" "standard" {
  name     = "my-standard-cluster"
  location = "us-central1"

  # Start with a small default node pool for system services
  initial_node_count = 1

  node_config {
    machine_type = "e2-standard-4"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Required for GPU node pools
  deletion_protection = false
}

# GPU node pool with NVIDIA L4
resource "google_container_node_pool" "gpu_pool" {
  name     = "gpu-l4-pool"
  cluster  = google_container_cluster.standard.id
  location = "us-central1"

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = 4
  }

  node_config {
    machine_type = "g2-standard-8"

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }

    # GKE installs GPU drivers automatically
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_locations = ["us-central1-a"]
}
```

### Example 4: GPU Machine Type Quick Reference

When creating node pools, you need to match the **machine type** with the **accelerator type**:

| GPU | Machine Type | Accelerator Type | GPUs per VM | Use Case |
|---|---|---|---|---|
| NVIDIA T4 | `n1-standard-4` + accelerator | `nvidia-tesla-t4` | 1–4 | Inference, light training |
| NVIDIA L4 | `g2-standard-8` | `nvidia-l4` | 1–8 | Inference, fine-tuning |
| NVIDIA A100 (40GB) | `a2-highgpu-1g` | `nvidia-tesla-a100` | 1–16 | Training, fine-tuning |
| NVIDIA A100 (80GB) | `a2-ultragpu-1g` | `nvidia-a100-80gb` | 1–8 | Large model training |
| NVIDIA H100 (80GB) | `a3-megagpu-8g` | `nvidia-h100-mega-80gb` | 8 | Distributed training |
| NVIDIA H200 (141GB) | `a3-ultragpu-8g` | `nvidia-h200-141gb` | 8 | Large-scale training |
| NVIDIA B200 (180GB) | `a4-megagpu-8g` | `nvidia-b200` | 8 | Latest generation training |

### Connect and Verify

```bash
# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID

# List nodes (you'll see your system nodes)
kubectl get nodes

# List node pools
gcloud container node-pools list \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID

# Check GPU availability on nodes
kubectl get nodes -l cloud.google.com/gke-accelerator=nvidia-l4
```

---

## 6. Deploying GPU Workloads on Autopilot

In Autopilot mode, you don't create node pools. Instead, you **request GPUs directly in your Pod spec**, and GKE automatically provisions the right node.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  Autopilot GPU Workflow                                         │
│                                                                  │
│  1. You submit a Pod that requests GPUs                          │
│     (via nodeSelector + resource requests)                       │
│                                                                  │
│  2. GKE sees the GPU request and provisions                      │
│     a GPU node automatically                                     │
│                                                                  │
│  3. GKE installs GPU drivers on the node                         │
│                                                                  │
│  4. Your Pod runs on the GPU node                                │
│                                                                  │
│  5. When your Pod finishes, GKE removes                          │
│     the GPU node (you stop paying)                               │
└─────────────────────────────────────────────────────────────────┘
```

### Example 1: Simple GPU Pod (NVIDIA L4)

```yaml
# autopilot-gpu-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test-l4
spec:
  nodeSelector:
    cloud.google.com/gke-accelerator: nvidia-l4        # Request L4 GPU
  containers:
    - name: gpu-container
      image: nvidia/cuda:12.0.0-runtime-ubuntu22.04
      command: ["nvidia-smi"]                           # Print GPU info
      resources:
        limits:
          nvidia.com/gpu: 1                             # Request 1 GPU
```

```bash
# Deploy the Pod
kubectl apply -f autopilot-gpu-pod.yaml

# Watch it run (may take a few minutes as GKE provisions a GPU node)
kubectl get pod gpu-test-l4 -w

# Check the output (nvidia-smi shows GPU details)
kubectl logs gpu-test-l4
```

**Expected output:**
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.129.03   Driver Version: 535.129.03   CUDA Version: 12.2     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA L4           Off  | 00000000:00:04.0 Off |                    0 |
| N/A   44C    P0    28W /  72W |      0MiB / 23034MiB |      4%      Default |
+-------------------------------+----------------------+----------------------+
```

### Example 2: GPU Pod with A100

```yaml
# autopilot-a100-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test-a100
spec:
  nodeSelector:
    cloud.google.com/gke-accelerator: nvidia-tesla-a100   # Request A100 GPU
    cloud.google.com/gke-accelerator-count: "2"           # Request 2 GPUs on the node
  containers:
    - name: training-container
      image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
      command: ["python3", "-c", "import torch; print(f'GPUs available: {torch.cuda.device_count()}')"]
      resources:
        limits:
          nvidia.com/gpu: 2                                # Use 2 GPUs in this container
```

```bash
kubectl apply -f autopilot-a100-pod.yaml
kubectl logs gpu-test-a100
# Output: GPUs available: 2
```

### Example 3: Training Job with GPU (Batch Job)

A **Job** runs a task to completion (unlike a Pod which just runs once). This is the standard pattern for training workloads:

```yaml
# autopilot-training-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: mnist-training
spec:
  completions: 1
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-l4
      containers:
        - name: trainer
          image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
          command:
            - python3
            - -c
            - |
              import torch
              import torch.nn as nn
              import torch.optim as optim

              # Verify GPU is available
              device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
              print(f'Training on: {device}')

              # Simple neural network
              model = nn.Sequential(
                  nn.Linear(784, 128),
                  nn.ReLU(),
                  nn.Linear(128, 10)
              ).to(device)

              # Dummy training loop
              optimizer = optim.Adam(model.parameters())
              for epoch in range(5):
                  x = torch.randn(64, 784).to(device)
                  y = torch.randint(0, 10, (64,)).to(device)
                  loss = nn.CrossEntropyLoss()(model(x), y)
                  optimizer.zero_grad()
                  loss.backward()
                  optimizer.step()
                  print(f'Epoch {epoch+1}/5, Loss: {loss.item():.4f}')

              print('Training complete!')
          resources:
            requests:
              cpu: "2"
              memory: "8Gi"
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
  backoffLimit: 3
```

```bash
# Submit the training job
kubectl apply -f autopilot-training-job.yaml

# Watch job progress
kubectl get jobs -w

# View training logs
kubectl logs job/mnist-training
```

### Example 4: Multi-GPU Inference Pod (H100)

```yaml
# autopilot-h100-inference.yaml
apiVersion: v1
kind: Pod
metadata:
  name: llm-inference-h100
spec:
  nodeSelector:
    cloud.google.com/gke-accelerator: nvidia-h100-mega-80gb
    cloud.google.com/gke-accelerator-count: "8"
  containers:
    - name: vllm-server
      image: vllm/vllm-openai:latest
      args:
        - "--model=meta-llama/Llama-2-7b-hf"
        - "--tensor-parallel-size=8"
        - "--host=0.0.0.0"
        - "--port=8000"
      resources:
        requests:
          cpu: "16"
          memory: "128Gi"
          nvidia.com/gpu: 8
        limits:
          nvidia.com/gpu: 8
      ports:
        - containerPort: 8000
```

### Key Points for Autopilot GPU Workloads

| Setting | Purpose | Required? |
|---|---|---|
| `cloud.google.com/gke-accelerator` nodeSelector | Tells GKE which GPU type you need | ✅ Yes |
| `cloud.google.com/gke-accelerator-count` nodeSelector | How many GPUs the node should have | Optional (defaults to GPU quantity) |
| `nvidia.com/gpu` in resource limits | How many GPUs this container uses | ✅ Yes |
| `cloud.google.com/gke-gpu-driver-version` nodeSelector | Choose `default` or `latest` GPU driver | Optional |

---

## 7. Deploying GPU Workloads on Standard

In Standard mode, you first create a GPU node pool, then deploy workloads that target it using node selectors and tolerations.

### Step 1: Create a GPU Node Pool (if not already done)

```bash
# Create an L4 GPU node pool with autoscaling
gcloud container node-pools create gpu-l4-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --machine-type=g2-standard-8 \
    --accelerator=type=nvidia-l4,count=1 \
    --node-locations=us-central1-a \
    --num-nodes=0 \
    --enable-autoscaling \
    --min-nodes=0 \
    --max-nodes=4
```

### Step 2: Deploy a Workload

### Example 1: Simple GPU Job on Standard

```yaml
# standard-gpu-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: gpu-test-standard
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-l4
      # Tolerations allow this Pod to run on GPU nodes
      # (GPU nodes have taints that prevent non-GPU Pods from landing on them)
      tolerations:
        - key: "nvidia.com/gpu"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: gpu-task
          image: nvidia/cuda:12.0.0-runtime-ubuntu22.04
          command: ["nvidia-smi"]
          resources:
            requests:
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
```

```bash
kubectl apply -f standard-gpu-job.yaml
kubectl logs job/gpu-test-standard
```

> **What is a "toleration"?** In Kubernetes, GPU nodes have a **taint** (a label that repels Pods). Your Pod needs a matching **toleration** to be allowed onto the GPU node. Think of it as a "permission slip" for your workload to use the GPU node.

### Example 2: Training Job with Checkpointing to GCS

```yaml
# standard-training-checkpoint.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: training-with-checkpoints
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-tesla-a100
      tolerations:
        - key: "nvidia.com/gpu"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: trainer
          image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
          command:
            - python3
            - -c
            - |
              import torch
              import os
              from google.cloud import storage

              device = torch.device('cuda')
              print(f'Using device: {device}')
              print(f'GPU: {torch.cuda.get_device_name(0)}')

              # Simple model
              model = torch.nn.Linear(100, 10).to(device)
              optimizer = torch.optim.Adam(model.parameters())

              # Training loop with checkpointing
              for epoch in range(10):
                  x = torch.randn(32, 100).to(device)
                  y = torch.randint(0, 10, (32,)).to(device)
                  loss = torch.nn.CrossEntropyLoss()(model(x), y)
                  optimizer.zero_grad()
                  loss.backward()
                  optimizer.step()
                  print(f'Epoch {epoch+1}, Loss: {loss.item():.4f}')

                  # Save checkpoint every 5 epochs
                  if (epoch + 1) % 5 == 0:
                      checkpoint_path = f'/tmp/checkpoint_epoch_{epoch+1}.pt'
                      torch.save({
                          'epoch': epoch,
                          'model_state_dict': model.state_dict(),
                          'optimizer_state_dict': optimizer.state_dict(),
                          'loss': loss.item(),
                      }, checkpoint_path)
                      # Upload to GCS
                      os.system(f'gsutil cp {checkpoint_path} gs://YOUR_BUCKET/checkpoints/')
                      print(f'Checkpoint saved to GCS')

              print('Training complete!')
          resources:
            requests:
              cpu: "4"
              memory: "16Gi"
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
          env:
            - name: GOOGLE_APPLICATION_CREDENTIALS
              value: "/var/run/secrets/google/key.json"
      restartPolicy: Never
  backoffLimit: 3
```

### Example 3: Multi-Node Distributed Training with JobSet

For training that spans multiple GPU nodes (distributed training), use **JobSet**:

```yaml
# standard-distributed-training.yaml
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: distributed-pytorch-training
spec:
  replicatedJobs:
    - name: workers
      replicas: 2                          # 2 worker nodes
      template:
        spec:
          parallelism: 1
          completions: 1
          template:
            spec:
              nodeSelector:
                cloud.google.com/gke-accelerator: nvidia-h100-mega-80gb
              tolerations:
                - key: "nvidia.com/gpu"
                  operator: "Exists"
                  effect: "NoSchedule"
              containers:
                - name: worker
                  image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
                  command:
                    - python3
                    - -c
                    - |
                      import torch
                      import torch.distributed as dist
                      import os

                      # PyTorch distributed setup
                      world_size = int(os.environ.get('WORLD_SIZE', '1'))
                      rank = int(os.environ.get('RANK', '0'))
                      print(f'Worker {rank}/{world_size}, GPUs: {torch.cuda.device_count()}')

                      # Your distributed training code here
                      print(f'Worker {rank} completed!')
                  resources:
                    requests:
                      cpu: "8"
                      memory: "64Gi"
                      nvidia.com/gpu: 8
                    limits:
                      nvidia.com/gpu: 8
              restartPolicy: Never
```

> **What is JobSet?** JobSet is a Kubernetes extension that coordinates multiple Jobs as a single unit — perfect for distributed training where all workers need to start together. Install it with: `kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/latest/download/manifests.yaml`

---

## 8. DWS Integration — Flex-Start on GKE

**Dynamic Workload Scheduler (DWS) flex-start** lets you get GPUs at up to **53% discount** by telling Google Cloud "I need these GPUs, but I can wait until they're available." GKE provisions the resources when capacity opens up.

### What is Flex-Start?

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Without Flex-Start (On-Demand):                                        │
│                                                                         │
│  You: "I need 8 H100 GPUs now"                                         │
│  Google Cloud: "Sorry, none available" ❌                               │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  With Flex-Start:                                                       │
│                                                                         │
│  You: "I need 8 H100 GPUs, I can wait"                                 │
│  Google Cloud: "OK, I'll queue your request and provision them          │
│                 when available — at up to 53% discount" ✅              │
│                                                                         │
│  [Request queued] ──► [Capacity available] ──► [VMs provisioned]        │
│   (minutes to hours)    (automatic)              (your job runs)        │
│                                                                         │
│  Key constraints:                                                       │
│  • Maximum run duration: 7 days                                         │
│  • VMs are deleted when duration expires                                │
│  • You must checkpoint your work                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Two Flex-Start Configurations

| | Flex-Start | Flex-Start + Queued Provisioning |
|---|---|---|
| **How nodes are provisioned** | One node at a time, as each becomes available | All nodes at once, when all capacity is available |
| **Best for** | Small/medium workloads (single node) | Large distributed workloads (multi-node) |
| **Complexity** | Simple — just add a flag/selector | More complex — requires Kueue setup |
| **Example** | Fine-tuning on 1-2 GPUs | Distributed pre-training across 8+ nodes |
| **Setup** | `--flex-start` flag or nodeSelector | `--flex-start` + `--enable-queued-provisioning` + Kueue |

### Flex-Start on Autopilot

On Autopilot, using flex-start is as simple as adding a **node selector** to your Pod:

#### Example 1: Autopilot Flex-Start Job

```yaml
# autopilot-flex-start-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dws-training-autopilot
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-tesla-a100  # GPU type
        cloud.google.com/gke-flex-start: "true"              # ← Enable flex-start!
      containers:
        - name: trainer
          image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
          command:
            - python3
            - -c
            - |
              import torch
              print(f'Running on flex-start GPU: {torch.cuda.get_device_name(0)}')
              print(f'GPU count: {torch.cuda.device_count()}')

              # Your training code here
              model = torch.nn.Linear(100, 10).cuda()
              for i in range(100):
                  x = torch.randn(32, 100).cuda()
                  loss = model(x).sum()
                  loss.backward()
              print('Flex-start training complete!')
          resources:
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
  backoffLimit: 3
```

```bash
kubectl apply -f autopilot-flex-start-job.yaml

# The job may take some time to start as GKE waits for GPU capacity
kubectl get job dws-training-autopilot -w
```

#### Example 2: Autopilot Flex-Start with Two Jobs Sharing a Node

This is the pattern from Google's official documentation — two Jobs share a single flex-start node:

```yaml
# autopilot-flex-start-shared.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: flex-job-1
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-flex-start: "true"
        cloud.google.com/gke-accelerator: nvidia-l4
      containers:
        - name: task-1
          image: gcr.io/k8s-staging-perf-tests/sleep:latest
          args: ["30s"]
          resources:
            requests:
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
      restartPolicy: OnFailure
---
apiVersion: batch/v1
kind: Job
metadata:
  name: flex-job-2
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-flex-start: "true"
        cloud.google.com/gke-accelerator: nvidia-l4
      containers:
        - name: task-2
          image: gcr.io/k8s-staging-perf-tests/sleep:latest
          args: ["30s"]
          resources:
            requests:
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
      restartPolicy: OnFailure
```

```bash
kubectl apply -f autopilot-flex-start-shared.yaml

# Both Jobs run on the same flex-start node (if it has 2+ GPUs)
kubectl get pods -l "job-name in (flex-job-1,flex-job-2)" -o wide
```

### Flex-Start on Standard

On Standard, you create a **flex-start-enabled node pool**:

#### Example 3: Create a Flex-Start Node Pool (Standard)

```bash
# Create a node pool with flex-start enabled
gcloud container node-pools create dws-flex-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --accelerator=type=nvidia-l4,count=1 \
    --machine-type=g2-standard-8 \
    --flex-start \
    --max-run-duration=86400s \
    --node-locations=us-central1-a \
    --num-nodes=0 \
    --enable-autoscaling \
    --total-min-nodes=0 \
    --total-max-nodes=5 \
    --location-policy=ANY \
    --reservation-affinity=none \
    --no-enable-autorepair
```

**Key flags explained:**

| Flag | What It Does |
|---|---|
| `--flex-start` | Enables DWS flex-start on this node pool |
| `--max-run-duration=86400s` | Nodes run for max 1 day (86400 seconds). Max is 7 days (604800s) |
| `--num-nodes=0` | Start with zero nodes — autoscaler provisions when workloads arrive |
| `--reservation-affinity=none` | Required — flex-start cannot use reservations |
| `--no-enable-autorepair` | Disable auto-repair to prevent workload disruption |

#### Example 4: Deploy a Job on Flex-Start Node Pool (Standard)

```yaml
# standard-flex-start-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dws-training-standard
spec:
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-nodepool: dws-flex-pool       # Target the flex-start node pool
        cloud.google.com/gke-accelerator: nvidia-l4
      tolerations:
        - key: "nvidia.com/gpu"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: trainer
          image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
          command:
            - python3
            - -c
            - |
              import torch
              device = torch.device('cuda')
              print(f'Training on flex-start GPU: {torch.cuda.get_device_name(0)}')

              # Simulated training with checkpointing
              model = torch.nn.Linear(784, 10).to(device)
              optimizer = torch.optim.SGD(model.parameters(), lr=0.01)

              for epoch in range(20):
                  x = torch.randn(64, 784).to(device)
                  y = torch.randint(0, 10, (64,)).to(device)
                  loss = torch.nn.CrossEntropyLoss()(model(x), y)
                  optimizer.zero_grad()
                  loss.backward()
                  optimizer.step()
                  if (epoch + 1) % 5 == 0:
                      print(f'Epoch {epoch+1}: Loss={loss.item():.4f}')

              print('DWS flex-start training complete!')
          resources:
            requests:
              cpu: "2"
              memory: "8Gi"
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
  backoffLimit: 3
```

```bash
kubectl apply -f standard-flex-start-job.yaml

# Check the provisioning status
kubectl get nodes -l cloud.google.com/gke-nodepool=dws-flex-pool
kubectl get pods -o wide
```

#### Example 5: Verify Flex-Start Status on a Node Pool

```bash
# Check if flex-start is enabled
gcloud container node-pools describe dws-flex-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format="get(config.flexStart)"

# Expected output: True
```

### Flex-Start with H100/H200/B200 (Standard)

For high-end GPUs, the process is similar but with different machine types:

```bash
# H100 flex-start node pool
gcloud container node-pools create dws-h100-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --accelerator=type=nvidia-h100-mega-80gb,count=8 \
    --machine-type=a3-megagpu-8g \
    --flex-start \
    --max-run-duration=604800s \
    --node-locations=us-central1-a \
    --num-nodes=0 \
    --enable-autoscaling \
    --total-min-nodes=0 \
    --total-max-nodes=4 \
    --location-policy=ANY \
    --reservation-affinity=none \
    --no-enable-autorepair

# H200 flex-start node pool
gcloud container node-pools create dws-h200-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --accelerator=type=nvidia-h200-141gb,count=8 \
    --machine-type=a3-ultragpu-8g \
    --flex-start \
    --max-run-duration=604800s \
    --node-locations=us-central1-a \
    --num-nodes=0 \
    --enable-autoscaling \
    --total-min-nodes=0 \
    --total-max-nodes=4 \
    --location-policy=ANY \
    --reservation-affinity=none \
    --no-enable-autorepair
```

---

## 9. DWS Integration — Flex-Start with Queued Provisioning (Kueue)

For **distributed training** that requires multiple GPU nodes to start simultaneously, you need **flex-start with queued provisioning**. This uses **Kueue** — a Kubernetes-native job queuing system — to coordinate DWS requests.

### When to Use Queued Provisioning

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  Flex-Start (Basic)                  Flex-Start + Queued Provisioning   │
│  ───────────────────                 ──────────────────────────────     │
│                                                                         │
│  1 node at a time                    All nodes at once                  │
│  Simple setup                        Requires Kueue                     │
│                                                                         │
│  ✅ Fine-tuning on 1 GPU             ✅ Distributed pre-training        │
│  ✅ Single-node inference             ✅ Multi-node NCCL training        │
│  ✅ Batch processing                  ✅ Jobs needing all GPUs together  │
│                                                                         │
│  ❌ Multi-node training               ❌ Single-GPU tasks (overkill)    │
│     (nodes come one at a time,                                          │
│      can't coordinate)                                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Setup

#### Step 1: Create the Node Pool with Queued Provisioning

```bash
# Create a node pool with both flex-start AND queued provisioning
gcloud container node-pools create dws-queued-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --accelerator=type=nvidia-tesla-a100,count=1 \
    --machine-type=a2-highgpu-1g \
    --flex-start \
    --enable-queued-provisioning \
    --max-run-duration=172800s \
    --node-locations=us-central1-a \
    --num-nodes=0 \
    --enable-autoscaling \
    --total-min-nodes=0 \
    --total-max-nodes=8 \
    --location-policy=ANY \
    --reservation-affinity=none \
    --no-enable-autorepair
```

#### Step 2: Install Kueue

[Kueue](https://kueue.sigs.k8s.io/) is the job queue manager that coordinates DWS provisioning requests.

```bash
# Install the latest Kueue version
KUEUE_VERSION=v0.10.0   # Check https://github.com/kubernetes-sigs/kueue/releases for latest
kubectl apply --server-side \
    -f https://github.com/kubernetes-sigs/kueue/releases/download/$KUEUE_VERSION/manifests.yaml

# Verify Kueue is running
kubectl get pods -n kueue-system
```

**Expected output:**
```
NAME                                        READY   STATUS    RESTARTS   AGE
kueue-controller-manager-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

#### Step 3: Create Kueue Resources

These resources configure the DWS provisioning pipeline:

```yaml
# kueue-dws-setup.yaml
# 1. ResourceFlavor — defines what type of resources are available
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "dws-gpu-flavor"
---
# 2. AdmissionCheck — gates job admission on GPU provisioning via DWS
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
# 3. ProvisioningRequestConfig — tells GKE to use DWS queued provisioning
apiVersion: kueue.x-k8s.io/v1beta1
kind: ProvisioningRequestConfig
metadata:
  name: dws-config
spec:
  provisioningClassName: queued-provisioning.gke.io
  managedResources:
    - nvidia.com/gpu
---
# 4. ClusterQueue — cluster-wide queue that limits total GPUs
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "dws-cluster-queue"
spec:
  namespaceSelector: {}       # Accept jobs from all namespaces
  resourceGroups:
    - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
      flavors:
        - name: "dws-gpu-flavor"
          resources:
            - name: "cpu"
              nominalQuota: 10000          # High quota (effectively unlimited)
            - name: "memory"
              nominalQuota: 10000Gi
            - name: "nvidia.com/gpu"
              nominalQuota: 32             # Max 32 GPUs admitted at once
  admissionChecks:
    - dws-prov
---
# 5. LocalQueue — namespace-scoped queue that users submit jobs to
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: "default"
  name: "dws-local-queue"
spec:
  clusterQueue: "dws-cluster-queue"
```

```bash
kubectl apply -f kueue-dws-setup.yaml

# Verify all resources are created
kubectl get resourceflavors
kubectl get admissionchecks
kubectl get provisioningrequestconfigs
kubectl get clusterqueues
kubectl get localqueues -A
```

**Expected output for ClusterQueue:**
```
NAME                COHORT   PENDING WORKLOADS   ADMITTED WORKLOADS
dws-cluster-queue            0                   0
```

> **Understanding `nominalQuota`:** The `nominalQuota` for `nvidia.com/gpu` (set to 32 in this example) controls how many GPUs Kueue will admit simultaneously. If you submit jobs requesting more than 32 total GPUs, the excess jobs wait in the queue until running jobs finish.

#### Step 4: Submit a DWS Job via Kueue

```yaml
# kueue-dws-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dws-queued-training
  namespace: default
  labels:
    kueue.x-k8s.io/queue-name: dws-local-queue       # ← Route to DWS queue
  annotations:
    provreq.kueue.x-k8s.io/maxRunDurationSeconds: "86400"  # Max 24 hours
spec:
  parallelism: 1
  completions: 1
  suspend: true              # ← Required! Kueue manages scheduling
  template:
    spec:
      nodeSelector:
        cloud.google.com/gke-nodepool: dws-queued-pool
      tolerations:
        - key: "nvidia.com/gpu"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: training
          image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
          command:
            - python3
            - -c
            - |
              import torch
              print(f'DWS Queued Provisioning Training')
              print(f'GPU: {torch.cuda.get_device_name(0)}')
              print(f'GPU Count: {torch.cuda.device_count()}')

              # Your training code here
              model = torch.nn.Linear(100, 10).cuda()
              for epoch in range(50):
                  x = torch.randn(64, 100).cuda()
                  loss = model(x).sum()
                  loss.backward()
                  if (epoch + 1) % 10 == 0:
                      print(f'Epoch {epoch+1}/50')
              print('DWS queued training complete!')
          resources:
            requests:
              cpu: "4"
              memory: "16Gi"
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
```

```bash
kubectl apply -f kueue-dws-job.yaml
```

**Key fields explained:**

| Field | What It Does | Why It's Required |
|---|---|---|
| `kueue.x-k8s.io/queue-name` label | Tells Kueue to manage this job via the DWS queue | Without this, the job bypasses Kueue and DWS |
| `suspend: true` | Creates the job but doesn't schedule it yet | Kueue unsuspends it when GPUs are provisioned |
| `maxRunDurationSeconds` annotation | How long DWS nodes will run (max 604800 = 7 days) | Controls cost; nodes are deleted when this expires |

#### Step 5: Monitor the DWS Pipeline

```bash
# Watch job status
kubectl get jobs -w

# Check Kueue workload status (shows admission state)
kubectl get workloads -A

# Check DWS provisioning requests (shows GPU provisioning status)
kubectl get provisioningrequests -A

# Detailed provisioning status
kubectl describe provisioningrequest -A

# Kueue controller logs (for debugging)
kubectl logs -n kueue-system -l control-plane=controller-manager --tail=50
```

**DWS provisioning flow:**
```
Job submitted ──► Kueue admits ──► AdmissionCheck triggers ──► ProvisioningRequest
    │                                                              │
    │                                                    GKE creates DWS
    │                                                    resize request
    │                                                              │
    │                                                    DWS queues until
    │                                                    capacity available
    │                                                              │
    └──────────────────── Job runs on provisioned nodes ◄──────────┘
```

### Example: Multi-Node Distributed Training with Kueue + DWS

```yaml
# kueue-dws-distributed.yaml
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: distributed-dws-training
  namespace: default
  labels:
    kueue.x-k8s.io/queue-name: dws-local-queue
  annotations:
    provreq.kueue.x-k8s.io/maxRunDurationSeconds: "172800"   # 48 hours
spec:
  replicatedJobs:
    - name: workers
      replicas: 4                    # 4 worker nodes, all provisioned at once
      template:
        spec:
          parallelism: 1
          completions: 1
          suspend: true
          template:
            spec:
              nodeSelector:
                cloud.google.com/gke-nodepool: dws-queued-pool
              tolerations:
                - key: "nvidia.com/gpu"
                  operator: "Exists"
                  effect: "NoSchedule"
              containers:
                - name: worker
                  image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
                  command:
                    - python3
                    - -c
                    - |
                      import torch
                      import os
                      rank = os.environ.get('JOB_COMPLETION_INDEX', '0')
                      print(f'Worker {rank}: GPU={torch.cuda.get_device_name(0)}')
                      print(f'Worker {rank}: Training started')

                      model = torch.nn.Linear(1000, 100).cuda()
                      for step in range(100):
                          x = torch.randn(128, 1000).cuda()
                          loss = model(x).sum()
                          loss.backward()

                      print(f'Worker {rank}: Training complete!')
                  resources:
                    requests:
                      cpu: "4"
                      memory: "16Gi"
                      nvidia.com/gpu: 1
                    limits:
                      nvidia.com/gpu: 1
              restartPolicy: Never
```

```bash
kubectl apply -f kueue-dws-distributed.yaml

# All 4 workers will start simultaneously once DWS provisions all nodes
kubectl get pods -l jobset.sigs.k8s.io/jobset-name=distributed-dws-training -w
```

---

## 10. DWS Integration — Reservation + DWS Fallback Pattern

For production workloads, the recommended pattern uses **reserved GPUs first**, and **falls back to DWS** when reservations are exhausted. This is achieved with Kueue's **multi-flavor ClusterQueue**.

### How It Works

```
Job submitted
    │
    ▼
Kueue tries Reservation flavor (Priority 1)
    │
    ├── Reservation has capacity ──► Job runs on reserved nodes (no discount, guaranteed)
    │
    └── Reservation exhausted ──► Falls back to DWS flavor (Priority 2)
                                      │
                                      └── DWS queues and provisions when available
                                           (up to 53% discount)
```

### Complete Setup Example

#### Step 1: Create Both Node Pools

```bash
# Reserved node pool (uses your existing reservation)
gcloud container node-pools create reserved-gpu-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --accelerator=type=nvidia-tesla-a100,count=1 \
    --machine-type=a2-highgpu-1g \
    --reservation-affinity=specific \
    --reservation=MY_RESERVATION_NAME \
    --node-locations=us-central1-a \
    --num-nodes=2

# DWS flex-start node pool (fallback)
gcloud container node-pools create dws-fallback-pool \
    --cluster=$CLUSTER_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --accelerator=type=nvidia-tesla-a100,count=1 \
    --machine-type=a2-highgpu-1g \
    --flex-start \
    --enable-queued-provisioning \
    --node-locations=us-central1-a \
    --num-nodes=0 \
    --enable-autoscaling \
    --total-min-nodes=0 \
    --total-max-nodes=8 \
    --location-policy=ANY \
    --reservation-affinity=none \
    --no-enable-autorepair
```

#### Step 2: Create Multi-Flavor Kueue Configuration

```yaml
# kueue-reservation-dws-fallback.yaml

# Flavor for reserved nodes
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "reserved-flavor"
spec:
  nodeLabels:
    cloud.google.com/gke-nodepool: reserved-gpu-pool
---
# Flavor for DWS flex-start nodes
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "dws-flavor"
spec:
  nodeLabels:
    cloud.google.com/gke-nodepool: dws-fallback-pool
---
# DWS AdmissionCheck (only for DWS flavor)
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
# ClusterQueue with reservation (priority 1) + DWS fallback (priority 2)
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "hybrid-cluster-queue"
spec:
  namespaceSelector: {}
  resourceGroups:
    - coveredResources: ["nvidia.com/gpu"]
      flavors:
        # Priority 1: Try reserved capacity first
        - name: "reserved-flavor"
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: 2            # 2 reserved GPUs available
        # Priority 2: Fall back to DWS
        - name: "dws-flavor"
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: 16           # Up to 16 DWS GPUs
  admissionChecks:
    - dws-prov
  flavorFungibility:
    whenCanBorrow: TryNextFlavor         # Try next flavor if current is full
    whenCanPreempt: TryNextFlavor
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: "default"
  name: "hybrid-local-queue"
spec:
  clusterQueue: "hybrid-cluster-queue"
```

```bash
kubectl apply -f kueue-reservation-dws-fallback.yaml
```

#### Step 3: Submit Jobs (They Automatically Use the Best Available Resource)

```yaml
# hybrid-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: smart-gpu-training
  labels:
    kueue.x-k8s.io/queue-name: hybrid-local-queue
  annotations:
    provreq.kueue.x-k8s.io/maxRunDurationSeconds: "86400"
spec:
  suspend: true
  template:
    spec:
      tolerations:
        - key: "nvidia.com/gpu"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        - name: trainer
          image: us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest
          command: ["python3", "-c", "import torch; print(f'Running on {torch.cuda.get_device_name(0)}'); print('Job complete!')"]
          resources:
            requests:
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
      restartPolicy: Never
```

```bash
kubectl apply -f hybrid-job.yaml

# If reserved capacity is available → runs immediately on reserved nodes
# If reserved capacity is full → falls back to DWS (queued, discounted)
```

---

## 11. When to Use What — Decision Framework

### GKE Mode Decision

```
                    Starting a new AI/ML project on GKE?
                               │
                    ┌──────────┴──────────┐
                    │                      │
              Need GPUDirect         No GPUDirect
              RDMA? Need              needed?
              privileged access?
                    │                      │
              Use Standard          Need simplest
                                    setup possible?
                                          │
                                   ┌──────┴──────┐
                                  Yes            No
                                   │              │
                             Use Autopilot   Either works,
                             (recommended)   but consider:
                                             • Multi-team → Standard
                                             • Custom networking → Standard
                                             • Simple workloads → Autopilot
```

### DWS Decision

```
                    Do you need GPUs/TPUs?
                               │
                    ┌──────────┴──────────┐
                   Yes                    No
                    │                      │
              Do you have           Standard GKE
              reserved capacity?    (no DWS needed)
                    │
             ┌──────┴──────┐
            Yes            No
             │              │
        Use reservations  Is the workload
        (or hybrid with   time-flexible?
        DWS fallback)         │
                        ┌─────┴─────┐
                       Yes          No
                        │            │
                  Use DWS         Use on-demand
                  flex-start      (if available)
                  (53% discount)  or request
                        │          a reservation
                        │
                  Single node    Multi-node
                  workload?      distributed?
                        │              │
                  Flex-start      Flex-start +
                  (simple)        Queued Provisioning
                                  (Kueue)
```

### Complete Decision Matrix

| Scenario | GKE Mode | DWS Config | Tool Suggestion |
|---|---|---|---|
| Quick GPU experiment, 1 GPU | **Autopilot** | Flex-start (nodeSelector) | Direct `kubectl` |
| Fine-tuning LLM, 1-4 GPUs, cost-sensitive | **Autopilot** | Flex-start (nodeSelector) | Direct `kubectl` |
| Distributed pre-training, 8+ GPUs | **Standard** | Flex-start + Queued Provisioning | Kueue or [XPK](../xpk/) |
| Production training pipeline | **Standard** | Reservation + DWS fallback | [Cluster Toolkit](../cluster-toolkit/) |
| Inference serving with auto-scaling | **Autopilot** | On-demand or Flex-start | Direct `kubectl` |
| GPUDirect RDMA multi-node training | **Standard** | Reservation or DWS | [Cluster Toolkit](../cluster-toolkit/) |
| PoC with minimal setup | **Autopilot** | Any | [XPK](../xpk/) |
| HPC/MPI workloads | **Standard** | Reservation | [Cluster Director](../cluster-director/) |

### Relationship to Cluster Toolkit and XPK

This guide shows you how to create GKE clusters and deploy GPU workloads **directly**. However, two other tools in this repository create GKE clusters for you with additional automation:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Ways to Create AI-Optimized GKE Clusters                               │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────┐    │
│  │ This Guide       │  │ Cluster Toolkit │  │ XPK                  │    │
│  │ (gcloud / TF)    │  │                 │  │                      │    │
│  │                  │  │ Terraform        │  │ Python CLI           │    │
│  │ Manual setup     │  │ blueprints for   │  │ for quick PoC        │    │
│  │ Full flexibility │  │ production       │  │ clusters             │    │
│  │ Learn GKE basics │  │ GKE clusters     │  │                      │    │
│  └─────────────────┘  └─────────────────┘  └──────────────────────┘    │
│       ▲ THIS GUIDE         Best for              Best for              │
│       │                    production             experimentation      │
│       │                                                                 │
│  Use when you want     [→ cluster-toolkit/]    [→ xpk/]               │
│  to understand GKE                                                      │
│  or customize deeply                                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Best Practices

### Cluster Configuration

| Best Practice | Detail |
|---|---|
| **Start with Autopilot** | Simpler for beginners; migrate to Standard if you need more control |
| **Use a dedicated project** | Separate AI/ML workloads from other production services to avoid quota contention |
| **Enable Workload Identity** | Use Workload Identity Federation instead of service account keys for GCS access |
| **Set maintenance windows** | Prevent GKE auto-upgrades during active training runs |

### GPU Workloads

| Best Practice | Detail |
|---|---|
| **Always checkpoint** | DWS flex-start VMs are deleted when the run duration expires — save progress to GCS frequently |
| **Test with small configs first** | Validate your container image and training script on 1 GPU before scaling up |
| **Use the right GPU for the job** | L4 for inference, A100/H100 for training — don't overpay for hardware you don't need |
| **Set resource requests AND limits** | Kubernetes uses these to schedule Pods correctly; always set `nvidia.com/gpu` in both |

### DWS Flex-Start

| Best Practice | Detail |
|---|---|
| **Right-size `maxRunDuration`** | Don't request 7 days if your job needs 6 hours — shorter durations may be fulfilled faster |
| **Use `suspend: true` with Kueue** | Required for Kueue to manage DWS provisioning; without it, jobs bypass the queue |
| **Disable node auto-repair** | Auto-repair removes all workloads from a node; use `--no-enable-autorepair` for DWS node pools |
| **Set `nominalQuota` appropriately** | Match your `ACTIVE_RESIZE_REQUESTS` quota (default: 100 per project) |
| **Try multiple zones** | If not zone-bound, submit requests in multiple zones to increase chances of DWS fulfillment |

### Cost Optimization

| Strategy | Savings | Trade-off |
|---|---|---|
| **DWS flex-start** | Up to 53% discount | Must wait for capacity; 7-day max |
| **Spot VMs** | Up to 91% discount | Can be preempted at any time |
| **Reservations** | Guaranteed capacity at committed rate | Long-term commitment required |
| **Reservation + DWS fallback** | Best of both — guaranteed + discounted overflow | More complex Kueue setup |
| **Autopilot** | Pay only for Pods, not idle nodes | Less control over node configuration |

### Data Residency (Public Sector)

| Best Practice | Detail |
|---|---|
| **Specify zones explicitly** | DWS provisions VMs only in the zone you specify — no cross-region movement |
| **Use Assured Workloads** | For FedRAMP High, DoD IL4/IL5 — automatically enforces resource location constraints |
| **Align storage and compute regions** | Keep GCS buckets in the same region as your GKE cluster |

> For detailed data residency and compliance guidance, see the [DWS Guide — Data Residency & Compliance](../dws/#5-data-residency--compliance-considerations).

---

## 13. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|---|---|---|
| **Pod stuck in `Pending`** | No GPU nodes available or insufficient quota | Check `kubectl describe pod <name>` for events; verify GPU quota with `gcloud compute regions describe $REGION` |
| **"Insufficient nvidia.com/gpu" error** | Node doesn't have enough GPUs for the request | Reduce GPU request or use a node with more GPUs |
| **Autopilot rejects GPU Pod** | Missing or invalid nodeSelector | Ensure you specify both `gke-accelerator` (GPU type) and `nvidia.com/gpu` (resource limit) |
| **DWS job stays queued indefinitely** | No GPU capacity in the zone | Wait (DWS queues automatically); try a different zone |
| **Kueue workload not admitted** | Kueue resources misconfigured | Check `kubectl get workloads -A` and `kubectl describe clusterqueue` |
| **ProvisioningRequest failed** | Quota exceeded or invalid config | Check `kubectl describe provisioningrequest <name>`; verify GPU quota |
| **GPU driver not installed** | GKE version too old or driver issue | Use GKE ≥1.28; add `cloud.google.com/gke-gpu-driver-version: latest` nodeSelector |
| **Node pool creation fails** | Accelerator type not available in zone | Check availability: `gcloud compute accelerator-types list --filter="zone:$ZONE"` |
| **Standard: Pod can't schedule on GPU node** | Missing toleration | Add `tolerations` for `nvidia.com/gpu` taint (see examples above) |
| **Flex-start nodes not provisioning** | GKE version too old | Flex-start requires GKE ≥1.32.2-gke.1652000 |

### Useful Debug Commands

```bash
# ── Cluster & Node Status ──

# Check cluster status
gcloud container clusters describe $CLUSTER_NAME \
    --location=$REGION --project=$PROJECT_ID \
    --format="yaml(status, currentNodeCount)"

# List all nodes and their GPUs
kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,\
GPU:.status.allocatable.nvidia\.com/gpu,\
TYPE:.metadata.labels.cloud\.google\.com/gke-accelerator"

# Check node details (GPU info, taints, conditions)
kubectl describe node <node-name>

# ── Pod & Job Status ──

# Why is my Pod pending?
kubectl describe pod <pod-name> | grep -A 10 "Events"

# Get job logs
kubectl logs job/<job-name>

# ── DWS & Kueue Status ──

# Check Kueue workloads (shows admission status)
kubectl get workloads -A -o wide

# Check DWS provisioning requests
kubectl get provisioningrequests -A -o wide

# Kueue controller logs
kubectl logs -n kueue-system -l control-plane=controller-manager --tail=100

# ── GPU Quota ──

# Check GPU quota
gcloud compute regions describe $REGION \
    --format="yaml(quotas)" --project=$PROJECT_ID | grep -i -A2 gpu

# Check active resize requests quota (for DWS)
gcloud compute project-info describe \
    --format="yaml(quotas)" --project=$PROJECT_ID | grep -i -A2 resize
```

---

## 14. References

### GKE Fundamentals

- [Choose a GKE Mode of Operation](https://cloud.google.com/kubernetes-engine/docs/concepts/choose-cluster-mode) — Autopilot vs Standard
- [Compare Autopilot and Standard Features](https://cloud.google.com/kubernetes-engine/docs/resources/autopilot-standard-feature-comparison)
- [Create an Autopilot Cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-an-autopilot-cluster)
- [Create a Standard Cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-regional-cluster)
- [GKE Pricing](https://cloud.google.com/kubernetes-engine/pricing)

### GPUs on GKE

- [Deploy GPUs in Autopilot](https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-gpus)
- [Deploy GPUs in Standard](https://cloud.google.com/kubernetes-engine/docs/how-to/gpus)
- [GPU Regions and Zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)
- [GPU Machine Types](https://cloud.google.com/compute/docs/gpus/about-gpus#gpu-machine-types)

### DWS on GKE

- [About Flex-Start in GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/dws)
- [Run a Small Batch Workload with Flex-Start](https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-training)
- [Run Large-Scale Workloads with Queued Provisioning](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest)
- [Flex-Start Inference on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-inference)
- [DWS Pricing](https://cloud.google.com/products/dws/pricing)

### Job Scheduling

- [Kueue Documentation](https://kueue.sigs.k8s.io/)
- [JobSet Documentation](https://github.com/kubernetes-sigs/jobset)
- [Best Practices for Batch Workloads on GKE](https://cloud.google.com/kubernetes-engine/docs/best-practices/batch-platform-on-gke)

### Related Guides in This Repository

- [DWS Concepts](../dws/) — Capacity acquisition models, pricing, compliance, data residency
- [Cluster Toolkit](../cluster-toolkit/) — Production-ready GKE clusters with Terraform blueprints
- [XPK](../xpk/) — Quick PoC GKE clusters with Python CLI
- [Deployment Methods Overview](../) — Compare all deployment methods
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket for training data
- [Zero Trust IAP Access](../../02-core-infrastructure/zero-trust-iap-access/README.md) — Securing cluster access

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies, verify GPU availability in your target zones, and review [GKE pricing](https://cloud.google.com/kubernetes-engine/pricing) and [DWS pricing](https://cloud.google.com/products/dws/pricing) before deploying workloads. Flex-start features marked as Preview are subject to change.
