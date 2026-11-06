# Get capacity: GPUs and TPUs, and the quota to use them

How you get GPUs and TPUs is a separate choice from where you run them. Pick a capacity option and check your quota here, then pick a platform in [run](../5-run/).

## The options

| Option | What you get | Page |
|---|---|---|
| On-demand | Immediate, full price, if available | [Prices](../7-cost/prices.md) |
| Calendar mode | Book fixed dates: guaranteed start time, committed cost, 1 to 90 days | [calendar-mode](./calendar-mode/), with its [availability check](./calendar-mode/README.md#check-calendar-availability-before-you-book) |
| Flex-start | Queued, no fixed start, up to 53% discount, up to 7 days | [flex-start](./flex-start/), and [VMs](../5-run/vms/) for Flex-start VMs through managed instance groups |
| Reservations | Guaranteed, committed, long-term, through your account team | [reservation-placement.md](./reservation-placement.md) for how VMs use a reservation and dense placement |
| Spot | Cheapest, preemptible, no guarantee | [spot](./spot/), which ranks zones for Spot |

[quota.md](./quota.md) lists the quota each option uses, and how to raise it.

## Choose an option

```
               Do you need GPUs for more than 90 days?
                              │
                   ┌──────────┴──────────┐
                  Yes                    No
                   │                      │
            Reservation           Do you want guaranteed
            (AI Hypercomputer)    capacity at a specific time?
            Contact account team        │
                              ┌─────────┴─────────┐
                             Yes                   No
                              │                     │
                        Calendar Mode         Is your workload
                        (≤90 days)            fault-tolerant, with
                        guaranteed start      checkpointing?
                                                    │
                                         ┌──────────┴──────────┐
                                        Yes                    No
                                         │                      │
                                    Can you tolerate       Flex-Start (DWS)
                                    preemption?            Up to 53% discount
                                         │                 7-day max
                                  ┌──────┴──────┐
                                 Yes            No
                                  │              │
                                Spot         Flex-Start
                                Up to 91%    Up to 53%
                                discount     discount
```

## Which machine types take which option

Your choice of accelerator constrains which consumption models are available. From the consumption tables on [Accelerator-optimized machine family](https://docs.cloud.google.com/compute/docs/accelerator-optimized-machines) and [Plan your Cloud TPU resources](https://docs.cloud.google.com/tpu/docs/plan-tpus), read 2026-11-06:

| Machine type (GPU) | On-demand | Spot | Flex-start | Calendar mode | Reservations | Capacity blocks |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **A4X Max** (GB300), **A4X** (GB200) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **A4** (B200) | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| **A3 Ultra** (H200) | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| **A3 Mega** (H100) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **A3 High**, 8 GPUs (H100) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **A3 High**, 1, 2 or 4 GPUs (H100) | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **A3 Edge** (H100) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **A2** (A100) | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| **G4** (RTX PRO 6000) | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| **G2** (L4) | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |

Reservations covers on-demand and future reservations, which the page marks the same way for every machine type. Before you request a future reservation for these GPUs, talk to your account team. The page says Google Cloud is likely to decline the request otherwise.

| TPU version | On-demand | Spot | Flex-start (Preview) | Calendar mode | Reservation for 1 year or longer |
|---|:---:|:---:|:---:|:---:|:---:|
| **TPU7x** (Ironwood) | ✅ | ✅ allowlist | ✅ allowlist | ✅ allowlist | ✅ allowlist |
| **v6e** (Trillium) | ✅ | ✅ | ✅ | ✅ | ✅ |
| **v5p** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **v5e** | ✅ | ✅ | ❌ | ❌ | ✅ |

TPU7x Spot, Flex-start, Calendar mode and capacity blocks need an allowlist from your account team.

## Look up facts that change

Zones and support change. This repo dates the numbers it prints. Get the current ones here:

| Fact | Get it now |
|---|---|
| Price of a machine type | [Get today's price](../7-cost/prices.md#get-todays-price) |
| Which machine types take Flex-start and Calendar mode | Ask your harness: "Which GPU and TPU machine types support Dynamic Workload Scheduler flex-start and calendar mode?" |
| Zones that take Calendar requests | [`discover-calendar-zones.py`](./calendar-mode/discover-calendar-zones.py) |
| Spot obtainability by zone | [Capacity Advisor for Spot](./spot/) |
| GPU zones | [GPU regions and zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones) |
| TPU zones | [TPU regions and zones](https://docs.cloud.google.com/tpu/docs/regions-zones) |

[Ask your harness](../1-harness-setup/README.md#ask-your-harness) lists more questions the docs MCP answers. Scripts that spray requests across zones and poll for capacity are in [examples](../8-examples/README.md#spray-requests-across-zones-and-poll-for-capacity).

## Keep a training job alive on Spot

See [Keep a training job alive on Spot](./spot/README.md#keep-a-training-job-alive-on-spot) and [checkpointing](../5-run/checkpointing.md). On GKE, [Spot VMs for AI jobs](../5-run/kubernetes/README.md#spot-vms-for-ai-jobs) gives the shutdown window, and a [custom ComputeClass](../5-run/kubernetes/README.md#fall-back-across-capacity-types-with-custom-computeclasses) falls back from a reservation to Flex-start, Spot and on-demand.

## In this folder

| Page | What's in it |
|---|---|
| [flex-start](./flex-start/) | Dynamic Workload Scheduler and Flex-start: how it queues, how it works with GKE, supported machine types, data residency |
| [calendar-mode](./calendar-mode/) | Calendar mode future reservations: sizes, lead times, the availability check and Calendar zone discovery |
| [spot](./spot/) | Spot VMs: the Capacity Advisor for Spot API and keeping training alive through preemption |
| [quota.md](./quota.md) | The quota each option uses, how to view it, raise it and alert on it |
| [reservation-placement.md](./reservation-placement.md) | How VMs use a reservation: affinity, machine topology, dense allocation and topology-aware scheduling |
