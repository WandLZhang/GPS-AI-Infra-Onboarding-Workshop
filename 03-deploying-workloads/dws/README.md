# Dynamic Workload Scheduler (DWS) — Concepts & Capacity Acquisition

> Understand how Dynamic Workload Scheduler (DWS) enables cost-effective GPU and TPU resource acquisition on Google Cloud. This guide covers DWS concepts, capacity models, pricing, compliance, and best practices — independent of any specific deployment method.

---

## 📋 Table of Contents

1. [What is Dynamic Workload Scheduler?](#1-what-is-dynamic-workload-scheduler)
2. [Capacity Acquisition Models](#2-capacity-acquisition-models)
3. [How DWS Integrates with GKE](#3-how-dws-integrates-with-gke)
4. [Supported GPU Machine Types & Zones](#4-supported-gpu-machine-types--zones)
5. [Data Residency & Compliance Considerations](#5-data-residency--compliance-considerations)
6. [Best Practices](#6-best-practices)
7. [Quota & Pricing](#7-quota--pricing)
8. [Limitations](#8-limitations)
9. [Deployment Methods](#9-deployment-methods)
10. [References](#10-references)

---

## 1. What is Dynamic Workload Scheduler?

**Dynamic Workload Scheduler (DWS)** is a Google Cloud service that enables customers to request and obtain high-demand compute resources — specifically GPUs and TPUs — by scheduling workloads to run when the requested capacity becomes available. Instead of failing immediately when on-demand capacity is unavailable, DWS queues your request and provisions all the required VMs together ("all-at-once") as soon as sufficient resources exist.

### The Problem DWS Solves

High-performance accelerators like NVIDIA H100, H200, B200, and Google TPUs are in extreme demand. Customers frequently encounter:

- **Capacity unavailability**: On-demand GPU requests fail because the zone is fully utilized.
- **Partial allocation waste**: Getting 6 of 8 requested GPU VMs means paying for unusable partial capacity.
- **Unpredictable scheduling**: No visibility into when resources might become available.

### How DWS Solves It

| Capability | Benefit |
|---|---|
| **Queued requests** | Your request persists until capacity is available — no need to retry manually |
| **All-at-once provisioning** | All requested VMs are created simultaneously, avoiding partial allocation charges |
| **Dense allocation** | VMs are placed close together for minimal network latency (critical for distributed training) |
| **Discounted pricing** | Up to **53% discount** on vCPUs, GPUs, and TPUs compared to on-demand pricing |
| **Flexible scheduling** | Resources are provisioned when available — ideal for time-flexible workloads |

### DWS Is a Service, Not a Deployment Method

DWS is a **capacity acquisition service** that can be consumed through multiple deployment methods. The capacity model (how you get GPUs) and the deployment surface (where you run workloads) are independent choices:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   DWS (Capacity Acquisition Service)                                       │
│   ───────────────────────────────────                                      │
│                                                                             │
│   ┌─────────────────────────┐    ┌──────────────────────────────┐          │
│   │  Flex-start             │    │  Calendar Mode               │          │
│   │  (queued, when avail.)  │    │  (guaranteed start time)     │          │
│   │  Up to 53% discount     │    │  Committed cost obligation   │          │
│   │  Up to 7-day duration   │    │  87h lead time (GPUs)        │          │
│   └────────┬────────────────┘    └──────────────┬───────────────┘          │
│            │                                     │                          │
│   Consumed via:                        Consumed via:                       │
│   • Compute Engine (MIG resize)        • Compute Engine (future res.)      │
│   • GKE (Cluster Toolkit, XPK)         • Cluster Director                  │
│   • Cluster Director                                                       │
│   • Vertex AI (FLEX_START)                                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

> For deployment-specific guides, see [§9 Deployment Methods](#9-deployment-methods).

---

## 2. Capacity Acquisition Models

DWS offers two capacity models. These sit alongside on-demand, reservations, and Spot in the broader GPU acquisition strategy.

### Where DWS Fits in the GPU Acquisition Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GPU/TPU Acquisition Strategy                            │
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  On-Demand   │  │ Reservations │  │     DWS      │  │   Spot VMs   │   │
│  │              │  │              │  │              │  │              │   │
│  │ Immediate    │  │ Guaranteed   │  │ Queued,      │  │ Cheapest,    │   │
│  │ Full price   │  │ Committed    │  │ Discounted   │  │ Preemptible  │   │
│  │ If available │  │ Long-term    │  │ Up to 7 days │  │ No guarantee │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                 │                 │                 │            │
│    Best when:        Best when:        Best when:        Best when:       │
│    - Need now        - Predictable     - Time-flexible   - Fault-tolerant │
│    - Short tasks       long-term       - Medium jobs     - Checkpointing  │
│    - Budget allows     demand          - Cost-sensitive  - Max savings    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Flex-start (Queued Provisioning)

Flex-start is DWS's queued provisioning model. Your request persists until capacity becomes available, at which point all VMs are provisioned simultaneously.

| Property | Value |
|---|---|
| **Start time** | When capacity becomes available (not guaranteed) |
| **Max duration** | 7 days |
| **Pricing** | Up to 53% discount vs. on-demand |
| **Allocation** | Dense (VMs placed close together) |
| **All-at-once** | Yes — all VMs created simultaneously |
| **Preemptible?** | No — once provisioned, VMs run until duration expires or you delete them |

### Calendar Mode (Guaranteed Start)

Calendar mode uses future reservations to guarantee capacity at a specific start time.

| Property | Value |
|---|---|
| **Start time** | Guaranteed at your requested time |
| **Min lead time** | 87 hours (GPUs), 6 hours (TPUs) |
| **Pricing** | DWS pricing (up to 53% discount) |
| **Cost commitment** | Cannot cancel after submission — you pay from start time regardless |
| **Allocation** | Dense (GPUs), Flexible (TPUs) |
| **Share type** | Single-project or shared (up to 100 projects) |

### Choosing Between Flex-start and Calendar Mode

```
                    Do you need guaranteed capacity
                    at a specific start time?
                               │
                    ┌──────────┴──────────┐
                   Yes                    No
                    │                      │
              Calendar Mode           Flex-start
              • Guaranteed start      • Runs when available
              • Committed cost        • Up to 53% discount
              • 87h lead time (GPU)   • Up to 7-day duration
              • Cannot cancel         • Cancel anytime
```

---

## 3. How DWS Integrates with GKE

When DWS is used through GKE-based deployment methods ([Cluster Toolkit](../cluster-toolkit/), [XPK](../xpk/)), the integration works through **queued provisioning** and **[Kueue](https://kueue.sigs.k8s.io/)** (Kubernetes-native job queuing).

### Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                         GKE Cluster                               │
│                                                                   │
│  ┌──────────────┐     ┌──────────────────────────────────────┐   │
│  │ User submits │     │           Kueue Controller            │   │
│  │ Job with     │────►│                                      │   │
│  │ queue label  │     │  ClusterQueue ─► AdmissionCheck      │   │
│  └──────────────┘     │       │              │               │   │
│                        │       ▼              ▼               │   │
│                        │  ResourceFlavor  ProvisioningRequest │   │
│                        │  (reservation)   (DWS queued prov.) │   │
│                        └──────────┬───────────────┬───────────┘   │
│                                   │               │               │
│  ┌────────────────────┐    ┌──────▼───────┐ ┌─────▼──────────┐   │
│  │ Reserved Node Pool │    │  DWS Node    │ │ Cluster        │   │
│  │ (try first)        │    │  Pool        │ │ Autoscaler     │   │
│  │                    │    │  (fallback)  │ │ + DWS          │   │
│  └────────────────────┘    └──────────────┘ └────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

### Key Kueue Resources for DWS

| Resource | Purpose |
|---|---|
| **ResourceFlavor** | Defines the type of resources available (maps to a node pool) |
| **AdmissionCheck** | Gates job admission on successful GPU provisioning via DWS |
| **ProvisioningRequestConfig** | Configures the provisioning class (`queued-provisioning.gke.io`) and managed resources |
| **ClusterQueue** | Cluster-wide queue with `nominalQuota` limiting total admitted GPUs |
| **LocalQueue** | Namespace-scoped queue that routes jobs to the ClusterQueue |

### Reservation + DWS Fallback Pattern

The recommended production pattern for GKE uses Kueue's multi-flavor ClusterQueue to try reserved capacity first, then fall back to DWS when reservations are exhausted:

```
Job submitted → Kueue tries Reservation flavor (Priority 1)
                    │
                    ├── Reservation has capacity → Job runs on reserved nodes
                    │
                    └── Reservation exhausted → Falls back to DWS flavor (Priority 2)
                                                    │
                                                    └── DWS queues and provisions when available
```

> For step-by-step implementation of this pattern, see the [Cluster Toolkit Guide](../cluster-toolkit/) or [DWS on GKE documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest).

### GKE Version Requirements

| Resource | Minimum GKE Version |
|---|---|
| **GPUs** | 1.32.2-gke.1652000 or later |
| **TPUs** | Varies by TPU generation (see [Plan TPUs in GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/plan-tpus)) |

---

## 4. Supported GPU Machine Types & Zones

### GPU Machine Types Available with DWS

For GPUs, **future reservations in calendar mode and Flex-start VMs are available in all zones where the GPU machine types are available**.

| Machine Type | GPU | GPUs per VM | Key US Zones | Notes |
|---|---|---|---|---|
| **A4** | NVIDIA B200 | 8 | us-central1, us-east4, us-east5, us-south1, us-west1-c, us-west2-c, us-west3 | Latest generation |
| **A3 Ultra** | NVIDIA H200 | 8 | us-central1, us-east4, us-east5, us-south1, us-west1-c | High-bandwidth memory |
| **A3 Mega** | NVIDIA H100 | 8 | us-central1, us-east4, us-east5, us-west1, us-west4-a | Most popular for training |
| **A3 High** | NVIDIA H100 | 1, 2, 4, 8 | us-central1, us-east4, us-east5, us-west1, us-west4-a | Fractional (1g/2g/4g) require Spot or Flex-start |
| **A3 Edge** | NVIDIA H100 | 8 | us-central1, us-east4, us-west1, us-west4-a | GPUDirect-TCPX |
| **A2 Standard** | NVIDIA A100 40GB | 1, 2, 4, 8, 16 | us-central1, us-east1, us-west1-b, us-west3-b, us-west4-b | Widely available |
| **A2 Ultra** | NVIDIA A100 80GB | 1, 2, 4, 8 | us-central1, us-east4 | Higher memory A100 |
| **G2** | NVIDIA L4 | 1, 2, 4, 8 | us-central1, us-east1, us-east4, us-west1, us-west4 | Inference-optimized |
| **G4** | NVIDIA RTX PRO 6000 | varies | us-central1, us-south1, us-west1, us-west3 | Workstation/rendering |

> **Full zone list**: See [GPU regions and zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones) for the complete availability matrix.

### TPU Zones (Flex-start on GKE)

| TPU Generation | Supported Zones |
|---|---|
| Ironwood (TPU7x) | `us-central1-c` |
| Trillium (v6e) | `asia-northeast1-b`, `us-east5-a`, `us-east5-b` |
| v5e | `us-west4-a` |
| v5p | `us-east5-a` |

> **Note**: TPU v3 and v4 are **not supported** with flex-start on GKE.

---

## 5. Data Residency & Compliance Considerations

When using DWS in regulated environments — particularly Public Sector — data residency is a critical concern. GPU/TPU workloads process sensitive data, and the zone where VMs are provisioned determines where that data resides.

### Key Principles

| Principle | DWS Implication |
|---|---|
| **Data stays in the VM's zone** | DWS provisions VMs in the zone you specify — data does not leave that zone |
| **You choose the zone** | All DWS options (flex-start, calendar mode) require you to specify a zone |
| **No cross-region movement** | DWS does not move your workload to a different region for capacity — it queues until capacity is available in your specified zone |
| **Zone = data residency** | The zone in your resize request, node pool, or Vertex AI region determines data residency |

### Compliance Framework Matrix

| Framework | Region Requirement | DWS Strategy |
|---|---|---|
| **FedRAMP High** | US-only regions | Use US zones exclusively; deploy in Assured Workloads folder |
| **FedRAMP Moderate** | Any authorized region (incl. non-US) | US regions recommended; broader zone selection available |
| **DoD IL2** | Full reciprocity with FedRAMP Moderate/High | Use US-based regions |
| **DoD IL4** | US-only regions | Restrict to US zones; use Assured Workloads |
| **DoD IL5** | US-only regions | Restrict to US zones; use Assured Workloads with IL5 boundary |
| **ITAR** | US-only regions | Use Assured Workloads ITAR boundary; restrict zones to US |
| **Sovereign controls (non-US)** | Region-specific (EU, etc.) | Use region-specific zones; verify GPU availability in those zones |

### GPU Availability in US Regions (Compliance-Aligned)

For FedRAMP High, DoD IL4/IL5 workloads that require US-only data residency:

| US Region | Key GPU Machine Types | Compliance Notes |
|---|---|---|
| `us-central1` (Iowa) | A4, A3 Ultra, A3 Mega*, A3 High, A3 Edge, A2, G2, G4 | Broadest GPU availability; primary choice for US-regulated workloads |
| `us-east1` (South Carolina) | A2, G2, N1+T4/V100/P100 | Good for A2-based workloads |
| `us-east4` (Virginia) | A4, A3 Ultra, A3 Mega, A3 High, A2 Ultra, G2, G4 | Key for DoD/IC proximity to Northern Virginia |
| `us-east5` (Columbus, OH) | A4, A3 Ultra, A3 Mega, A3 High, A3 Edge, G2 | Growing GPU region |
| `us-south1` (Dallas, TX) | A4, A3 Ultra, G4 | Southern US presence |
| `us-west1` (Oregon) | A3 Mega, A3 High, A3 Edge, A2, G2, G4 | West coast option |
| `us-west2` (Los Angeles) | A4, N1+T4/P4 | Limited GPU types |
| `us-west3` (Salt Lake City) | A4, A2, G4 | Limited GPU types |
| `us-west4` (Las Vegas) | A3 Mega, A3 High, A3 Edge, A2, G2, G4 | Good GPU coverage |

> **\*** `us-central1-b` has limited A3 Mega capacity — contact your account team.

### Recommendations for Regulated Environments

1. **Use Assured Workloads**: Create an Assured Workloads folder with the appropriate compliance program (FedRAMP High, IL4, IL5). This automatically enforces resource location constraints via Organization Policy.

    ```bash
    gcloud assured workloads create \
        --organization=ORGANIZATION_ID \
        --location=us-central1 \
        --display-name="AI Training - FedRAMP High" \
        --compliance-regime=FEDRAMP_HIGH \
        --billing-account=BILLING_ACCOUNT_ID
    ```

2. **Verify GPU availability in compliant zones BEFORE submitting DWS requests**: Not all US zones have all GPU types. Check availability first:

    ```bash
    # Check GPU availability in a specific zone
    gcloud compute accelerator-types list --filter="zone:us-east4-a"
    
    # Check future resource availability for calendar mode
    gcloud compute future-reservations list-available \
        --zone=us-east4-a \
        --machine-type=a3-megagpu-8g
    ```

3. **Enforce resource location with Organization Policy**: Even outside Assured Workloads, use org policies to restrict where VMs can be created:

    ```bash
    gcloud resource-manager org-policies set-policy \
        --project=$PROJECT_ID \
        resource-location-policy.yaml
    ```

    ```yaml
    # resource-location-policy.yaml
    constraint: constraints/gcloud.resourceLocations
    listPolicy:
      allowedValues:
        - in:us-locations
    ```

4. **Consider zone-specific capacity**: If your compliance requirement restricts you to specific zones (e.g., `us-east4` for DoD/IC proximity), understand that DWS will queue your request rather than redirecting it to another zone. Plan for potentially longer wait times in zones with less capacity.

5. **Storage residency alignment**: Ensure your training data, model artifacts, and checkpoint storage (GCS buckets, Rapid Buckets) are in the **same region** as your DWS GPU workloads. See [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md).

---

## 6. Best Practices

### Project Configuration

| Best Practice | Detail | Command |
|---|---|---|
| **Enable required APIs** | Compute Engine, GKE, Vertex AI, IAM | `gcloud services enable compute.googleapis.com container.googleapis.com aiplatform.googleapis.com` |
| **Verify GPU quota** | Check quota for your target GPU type before submitting DWS requests | `gcloud compute regions describe $REGION --format="yaml(quotas)"` |
| **Check `ACTIVE_RESIZE_REQUESTS` quota** | Default limit: 100 pending requests per project | `gcloud compute project-info describe --format="yaml(quotas)"` |
| **Request preemptible quota (Vertex AI)** | Vertex AI DWS uses preemptible quota names | Request via [Quota console](https://console.cloud.google.com/iam-admin/quotas) |
| **Use dedicated projects** | Separate DWS workloads from other production workloads to avoid quota contention | — |

### Workload Design

| Best Practice | Detail |
|---|---|
| **Always checkpoint** | DWS VMs are deleted at end of run duration. Checkpoint frequently to GCS, Rapid Bucket, or HyperDisk |
| **Set appropriate `maxRunDuration`** | Don't request 7 days if you need 6 hours — shorter durations may be fulfilled faster |
| **Design for all-at-once** | DWS provisions all VMs simultaneously — ensure your workload can start with all nodes available |
| **Use dense deployment (Calendar Mode)** | Required for GPU VMs; ensures minimal network latency for distributed training |

### Cost Optimization

| Strategy | Detail |
|---|---|
| **Reservation + DWS fallback** | Use Kueue's multi-flavor ClusterQueue to try reservations first, fall back to DWS (GKE only) |
| **Right-size run duration** | Shorter requests may be fulfilled faster and cost less |
| **Multi-zone submission** | If your workload is not zone-bound, create requests in multiple zones to increase chances of fulfillment |
| **Monitor and cancel** | Cancel pending requests you no longer need to free up `ACTIVE_RESIZE_REQUESTS` quota |

### Data Residency

| Best Practice | Detail |
|---|---|
| **Always specify a zone explicitly** | DWS never moves workloads cross-region, but be explicit about zone selection |
| **Use Assured Workloads for regulated workloads** | Automatically enforces resource location constraints |
| **Align storage and compute regions** | Keep GCS buckets, Rapid Buckets, and Rapid Cache in the same region as GPU workloads |
| **Verify GPU availability in compliant zones** | Not all US zones have all GPU types — check before planning |
| **Document zone selection rationale** | For audit purposes, document why specific zones were chosen for regulated workloads |
| **Use Organization Policy constraints** | Enforce `gcloud.resourceLocations` to prevent accidental deployment in non-compliant regions |

---

## 7. Quota & Pricing

### Quota Requirements by Deployment Method

| Deployment Method | Quota Required | Notes |
|---|---|---|
| **[Compute Engine](../compute-engine-Managed%20Instance%20Groups/)** | Standard GPU quota (e.g., `NVIDIA_H100_GPUS`) | Request stays pending if insufficient quota |
| **[Calendar Mode](../compute-engine-future-reservations/)** | No Compute Engine quota needed (reservation-bound model) | Only need quota for non-reservation resources (disks, IPs) |
| **[Cluster Toolkit](../cluster-toolkit/) / [XPK](../xpk/)** | `ACTIVE_RESIZE_REQUESTS` (default: 100/project) + GPU quota | GKE uses Compute Engine quota under the hood |
| **[Vertex AI](../vertex-ai/)** | Preemptible Vertex AI quota (e.g., `custom_model_training_preemptible_nvidia_h100_gpus`) | Despite name, resources are NOT preemptible |

### DWS Pricing

DWS offers **up to 53% discount** compared to on-demand pricing for vCPUs, memory, GPUs, and TPUs.

| Component | Pricing Model |
|---|---|
| **Flex-start VMs** | [DWS pricing](https://cloud.google.com/products/dws/pricing) — discounted vs. on-demand |
| **Calendar Mode reservations** | [DWS pricing](https://cloud.google.com/products/dws/pricing) — charged from start time regardless of usage |
| **Vertex AI DWS** | [DWS pricing](https://cloud.google.com/products/dws/pricing) + [serverless training management fees](https://cloud.google.com/vertex-ai/pricing#custom-trained_models) |

> **Key Pricing Facts:**
> - You are **not charged** for creating, canceling, or deleting resize requests.
> - For flex-start, charges begin when VMs are created and end when VMs are deleted or run duration expires.
> - For calendar mode, you **commit to pay at the start time** regardless of whether you use the capacity. You cannot cancel after submission.
> - If a MIG creates only some Flex-start VMs and fails to create the rest, you may still incur charges until the partial VMs are automatically deleted.

---

## 8. Limitations

| Limitation | Applies To | Detail |
|---|---|---|
| **7-day max run duration** | Flex-start (all) | VMs run for up to 7 days maximum |
| **Spot VMs not supported** | DWS (all) | Cannot combine Spot provisioning model with DWS resize requests |
| **1,000 VM max per resize request** | Compute Engine | Maximum VMs per single resize request |
| **100 pending requests per project** | Compute Engine / GKE | `ACTIVE_RESIZE_REQUESTS` quota limit (adjustable) |
| **87-hour minimum lead time (GPUs)** | Calendar Mode | Must submit request at least 3 days 15 hours before start time |
| **Cannot cancel/modify after submission** | Calendar Mode | You commit to paying at start time |
| **No VM stop/suspend** | Flex-start VMs | You can only delete Flex-start VMs, not stop or suspend them |
| **No ephemeral volumes** | GKE flex-start | Must use persistent volumes for storage |
| **Single podSet per ProvisioningRequest** | GKE | Requests with multiple podSet entries fail |
| **No inter-pod anti-affinity** | GKE | Cluster autoscaler doesn't consider anti-affinity during DWS provisioning |
| **Same machine config required** | Vertex AI DWS | All worker pools must use the same machine configuration |

---

## 9. Deployment Methods

DWS can be consumed through multiple deployment methods. Each has its own guide with step-by-step instructions:

| Deployment Method | Description | Guide |
|---|---|---|
| **Compute Engine** | MIG resize requests for raw VMs — no K8s or Slurm needed | [→ compute-engine/](../compute-engine-Managed%20Instance%20Groups/) |
| **Calendar Mode** | Future reservations with guaranteed start time | [→ compute-engine-future-reservations/](../compute-engine-future-reservations/) |
| **Cluster Toolkit** | Production GKE clusters via Terraform blueprints with Kueue integration | [→ cluster-toolkit/](../cluster-toolkit/) |
| **XPK** | Quick PoC GKE clusters with `--flex` flag | [→ xpk/](../xpk/) |
| **Cluster Director** | Fully managed Slurm clusters with DWS flex-start and calendar mode | [→ cluster-director/](../cluster-director/) |
| **Vertex AI** | Serverless training with FLEX_START scheduling strategy | [→ vertex-ai/](../vertex-ai/) |

> For a comparison of all deployment methods, see the [Deploying Workloads Overview](../).

---

## 10. References

### Official Documentation

- [DWS Product Page & Pricing](https://cloud.google.com/products/dws/pricing)
- [About Flex-start VMs](https://cloud.google.com/compute/docs/instances/about-flex-start-vms)
- [About Flex-start in GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/dws)
- [Deploy GPUs with DWS on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest)
- [Flex-start Training on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-training)
- [Flex-start Inference on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-inference)
- [About Resize Requests in a MIG](https://cloud.google.com/compute/docs/instance-groups/about-resize-requests-mig)
- [Future Reservations in Calendar Mode](https://cloud.google.com/compute/docs/instances/future-reservations-calendar-mode-overview)
- [Vertex AI DWS for Training Jobs](https://cloud.google.com/vertex-ai/docs/training/schedule-jobs-dws)

### GPU & Zone References

- [GPU Regions and Zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)
- [GPU Machine Types](https://cloud.google.com/compute/docs/gpus/about-gpus#gpu-machine-types)
- [Accelerator-Optimized Machine Families](https://cloud.google.com/compute/docs/accelerator-optimized-machines)

### Compliance & Data Residency

- [Assured Workloads Overview](https://cloud.google.com/assured-workloads/docs/overview)
- [FedRAMP Implementation Guide](https://cloud.google.com/architecture/fedramp-implementation-guide)
- [FedRAMP & DoD Compliance Scope](https://cloud.google.com/architecture/security/fedramp-dod-compliance-scope)
- [Data Residency Contractual Commitments](https://cloud.google.com/terms/data-residency)
- [Assured Workloads US Regions](https://cloud.google.com/assured-workloads/docs/locations#us_regions)

### Related Guides in This Repository

- [Deploying Workloads Overview](../) — Compare all deployment methods and decision framework
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket for training data and checkpointing
- [Zero Trust IAP Access](../../02-core-infrastructure/zero-trust-iap-access/README.md) — Securing VM access for DWS-provisioned GPU VMs

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies, verify GPU availability in your target zones, and review DWS pricing before deploying in production environments. Calendar mode future reservations represent a financial commitment — ensure organizational approval before submission.
