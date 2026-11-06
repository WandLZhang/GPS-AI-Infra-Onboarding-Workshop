# Colab Enterprise — GPU-Accelerated Notebooks on Google Cloud

> Run interactive notebooks with GPU accelerators in a fully managed, secure environment. Colab Enterprise provides notebook-first development with enterprise-grade IAM, networking, CMEK, and the ability to leverage Compute Engine reservations and DWS-backed training from within your notebook.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [When to Use](#2-when-to-use)
3. [Accelerator Options](#3-accelerator-options)
4. [Creating GPU Runtime Templates](#4-creating-gpu-runtime-templates)
5. [Using Reservations for Guaranteed GPU Access](#5-using-reservations-for-guaranteed-gpu-access)
6. [DWS Integration Patterns](#6-dws-integration-patterns)
7. [Scheduled Notebook Runs](#7-scheduled-notebook-runs)
8. [Networking & Security](#8-networking--security)
9. [Quota & Pricing](#9-quota--pricing)
10. [Best Practices](#10-best-practices)
11. [Limitations](#11-limitations)
12. [References](#12-references)

---

## 1. Overview

**Colab Enterprise** is Google Cloud's managed, collaborative notebook environment built on top of Vertex AI. It provides the familiar Jupyter/Colab notebook experience with the security and compliance capabilities of Google Cloud — IAM-based access control, VPC networking, CMEK encryption, and regional storage.

### Key Points

- **Managed compute** — Colab Enterprise provisions and manages runtimes (VMs) for you. No clusters, node pools, or infrastructure to manage.
- **GPU-accelerated runtimes** — Attach accelerators (T4, L4, V100, A100) to your notebook runtimes via runtime templates.
- **Enterprise security** — IAM access control, VPC networking, CMEK, Access Transparency, and Assured Workloads support.
- **Integrated with Vertex AI & BigQuery** — Seamless access to Google Cloud services from your notebook.
- **Scheduled execution** — Run notebooks on a one-off or recurring schedule with results stored in GCS.

### Colab Enterprise vs. Colab (Colaboratory)

Colab Enterprise is **different from** the free [Google Colaboratory](https://colab.google/). Both have specific advantages:

| Component | Colab Enterprise | Colab (Free/Pro) |
|---|---|---|
| **Storage** | Regional storage in Dataform | Google Drive (no regionalization) |
| **Access control** | Managed by IAM | Google Drive sharing |
| **Security & networking** | Google Cloud VPC, CMEK, IAP | Google Drive-based, internet always available |
| **Accelerators** | V100, T4, A100, L4 (via templates) | T4 (free), A100/V100 (Pro) |
| **Reservations** | ✅ Compute Engine reservations | ❌ |
| **Compliance** | FedRAMP, CMEK, Access Transparency | ❌ |
| **Scheduled runs** | ✅ One-off and recurring | ❌ |
| **Support** | Google Cloud support | Community/feedback only |

### How It Fits

```
┌───────────────────────────────────────────────────────────────────┐
│           Capacity Model        ×        Deployment Method        │
│                                                                   │
│   On-demand / Reservations  →    Colab Enterprise                 │
│                                  (Interactive GPU notebooks)      │
│                                                                   │
│   Develop interactively, then deploy training to:                │
│   • Vertex AI (FLEX_START)   — serverless DWS training           │
│   • GKE (Cluster Toolkit)   — production DWS training            │
│   • Compute Engine (MIGs)   — raw VM DWS training                │
└───────────────────────────────────────────────────────────────────┘
```

> For DWS concepts, pricing, and compliance guidance, see the [DWS Guide](../dws/).

---

## 2. When to Use

| Scenario | Why Colab Enterprise |
|---|---|
| **Interactive ML development** | Notebook-first experience — prototype, debug, and visualize with GPU acceleration |
| **Teams without infra expertise** | Data scientists and researchers can access GPUs without K8s, Terraform, or Slurm knowledge |
| **Rapid prototyping & PoC** | Fastest path from idea to GPU-accelerated code — create a notebook and connect |
| **Notebook-based pipelines** | Schedule notebook runs for automated data processing, retraining, or reporting |
| **Enterprise compliance** | IAM, VPC, CMEK, Access Transparency for regulated environments |
| **Develop → Deploy pattern** | Prototype in Colab Enterprise, then deploy production training via Vertex AI FLEX_START or GKE DWS |
| **Fine-tuning small/medium models** | Single-GPU fine-tuning (LoRA, QLoRA) on L4, T4, A100 — no distributed setup needed |

### When NOT to Use

| Scenario | Better Alternative |
|---|---|
| Large-scale distributed training (multi-node) | [Vertex AI](../vertex-ai/) (FLEX_START), [Cluster Toolkit](../cluster-toolkit/), [Cluster Director](../cluster-director/) |
| Production inference / serving | [Cluster Toolkit](../cluster-toolkit/) (GKE) |
| H100 / H200 / B200 / TPU workloads | [Cluster Toolkit](../cluster-toolkit/), [XPK](../xpk/), [Compute Engine](../compute-engine-Managed%20Instance%20Groups/) |
| Long-running training (> 18 hours) | [Vertex AI](../vertex-ai/), [Cluster Toolkit](../cluster-toolkit/), [Compute Engine](../compute-engine-Managed%20Instance%20Groups/) |
| Slurm-native HPC workloads | [Cluster Director](../cluster-director/) |
| Guaranteed start time with DWS Calendar Mode | [Calendar Mode](../compute-engine-future-reservations/) |

---

## 3. Accelerator Options

Colab Enterprise offers GPU accelerators through two mechanisms: **default GPU runtimes** (one-click) and **custom runtime templates** (full control).

### Option 1: Default GPU Runtimes (One-Click)

> **Status:** Preview

Default GPU runtimes provide the simplest path to GPU-accelerated notebooks. An administrator enables them once, and all users in the project can switch to a GPU runtime with a single click.

| Region Type | Machine Type | Accelerator | Data Disk |
|---|---|---|---|
| Regions with L4 support | `g2-standard-4` | 1 × NVIDIA L4 (24 GB) | 100 GB pd-balanced |
| Regions with T4 support (no L4) | `n1-standard-4` | 1 × NVIDIA T4 (16 GB) | 100 GB pd-standard |
| Regions without L4 or T4 | Not supported | — | — |

**How to enable:**

```
1. Open a notebook in Colab Enterprise
2. Click "Connect" to start the default runtime
3. Click "Switch to L4" (or "Switch to T4") in the top-right corner
4. Colab Enterprise creates a GPU-enabled default runtime template
5. All project users can now switch to the GPU default runtime
```

> **Note:** Requires the `roles/aiplatform.colabEnterpriseAdmin` role or `aiplatform.notebookRuntimeTemplates.create` permission for the initial enablement.

### Option 2: Custom Runtime Templates (Full Control)

Custom runtime templates give you full control over the machine type, accelerator type and count, disk configuration, networking, and security settings.

#### Supported Accelerator Types

| Accelerator Type | GPU Model | GPU Memory | Compatible Machine Types | Best For |
|---|---|---|---|---|
| `NVIDIA_L4` | NVIDIA L4 | 24 GB GDDR6 | `g2-standard-*` | Inference, small fine-tuning, cost-effective GPU |
| `NVIDIA_TESLA_T4` | NVIDIA T4 | 16 GB GDDR6 | `n1-standard-*` | Inference, light training, budget-friendly |
| `NVIDIA_TESLA_V100` | NVIDIA V100 | 16 GB HBM2 | `n1-standard-*` | Training, mixed precision, legacy workloads |
| `NVIDIA_TESLA_A100` | NVIDIA A100 | 40 GB HBM2e | `a2-highgpu-*` | Training, fine-tuning medium models |
| `NVIDIA_A100_80GB` | NVIDIA A100 | 80 GB HBM2e | `a2-ultragpu-*` | Training, fine-tuning large models, large batch inference |

#### Accelerator × Machine Type Matrix

| Accelerator | 1 GPU | 2 GPUs | 4 GPUs | 8 GPUs | Machine Family |
|---|:---:|:---:|:---:|:---:|---|
| **L4** | ✅ | ✅ | ✅ | ✅ | g2-standard |
| **T4** | ✅ | ✅ | ✅ | ✅ | n1-standard / n1-highmem |
| **V100** | ✅ | ✅ | ✅ | ✅ | n1-standard / n1-highmem |
| **A100 40GB** | ✅ | ✅ | ✅ | ✅ | a2-highgpu |
| **A100 80GB** | ✅ | ✅ | ✅ | ✅ | a2-ultragpu |

> **Not supported in Colab Enterprise:** H100, H200, B200, TPUs. For these accelerators, use [Vertex AI](../vertex-ai/), [Cluster Toolkit](../cluster-toolkit/), or [Compute Engine](../compute-engine-Managed%20Instance%20Groups/).

#### Workload Sizing Guide for Colab Enterprise

| Model / Task | Recommended Accelerator | Count | Rationale |
|---|---|---|---|
| **Gemma 3 4B fine-tune (LoRA)** | L4 or T4 | 1 | ~8 GB model weights (BF16); LoRA adds minimal overhead |
| **Gemma 3 27B inference** | A100 40GB | 1 | ~54 GB BF16 → quantize to INT8 (~27 GB) to fit in 40 GB |
| **Llama 3.3 70B inference (INT4)** | A100 80GB | 1 | ~35 GB INT4 weights fit in 80 GB memory |
| **Stable Diffusion XL inference** | L4 | 1 | ~7 GB model; L4 is cost-effective with good FP8 support |
| **Data preprocessing with GPU** | T4 or L4 | 1 | RAPIDS/cuDF for GPU-accelerated data processing |
| **Small model training (< 1B)** | L4 or T4 | 1 | Fits comfortably; L4 offers better price-performance |
| **Medium model fine-tune (7B, full)** | A100 40GB | 2–4 | ~126 GB for full fine-tune with Adam; distribute across GPUs |

> For detailed memory sizing formulas, see the [Accelerator Selection Guide](../../01-foundational-tools/accelerator-guide/).

---

## 4. Creating GPU Runtime Templates

### Console

1. Go to **Vertex AI → Colab Enterprise → Runtime templates**
   ([Direct link](https://console.cloud.google.com/vertex-ai/colab/runtime-templates))
2. Click **+ New template**
3. Enter a **Display name** and select a **Region**
4. Under **Configure compute**:
   - Select a **Machine type** (e.g., `a2-highgpu-1g`)
   - Select **Accelerator type** (e.g., `NVIDIA_TESLA_A100`)
   - Select **Accelerator count** (e.g., `1`)
5. Configure **Data disk** (type and size)
6. Configure **Networking and security** as needed
7. Click **Create**

### gcloud CLI

#### Example: L4 GPU Runtime

```bash
gcloud beta colab runtime-templates create \
    --display-name="L4 GPU Runtime" \
    --machine-type=g2-standard-8 \
    --accelerator-type=NVIDIA_L4 \
    --accelerator-count=1 \
    --disk-type=PD_BALANCED \
    --disk-size-gb=200 \
    --region=us-central1
```

#### Example: T4 GPU Runtime

```bash
gcloud beta colab runtime-templates create \
    --display-name="T4 GPU Runtime" \
    --machine-type=n1-standard-8 \
    --accelerator-type=NVIDIA_TESLA_T4 \
    --accelerator-count=1 \
    --disk-type=PD_STANDARD \
    --disk-size-gb=200 \
    --region=us-central1
```

#### Example: A100 40GB GPU Runtime

```bash
gcloud beta colab runtime-templates create \
    --display-name="A100 40GB Runtime" \
    --machine-type=a2-highgpu-1g \
    --accelerator-type=NVIDIA_TESLA_A100 \
    --accelerator-count=1 \
    --disk-type=PD_SSD \
    --disk-size-gb=500 \
    --region=us-central1
```

#### Example: A100 80GB GPU Runtime

```bash
gcloud beta colab runtime-templates create \
    --display-name="A100 80GB Runtime" \
    --machine-type=a2-ultragpu-1g \
    --accelerator-type=NVIDIA_A100_80GB \
    --accelerator-count=1 \
    --disk-type=PD_SSD \
    --disk-size-gb=500 \
    --region=us-central1
```

#### Example: Multi-GPU A100 Runtime (4 GPUs)

```bash
gcloud beta colab runtime-templates create \
    --display-name="A100 4-GPU Runtime" \
    --machine-type=a2-highgpu-4g \
    --accelerator-type=NVIDIA_TESLA_A100 \
    --accelerator-count=4 \
    --disk-type=PD_SSD \
    --disk-size-gb=1000 \
    --region=us-central1
```

#### Example: Secure Runtime (No Public Internet, CMEK)

```bash
gcloud beta colab runtime-templates create \
    --display-name="Secure A100 Runtime" \
    --machine-type=a2-highgpu-1g \
    --accelerator-type=NVIDIA_TESLA_A100 \
    --accelerator-count=1 \
    --disk-type=PD_SSD \
    --disk-size-gb=500 \
    --no-enable-internet-access \
    --enable-secure-boot \
    --network=projects/$PROJECT_ID/global/networks/$NETWORK \
    --subnetwork=projects/$PROJECT_ID/regions/us-central1/subnetworks/$SUBNET \
    --subnetwork-region=us-central1 \
    --kms-key=projects/$PROJECT_ID/locations/us-central1/keyRings/$KEYRING/cryptoKeys/$KEY \
    --region=us-central1
```

### Terraform

```hcl
resource "google_colab_runtime_template" "a100_runtime" {
  name         = "a100-training-runtime"
  display_name = "A100 Training Runtime"
  location     = "us-central1"
  description  = "Runtime template with A100 GPU for model training"

  machine_spec {
    machine_type      = "a2-highgpu-1g"
    accelerator_type  = "NVIDIA_TESLA_A100"
    accelerator_count = 1
  }

  data_persistent_disk_spec {
    disk_type    = "pd-ssd"
    disk_size_gb = 500
  }

  network_spec {
    enable_internet_access = true
    network                = google_compute_network.my_network.id
    subnetwork             = google_compute_subnetwork.my_subnetwork.id
  }

  idle_shutdown_config {
    idle_timeout = "7200s"  # 2 hours
  }

  shielded_vm_config {
    enable_secure_boot = true
  }

  labels = {
    team        = "ml-research"
    environment = "development"
  }
}
```

### After Creating the Template

1. **Grant access** — Share the runtime template with users via IAM:
   - Users need `aiplatform.notebookRuntimes.assign` on the project
   - Users need `aiplatform.notebookRuntimeTemplates.apply` on the template
   - The `roles/aiplatform.colabEnterpriseUser` role includes both permissions

2. **Create a runtime** — Users create a runtime from the template in the Colab Enterprise UI

3. **Connect and use** — Connect a notebook to the runtime and run GPU-accelerated code

---

## 5. Using Reservations for Guaranteed GPU Access

Compute Engine [reservations](https://cloud.google.com/compute/docs/instances/reservations-overview) guarantee that GPU resources are available when you need them. Colab Enterprise supports reservations through runtime templates.

### Why Use Reservations with Colab Enterprise?

| Benefit | Detail |
|---|---|
| **Guaranteed availability** | Reserved GPUs are always available — no "resource unavailable" errors |
| **Predictable capacity** | Teams can rely on GPU access for scheduled work |
| **Same on-demand pricing** | Reservations charge the same as on-demand (with applicable discounts) |

### Step 1: Create a Compute Engine Reservation

```bash
# Create a single-project reservation for A100 GPUs
gcloud compute reservations create colab-a100-reservation \
    --zone=us-central1-a \
    --machine-type=a2-highgpu-1g \
    --accelerator=count=1,type=nvidia-tesla-a100 \
    --vm-count=2 \
    --description="Reserved A100s for Colab Enterprise notebooks"
```

### Step 2: Create a Runtime Template with the Reservation

In the **Google Cloud Console**:

1. Go to **Vertex AI → Colab Enterprise → Runtime templates**
2. Click **+ New template**
3. Set the **Machine type** to match the reservation exactly (e.g., `a2-highgpu-1g`)
4. Set **Accelerator type** and **count** to match (e.g., `NVIDIA_TESLA_A100`, count `1`)
5. In the **Reservations** dropdown, select your specific reservation or **"Use automatically selected reservations"**
6. Complete the rest and click **Create**

> **⚠️ Important:** The runtime template's machine type, accelerator type, and accelerator count **must exactly match** the reservation's VM properties. Mismatches will cause runtime creation to fail.

### Step 3: Use the Reservation

1. Create a runtime from the reservation-backed template
2. Open or create a notebook
3. Connect to the runtime — it consumes a reserved VM slot
4. When you disconnect or the runtime shuts down, the reservation slot becomes available again

### Shared Reservations

For multi-project organizations, use [shared reservations](https://cloud.google.com/compute/docs/instances/reservations-shared) to share GPU capacity across projects:

```bash
# Create a shared reservation
gcloud compute reservations create shared-a100-reservation \
    --zone=us-central1-a \
    --machine-type=a2-highgpu-1g \
    --accelerator=count=1,type=nvidia-tesla-a100 \
    --vm-count=5 \
    --share-setting=projects \
    --share-with=project-a,project-b,project-c \
    --description="Shared A100s for Colab Enterprise across teams"
```

---

## 6. DWS Integration Patterns

Colab Enterprise does **not** have native DWS flex-start support in its runtimes. However, you can leverage DWS effectively through several patterns that combine Colab Enterprise's interactive development experience with DWS's cost-effective GPU provisioning.

### Pattern 1: Reservation-Backed Runtimes (Guaranteed Access)

Use Compute Engine reservations with Colab Enterprise runtime templates for guaranteed GPU access at on-demand pricing. See [§5 Using Reservations](#5-using-reservations-for-guaranteed-gpu-access) above.

```
┌───────────────────────────────────────────────────────────────────┐
│  Reservation-Backed Colab Enterprise                              │
│                                                                   │
│  Reservation (A100 × 2)  ──→  Runtime Template  ──→  Notebook    │
│  (guaranteed capacity)        (matches reservation)   (GPU access)│
│                                                                   │
│  ✅ Guaranteed availability                                       │
│  ✅ On-demand pricing (with applicable discounts)                 │
│  ❌ No DWS discount                                               │
└───────────────────────────────────────────────────────────────────┘
```

**Best for:** Teams that need reliable GPU access for interactive development and can justify on-demand costs.

### Pattern 2: Develop in Colab → Deploy to Vertex AI FLEX_START

Use Colab Enterprise as your interactive development environment, then submit production training jobs to Vertex AI with DWS FLEX_START scheduling for up to 53% discount.

```
┌───────────────────────────────────────────────────────────────────┐
│  Develop → Deploy (Vertex AI DWS)                                 │
│                                                                   │
│  Colab Enterprise          Vertex AI Custom Job                   │
│  (interactive dev)    ──→  (FLEX_START)                           │
│  • Prototype on L4/T4     • Submit via Python SDK                │
│  • Debug & iterate        • Up to 53% discount                   │
│  • Visualize results      • Up to 7-day duration                 │
│                            • A100, H100, H200, B200              │
└───────────────────────────────────────────────────────────────────┘
```

**Example: Submit a DWS training job from a Colab Enterprise notebook**

```python
# In your Colab Enterprise notebook:
from google.cloud import aiplatform
from google.cloud.aiplatform_v1.types import custom_job as gca_custom_job

aiplatform.init(
    project="your-project-id",
    location="us-central1",
    staging_bucket="gs://your-staging-bucket",
)

# Submit training job with DWS FLEX_START
job = aiplatform.CustomJob.from_local_script(
    display_name="dws-training-from-colab",
    script_path="train.py",            # Your training script
    container_uri="us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest",
    machine_type="a3-megagpu-8g",      # H100 — not available in Colab runtimes!
    accelerator_type="NVIDIA_H100_80GB",
    accelerator_count=8,
)

job.run(
    service_account="your-sa@your-project.iam.gserviceaccount.com",
    max_wait_duration=3600,  # Wait up to 1 hour for DWS provisioning
    scheduling_strategy=gca_custom_job.Scheduling.Strategy.FLEX_START,
)

# Monitor the job
print(f"Job state: {job.state}")
print(f"Job resource: {job.resource_name}")
```

**Best for:** Teams that want interactive notebook development on smaller GPUs (L4/T4/A100) and production training on larger GPUs (H100, H200, B200) with DWS discounts.

> For full Vertex AI DWS details, see the [Vertex AI Guide](../vertex-ai/).

### Pattern 3: Develop in Colab → Deploy to GKE with DWS

Use Colab Enterprise for prototyping, then deploy production workloads to a GKE cluster provisioned with DWS flex-start via Cluster Toolkit or XPK.

```
┌───────────────────────────────────────────────────────────────────┐
│  Develop → Deploy (GKE DWS)                                      │
│                                                                   │
│  Colab Enterprise          GKE + DWS Flex-start                  │
│  (interactive dev)    ──→  (via Cluster Toolkit / XPK)           │
│  • Prototype on L4/A100   • Submit via kubectl / xpk             │
│  • Develop training code  • Kueue job scheduling                 │
│  • Test with small data   • Reservation + DWS fallback           │
│                            • Full Kubernetes ecosystem            │
└───────────────────────────────────────────────────────────────────┘
```

**Example: Submit a GKE job from a Colab Enterprise notebook**

```python
# In your Colab Enterprise notebook:
import subprocess

# Authenticate kubectl to your GKE cluster
subprocess.run([
    "gcloud", "container", "clusters", "get-credentials",
    "my-gpu-cluster",
    "--zone=us-central1-a",
    "--project=your-project-id"
], check=True)

# Apply a Kueue-managed Job with DWS flex-start
job_yaml = """
apiVersion: batch/v1
kind: Job
metadata:
  name: training-job
  labels:
    kueue.x-k8s.io/queue-name: dws-local-queue
spec:
  template:
    spec:
      containers:
      - name: training
        image: us-docker.pkg.dev/your-project/repo/training:latest
        resources:
          limits:
            nvidia.com/gpu: 8
      restartPolicy: Never
      nodeSelector:
        cloud.google.com/gke-accelerator: nvidia-h100-80gb
"""

with open("/tmp/job.yaml", "w") as f:
    f.write(job_yaml)

subprocess.run(["kubectl", "apply", "-f", "/tmp/job.yaml"], check=True)
```

**Best for:** Teams with existing GKE infrastructure that want the notebook-first development experience.

> For full GKE DWS details, see the [Cluster Toolkit Guide](../cluster-toolkit/) or [XPK Guide](../xpk/).

### DWS Integration Decision Guide

```
          Do you need GPU access for
          interactive notebook work?
                     │
          ┌──────────┴──────────┐
         Yes                    No
          │                      │
    Colab Enterprise        Use Vertex AI FLEX_START
    (L4/T4/A100)            or GKE DWS directly
          │
    Do you also need
    large-scale training?
          │
   ┌──────┴──────┐
  Yes            No
   │              │
   │         Use Colab Enterprise
   │         with reservations
   │         (on-demand pricing)
   │
  What platform for
  production training?
          │
   ┌──────┴──────────┐
   │                  │
Serverless         Kubernetes
   │                  │
Vertex AI          GKE + Cluster
FLEX_START         Toolkit / XPK
(Pattern 2)        (Pattern 3)
```

---

## 7. Scheduled Notebook Runs

Colab Enterprise supports automated notebook execution — run a notebook immediately (one-off) or on a recurring schedule. Results are stored in Cloud Storage.

### One-Off Execution

#### Console

1. Go to **Colab Enterprise → My notebooks**
2. Click the **⋮** menu next to a notebook → **Schedule**
3. Enter a **Schedule name**
4. Select a **Runtime template** (this determines the GPU configuration)
5. Select **One-off** under Run schedule
6. Choose a **Cloud Storage output location** for results
7. Click **Submit**

#### gcloud CLI

```bash
gcloud colab executions create \
    --display-name="one-off-training-run" \
    --notebook-runtime-template=RUNTIME_TEMPLATE_ID \
    --gcs-notebook-uri="gs://my-bucket/notebooks/train.ipynb" \
    --gcs-output-uri="gs://my-bucket/results/" \
    --user-email=user@example.com \
    --project=$PROJECT_ID \
    --region=us-central1
```

### Recurring Execution

#### Console

1. Follow the same steps as one-off, but select **Recurring**
2. Set the schedule interval (e.g., daily, weekly)
3. Click **Submit**

#### gcloud CLI

```bash
gcloud colab schedules create \
    --display-name="weekly-retraining" \
    --cron-schedule="00 02 * * MON" \
    --execution-display-name="weekly-retrain-run" \
    --notebook-runtime-template=RUNTIME_TEMPLATE_ID \
    --gcs-notebook-uri="gs://my-bucket/notebooks/retrain.ipynb" \
    --gcs-output-uri="gs://my-bucket/results/" \
    --user-email=user@example.com \
    --project=$PROJECT_ID \
    --region=us-central1
```

### View Results

```bash
# List all notebook execution results
gcloud colab executions list \
    --project=$PROJECT_ID \
    --region=us-central1

# Filter by schedule name
gcloud colab executions list \
    --project=$PROJECT_ID \
    --region=us-central1 \
    --filter="scheduleResourceName: weekly-retraining"
```

---

## 8. Networking & Security

### Security Configuration Options

| Feature | Default | Configurable | Detail |
|---|---|---|---|
| **VPC networking** | Default VPC | ✅ | Specify custom network and subnetwork |
| **Public internet access** | Enabled | ✅ | Disable for air-gapped environments |
| **End-user credentials (EUC)** | Enabled | ✅ | Disable and use service accounts instead |
| **CMEK encryption** | Google-managed | ✅ | Use your own Cloud KMS keys |
| **Secure Boot** | Disabled | ✅ | Enable for Shielded VM support |
| **Network tags** | None | ✅ | Apply Compute Engine network tags |
| **Access Transparency** | Supported | ✅ | Logs when Google personnel access your content |

### IAM Roles

| Role | Description | Typical User |
|---|---|---|
| `roles/aiplatform.colabEnterpriseAdmin` | Full admin — create templates, manage runtimes | Platform admins |
| `roles/aiplatform.colabEnterpriseUser` | Use templates, create runtimes, run notebooks | Data scientists, ML engineers |
| `roles/compute.admin` | Required for reservation management | Platform admins |

### Secure Runtime Template (No Public Internet, CMEK)

```bash
gcloud beta colab runtime-templates create \
    --display-name="Secure GPU Runtime" \
    --machine-type=a2-highgpu-1g \
    --accelerator-type=NVIDIA_TESLA_A100 \
    --accelerator-count=1 \
    --no-enable-internet-access \
    --no-enable-euc \
    --enable-secure-boot \
    --network=projects/$PROJECT_ID/global/networks/secure-vpc \
    --subnetwork=projects/$PROJECT_ID/regions/us-central1/subnetworks/secure-subnet \
    --subnetwork-region=us-central1 \
    --kms-key=projects/$PROJECT_ID/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-key \
    --region=us-central1
```

---

## 9. Quota & Pricing

### Quota

Colab Enterprise runtimes consume **Compute Engine quota**. Ensure you have sufficient quota for your desired accelerator:

| Accelerator | Quota Name | Check Command |
|---|---|---|
| T4 | `NVIDIA_T4_GPUS` | `gcloud compute regions describe $REGION --format="yaml(quotas)"` |
| V100 | `NVIDIA_V100_GPUS` | Same as above |
| L4 | `NVIDIA_L4_GPUS` | Same as above |
| A100 40GB | `NVIDIA_A100_GPUS` | Same as above |
| A100 80GB | `NVIDIA_A100_80GB_GPUS` | Same as above |

Request quota increases via the [Quota console](https://console.cloud.google.com/iam-admin/quotas).

### Pricing

Colab Enterprise pricing has two components:

| Component | Detail |
|---|---|
| **Compute Engine resources** | Standard Compute Engine pricing for VMs, GPUs, and disks. Billed while the runtime is active. |
| **Colab Enterprise management fee** | Additional management fee on top of infrastructure costs. See [Colab Enterprise pricing](https://cloud.google.com/colab/pricing). |

> **Cost optimization tip:** Enable **idle shutdown** (default: 180 minutes) to automatically stop GPU runtimes when not in use. GPU runtimes are expensive — a single A100 80GB runtime costs significantly more per hour than a CPU-only runtime.

---

## 10. Best Practices

| Best Practice | Detail |
|---|---|
| **Use the right GPU for the task** | Don't use A100 for tasks that fit on T4/L4. Start small and scale up. |
| **Enable idle shutdown** | GPU runtimes are expensive. Default is 180 min; consider reducing for costly GPUs. |
| **Save work to durable storage** | Runtimes auto-delete after 18 hours. Save notebooks, data, and checkpoints to GCS. |
| **Use reservations for predictable workloads** | If your team needs daily GPU access, reservations prevent "resource unavailable" errors. |
| **Develop in Colab, train with DWS** | Prototype on L4/T4 in Colab, then submit large training jobs via Vertex AI FLEX_START for up to 53% discount. |
| **Match machine types exactly for reservations** | Runtime template machine type must exactly match the reservation — otherwise runtime creation fails. |
| **Use runtime templates for team standardization** | Create templates for common workload profiles (inference, training, data processing) and share via IAM. |
| **Enable secure boot and CMEK for compliance** | Required for FedRAMP and other regulated environments. |
| **Test with scheduled runs before production** | Validate notebook execution with a one-off run before setting up recurring schedules. |
| **Request GPU quota in advance** | GPU quota requests can take time to process. Request well before you need the accelerators. |

---

## 11. Limitations

| Limitation | Detail |
|---|---|
| **18-hour auto-deletion** | Runtimes are automatically deleted 18 hours after creation |
| **No H100/H200/B200** | Only V100, T4, A100, L4 accelerators are supported in runtime templates |
| **No TPU support** | TPUs are not available in Colab Enterprise runtimes |
| **No DWS flex-start** | DWS is not natively available for Colab Enterprise runtimes (use patterns in [§6](#6-dws-integration-patterns)) |
| **~20 MB notebook size limit** | Large notebooks may impact performance |
| **Single-node only** | Runtimes are single VMs — no multi-node distributed training |
| **Default GPU runtimes in Preview** | One-click GPU switching is a Preview feature with limited support |
| **Regional** | Runtime templates and runtimes are regional — notebook and runtime must be in the same region |
| **No persistent file changes** | Files uploaded to or modified on the runtime are lost when the runtime is deleted |

---

## 12. References

### Official Documentation

- [Introduction to Colab Enterprise](https://cloud.google.com/colab/docs/introduction)
- [Runtimes and Runtime Templates](https://cloud.google.com/colab/docs/runtimes)
- [Create a Runtime Template](https://cloud.google.com/colab/docs/create-runtime-template)
- [Enable Default Runtimes with GPUs](https://cloud.google.com/colab/docs/default-runtimes-with-gpus)
- [Use Reservations](https://cloud.google.com/colab/docs/reservations)
- [Schedule a Notebook Run](https://cloud.google.com/colab/docs/schedule-notebook-run)
- [Colab Enterprise Pricing](https://cloud.google.com/colab/pricing)
- [Colab Enterprise Locations](https://cloud.google.com/colab/docs/locations)
- [gcloud beta colab runtime-templates create](https://cloud.google.com/sdk/gcloud/reference/beta/colab/runtime-templates/create)

### Related Guides in This Repository

- [DWS Concepts](../dws/) — Capacity acquisition models, pricing, compliance
- [Vertex AI DWS Training](../vertex-ai/) — Serverless training with FLEX_START (deploy from Colab)
- [Cluster Toolkit](../cluster-toolkit/) — Production GKE clusters with DWS flex-start
- [XPK](../xpk/) — Quick PoC GKE clusters with DWS flex-start
- [Accelerator Selection Guide](../../01-foundational-tools/accelerator-guide/) — GPU sizing, checkpointing, consumption models
- [Storage for AI Workloads](../../02-core-infrastructure/storage/) — GCSFuse, Rapid Cache, Rapid Bucket
- [Deployment Methods Overview](../) — Compare all deployment methods

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies, verify GPU availability and quota, and review [Colab Enterprise pricing](https://cloud.google.com/colab/pricing) and [Compute Engine pricing](https://cloud.google.com/compute/all-pricing) before deploying. Default GPU runtimes are a Preview feature and may have limited support.
