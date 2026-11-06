# Quota

Quota caps how many GPUs, TPUs and requests a project can use in each region or zone. Check it before you request capacity, and ask for an increase early.

## Quota Requirements by Deployment Method

| Deployment Method | Quota Required | Notes |
|---|---|---|
| **[Compute Engine](../5-run/vms/)** | Standard GPU quota (e.g., `NVIDIA_H100_GPUS`) | Request stays pending if insufficient quota |
| **[Calendar Mode](./calendar-mode/)** | No Compute Engine quota needed (reservation-bound model) | Only need quota for non-reservation resources (disks, IPs) |
| **[Cluster Toolkit](../5-run/kubernetes/cluster-toolkit/) / [XPK](../5-run/kubernetes/xpk/)** | `ACTIVE_RESIZE_REQUESTS` (default: 100/project) + GPU quota | GKE uses Compute Engine quota under the hood |
| **[Vertex AI](../5-run/managed-training-vertex-ai/)** | Preemptible Vertex AI quota (e.g., `custom_model_training_preemptible_nvidia_h100_gpus`) | Despite name, resources are NOT preemptible |

## View Current Quotas

```bash
# View all Compute Engine quotas for a project
gcloud compute project-info describe --project=$PROJECT_ID \
    --format="table(quotas.metric,quotas.limit,quotas.usage)"

# View GPU-specific quotas
gcloud compute project-info describe --project=$PROJECT_ID \
    --format="table(quotas.metric,quotas.limit,quotas.usage)" \
    | grep -i gpu

# View quotas for a specific region
gcloud compute regions describe us-central1 \
    --project=$PROJECT_ID \
    --format="table(quotas.metric,quotas.limit,quotas.usage)" \
    | grep -i gpu

# View TPU quotas
gcloud services quota list \
    --service=tpu.googleapis.com \
    --project=$PROJECT_ID
```

## Key GPU/TPU Quotas

| Quota | Scope | Description |
|---|---|---|
| `NVIDIA_H100_GPUS` | Per region | Max H100 GPUs in a region |
| `NVIDIA_H200_GPUS` | Per region | Max H200 GPUs in a region |
| `NVIDIA_A100_GPUS` | Per region | Max A100 GPUs in a region |
| `NVIDIA_L4_GPUS` | Per region | Max L4 GPUs in a region |
| `GPUS_ALL_REGIONS` | Global | Max GPUs across all regions |
| `PREEMPTIBLE_NVIDIA_H100_GPUS` | Per region | Max Spot/preemptible H100 GPUs |
| `TPU v6e cores per project per zone` | Per zone | Max TPU v6e cores |
| `TPU v5p cores per project per zone` | Per zone | Max TPU v5p cores |
| `TPU v5 lite pod cores per project per zone` | Per zone | Max TPU v5e cores |

## Request Quota Increases

```bash
# Request a GPU quota increase via the console
# Navigate to: IAM & Admin → Quotas → Filter by "GPU"
# Select the quota → Edit Quotas → Enter new limit → Submit

# Direct URL
# https://console.cloud.google.com/iam-admin/quotas?project=$PROJECT_ID
```

> **Best Practice:** Request only the quota you need. Lower quotas act as a natural spending cap — you physically cannot spin up more GPUs/TPUs than your quota allows.

Google's steps are in [Request a quota adjustment](https://cloud.google.com/docs/quotas/help/request_increase).

## Default TPU Quotas

| TPU Version | On-Demand Default | Preemptible Default |
|---|---|---|
| **v6e** | 512 cores/zone | 1,536 cores/zone |
| **v5p** | 128 cores/zone | 768 cores/zone |
| **v5e** | 512 cores/zone | 1,536 cores/zone |
| **v4** | 0 cores/zone | 0 cores/zone |

> **Note:** TPU v4 requires manual quota approval. All TPU v6e and v5p on-demand quota increases require manual approval (auto-approve threshold is 0).

## Monitor Quota Usage with Alerts

Set up alerts when quota usage approaches the limit:

```bash
# Create a Cloud Monitoring alert for GPU quota usage
# Navigate to: Monitoring → Alerting → Create Policy

# PromQL for GPU quota utilization
# serviceruntime.googleapis.com/quota/allocation/usage
# filtered by quota_metric containing "gpu"
```

**Recommended quota alerts:**

| Alert | Condition | Threshold | Action |
|---|---|---|---|
| **GPU quota > 80%** | Usage / Limit > 0.8 | Warning | Request quota increase proactively |
| **GPU quota > 95%** | Usage / Limit > 0.95 | Critical | Immediate review — jobs may fail |
| **TPU quota > 80%** | Usage / Limit > 0.8 | Warning | Request quota increase proactively |

## References

- [Compute Engine Quotas & Limits](https://cloud.google.com/compute/quotas-limits) — GPU quotas per region
- [Cloud TPU Quotas](https://cloud.google.com/tpu/docs/quota) — TPU core quotas per zone
- [Request a Quota Increase](https://cloud.google.com/docs/quotas/help/request_increase) — How to request more
- [Quota Adjuster](https://cloud.google.com/docs/quotas/quota-adjuster) — Automate quota adjustments
- [Cloud Quotas Overview](https://cloud.google.com/docs/quotas/overview) — How quotas work
