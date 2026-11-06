# Capacity: get GPUs and TPUs

How you get accelerators is a separate choice from where you run them. Pick a capacity option here, then a platform in [workloads](../workloads/).

## The options

| Option | What you get | Page |
|---|---|---|
| On-demand | Immediate, full price, if available | [Prices by machine type](./dws/README.md#prices-by-machine-type) |
| Reservations | Guaranteed, committed, long-term | [DWS](./dws/README.md#where-dws-fits-in-the-gpu-acquisition-strategy) |
| Flex-start | Queued, up to 53% discount, up to 7 days | [DWS](./dws/), and [flex-start-mig](./flex-start-mig/) for Flex-start VMs through managed instance groups |
| Calendar mode | Guaranteed start time, committed cost | [future-reservations](./future-reservations/), and [Check Calendar availability](./dws/README.md#check-calendar-availability-before-you-book) |
| Spot | Cheapest, preemptible, no guarantee | [spot-capacity-advisor](./spot-capacity-advisor/), which ranks zones for Spot |

[Quota and pricing](./dws/README.md#7-quota--pricing) lists which quota each option uses.

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

For TPUs and the current list, ask your harness the Flex-start question below.

## Look up facts that change

Prices and zones change. This repo dates the numbers it prints. Get the current ones here:

| Fact | Get it now |
|---|---|
| Price of a machine type | `gcp-pricing accelerator --filter <machine-type>` or `gcp-pricing tpu --filter <generation>` ([gcp-pricing](https://github.com/WandLZhang/gcp-pricing-scraper)) |
| Which machine types take Flex-start and Calendar mode | Ask your harness: "Which GPU and TPU machine types support Dynamic Workload Scheduler flex-start and calendar mode?" |
| Zones that take Calendar requests | [`discover-calendar-zones.py`](./dws/discover-calendar-zones.py) |
| Spot obtainability by zone | [Capacity Advisor for Spot](./spot-capacity-advisor/) |
| GPU zones | [GPU regions and zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones) |
| TPU zones | [TPU regions and zones](https://docs.cloud.google.com/tpu/docs/regions-zones) |

[Ask your harness](../harness-setup/README.md#ask-your-harness) lists more questions the docs MCP answers.

## Spray requests across zones and poll for capacity

These scripts live in [slurm-multi-region-gpu-public](https://github.com/WandLZhang/slurm-multi-region-gpu-public):

- [spot-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-spray.sh)
- [flex-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-spray.sh)
- [flex-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-poll.sh)
- [calendar-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/calendar-poll.sh)
- [spot-obtainability-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-obtainability-poll.sh)

## Keep a training job alive on Spot

See [Training on Spot](./spot-capacity-advisor/README.md#keep-a-training-job-alive-on-spot), and [Spot VMs on GKE](../workloads/gke/README.md#spot-vms-for-ai-jobs) for the shutdown window. On GKE, a [custom ComputeClass](../workloads/gke/README.md#fall-back-across-capacity-types-with-custom-computeclasses) falls back from a reservation to Flex-start, Spot and on-demand.

## In this folder

| Folder | What's in it |
|---|---|
| [dws](./dws/) | Dynamic Workload Scheduler: Flex-start and Calendar mode, prices, quota, data residency and Calendar zone discovery |
| [flex-start-mig](./flex-start-mig/) | Flex-start VMs through managed instance group resize requests |
| [future-reservations](./future-reservations/) | Calendar mode future reservations with a guaranteed start time |
| [spot-capacity-advisor](./spot-capacity-advisor/) | The Capacity Advisor for Spot API: best zone, region and machine for Spot |
