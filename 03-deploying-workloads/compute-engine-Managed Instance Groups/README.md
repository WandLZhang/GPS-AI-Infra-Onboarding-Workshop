# Compute Engine — Flex-start VMs via MIG Resize Requests

> Deploy GPU VMs directly on Compute Engine using Managed Instance Groups (MIGs) with resize requests. Ideal for batch training, fine-tuning, and teams that want raw VM control without Kubernetes overhead.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [When to Use](#2-when-to-use)
3. [How It Works](#3-how-it-works)
4. [Resize Request Lifecycle](#4-resize-request-lifecycle)
5. [Step-by-Step Example](#5-step-by-step-example)
6. [Best Practices](#6-best-practices)
7. [Limitations](#7-limitations)
8. [References](#8-references)

---

## 1. Overview

MIG resize requests are a **Compute Engine mechanism** for requesting multiple GPU VMs simultaneously. When combined with the **flex-start provisioning model**, they integrate with [Dynamic Workload Scheduler (DWS)](../dws/) to queue your request and provision all VMs together when capacity becomes available — at up to **53% discount** compared to on-demand pricing.

### Key Points

- **MIG resize requests** are a Compute Engine feature that exists independently — they can be used with on-demand, flex-start, or other provisioning models.
- **Flex-start** is the DWS integration that enables queued, discounted provisioning through MIG resize requests.
- No Kubernetes, Slurm, or managed service required — just Compute Engine VMs.

### How It Fits

```
┌───────────────────────────────────────────────────────────────────┐
│           Capacity Model        ×        Deployment Method        │
│                                                                   │
│   DWS Flex-start (queued,          Compute Engine MIG             │
│   up to 53% discount)      →      (resize requests)              │
│                                                                   │
│   All VMs provisioned at once, densely allocated,                │
│   up to 7-day run duration                                       │
└───────────────────────────────────────────────────────────────────┘
```

> For DWS concepts, pricing, and compliance guidance, see the [DWS Guide](../dws/).

---

## 2. When to Use

| Scenario | Why Compute Engine with MIG Resize Requests |
|---|---|
| **Batch training jobs** | Run for up to 7 days at a discounted rate without K8s overhead |
| **Custom VM images** | Full control over OS, drivers, and software stack |
| **Simple infrastructure** | Single MIG with a resize request — no Kubernetes cluster needed |
| **Teams without K8s expertise** | Lower complexity than GKE-based approaches |
| **A3 High fractional GPUs** | `a3-highgpu-1g`, `a3-highgpu-2g`, `a3-highgpu-4g` require Spot or Flex-start |

### When NOT to Use

| Scenario | Better Alternative |
|---|---|
| Need Kubernetes-native job orchestration | [Cluster Toolkit](../cluster-toolkit/) or [XPK](../xpk/) |
| Want zero infrastructure management | [Vertex AI](../vertex-ai/) |
| Need Slurm job scheduling | [Cluster Director](../cluster-director/) |
| Need guaranteed start time | [Calendar Mode](../compute-engine-future-reservations/) |
| Need reservation + DWS fallback | [Cluster Toolkit](../cluster-toolkit/) (Kueue pattern) |

---

## 3. How It Works

```
1. Create Instance Template (defines GPU machine type, disk, network)
       │
2. Create Zonal MIG (references the instance template)
       │
3. Create Resize Request (specifies VM count + run duration)
       │
4. DWS queues the request (state: ACCEPTED)
       │
5. Capacity becomes available → All VMs created at once (state: SUCCEEDED)
       │
6. VMs run until run duration expires or you delete them
```

---

## 4. Resize Request Lifecycle

| State | Description |
|---|---|
| `CREATING` | Compute Engine received the request; MIG target size increases |
| `ACCEPTED` | Request accepted; DWS schedules VM creation based on availability |
| `SUCCEEDED` | All VMs created; densely allocated for minimal latency |
| `FAILED` | Technical error; MIG target size decreases |
| `CANCELLED` | User canceled; MIG target size decreases; request auto-deleted after 14 days |

---

## 5. Step-by-Step Example

### Prerequisites

```bash
export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"
export REGION="us-central1"
export MIG_NAME="gpu-training-mig"
export TEMPLATE_NAME="gpu-training-template"

gcloud config set project $PROJECT_ID
```

### 1. Create an Instance Template

```bash
gcloud compute instance-templates create $TEMPLATE_NAME \
    --machine-type=a3-highgpu-8g \
    --maintenance-policy=TERMINATE \
    --boot-disk-size=200GB \
    --boot-disk-type=pd-ssd \
    --image-family=common-cu126-debian-12 \
    --image-project=ml-images \
    --network=default \
    --no-address \
    --metadata=enable-oslogin=TRUE
```

### 2. Create a Zonal MIG

```bash
gcloud compute instance-groups managed create $MIG_NAME \
    --zone=$ZONE \
    --template=$TEMPLATE_NAME \
    --size=0 \
    --default-action-on-vm-failure=do-nothing
```

> **Important**: Set `--size=0` — the resize request controls VM creation.

### 3. Create a Resize Request

```bash
gcloud compute instance-groups managed resize-requests create $MIG_NAME \
    --resize-request=training-run-001 \
    --resize-by=8 \
    --requested-run-duration=86400s \
    --zone=$ZONE
```

| Flag | Description |
|---|---|
| `--resize-by=8` | Number of VMs to create (all at once) |
| `--requested-run-duration=86400s` | Run duration in seconds (24 hours = 86400s, max 7 days = 604800s) |

### 4. Monitor the Request

```bash
# Check resize request status
gcloud compute instance-groups managed resize-requests describe $MIG_NAME \
    --resize-request=training-run-001 \
    --zone=$ZONE

# List all resize requests
gcloud compute instance-groups managed resize-requests list $MIG_NAME \
    --zone=$ZONE
```

### 5. Cancel (If Needed)

```bash
gcloud compute instance-groups managed resize-requests cancel $MIG_NAME \
    --resize-request=training-run-001 \
    --zone=$ZONE
```

---

## 6. Best Practices

### Workload Design

| Best Practice | Detail |
|---|---|
| **Always checkpoint** | DWS VMs are deleted at end of run duration. Checkpoint frequently to GCS, Rapid Bucket, or HyperDisk |
| **Set appropriate run duration** | Don't request 7 days if you need 6 hours — shorter durations may be fulfilled faster |
| **Design for all-at-once** | DWS provisions all VMs simultaneously — ensure your workload can start with all nodes available |

### Infrastructure

| Best Practice | Detail |
|---|---|
| **Use `--no-address`** | Deploy VMs without public IPs; use [IAP for SSH access](../../02-core-infrastructure/zero-trust-iap-access/README.md) |
| **Enable OS Login** | Use identity-based authentication instead of SSH keys |
| **Multi-zone submission** | If not zone-bound, create resize requests in multiple zones to increase chances of fulfillment |
| **Monitor and cancel** | Cancel pending requests you no longer need to free up `ACTIVE_RESIZE_REQUESTS` quota |

### Quota

| Best Practice | Detail |
|---|---|
| **Verify GPU quota** | Check quota for your target GPU type before submitting | 
| **Check `ACTIVE_RESIZE_REQUESTS` quota** | Default limit: 100 pending requests per project |
| **Set up IAM roles** | `roles/compute.instanceAdmin.v1` for MIG resize requests |

---

## 7. Limitations

| Limitation | Detail |
|---|---|
| **7-day max run duration** | Flex-start VMs run for up to 7 days maximum |
| **1,000 VM max per resize request** | Maximum VMs per single resize request |
| **100 pending requests per project** | `ACTIVE_RESIZE_REQUESTS` quota limit (adjustable) |
| **No VM stop/suspend** | You can only delete Flex-start VMs, not stop or suspend them |
| **Short-lived VMs may appear** | Compute Engine may create and promptly remove VMs until full capacity is available |
| **Spot VMs not supported** | Cannot combine Spot provisioning model with DWS resize requests |

---

## 8. References

### Official Documentation

- [About Resize Requests in a MIG](https://cloud.google.com/compute/docs/instance-groups/about-resize-requests-mig)
- [Create Resize Requests in a MIG](https://cloud.google.com/compute/docs/instance-groups/create-resize-requests-mig)
- [About Flex-start VMs](https://cloud.google.com/compute/docs/instances/about-flex-start-vms)
- [DWS Pricing](https://cloud.google.com/products/dws/pricing)

### Related Guides in This Repository

- [DWS Concepts](../dws/) — Capacity acquisition models, pricing, compliance
- [Calendar Mode](../compute-engine-future-reservations/) — Guaranteed start time via future reservations
- [Deployment Methods Overview](../) — Compare all deployment methods
- [Zero Trust IAP Access](../../02-core-infrastructure/zero-trust-iap-access/README.md) — Securing VM access
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies, verify GPU availability in your target zones, and review [DWS pricing](https://cloud.google.com/products/dws/pricing) before deploying in production environments.
