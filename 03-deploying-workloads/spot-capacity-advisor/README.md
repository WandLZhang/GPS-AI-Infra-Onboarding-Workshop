# Spot Capacity Advisor — Picking the Best Zone, Region & Machine for Spot

> Spot VMs are the cheapest GPU/TPU capacity on Google Cloud (up to ~91% off on-demand), but they are preemptible and never guaranteed. The **Capacity Advisor for Spot API** tells you *where* (region/zone) and *with what shape* (machine type) a Spot request is most likely to succeed right now — and roughly how long it's likely to run before preemption — so you place Spot workloads on a live signal instead of guesswork.

---

## 📋 Table of Contents

1. [When to use it](#1-when-to-use-it)
2. [Prerequisites & access](#2-prerequisites--access)
3. [The two scores](#3-the-two-scores)
4. [Calling the API](#4-calling-the-api)
5. [Worked examples](#5-worked-examples)
6. [Pattern: drive a scheduler from live obtainability](#6-pattern-drive-a-scheduler-from-live-obtainability)
7. [Why obtainability ≠ a free-capacity snapshot](#7-why-obtainability--a-free-capacity-snapshot)
8. [Limitations](#8-limitations)
9. [References](#9-references)

---

## 1. When to use it

If you consume Spot through **Managed Instance Groups (MIGs)**, **GKE**, or **bulk instance creation**, those products already use this guidance internally to place your VMs — you usually don't need to call the API yourself. Reach for the API directly when:

- **Region selection** — your workload can run in any of several regions and you want to pick the best one *now*.
- **Zone selection** — a single-zone workload (e.g. gang-scheduled training) and you need the best zone in a region.
- **Machine-type selection** — you're flexible across shapes (e.g. `a3-highgpu-8g` vs `a3-megagpu-8g`) and want the most obtainable one.
- **Custom / third-party schedulers** — you have your own ranking logic (e.g. Slurm nodeset weights) and want a "quality of Spot" signal to feed it.

> It is an **operational placement** tool, not a long-term capacity-planning tool. For planning, talk to your account team.

---

## 2. Prerequisites & access

1. **Enable the Compute Engine API** on your project.
2. **IAM**: you need `compute.advice.capacity` — already included in common roles like `roles/compute.viewer` and `roles/compute.admin`.
3. **Endpoint** (Compute **beta**):
   ```
   POST https://compute.googleapis.com/compute/beta/projects/{PROJECT}/regions/{REGION}/advice/capacity
   ```
   A `gcloud` surface also exists: [`gcloud alpha compute advice capacity`](https://docs.cloud.google.com/sdk/gcloud/reference/alpha/compute/advice/capacity).

---

## 3. The two scores

Both scores are **comparable across locations and machine types**; higher is better.

| Score | Range | Meaning |
|---|---|---|
| **Obtainability** | `0.0`–`1.0` | Likelihood of provisioning the **full** requested number of Spot VMs. |
| **Estimated Uptime** | `60s` / `600s` / `3600s` | Minimum duration most of the VMs are likely to run before preemption (1 min / 10 min / 60 min). |

**Interpreting obtainability:**

| Band | Value | Action |
|---|---|---|
| High | `0.7–1.0` | Proceed — good time to request the full quantity. |
| Medium | `0.4–0.7` | Proceed if you can accept partial fulfillment. |
| Low | `0.0–0.4` | Reduce the count, try another zone/machine type, or use a guaranteed model (Flex-start / on-demand / reservation). |

Estimated Uptime is a best-effort floor, not a guarantee or a max runtime — preemption can still happen earlier, and VMs may run longer.

---

## 4. Calling the API

Pick the best **single zone** in a region for 100 Spot `a3-highgpu-8g`:

```bash
PROJECT=my-project; REGION=us-central1; TOKEN=$(gcloud auth print-access-token)
curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  "https://compute.googleapis.com/compute/beta/projects/${PROJECT}/regions/${REGION}/advice/capacity" \
  -d '{
    "instanceProperties": {"scheduling": {"provisioningModel": "SPOT"}},
    "instanceFlexibilityPolicy": {"instanceSelections": {"sel": {"machineTypes": ["a3-highgpu-8g"]}}},
    "distributionPolicy": {"targetShape": "ANY_SINGLE_ZONE"},
    "size": 100
  }'
```

Response (shape):

```json
{
  "recommendations": [{
    "scores": { "obtainability": 0.9, "estimatedUptime": "3600s" },
    "shards": [{ "zone": ".../zones/us-central1-c", "machineType": "a3-highgpu-8g",
                 "instanceCount": 100, "provisioningModel": "SPOT" }]
  }]
}
```

- `targetShape: ANY_SINGLE_ZONE` → all VMs in one zone (it picks the best).
- `targetShape: ANY` → may split across zones in the region (see the `shards` list).
- Constrain candidate zones by adding `distributionPolicy.zones: [{"zone": "zones/us-central1-a"}, ...]`.

---

## 5. Worked examples

**Best region** — the API is per-region, so call each region and compare:

```bash
for REGION in us-central1 us-east1; do
  printf "%s -> " "$REGION"
  curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "https://compute.googleapis.com/compute/beta/projects/$PROJECT/regions/$REGION/advice/capacity" \
    -d '{"instanceProperties":{"scheduling":{"provisioningModel":"SPOT"}},
         "instanceFlexibilityPolicy":{"instanceSelections":{"s":{"machineTypes":["a3-highgpu-8g"]}}},
         "distributionPolicy":{"targetShape":"ANY"},"size":100}' \
    | jq -c '.recommendations[0].scores'
done
```

Pick the region with the higher obtainability (break ties on estimated uptime).

**Best machine type** — issue one call per candidate shape (same region/zones) and compare the scores; choose the shape that meets your obtainability vs. uptime trade-off.

---

## 6. Pattern: drive a scheduler from live obtainability

Custom schedulers can rank placement candidates by live obtainability each morning. Minimal example — score a set of `(machine_type, zone)` candidates and print them best-first:

```bash
PROJECT=my-project; TOKEN=$(gcloud auth print-access-token)
CANDIDATES=( "a3-highgpu-8g:us-central1-a" "a3-highgpu-8g:us-east4-b" "a3-megagpu-8g:us-central1-c" )
for c in "${CANDIDATES[@]}"; do
  mt=${c%%:*}; zone=${c##*:}; region=${zone%-*}
  read ob up < <(curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "https://compute.googleapis.com/compute/beta/projects/$PROJECT/regions/$region/advice/capacity" \
    -d '{"instanceProperties":{"scheduling":{"provisioningModel":"SPOT"}},
         "instanceFlexibilityPolicy":{"instanceSelections":{"s":{"machineTypes":["'$mt'"]}}},
         "distributionPolicy":{"zones":[{"zone":"zones/'$zone'"}],"targetShape":"ANY_SINGLE_ZONE"},"size":1}' \
    | jq -r '"\(.recommendations[0].scores.obtainability) \(.recommendations[0].scores.estimatedUptime|rtrimstr("s"))"')
  printf "%s\t%s\tobtain=%s uptime=%ss\n" "$mt" "$zone" "$ob" "$up"
done | sort -t= -k2 -rn
```

Feed that ordering into your placement logic — for example **Slurm `node_conf.Weight`** (lower = higher priority), MIG distribution policy, or GKE custom compute-class priorities. A worked, end-to-end Slurm example (multi-region GPU cluster that re-weights nodesets from this API) lives in
[**WandLZhang/slurm-multi-region-gpu-public**](https://github.com/WandLZhang/slurm-multi-region-gpu-public) → `scripts/spot-obtainability-poll.sh` + `docs/capacity_strategy.md`.

> Keep the **GPU-class preference separate from obtainability**: re-rank zones *within* each SKU tier, not globally, so a more-obtainable lower-class GPU doesn't silently outrank the class you actually want.

---

## 7. Why obtainability ≠ a free-capacity snapshot

A common mistake is to place Spot by "how many chips look free." A zone can show plenty of idle GPUs and still **stock out** on a real Spot request — because free-now says nothing about churn/preemption pressure. In testing, a zone the API scored **0.9** provisioned the full request, while a **same-SKU** zone it scored **0.1 / 60s** stocked out immediately — even though a raw free-capacity view there looked plentiful. The API's obtainability + estimated uptime track **actual provisioning success and preemption risk**, which is the signal you actually want for placement.

---

## 8. Limitations

- **Beta endpoint.** Use `compute/beta`. The `gcloud alpha` command rides the alpha endpoint, which requires separate Compute alpha allowlisting.
- **`size` is capped at 1–1000 VMs** per request. Query a representative slice and extrapolate for larger fleets.
- **No TPUs.** TPU machine series (`ct*`) are rejected; this API is GPU/CPU Spot only today.
- **Ignores quota.** A high obtainability score does **not** mean you hold quota for the shape — check quota separately.
- **No N1+GPU or custom machine types** during preview; machine types that require choosing local SSD counts are unsupported.
- **Honors org `resourceLocations` policy** — regions outside your org's allowed locations aren't queryable.
- **Best-effort.** Even a high score can't prevent a stockout or preemption if demand spikes after the recommendation.

---

## 9. References

- [`gcloud alpha compute advice capacity`](https://docs.cloud.google.com/sdk/gcloud/reference/alpha/compute/advice/capacity)
- [Spot VMs overview](https://cloud.google.com/compute/docs/instances/spot)
- [Using Spot VMs in GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/spot-vms) · [Create a MIG with Spot VMs](https://cloud.google.com/compute/docs/instance-groups/create-mig-with-preemptible-vms)
- Capacity acquisition models overview: [`../dws/`](../dws/) · Accelerator selection: [`../../01-foundational-tools/accelerator-guide/`](../../01-foundational-tools/accelerator-guide/)
- End-to-end Slurm example: [WandLZhang/slurm-multi-region-gpu-public](https://github.com/WandLZhang/slurm-multi-region-gpu-public)
