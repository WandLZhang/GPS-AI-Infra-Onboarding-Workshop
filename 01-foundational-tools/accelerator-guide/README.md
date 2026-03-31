# Accelerator Selection, Sizing & Checkpointing Guide

> How to pick the right GPU accelerator for your workload, size it correctly (memory, shapes, node count), understand reservation affinity and topology, and implement checkpointing to protect your training investment.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Accelerator Catalog — Complete Specs at a Glance](#2-accelerator-catalog--complete-specs-at-a-glance)
3. [Picking the Right Accelerator for the Right Job](#3-picking-the-right-accelerator-for-the-right-job)
4. [Sizing Your Accelerator — Memory, Shapes & Node Count](#4-sizing-your-accelerator--memory-shapes--node-count)
5. [Reservation Affinity & Topology](#5-reservation-affinity--topology)
6. [Checkpointing](#6-checkpointing)
7. [Consumption Model Summary](#7-consumption-model-summary)
8. [References](#8-references)

---

## 1. Overview

Choosing the right accelerator is the **single most impactful decision** you make before deploying an AI workload on Google Cloud. It determines:

- **Cost** — GPU hourly rates vary by 10× or more across machine types
- **Performance** — the wrong accelerator can leave your workload memory-bound, compute-bound, or network-bound
- **Availability** — newer/larger accelerators are harder to obtain; your consumption model (reservation, DWS, Spot) depends on the machine type
- **Time-to-result** — an undersized cluster doubles your wall-clock time; an oversized cluster wastes budget

This guide helps you make that decision systematically. Use it **before** requesting quota, making reservations, or deploying workloads via [Cluster Toolkit](../../03-deploying-workloads/gke-ai-hypercompute/cluster-toolkit/README.md) or [DWS](../../03-deploying-workloads/dws/README.md).

### Where This Guide Fits

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AI Infrastructure Onboarding Journey             │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ 1. PLAN (you are here)                                        │  │
│  │    ├── Pick accelerator type    ◄── This guide, Sections 2–3  │  │
│  │    ├── Size memory & shape      ◄── This guide, Section 4     │  │
│  │    ├── Plan checkpointing       ◄── This guide, Section 6     │  │
│  │    ├── Request quota            ◄── quota-management/         │  │
│  │    └── Make reservations        ◄── reservations/             │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │ 2. BUILD                                                      │  │
│  │    ├── Set up networking, storage, disk images                │  │
│  │    └── core-infrastructure/                                   │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │ 3. DEPLOY                                                     │  │
│  │    ├── Cluster Toolkit / XPK / Vertex AI / DWS               │  │
│  │    └── deploying-workloads/                                   │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │ 4. OPERATE                                                    │  │
│  │    └── Monitoring, dashboards, TPU observability              │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

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
| **Data residency** | US zones with GPU availability | See [DWS Guide § 9](../../03-deploying-workloads/dws/README.md#9-data-residency--compliance-considerations) for zone availability by GPU type |
| **Fractional GPU needs** | G4 or A3 High | G4 offers ⅛, ¼, ½ GPU shapes. A3 High offers 1, 2, 4, 8 GPU shapes |

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

---

## 5. Reservation Affinity & Topology

### Understanding Reservation Affinity

When creating GPU node pools or VMs, you configure **reservation affinity** to control how your workload consumes reserved capacity:

| Affinity Type | When to Use | How It Works |
|---|---|---|
| **Specific reservation** | You have a named reservation | VMs target that specific reservation. Required for A4X Max, A4X. |
| **Any matching reservation** | You have reservations and want automatic matching | VMs consume any reservation that matches the machine type and zone. |
| **No reservation** | Using DWS flex-start or Spot | VMs do not consume reservations. Required for DWS node pools. |

### Machine Type Topology

Different machine types have different physical topology characteristics that affect workload performance:

| Machine Type | NVLink Domain | GPU Interconnect Topology | Inter-Node Network | Placement |
|---|---|---|---|---|
| **A4X Max / A4X** | 72 GPUs (18 instances) | NVL72 rack-scale, NVLink-C2C | RoCE, 8-way (A4X Max) / 4-way (A4X) rail-aligned | Always dense |
| **A4** | 8 GPUs (1 instance) | All-to-all NVLink within node | RoCE, 4-way rail-aligned | Dense available |
| **A3 Ultra** | 8 GPUs (1 instance) | All-to-all NVLink within node | RoCE, 4-way rail-aligned | Dense available |
| **A3 Mega** | 8 GPUs (1 instance) | All-to-all NVLink within node | GPUDirect-TCPXO | Dense available |
| **A3 High** (8g) | 8 GPUs (1 instance) | All-to-all NVLink within node | GPUDirect-TCPX | Compact placement optional |
| **A3 High** (1g/2g/4g) | Within VM only | NVLink within allocated GPUs | Standard | Standard |
| **G4** | Within VM only | PCIe Gen 5 with P2P | Standard | Standard |
| **G2** | Within VM only | PCIe | Standard | Compact placement optional |

### Dense Allocation

For distributed training, **dense allocation** ensures your VMs are placed physically close together, minimizing network hops and latency:

- **Automatically dense:** A4X Max, A4X (always provisioned as dense NVL72 domains)
- **Dense via reservation/DWS:** A4, A3 Ultra, A3 Mega, A3 High (8g), A3 Edge — request dense allocation through reservations or DWS resize requests
- **Compact placement policy:** A3 High, A2, G2 — use `--placement-policy` to request close placement (contact your account team for A3 with max distance)

### Topology-Aware Scheduling (TAS) on GKE

For GKE clusters with A4, A3 Ultra, A3 Mega, or A4X machine types, enable [Topology-Aware Scheduling](https://cloud.google.com/ai-hypercomputer/docs/workloads/schedule-gke-workloads-tas) to let GKE's scheduler place pods on nodes that are topologically close:

```yaml
# Example: Request topology-aware scheduling in a JobSet
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  annotations:
    alpha.jobset.sigs.k8s.io/exclusive-topology: cloud.google.com/gke-topology-block
spec:
  replicatedJobs:
    - name: workers
      template:
        spec:
          template:
            spec:
              nodeSelector:
                cloud.google.com/gke-accelerator: nvidia-b200
              topologySpreadConstraints:
                - maxSkew: 1
                  topologyKey: cloud.google.com/gke-topology-block
                  whenUnsatisfiable: DoNotSchedule
```

---

## 6. Checkpointing

### Why Checkpointing is Critical

GPU workloads are **always at risk of interruption**. Without checkpointing, you lose all training progress when:

| Event | Risk Level | Impact |
|---|---|---|
| **DWS run duration expires** (max 7 days) | 🔴 Guaranteed | VMs are deleted at expiry — all in-memory state is lost |
| **Spot VM preemption** | 🔴 High | Can happen at any time with no guarantee of advance warning |
| **Host maintenance** | 🟡 Scheduled | 7–90 day advance notification depending on machine type |
| **Hardware failure** | 🟡 Rare | GPU or host failures can occur during long training runs |
| **Software crash** | 🟡 Variable | OOM, NCCL timeout, NaN divergence |

> **Rule of Thumb:** The cost of lost work = `(hourly_GPU_cost × hours_since_last_checkpoint × GPU_count)`. For a 64-GPU A3 Mega cluster, losing 6 hours of training can cost **thousands of dollars** in wasted compute.

### Checkpointing Strategy Decision Tree

```
                    What is your workload type?
                               │
              ┌────────────────┼────────────────┐
              │                │                │
         Training         Fine-tuning       Inference
              │                │                │
    Checkpoint every     Checkpoint every    No checkpointing
    30 min – 2 hours     epoch or every      needed (stateless)
              │          30 min – 1 hour          │
              │                │             Save model artifacts
              │                │             to durable storage
              │                │             before serving
              ▼                ▼
    Where to store checkpoints?
              │
    ┌─────────┼─────────────┬──────────────┐
    │         │             │              │
  Rapid     GCS +       HyperDisk    ParallelStore
  Bucket    GCSFuse     (block)      (Lustre)
    │         │             │              │
  Best for  Good for     Good for     Good for
  largest   most cases   single-node  HPC/POSIX
  scale                  recovery     workloads
```

### Storage Options for Checkpointing

| Storage | Write Throughput | Latency | Append Support | Best For | Cost Tier |
|---|---|---|---|---|---|
| **[Rapid Bucket](../../02-core-infrastructure/storage/README.md)** | Up to 15 TB/s | Sub-ms | ✅ Appendable objects | Largest-scale training, streaming checkpoint writes | $$ |
| **GCS (standard)** | High | Low ms | ❌ Full rewrite | Most workloads — simple, durable, widely supported | $ |
| **GCS + GCSFuse** | High (with tuning) | Low ms | ❌ Full rewrite | K8s-native workloads via CSI driver | $ |
| **HyperDisk** | Tunable IOPS/throughput | Sub-ms | N/A (block) | Single-node checkpoint to persistent block storage | $$ |
| **ParallelStore (Lustre)** | Very high parallel I/O | Low | N/A (POSIX) | HPC workloads, existing Lustre-based pipelines | $$$ |
| **Local SSD** | Highest (local) | Lowest | N/A | Temp scratch during training; **NOT durable** — do NOT rely on for checkpoints | Included |

> **⚠️ Critical:** Never use Local SSD as your only checkpoint destination. Local SSD data is **lost** when the VM is deleted (DWS expiry, Spot preemption, maintenance). Always checkpoint to durable storage (GCS, Rapid Bucket, HyperDisk).

### Recommended Checkpointing Patterns

#### Pattern 1: Synchronous Checkpointing to GCS (Most Common)

Best for: most training workloads up to ~100B parameters

```python
# PyTorch example — checkpoint every N steps
import torch
import os

CHECKPOINT_DIR = "gs://my-bucket/checkpoints/run-001"
CHECKPOINT_INTERVAL = 500  # steps

def save_checkpoint(model, optimizer, step, loss):
    checkpoint = {
        'step': step,
        'model_state_dict': model.state_dict(),
        'optimizer_state_dict': optimizer.state_dict(),
        'loss': loss,
    }
    path = os.path.join(CHECKPOINT_DIR, f"checkpoint-{step}.pt")
    torch.save(checkpoint, path)
    print(f"Checkpoint saved at step {step} to {path}")

# In training loop:
for step, batch in enumerate(dataloader):
    loss = train_step(model, batch)
    if step % CHECKPOINT_INTERVAL == 0:
        save_checkpoint(model, optimizer, step, loss)
```

#### Pattern 2: Asynchronous Checkpointing with Orbax (JAX/Flax)

Best for: Large JAX/Flax models where synchronous checkpointing is too slow

```python
# JAX/Orbax example — asynchronous checkpointing
import orbax.checkpoint as ocp

# Configure async checkpointer
options = ocp.CheckpointManagerOptions(
    max_to_keep=3,  # Keep last 3 checkpoints
    save_interval_steps=500,
)
checkpoint_manager = ocp.CheckpointManager(
    'gs://my-bucket/checkpoints/run-001',
    options=options,
)

# In training loop:
for step in range(num_steps):
    state = train_step(state, batch)
    checkpoint_manager.save(step, args=ocp.args.StandardSave(state))

# Restore from latest checkpoint:
step = checkpoint_manager.latest_step()
state = checkpoint_manager.restore(step)
```

#### Pattern 3: Checkpoint to Rapid Bucket with Append (Largest Scale)

Best for: Trillion-parameter models, streaming writes

```python
# Use Rapid Bucket for appendable checkpoint writes
# Rapid Bucket supports append-without-rewrite, which is ideal
# for incrementally writing large checkpoint files

# Set CHECKPOINT_DIR to a Rapid Bucket (zonal storage)
CHECKPOINT_DIR = "gs://my-rapid-bucket/checkpoints/run-001"

# Use the same PyTorch/JAX checkpoint code as above —
# GCSFuse v3.7.2+ and GKE v1.35.0+ support Rapid Buckets
```

### Checkpointing Frequency Guidelines

| Workload Duration | GPU Count | Recommended Interval | Rationale |
|---|---|---|---|
| **< 4 hours** | Any | Every 30 min or every epoch | Short runs — minimal checkpoint overhead relative to total time |
| **4–24 hours** | 1–8 | Every 1 hour | Balance between lost-work cost and checkpoint I/O overhead |
| **4–24 hours** | 8–64 | Every 30 min | More GPUs = higher cost of lost work |
| **1–7 days (DWS)** | Any | Every 30 min – 1 hour | DWS VMs are deleted at `maxRunDurationSeconds` — checkpoint well before expiry |
| **> 7 days (reserved)** | Any | Every 1–2 hours | Long runs with maintenance windows — checkpoint before maintenance |
| **Spot VMs** | Any | Every 15–30 min | High preemption risk — frequent checkpoints minimize lost work |

### Checkpoint Size Estimation

| Model Size | Checkpoint Size (FP16) | Checkpoint Size (FP32) | Notes |
|---|---|---|---|
| 1B params | ~2 GB | ~4 GB | + optimizer state (Adam: ~8 GB FP32) |
| 7B params | ~14 GB | ~28 GB | + optimizer state (~56 GB) |
| 70B params | ~140 GB | ~280 GB | + optimizer state (~560 GB) |
| 405B params | ~810 GB | ~1,620 GB | + optimizer state (~3,240 GB). Use async checkpointing. |

> **Tip:** Use **mixed-precision checkpointing** — save model weights in FP16/BF16 and optimizer states in FP32. This halves checkpoint size for weights while preserving optimizer precision.

### Framework-Specific Checkpointing Reference

| Framework | Checkpointing Library | GCS Support | Async Support | Key Config |
|---|---|---|---|---|
| **PyTorch** | `torch.save()` / `torch.distributed.checkpoint` | Via GCSFuse mount or `fsspec` | `torch.distributed.checkpoint` supports async | Set `CHECKPOINT_DIR=gs://...` |
| **JAX/Flax** | [Orbax](https://github.com/google/orbax) | Native GCS support | ✅ `AsyncCheckpointer` | `ocp.CheckpointManager(gs://...)` |
| **TensorFlow** | `tf.train.Checkpoint` | Native GCS support | ✅ Via `experimental_io_device` | `checkpoint.write(gs://...)` |
| **DeepSpeed** | `model.save_checkpoint()` | Via GCSFuse mount | ✅ Via `async_checkpoint` | `ds_config.json`: `"checkpoint": {"async": true}` |
| **Megatron-LM** | Built-in checkpointing | Via GCSFuse mount | ✅ Via `--async-save` flag | `--save gs://... --save-interval 500` |

### XLA Compilation Caching (JAX/TPU)

For JAX workloads, also enable **XLA compilation caching** to avoid recompilation on restart (which can add 10–60 minutes to recovery time):

```bash
# Set before running JAX workload
export JAX_COMPILATION_CACHE_DIR=gs://my-bucket/xla-cache

# Requires gcsfs package
pip install gcsfs
```

> This is separate from model checkpointing — it caches compiled XLA programs. See [Storage README](../../02-core-infrastructure/storage/README.md) for details.

---

## 7. Consumption Model Summary

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

### Quick Decision Guide

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
                        (≤90 days)            fault-tolerant?
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

> For the full DWS guide with all consumption options, decision frameworks, and implementation details, see the [DWS Guide](../../03-deploying-workloads/dws/README.md).

---

## 8. References

### Google Cloud Documentation

- [Accelerator-Optimized Machine Family](https://cloud.google.com/compute/docs/accelerator-optimized-machines) — Complete specs for all GPU machine types
- [Recommended Configurations (Choose Strategy)](https://cloud.google.com/ai-hypercomputer/docs/choose-strategy) — Google's official accelerator recommendations by workload
- [Choose a Consumption Option](https://cloud.google.com/ai-hypercomputer/docs/consumption-models) — Reservation vs DWS vs Spot decision guide
- [GPU Regions and Zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones) — Availability matrix for all GPU types
- [AI Hypercomputer Overview](https://cloud.google.com/ai-hypercomputer/docs/overview) — Architecture and capabilities
- [Storage Services for AI](https://cloud.google.com/ai-hypercomputer/docs/storage) — Google's recommended storage for training/inference
- [Topology-Aware Scheduling on GKE](https://cloud.google.com/ai-hypercomputer/docs/workloads/schedule-gke-workloads-tas) — Schedule pods on topologically-close nodes
- [Compact Placement Policies](https://cloud.google.com/compute/docs/instances/placement-policies-overview#about-compact-policies) — Control VM physical placement

### Checkpointing & Storage

- [Orbax Checkpointing (JAX)](https://github.com/google/orbax) — Async checkpointing for JAX/Flax
- [PyTorch Distributed Checkpoint](https://pytorch.org/docs/stable/distributed.checkpoint.html) — Distributed checkpointing for PyTorch
- [DeepSpeed Checkpointing](https://www.deepspeed.ai/docs/config-json/#checkpoint-options) — Async checkpointing configuration
- [JAX Compilation Cache](https://jax.readthedocs.io/en/latest/persistent_compilation_cache.html) — XLA compilation caching

### Related Sections in This Repository

- [DWS Guide](../../03-deploying-workloads/dws/README.md) — Dynamic Workload Scheduler comprehensive guide
- [Cluster Toolkit](../../03-deploying-workloads/gke-ai-hypercompute/cluster-toolkit/README.md) — Deploy AI-optimized GKE clusters
- [Storage for AI Workloads](../../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, Rapid Bucket for training data and checkpointing
- [XPK](../../03-deploying-workloads/xpk/README.md) — Accelerated Processing Kit for quick PoCs

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. GPU specifications, availability, and pricing change frequently — always refer to the [official Google Cloud documentation](https://cloud.google.com/compute/docs/accelerator-optimized-machines) for the latest information. Memory sizing formulas are approximations; benchmark with your actual workload before making capacity commitments.
