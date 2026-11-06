# Prices

Get today's price before you create anything with a GPU or TPU. Prices change, so this page dates every figure it shows.

## Get today's price

Ask your harness to run [`gcp-pricing`](https://github.com/WandLZhang/gcp-pricing-scraper), or run it yourself:

```bash
gcp-pricing accelerator --filter a3-megagpu-8g   # a GPU machine type
gcp-pricing tpu --filter Trillium                 # a TPU generation
```

The TPU filter takes the name the TPU pricing page uses: `Ironwood` for TPU7x, `Trillium` for v6e, and `v5p` or `v5e` for those. On 2026-11-06, `--filter v6e` matched nothing and `--filter Trillium` returned the v6e row. Pricing pages render in JavaScript, so a plain fetch of the page comes back empty. The CLI captures every table and region to a file you can search.

Official pages:

- [TPU pricing](https://cloud.google.com/tpu/pricing)
- [VM instance pricing](https://cloud.google.com/products/compute/pricing), which includes GPUs
- [Dynamic Workload Scheduler pricing](https://cloud.google.com/products/dws/pricing), for Flex-start and Calendar mode
- [Spot VMs pricing](https://cloud.google.com/spot-vms/pricing)

## Prices by machine type

DWS prices are well below on-demand, but the discount depends on the machine type. Public prices on 2026-10-15, USD per hour:

| Machine type (us-central1) | On-demand | Flex-start | Calendar | Spot |
|---|---|---|---|---|
| `a3-highgpu-8g` (8x H100) | $88.49 | $38.32 | $41.60 | $52.79 |
| `a3-megagpu-8g` (8x H100) | $93.40 | $40.32 | $44.00 | $50.44 |
| `a3-ultragpu-8g` (8x H200) | $84.81 | $42.40 | $59.36 | $50.80 |
| `a4-highgpu-8g` (8x B200) | none | $64.44 | $90.22 | $39.63 |
| TPU Trillium (v6e), per chip, us-east1 | $2.70 | $1.35 | $1.89 | not on the TPU pricing page |

- On H100 and H200, Flex-start costs less per hour than Spot, and Flex-start VMs aren't preempted during their run of up to 7 days.
- On B200, Spot is the cheapest option, and there's no on-demand price.
- Spot prices change. Re-pull any row before you quote it with the commands above.

## DWS Pricing

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

Budgets, alerts, billing export and committed use discounts are in [cost](./README.md).
