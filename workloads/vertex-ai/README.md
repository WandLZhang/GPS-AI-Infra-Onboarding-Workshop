# Vertex AI — Serverless DWS Training (FLEX_START)

> Submit GPU training jobs with zero infrastructure management. Vertex AI integrates DWS natively — set the scheduling strategy to `FLEX_START` and Vertex AI handles queuing, provisioning, and resource lifecycle automatically.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [When to Use](#2-when-to-use)
3. [Supported GPUs & Requirements](#3-supported-gpus--requirements)
4. [Quota Note](#4-quota-note)
5. [Examples](#5-examples)
6. [Best Practices](#6-best-practices)
7. [Limitations](#7-limitations)
8. [References](#8-references)

---

## 1. Overview

Vertex AI integrates with [Dynamic Workload Scheduler (DWS)](../dws/) natively for **serverless training jobs**. By setting the scheduling strategy to `FLEX_START`, Vertex AI queues your training job and runs it when GPU resources become available — with zero infrastructure management.

### Key Points

- **Serverless** — no clusters, node pools, MIGs, or Slurm to manage.
- **Fastest time to first job** — submit a training job in minutes.
- **DWS integrated** — FLEX_START queues and provisions automatically.
- **Distributed support** — multi-node jobs wait until all nodes are provisioned simultaneously.

### How It Fits

```
┌───────────────────────────────────────────────────────────────────┐
│           Capacity Model        ×        Deployment Method        │
│                                                                   │
│   DWS Flex-start (queued,          Vertex AI                      │
│   up to 53% discount)      →      (FLEX_START custom jobs)        │
│                                                                   │
│   Zero infrastructure management, fully managed                  │
│   Up to 7-day job timeout                                        │
└───────────────────────────────────────────────────────────────────┘
```

> For DWS concepts, pricing, and compliance guidance, see the [DWS Guide](../dws/).

---

## 2. When to Use

| Scenario | Why Vertex AI DWS |
|---|---|
| **Serverless training** | No clusters, node pools, or MIGs to manage |
| **Fastest time to first job** | Submit a training job in minutes — Vertex AI handles everything |
| **Teams without infra expertise** | Data scientists can submit DWS jobs without K8s or Compute Engine knowledge |
| **Hyperparameter tuning** | Works with `HyperparameterTuningJob` and `TrainingPipeline` |
| **Distributed training** | Multi-node jobs wait until all nodes are provisioned simultaneously |

### When NOT to Use

| Scenario | Better Alternative |
|---|---|
| Need raw VM control | [Compute Engine](../compute-engine-Managed%20Instance%20Groups/) |
| Need Kubernetes-native pipelines | [Cluster Toolkit](../cluster-toolkit/) or [XPK](../xpk/) |
| Need Slurm job scheduling | [Cluster Director](../cluster-director/) |
| Need guaranteed start time | [Calendar Mode](../compute-engine-future-reservations/) |
| Inference / serving workloads | [Cluster Toolkit](../cluster-toolkit/) (GKE) |

---

## 3. Supported GPUs & Requirements

### Supported GPUs

L4, A100, H100, H200, B200

### Requirements

- Maximum job timeout of **7 days or less**
- Same machine configuration for **all worker pools**
- Sufficient **preemptible quota** (see [Quota Note](#4-quota-note) below)

---

## 4. Quota Note

> When submitting via DWS on Vertex AI, the job consumes **preemptible** quota (e.g., `custom_model_training_preemptible_nvidia_h100_gpus`) instead of on-demand quota. Despite the name, **your resources are not preemptible** — they behave like standard resources. Ensure your preemptible quotas are increased before submitting.

---

## 5. Examples

### Example: gcloud CLI

Create a `config.yaml`:

```yaml
workerPoolSpecs:
  machineSpec:
    machineType: a2-highgpu-1g
    acceleratorType: NVIDIA_TESLA_A100
    acceleratorCount: 1
  replicaCount: 1
  containerSpec:
    imageUri: gcr.io/your-project/training-image:latest
scheduling:
  strategy: FLEX_START
  maxWaitDuration: 7200s      # Wait up to 2 hours for resources
```

```bash
gcloud ai custom-jobs create \
    --region=us-central1 \
    --display-name="DWS Training Job" \
    --config=config.yaml
```

### Example: Python SDK

```python
from google.cloud import aiplatform
from google.cloud.aiplatform_v1.types import custom_job as gca_custom_job

aiplatform.init(
    project="your-project-id",
    location="us-central1",
    staging_bucket="gs://your-staging-bucket",
)

job = aiplatform.CustomJob.from_local_script(
    display_name="dws-training-job",
    script_path="train.py",
    container_uri="us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest",
    machine_type="a2-highgpu-1g",
    accelerator_type="NVIDIA_TESLA_A100",
    accelerator_count=1,
)

job.run(
    service_account="your-sa@your-project.iam.gserviceaccount.com",
    max_wait_duration=1800,  # seconds
    scheduling_strategy=gca_custom_job.Scheduling.Strategy.FLEX_START,
)
```

### Example: REST API

```json
{
  "displayName": "DWS Training Job",
  "jobSpec": {
    "workerPoolSpecs": [{
      "machineSpec": {
        "machineType": "a2-highgpu-1g",
        "acceleratorType": "NVIDIA_TESLA_A100",
        "acceleratorCount": 1
      },
      "replicaCount": 1,
      "containerSpec": {
        "imageUri": "us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-1:latest"
      }
    }],
    "scheduling": {
      "maxWaitDuration": "1800s",
      "strategy": "FLEX_START"
    }
  }
}
```

---

## 6. Best Practices

| Best Practice | Detail |
|---|---|
| **Set `maxWaitDuration` appropriately** | Default is 1 day; set to `0` for indefinite wait, or a specific duration to bound wait time |
| **Always checkpoint** | DWS VMs are deleted at end of job. Checkpoint frequently to GCS |
| **Request preemptible quota in advance** | Vertex AI DWS uses preemptible quota names — request via [Quota console](https://console.cloud.google.com/iam-admin/quotas) |
| **Use same machine config for all workers** | Required for distributed training — all worker pools must match |
| **Enable required APIs** | `gcloud services enable aiplatform.googleapis.com compute.googleapis.com` |
| **Test with small configs first** | Validate your container image and training script before scaling up |

---

## 7. Limitations

| Limitation | Detail |
|---|---|
| **7-day max job timeout** | Jobs run for up to 7 days maximum |
| **Same machine config required** | All worker pools must use the same machine configuration |
| **Preemptible quota naming** | Uses preemptible quota names despite resources not being preemptible |
| **Vertex AI management fees** | DWS pricing + [serverless training management fees](https://cloud.google.com/vertex-ai/pricing#custom-trained_models) |
| **No inference serving** | FLEX_START is for training jobs only |

---

## 8. References

### Official Documentation

- [Vertex AI DWS for Training Jobs](https://cloud.google.com/vertex-ai/docs/training/schedule-jobs-dws)
- [DWS Pricing](https://cloud.google.com/products/dws/pricing)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/pricing#custom-trained_models)

### Related Guides in This Repository

- [DWS Concepts](../dws/) — Capacity acquisition models, pricing, compliance
- [Deployment Methods Overview](../) — Compare all deployment methods
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies, verify GPU availability, and review [Vertex AI pricing](https://cloud.google.com/vertex-ai/pricing) and [DWS pricing](https://cloud.google.com/products/dws/pricing) before deploying.
