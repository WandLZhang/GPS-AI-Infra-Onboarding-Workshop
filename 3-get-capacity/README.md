# Get capacity: GPUs and TPUs, and the quota to use them

How you get GPUs and TPUs is a separate choice from where you run them. Pick a capacity option and check your quota here, then pick a platform in [run](../5-run/).

## The options

| Option | What you get | Page |
|---|---|---|
| On-demand | Immediate, full price, if available | [Prices](../7-cost/prices.md) |
| Reservations | Guaranteed, committed, long-term | [reservations.md](./reservations.md) for affinity and dense placement |
| Flex-start | Queued, up to 53% discount, up to 7 days | [flex-start](./flex-start/), and [VMs](../5-run/vms/) for Flex-start VMs through managed instance groups |
| Calendar mode | Guaranteed start time, committed cost, 1 to 90 days | [calendar-mode](./calendar-mode/), with its [availability check](./calendar-mode/README.md#check-calendar-availability-before-you-book) |
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

Your choice of accelerator constrains which consumption models are available:

| Machine Type | Reservation (AI Hypercomputer) | Reservation (Calendar Mode, ≤90 days) | Flex-Start (DWS) | Spot |
|---|:---:|:---:|:---:|:---:|
| **A4X Max / A4X** | ✅ (required) | ❌ | ❌ | ❌ |
| **A4** | ✅ | ✅ | ✅ | ✅ |
| **A3 Ultra** | ✅ | ✅ | ✅ | ✅ |
| **A3 Mega** | ✅ | ✅ | ✅ | ✅ |
| **A3 High (8 GPU)** | ✅ | ✅ | ✅ | ✅ |
| **A3 High (1/2/4 GPU)** | ❌ | ❌ | ✅ | ✅ |
| **A3 Edge** | ✅ | ❌ | ✅ | ✅ |
| **A2** | ✅ | ✅ | ✅ | ✅ |
| **G4** | ✅ | ✅ | ✅ | ✅ |
| **G2** | ✅ | ❌ | ✅ | ✅ |

For TPUs, Calendar mode takes TPU7x, v6e and v5p ([Calendar mode](./calendar-mode/README.md#sizes-durations-and-machine-types)). For the current list, ask your harness the Flex-start question below.

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

[Ask your harness](../1-setup/README.md#ask-your-harness) lists more questions the docs MCP answers. Scripts that spray requests across zones and poll for capacity are in [examples](../8-examples/README.md#spray-requests-across-zones-and-poll-for-capacity).

## Keep a training job alive on Spot

See [Keep a training job alive on Spot](./spot/README.md#keep-a-training-job-alive-on-spot) and [checkpointing](../5-run/checkpointing.md). On GKE, [Spot VMs for AI jobs](../5-run/kubernetes/README.md#spot-vms-for-ai-jobs) gives the shutdown window, and a [custom ComputeClass](../5-run/kubernetes/README.md#fall-back-across-capacity-types-with-custom-computeclasses) falls back from a reservation to Flex-start, Spot and on-demand.

## In this folder

| Page | What's in it |
|---|---|
| [flex-start](./flex-start/) | Dynamic Workload Scheduler and Flex-start: how it queues, how it works with GKE, supported machine types, data residency |
| [calendar-mode](./calendar-mode/) | Calendar mode future reservations: sizes, lead times, the availability check and Calendar zone discovery |
| [spot](./spot/) | Spot VMs: the Capacity Advisor for Spot API and keeping training alive through preemption |
| [quota.md](./quota.md) | The quota each option uses, how to view it, raise it and alert on it |
| [reservations.md](./reservations.md) | Reservation affinity, machine topology, dense allocation and topology-aware scheduling |
