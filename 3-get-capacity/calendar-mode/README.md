# Calendar Mode: Book GPUs or TPUs for Fixed Dates

> Reserve GPU/TPU capacity for a specific future time window with guaranteed provisioning. Unlike flex-start (which provisions when available), calendar mode guarantees resources at your requested start time — with a committed cost obligation.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [When to Use](#2-when-to-use)
3. [How It Works](#3-how-it-works)
4. [Request Lifecycle](#4-request-lifecycle)
5. [Key Properties](#5-key-properties)
6. [Step-by-Step Example](#6-step-by-step-example)
7. [Best Practices](#7-best-practices)
8. [Limitations](#8-limitations)
9. [References](#9-references)

---

## 1. Overview

Future Reservations in **Calendar Mode** let you reserve GPU capacity for a **specific future time window**. Google Cloud guarantees that resources will be provisioned at your requested start time. This is a fundamentally different capacity model from flex-start — you get certainty in exchange for a committed cost obligation.

### Key Points

- **Guaranteed start time** — resources are provisioned exactly when you request.
- **Committed cost** — after submission, you **cannot cancel, delete, or modify** the request. You pay from the start time regardless of usage.
- **Dense allocation** — VMs are placed close together for minimal network latency.
- **DWS pricing** — up to 53% discount compared to on-demand.

### How It Fits

```
┌───────────────────────────────────────────────────────────────────┐
│           Capacity Model        ×        Deployment Method        │
│                                                                   │
│   Calendar Mode (guaranteed      Compute Engine                   │
│   start, committed cost)    →    (Future Reservations)            │
│                                                                   │
│   Reservation created at start time, you create VMs              │
│   that consume the reservation                                   │
└───────────────────────────────────────────────────────────────────┘
```

> For DWS concepts, pricing, and compliance guidance, see the [DWS Guide](../flex-start/).

---

## 2. When to Use

| Scenario | Why Calendar Mode |
|---|---|
| **Planned training runs** | You know exactly when you need GPUs and for how long |
| **Hard deadlines** | You cannot afford to wait for capacity — it must be ready at a specific time |
| **Large-scale distributed training** | Need guaranteed simultaneous provisioning of many GPU VMs |
| **Recurring workloads** | Regular training cadence (e.g., weekly retraining) with predictable schedules |
| **Multi-team coordination** | Multiple teams sharing capacity on a schedule |

### When NOT to Use

| Scenario | Better Alternative |
|---|---|
| Time-flexible, cost-sensitive workloads | [Compute Engine Flex-start](../../5-run/vms/) or [Cluster Toolkit](../../5-run/kubernetes/cluster-toolkit/) |
| Quick PoC or experimentation | [XPK](../../5-run/kubernetes/xpk/) with `--flex` |
| Serverless training | [Vertex AI](../../5-run/managed-training-vertex-ai/) |
| Need Slurm-based scheduling | [Cluster Director](../../5-run/slurm/) |

---

## 3. How It Works

```
1. Create future reservation request in calendar mode
       │
2. Google Cloud auto-approves (within ~1 minute)
       │
3. Auto-created reservation is created (empty — no VMs yet)
       │
4. At start time: Compute Engine provisions VMs in the reservation
       │
5. You create VMs that consume the reservation (reservation-bound model)
       │
6. At end time: Reservation deleted, VMs stopped/deleted
```

---

## 4. Request Lifecycle

| State | Description |
|---|---|
| `PENDING_APPROVAL` | Request submitted for review |
| `APPROVED` | Auto-approved; empty reservation created within ~1 minute |
| `PROCURING` | Compute Engine scheduling resource provisioning |
| `PROVISIONING` | Resources being provisioned before start time |
| `FULFILLED` | Resources provisioned; you can create VMs to consume the reservation |

---

## 5. Key Properties

| Property | Value | Notes |
|---|---|---|
| **Minimum lead time (GPUs/H4D)** | 87 hours (3 days 15 hours) | Time between request creation and start time |
| **Minimum lead time (TPUs)** | 6 hours | Shorter lead time for TPU resources |
| **Deployment type (GPUs)** | `DENSE` (required) | Densely allocates for minimal network latency |
| **Deployment type (TPUs)** | `FLEXIBLE` (default) | Best-effort close placement |
| **Consumption type** | Specifically-targeted | Only VMs that target the reservation can consume it |
| **Auto-delete** | Required (enabled) | Reservation deleted at end time |
| **Share type** | Single-project or Shared (up to 100 projects) | Can share across projects in your org |

### Sizes, durations and machine types

| Property | Value |
|---|---|
| **Start time** | Guaranteed at your requested time |
| **Min lead time** | 87 hours (GPUs), 6 hours (TPUs) |
| **Pricing** | Discounted vs. on-demand: about 30% to 53% off, depending on the machine type ([Prices by machine type](../../7-cost/prices.md#prices-by-machine-type)) |
| **Cost commitment** | Cannot cancel after submission — you pay from start time regardless |
| **Allocation** | Dense (GPUs), Flexible (TPUs) |
| **Share type** | Single-project or shared (up to 100 projects) |
| **Request size** | GPUs: 1 to 80 VMs. H4D: 1 to 256 VMs. TPUs: 1, 4, 8, 16, 32, 64, 128, 256, 512 or 1,024 chips |
| **How far ahead** | Availability shows up to 60 days ahead for GPUs and H4D, 120 days for TPUs |
| **Duration** | 1 to 90 days |
| **Machine types** | GPU and H4D: A4, A3 Ultra, A3 Mega, A3 High with 8 GPUs, A3 Edge and H4D. TPU: TPU7x, v6e and v5p |

> Source: [Future reservation requests in calendar mode](https://docs.cloud.google.com/compute/docs/instances/future-reservations-calendar-mode-overview) (last updated 2026-10-13). A2, G2 and G4 aren't on the list, and the advice API rejects them with "This machine family is not supported in Calendar Mode." On 2026-10-15 the API also rejected TPU7x, which is on the list, and returned zones for v5e, which isn't.

---

## 6. Step-by-Step Example

### Prerequisites

```bash
export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"

gcloud config set project $PROJECT_ID
```

### Check Calendar availability before you book

The advice API tells you when and where you could book, and creates nothing:

```bash
gcloud compute advice calendar-mode \
  --machine-type=a3-megagpu-8g --vm-count=1 --region=us-central1 \
  --duration-range=min=7d,max=7d \
  --start-time-range=from=<YYYY-MM-DD>,to=<YYYY-MM-DD>
```

- It needs the `compute.advice.calendarMode` permission on the project you run it from.
- The API returns the longest block up to your `max` duration, even when a shorter block starts sooner. On 2026-10-15, a 7-day request for `a3-megagpu-8g` in us-central1 came back for Nov 9 to Nov 16, and a 1-to-30-day range came back for Dec 9 to Jan 8. Set `max` to the length you need.
- `NO_CAPACITY` means the zone takes Calendar requests for that machine type but has nothing free in your window. `NOT_SUPPORTED` means the zone doesn't take Calendar requests for that machine type, even if it carries the machine type. Retrying won't change it.
- [`discover-calendar-zones.py`](./discover-calendar-zones.py) runs the check for the A3, A4, H4D and TPU v5e, v5p and v6e machine types in every region that has them, and writes each zone's status to a CSV.
- [`calendar-poll.sh`](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/calendar-poll.sh) checks H100, H200 and B200 across US regions and prints each bookable window. Schedule it daily with cron. It books only if you set `CALENDAR_AUTOBOOK=1`.

### 1. Check Future Resource Availability

```bash
gcloud compute future-reservations list-available \
    --zone=$ZONE \
    --machine-type=a3-megagpu-8g
```

### 2. Create a Future Reservation Request

```bash
gcloud compute future-reservations create my-training-reservation \
    --zone=$ZONE \
    --total-count=16 \
    --machine-type=a3-megagpu-8g \
    --start-time=2026-04-05T08:00:00Z \
    --end-time=2026-04-07T08:00:00Z \
    --reservation-mode=CALENDAR \
    --deployment-type=DENSE \
    --auto-delete-auto-created-reservations \
    --planning-status=SUBMITTED \
    --require-specific-reservation \
    --reservation-name=my-training-reservation-auto
```

> **⚠️ Important**: After submission, you **cannot cancel, delete, or modify** the request. You commit to paying for the reserved capacity at the start time, regardless of usage.

### 3. Consume the Reservation (Create VMs)

After the reservation reaches `FULFILLED` state at the start time:

```bash
gcloud compute instances create training-vm-001 \
    --zone=$ZONE \
    --machine-type=a3-megagpu-8g \
    --provisioning-model=RESERVATION_BOUND \
    --reservation-affinity=specific \
    --reservation=my-training-reservation-auto \
    --maintenance-policy=TERMINATE \
    --boot-disk-size=200GB \
    --boot-disk-type=pd-ssd \
    --image-family=common-cu126-debian-12 \
    --image-project=ml-images
```

---

## 7. Best Practices

| Best Practice | Detail |
|---|---|
| **Verify availability first** | Always run `list-available` before submitting a reservation request |
| **Get organizational approval** | Calendar mode is a financial commitment — ensure budget approval before submission |
| **Plan for the lead time** | 87 hours minimum for GPUs — submit requests well in advance |
| **Right-size the time window** | You pay for the full window regardless of usage |
| **Always checkpoint** | Save progress frequently in case of unexpected issues |
| **Align storage regions** | Keep GCS buckets and other storage in the same region as reserved capacity |
| **Use dense deployment** | Required for GPU VMs; ensures minimal network latency for distributed training |

### For Regulated Environments

| Best Practice | Detail |
|---|---|
| **Verify GPU availability in compliant zones** | Not all US zones have all GPU types — check before planning |
| **Use Assured Workloads** | For FedRAMP High, DoD IL4/IL5 — automatically enforces resource location constraints |
| **Document zone selection rationale** | For audit purposes, document why specific zones were chosen |

> For detailed compliance guidance, see the [DWS Guide — Data Residency & Compliance](../flex-start/#5-data-residency--compliance-considerations).

---

## 8. Limitations

| Limitation | Detail |
|---|---|
| **87-hour minimum lead time (GPUs)** | Must submit request at least 3 days 15 hours before start time |
| **6-hour minimum lead time (TPUs)** | Shorter lead time for TPU resources |
| **Cannot cancel/modify after submission** | You commit to paying at start time |
| **Reservation-bound consumption** | Only VMs that specifically target the reservation can consume it |
| **Auto-delete at end time** | Reservation is deleted at the scheduled end time |
| **Shared up to 100 projects** | Can share across projects in your org, up to a limit |

---

## 9. References

### Official Documentation

- [Future Reservations in Calendar Mode](https://cloud.google.com/compute/docs/instances/future-reservations-calendar-mode-overview)
- [Create Future Reservations (Calendar Mode)](https://cloud.google.com/compute/docs/instances/create-future-reservations-calendar-mode)
- [DWS Pricing](https://cloud.google.com/products/dws/pricing)

### Related Guides in This Repository

- [DWS Concepts](../flex-start/) — Capacity acquisition models, pricing, compliance
- [Compute Engine Flex-start](../../5-run/vms/) — Queued provisioning (no guaranteed start)
- [Deployment Methods Overview](../../5-run/) — Compare all deployment methods
- [Storage for AI Workloads](../../4-storage-and-network/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Calendar mode future reservations represent a financial commitment — ensure organizational approval before submission. Always verify GPU availability in your target zones and review [DWS pricing](https://cloud.google.com/products/dws/pricing) before deploying.
