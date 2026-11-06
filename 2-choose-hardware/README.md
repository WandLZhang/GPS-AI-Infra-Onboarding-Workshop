# Choose and Size a GPU or TPU

> How to pick the right GPU or TPU for your workload, and size it correctly (memory, shapes, node count).

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Accelerator Catalog — Complete Specs at a Glance](#2-accelerator-catalog--complete-specs-at-a-glance)
3. [Picking the Right Accelerator for the Right Job](#3-picking-the-right-accelerator-for-the-right-job)
4. [Sizing Your Accelerator — Memory, Shapes & Node Count](#4-sizing-your-accelerator--memory-shapes--node-count)
5. [References](#5-references)

Porting a model to TPU, and benchmarking it against a GPU, has its own page: [port-to-tpu.md](./port-to-tpu.md). Which capacity options each machine type takes is in [get capacity](../3-get-capacity/README.md#which-machine-types-take-which-option). Reservation affinity and dense placement are in [reservations](../3-get-capacity/reservations.md). Checkpointing is in [run](../5-run/checkpointing.md).

---

## 1. Overview

Choosing the right accelerator is the **single most impactful decision** you make before deploying an AI workload on Google Cloud. It determines:

- **Cost** — GPU hourly rates vary by 10× or more across machine types
- **Performance** — the wrong accelerator can leave your workload memory-bound, compute-bound, or network-bound
- **Availability** — newer/larger accelerators are harder to obtain; your consumption model (reservation, DWS, Spot) depends on the machine type
- **Time-to-result** — an undersized cluster doubles your wall-clock time; an oversized cluster wastes budget

This guide helps you make that decision systematically. Use it **before** requesting quota, making reservations, or deploying workloads via [Cluster Toolkit](../5-run/kubernetes/cluster-toolkit/README.md) or [DWS](../3-get-capacity/flex-start/README.md).

### Learn how accelerators behave

- Read [How to Scale Your Model](https://jax-ml.github.io/scaling-book): the parts on rooflines, TPUs, sharded matmuls and transformers. GPU users add the GPU part.
- For an overview of Google Cloud's AI infrastructure, watch [The future of AI infrastructure](https://www.youtube.com/watch?v=PJQPMv8TqLA) and [AI Hypercomputer: resilient AI infrastructure at scale](https://www.youtube.com/watch?v=cvpasuzUB0Q) (Google Cloud Next '26).
- For what's new in TPUs, see [Cloud TPU generations](#cloud-tpu-generations).

The steps around this one are in the [journey map](../README.md#the-journey).

---

## 2. Accelerator Catalog — Complete Specs at a Glance

### Current-Generation GPU Machine Types

| Machine Type | GPU Model | GPUs/VM | GPU Mem/GPU | Total GPU Mem | vCPUs | Instance Mem (GB) | Network BW (Gbps) | NVLink BW/GPU | Local SSD (GiB) | CPU Platform |
|---|---|---|---|---|---|---|---|---|---|---|
| **A4X Max** | NVIDIA GB300 (B300) | 4 | 279 GB HBM3e | 1,116 GB | 144 | 960 | 3,600 | 1,800 GB/s | 12,000 | NVIDIA Grace (Arm) |
| **A4X** | NVIDIA GB200 (B200) | 4 | 186 GB HBM3e | 744 GB | 140 | 884 | 2,000 | 1,800 GB/s | 12,000 | NVIDIA Grace (Arm) |
| **A4** | NVIDIA B200 | 8 | 180 GB HBM3e | 1,440 GB | 224 | 3,968 | 3,600 | 1,800 GB/s | 12,000 | Intel Emerald Rapids |
| **A3 Ultra** | NVIDIA H200 | 8 | 141 GB HBM3e | 1,128 GB | 224 | 2,952 | 3,600 | 900 GB/s | 12,000 | Intel Emerald Rapids |
| **A3 Mega** | NVIDIA H100 | 8 | 80 GB HBM3 | 640 GB | 208 | 1,872 | 1,800 | 450 GB/s | 6,000 | Intel Sapphire Rapids |
| **A3 High** (`8g`) | NVIDIA H100 | 8 | 80 GB HBM3 | 640 GB | 208 | 1,872 | 1,000 | 450 GB/s | 6,000 | Intel Sapphire Rapids |
| **A3 Edge** | NVIDIA H100 | 8 | 80 GB HBM3 | 640 GB | 208 | 1,872 | 400–600 | 450 GB/s | 6,000 | Intel Sapphire Rapids |

### Fractional & Smaller GPU Shapes

| Machine Type | GPU Model | GPUs/VM | GPU Mem/GPU | Total GPU Mem | vCPUs | Instance Mem (GB) | Network BW (Gbps) | Local SSD (GiB) |
|---|---|---|---|---|---|---|---|---|
| **A3 High** (`4g`) | NVIDIA H100 | 4 | 80 GB HBM3 | 320 GB | 104 | 936 | 100 | 3,000 |
| **A3 High** (`2g`) | NVIDIA H100 | 2 | 80 GB HBM3 | 160 GB | 52 | 468 | 50 | 1,500 |
| **A3 High** (`1g`) | NVIDIA H100 | 1 | 80 GB HBM3 | 80 GB | 26 | 234 | 25 | 750 |
| **G4** (`8 GPU`) | NVIDIA RTX PRO 6000 | 8 | 96 GB GDDR7 | 768 GB | 384 | 1,440 | 400 | 12,000 |
| **G4** (`4 GPU`) | NVIDIA RTX PRO 6000 | 4 | 96 GB GDDR7 | 384 GB | 192 | 720 | 200 | 6,000 |
| **G4** (`2 GPU`) | NVIDIA RTX PRO 6000 | 2 | 96 GB GDDR7 | 192 GB | 96 | 360 | 100 | 3,000 |
| **G4** (`1 GPU`) | NVIDIA RTX PRO 6000 | 1 | 96 GB GDDR7 | 96 GB | 48 | 180 | 50 | 1,500 |
| **G4** (`½ GPU`) | NVIDIA RTX PRO 6000 | ½ | — | 48 GB | 24 | 90 | 20 | 750 |
| **G4** (`¼ GPU`) | NVIDIA RTX PRO 6000 | ¼ | — | 24 GB | 12 | 45 | 20 | 375 |
| **G4** (`⅛ GPU`) | NVIDIA RTX PRO 6000 | ⅛ | — | 12 GB | 6 | 22 | 20 | 0 |

### Previous-Generation Machine Types

| Machine Type | GPU Model | GPUs/VM | GPU Mem/GPU | Total GPU Mem | vCPUs | Instance Mem (GB) | Network BW (Gbps) |
|---|---|---|---|---|---|---|---|
| **A2 Ultra** (`8g`) | NVIDIA A100 80 GB | 8 | 80 GB HBM2e | 640 GB | 96 | 1,360 | 100 |
| **A2 Ultra** (`4g`) | NVIDIA A100 80 GB | 4 | 80 GB HBM2e | 320 GB | 48 | 680 | 50 |
| **A2 Ultra** (`2g`) | NVIDIA A100 80 GB | 2 | 80 GB HBM2e | 160 GB | 24 | 340 | 32 |
| **A2 Ultra** (`1g`) | NVIDIA A100 80 GB | 1 | 80 GB HBM2e | 80 GB | 12 | 170 | 24 |
| **A2 Standard** (`16g`) | NVIDIA A100 40 GB | 16 | 40 GB HBM2 | 640 GB | 96 | 1,360 | 100 |
| **A2 Standard** (`8g`) | NVIDIA A100 40 GB | 8 | 40 GB HBM2 | 320 GB | 96 | 680 | 100 |
| **A2 Standard** (`4g`) | NVIDIA A100 40 GB | 4 | 40 GB HBM2 | 160 GB | 48 | 340 | 50 |
| **A2 Standard** (`2g`) | NVIDIA A100 40 GB | 2 | 40 GB HBM2 | 80 GB | 24 | 170 | 32 |
| **A2 Standard** (`1g`) | NVIDIA A100 40 GB | 1 | 40 GB HBM2 | 40 GB | 12 | 85 | 24 |
| **G2** (`8 GPU`) | NVIDIA L4 | 8 | 24 GB GDDR6 | 192 GB | 96 | 384 | 100 |
| **G2** (`4 GPU`) | NVIDIA L4 | 4 | 24 GB GDDR6 | 96 GB | 48 | 192 | 50 |
| **G2** (`2 GPU`) | NVIDIA L4 | 2 | 24 GB GDDR6 | 48 GB | 24 | 96 | 32 |
| **G2** (`1 GPU`) | NVIDIA L4 | 1 | 24 GB GDDR6 | 24 GB | 4–32 | 16–128 | 10–32 |

### Cloud TPU generations

| | TPU7x (Ironwood) | v6e (Trillium) | v5p | v5e |
|---|---|---|---|---|
| Peak BF16 per chip | 2,307 TFLOPs | 918 TFLOPs | 459 TFLOPs | 197 TFLOPs |
| Peak FP8 per chip | 4,614 TFLOPs | 918 TFLOPs | 459 TFLOPs | not listed |
| HBM per chip | 192 GiB | 32 GB | 95 GiB | 16 GB |
| HBM bandwidth per chip | 7,380 GBps | 1,638 GBps | 2,765 GBps | 800 GiBps |
| TensorCores / SparseCores per chip | 2 / 4 | 1 / 2 | 2 / 4 | not listed |
| Matrix unit (MXU) | 256 x 256 | 256 x 256 | 128 x 128 | 128 x 128 |
| Chips per pod | 9,216 | 256 | 8,960 | 256 |
| ICI bandwidth per chip | 1,200 GBps | 800 GBps | 1,200 GBps | 400 GBps |

Sources: the [TPU7x](https://docs.cloud.google.com/tpu/docs/tpu7x), [v6e](https://docs.cloud.google.com/tpu/docs/v6e), [v5p](https://docs.cloud.google.com/tpu/docs/v5p) and [v5e](https://docs.cloud.google.com/tpu/docs/v5e) pages and [TPU system architecture](https://docs.cloud.google.com/tpu/docs/system-architecture-tpu-vm), all last updated 2026-10-13. Units follow each page. Google engineers walk through the 9,216-chip Ironwood pod in their [Hot Chips 2025 talk](https://www.youtube.com/watch?v=Zy3LfsAxc64).

What's new in TPUs: [Inside the 8th-generation TPU](https://cloud.google.com/blog/products/compute/tpu-8t-and-tpu-8i-technical-deep-dive) and [Unlock high-performance AI with the new Cloud TPU experience](https://www.youtube.com/watch?v=fUELeEaTLVs) (Google Cloud Next '26).

### Key Takeaways from the Catalog

| Question | Answer |
|---|---|
| **Most GPU memory per VM?** | A4 — 1,440 GB (8 × 180 GB B200) |
| **Most GPU memory per GPU?** | A4X Max — 279 GB per GB300 GPU |
| **Highest network bandwidth?** | A4X Max — 3,600 Gbps (RoCE, CX-8 SuperNICs) |
| **Highest NVLink bandwidth?** | A4X Max, A4X, A4 — 1,800 GB/s per GPU |
| **Largest NVLink domain?** | A4X Max, A4X — 72 GPUs (18 instances) in one NVLink domain |
| **Cheapest GPU option?** | G2 (L4) — best price-performance for inference |
| **Fractional GPU support?** | G4 (⅛, ¼, ½ GPU shapes), A3 High (1g, 2g, 4g) |

---

## 3. Picking the Right Accelerator for the Right Job

### Decision Flowchart

```
                          What is your primary workload?
                                     │
            ┌────────────┬───────────┼───────────┬──────────────┐
            │            │           │           │              │
       Pre-training   Fine-tuning  Inference    HPC      Graphics/
       Foundation     Models       / Serving              Rendering
       Models                                             
            │            │           │           │              │
            ▼            ▼           ▼           ▼              ▼
     How large is    How large    Single or   GPU-heavy?    G4, G2,
     the model?      is the       multi-host?              or N1+T4
            │        model?           │           │
       ┌────┴────┐    │         ┌────┴────┐      │
       │         │    │         │         │      │
    Frontier  Large   │      Single    Multi    Any A-series
    (100B+)  (10-100B)│      host      host     or G-series
       │         │    │         │         │
       ▼         ▼    ▼         ▼         ▼
    A4X Max   A4     A4X Max   A4       A4X Max
    A4X       A3     A4X       A3 Ultra A4X
    A4        Ultra  A4        A3 High  A4
    A3 Ultra  A3     A3 Ultra           A3 Ultra
    A3 Mega   Mega   A3 Mega            A3 Mega
              A3     A3 High
              High   G4
```

### Workload-to-Accelerator Recommendation Matrix

| Workload | Recommended Machine Types | Why |
|---|---|---|
| **Frontier model pre-training** (100B+ params, weeks/months) | A4X Max, A4X, A4, A3 Ultra | Largest GPU memory (180–279 GB/GPU), highest NVLink bandwidth (1,800 GB/s), RoCE networking for multi-node scaling. A4X Max/A4X offer 72-GPU NVLink domains for massive model parallelism. |
| **Large model pre-training** (10–100B params, days/weeks) | A4, A3 Ultra, A3 Mega, A3 High | High GPU memory (80–180 GB/GPU), strong multi-node networking. A3 Mega is widely available and well-suited. |
| **Fine-tuning large models** (LoRA, full fine-tune, RLHF) | A4X Max, A4X, A4, A3 Ultra, A3 Mega, A3 High, G4 | Memory needs depend on technique: full fine-tuning needs ~3× model size; LoRA/QLoRA can fit on smaller GPUs. G4 with 96 GB/GPU is cost-effective for mid-size models. |
| **Multi-host inference** (frontier/large models) | A4X Max, A4X, A4, A3 Ultra, A3 Mega | Model sharded across multiple nodes — need high inter-node bandwidth. |
| **Single-host inference** (models that fit on one node) | A4, A3 Ultra, A3 High, G4, G2 | Optimize for GPU memory to fit the model and cost-per-query. G4 offers 96 GB/GPU at lower cost than A-series. G2 (L4, 24 GB) is cheapest for small models. |
| **Small/medium ML** (CV, NLP < 10B params) | G4, G2 | Best price-performance. G4 with FP4 support and 96 GB memory handles most use cases. G2 (L4) for budget-conscious workloads. |
| **HPC** (simulation, molecular dynamics, CFD) | Any A-series or G-series | Depends on GPU compute intensity. Use A-series for heavy GPU compute, G-series for lighter GPU + strong CPU. |
| **Graphics / rendering / virtual desktops** | G4, G2, N1+T4 | G4 has RTX PRO 6000 with RT cores and DLSS 4. G2 has L4 with RT cores. Both support NVIDIA vWS. |

### Detailed Selection Criteria

When the recommendation matrix doesn't give a clear answer, use these criteria to break the tie:

| Criterion | Favors | Details |
|---|---|---|
| **Model parameter count** | Larger GPU memory | See [Section 4](#4-sizing-your-accelerator--memory-shapes--node-count) for sizing formulas |
| **Training duration** | More stable accelerators | Jobs > 7 days need reservations (DWS max is 7 days). A4X Max/A4X require reservations. |
| **Budget sensitivity** | Smaller / older GPUs | G2 (L4) or A2 Standard (A100 40 GB) offer best price-per-FLOP for moderate workloads |
| **Availability urgency** | Widely available types | G2, A2 Standard are most available. A4X Max/A4X are newest and most constrained |
| **Multi-node scaling** | High-bandwidth networking | A4X Max (3,600 Gbps), A4/A3 Ultra (3,600 Gbps) for strong scaling. A3 High (1,000 Gbps) for modest scaling |
| **Data residency** | US zones with GPU availability | See [DWS guide: data residency](../3-get-capacity/flex-start/README.md#5-data-residency--compliance-considerations) for zone availability by GPU type |
| **Fractional GPU needs** | G4 or A3 High | G4 offers ⅛, ¼, ½ GPU shapes. A3 High offers 1, 2, 4, 8 GPU shapes |

### Double-precision (FP64) science codes

B300 (Blackwell Ultra) has a small fraction of the FP64 throughput of B200. NVIDIA's [HGX spec table](https://www.nvidia.com/en-us/data-center/hgx/) lists FP64 at 10 TFLOPS for HGX B300 and 296 TFLOPS for HGX B200, both 8-GPU systems (read 2026-10-15). Run CFD, climate, molecular dynamics and other double-precision codes on A4 (B200), or on H4D CPUs for MPI codes. Don't put them on A4X Max, whose GB300 uses the same Blackwell Ultra GPU.

---

## 4. Sizing Your Accelerator — Memory, Shapes & Node Count

### GPU Memory Sizing

GPU memory (HBM) is typically the binding constraint. Your model, optimizer states, gradients, and activations must all fit in GPU memory (possibly distributed across GPUs via model parallelism).

#### Memory Estimation Rules of Thumb

| Scenario | Approximate GPU Memory Required | Formula |
|---|---|---|
| **FP16/BF16 inference** (weights only) | ~2 GB per billion parameters | `params_B × 2 GB` |
| **FP8/INT8 inference** (quantized) | ~1 GB per billion parameters | `params_B × 1 GB` |
| **FP4/INT4 inference** (heavily quantized) | ~0.5 GB per billion parameters | `params_B × 0.5 GB` |
| **FP16/BF16 training** (weights + optimizer + gradients + activations) | ~18–20 GB per billion parameters (with Adam) | `params_B × 18 GB` (approx.) |
| **LoRA fine-tuning** (frozen base + adapters) | ~2–4 GB per billion parameters (base) + adapters | `params_B × 2 GB` + small overhead |
| **QLoRA fine-tuning** (4-bit base + LoRA) | ~0.5–1 GB per billion parameters (base) + adapters | `params_B × 0.75 GB` + small overhead |

> **Note:** These are approximations. Actual memory usage depends on batch size, sequence length, activation checkpointing, tensor parallelism degree, and framework. Always benchmark with your actual workload.

#### Sizing Examples

| Model | Params | Inference (BF16) | Inference (INT8) | Training (BF16 + Adam) | Recommended Machine Types |
|---|---|---|---|---|---|
| **Llama 3.3 70B** | 70B | ~140 GB | ~70 GB | ~1,260 GB | Inference: A3 Ultra (1 node), A3 High 2g (INT8). Training: A4 (1 node) or A3 Ultra × 2 |
| **Llama 4 Maverick** | 400B (17B active MoE) | ~800 GB (full) / ~34 GB (active) | ~400 GB (full) | ~7,200 GB | Inference: A4 (1 node, INT8 full). Training: A4X Max/A4X cluster |
| **Gemma 3 27B** | 27B | ~54 GB | ~27 GB | ~486 GB | Inference: G4 1-GPU (INT8) or A3 High 1g (BF16). Training: A3 Mega 1 node |
| **Gemma 3 4B** | 4B | ~8 GB | ~4 GB | ~72 GB | Inference: G2 1-GPU or G4 ⅛. Training: G4 1-GPU or A3 High 1g |
| **Stable Diffusion XL** | 3.5B | ~7 GB | ~3.5 GB | ~63 GB | Inference: G2 1-GPU. Training: G4 1-GPU |
| **Custom 1T model** | 1,000B | ~2,000 GB | ~1,000 GB | ~18,000 GB | Training: A4X Max cluster (many nodes, 72-GPU NVLink domains) |

### Available Machine Shapes

Not every workload needs 8 GPUs. Google Cloud offers **fractional shapes** to right-size your deployment:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                      GPU Shapes Available on Google Cloud                    │
│                                                                              │
│  A-Series (Training/Inference):                                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                                       │
│  │ 1 GPU│ │ 2 GPU│ │ 4 GPU│ │ 8 GPU│   A3 High: all four shapes            │
│  └──────┘ └──────┘ └──────┘ └──────┘   A3 Mega/Ultra/Edge, A4: 8 GPU only  │
│                                         A4X Max/A4X: 4 GPU only             │
│                                                                              │
│  G-Series (Inference/Graphics):                                              │
│  ┌───┐ ┌───┐ ┌───┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                    │
│  │⅛  │ │¼  │ │½  │ │ 1 GPU│ │ 2 GPU│ │ 4 GPU│ │ 8 GPU│  G4: all shapes    │
│  └───┘ └───┘ └───┘ └──────┘ └──────┘ └──────┘ └──────┘  G2: 1-8 GPU       │
│                                                                              │
│  A2 Series (Previous Gen):                                                   │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌───────┐                             │
│  │ 1 GPU│ │ 2 GPU│ │ 4 GPU│ │ 8 GPU│ │16 GPU │  A2 Std: 1/2/4/8/16       │
│  └──────┘ └──────┘ └──────┘ └──────┘ └───────┘  A2 Ultra: 1/2/4/8         │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### Shape Selection Guidelines

| Scenario | Recommended Shape | Why |
|---|---|---|
| **Small model inference** (< 24 GB) | G2 1-GPU or G4 ⅛/¼ | Cheapest option; model fits in one GPU |
| **Medium model inference** (24–80 GB) | G4 1-GPU or A3 High 1g | G4 has 96 GB/GPU; A3 High 1g has 80 GB |
| **Large model inference** (80–320 GB) | A3 High 4g or A3 Ultra | Distribute across 4 GPUs (TP=4) on A3 High, or use A3 Ultra |
| **Single-node fine-tuning** (LoRA, small models) | A3 High 1g/2g or G4 1-GPU | Right-size to model; avoid paying for unused GPUs |
| **Multi-GPU training** (data parallelism) | A3 Mega 8g or A3 Ultra 8g | Need all-to-all NVLink for gradient synchronization |
| **Large-scale distributed training** | A4X Max, A4X, or A4 | 72-GPU NVLink domains (A4X), highest bandwidth |

### Scaling: Single-Host vs Multi-Host

```
                    Does your model + optimizer + gradients
                    fit in total GPU memory of ONE machine?
                                   │
                        ┌──────────┴──────────┐
                       Yes                    No
                        │                      │
                  Single-host             Multi-host
                        │                      │
              ┌─────────┴─────────┐    Use model parallelism
              │                   │    (tensor + pipeline)
         Data parallelism     Single GPU        │
         (multiple GPUs,    (model fits in   How many nodes?
          same model copy)   1 GPU memory)        │
              │                   │         total_mem_needed
              │                   │         ──────────────── = min nodes
              │                   │         gpu_mem_per_node
              │                   │
         Pick shape with     Pick smallest
         enough GPUs         shape that fits
```

#### Multi-Node Scaling Considerations

| Factor | Guidance |
|---|---|
| **Network bandwidth** | For strong scaling (linear speedup), you need high inter-node bandwidth. Use A4X Max (3,600 Gbps), A4/A3 Ultra (3,600 Gbps), or A3 Mega (1,800 Gbps). |
| **Communication overhead** | Increases with node count. At 64+ nodes, communication can dominate compute. Use pipeline parallelism to reduce all-reduce volume. |
| **NVLink domains** | A4X Max/A4X provide 72-GPU NVLink domains (18 instances). Within a domain, all GPUs communicate at NVLink speed (1,800 GB/s). Use for largest models. |
| **Topology-Aware Scheduling** | On GKE, use [TAS](https://cloud.google.com/ai-hypercomputer/docs/workloads/schedule-gke-workloads-tas) to schedule pods on topologically-close nodes. |
| **Dense allocation** | Request dense allocation for multi-node training to minimize network hops. All A-series 8-GPU types support this via Cluster Toolkit / reservations. |

### Size a job before you ask for chips

- Training a dense model takes about 6 x parameters x tokens FLOPs, plus an attention term that grows with sequence length. For a mixture-of-experts model, count active parameters.
- Wall-clock time is that FLOP count divided by (chips x peak FLOP/s per chip x MFU). We plan with 30% to 40% MFU until we've measured our own.
- For serving, prefill is compute-bound and decode is memory-bandwidth-bound, so size them separately.
- Round up to a real slice size, because TPU slices come in fixed sizes.
- On TPU, fit matrix dimensions to the MXU: [TPU: fit matmuls to the MXU](../6-debug-and-profile/README.md#tpu-fit-matmuls-to-the-mxu).
- [How to Scale Your Model](https://jax-ml.github.io/scaling-book) works through all of this for TPUs and GPUs.

---

## 5. References

### Google Cloud Documentation

- [Accelerator-Optimized Machine Family](https://cloud.google.com/compute/docs/accelerator-optimized-machines) — Complete specs for all GPU machine types
- [Recommended Configurations (Choose Strategy)](https://cloud.google.com/ai-hypercomputer/docs/choose-strategy) — Google's official accelerator recommendations by workload
- [Choose a Consumption Option](https://cloud.google.com/ai-hypercomputer/docs/consumption-models) — Reservation vs DWS vs Spot decision guide
- [GPU Regions and Zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones) — Availability matrix for all GPU types
- [AI Hypercomputer Overview](https://cloud.google.com/ai-hypercomputer/docs/overview) — Architecture and capabilities
- [Storage Services for AI](https://cloud.google.com/ai-hypercomputer/docs/storage) — Google's recommended storage for training/inference

### Related Sections in This Repository

- [Port a model to TPU](./port-to-tpu.md) — TorchTPU, what worked on our ports, MaxKernel and the TPU agent suite
- [Get capacity](../3-get-capacity/README.md) — Which capacity options each machine type takes, and how to choose one
- [Reservations](../3-get-capacity/reservations.md) — Reservation affinity, topology and dense allocation
- [Checkpointing](../5-run/checkpointing.md) — Strategies, storage options and frequency for checkpoints
- [Storage for AI Workloads](../4-storage-and-network/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket for training data and checkpointing
- [Debug and profile](../6-debug-and-profile/README.md) — Profile with XProf, and fit matmuls to the MXU

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. GPU specifications, availability, and pricing change frequently — always refer to the [official Google Cloud documentation](https://cloud.google.com/compute/docs/accelerator-optimized-machines) for the latest information. Memory sizing formulas are approximations; benchmark with your actual workload before making capacity commitments.
