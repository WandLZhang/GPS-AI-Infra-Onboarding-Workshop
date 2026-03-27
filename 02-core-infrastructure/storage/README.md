# Storage for AI Workloads on Google Cloud

> A practitioner's guide to choosing and configuring storage for GPU and TPU workloads. Examples: loading 400GB model weights into accelerator memory in seconds, checkpointing trillion-parameter training runs, staging research data from Google Drive.

---

## 📋 Table of Contents

1. [Storage Features Overview](#1-storage-features-overview)
2. [Storage Feature × Workload Matrix](#2-storage-feature--workload-matrix)
3. [Google Drive → GCS Sync](#3-google-drive--gcs-sync)
4. [Other Cloud Contexts](#4-other-cloud-contexts)

---

## 1. Storage Features Overview

Google Cloud provides a layered storage stack for AI workloads. Each feature addresses a different part of the data pipeline — from mounting buckets as filesystems, to zonal SSD caching, to purpose-built zonal object storage with append semantics.

| Storage Feature | What It Does | Highlight | Use Case | Key Links |
|----------------|-------------|----------------|----------|-----------|
| **GCSFuse** | Mounts GCS buckets as local file systems via CSI driver on GKE. 4 optimization pillars: [hierarchical namespace buckets](https://cloud.google.com/storage/docs/hns-overview), [parallel downloads + file caching](https://cloud.google.com/kubernetes-engine/docs/how-to/cloud-storage-fuse-csi-driver-perf#parallel-download), [RAM disk cache](https://cloud.google.com/kubernetes-engine/docs/how-to/cloud-storage-fuse-csi-driver-perf#select-storage-for-file-cache) (only option on TPU VMs — no Local SSD), and [prefetch init containers](https://github.com/GoogleCloudPlatform/accelerated-platforms/blob/main/use-cases/inferencing/cost-optimization/gcsfuse/manifests/model-deployment-tuned-a100-dws.yaml). GKE v1.33+ sets smart mount defaults automatically for GPU/TPU families. | **7× faster pod startup** vs basic config; **41% faster** on A3 vs A2 | Model weight loading, training data access, inference serving — the standard pattern in [gpu-recipes](https://github.com/AI-Hypercomputer/gpu-recipes). | [CSI driver docs](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver) · [Performance tuning](https://cloud.google.com/kubernetes-engine/docs/how-to/cloud-storage-fuse-csi-driver-perf) · [7× startup tutorial](https://github.com/GoogleCloudPlatform/accelerated-platforms/blob/main/use-cases/inferencing/cost-optimization/gcsfuse/AchievingFasterPodStartup.md) · [Helm chart](https://github.com/AI-Hypercomputer/gpu-recipes/tree/main/src/helm-charts/storage/gcs-fuse) · [HF→GCS hydration](https://gke-ai-labs.dev/docs/tutorials/storage/hf-gcs-transfer/) |
| **Rapid Cache** (fka Anywhere Cache) | Fully managed SSD-backed zonal read cache for existing GCS buckets. Zero app changes — just create a cache in the workload zone. Auto-scales capacity and bandwidth. Store once in multi-region, read anywhere with zonal speed. Lower operation charges + avoids multi-region transfer fees. | **2.5 TB/s throughput**, up to **96% latency reduction** (multi-region), **70%** (regional) | Spinning up dozens of LLM inference pods simultaneously; read-heavy training across many GKE nodes; checkpoint restores; BigQuery acceleration (enable in all zones of region as best practice). | [Overview](https://cloud.google.com/storage/docs/rapid/rapid-cache) · [Create & Manage](https://cloud.google.com/storage/docs/rapid/use-rapid-cache) · [Recommender](https://cloud.google.com/storage/docs/rapid/rapid-cache-recommender) · [Pricing](https://cloud.google.com/storage/pricing#anywhere-cache) |
| **Rapid Bucket** | Zonal object storage with Rapid storage class — data lives in the same zone as compute. Supports appendable objects (append without full rewrite, readers see data as it's written). Compatible with Cloud Storage FUSE v3.7.2+ / GKE v1.35.0+. Does **not** support: Object Versioning, Soft Delete, Rapid Cache, Resumable Uploads, CSEK. [Full incompatibilities](https://cloud.google.com/storage/docs/rapid/rapid-bucket#incompatibilities). | **Sub-ms latency**, up to **15 TB/s**, **20M QPS**, appendable objects | Model checkpointing (append without rewrite), streaming writes, active training I/O at the largest scales, logging/messaging queues. | [Overview](https://cloud.google.com/storage/docs/rapid/rapid-bucket) · [Create zonal buckets](https://cloud.google.com/storage/docs/rapid/create-zonal-buckets) · [Use objects](https://cloud.google.com/storage/docs/rapid/use-objects-in-zonal-buckets) · [Rapid family](https://cloud.google.com/storage/docs/rapid/high-performance-storage) |
| **ParallelStore** | Fully managed parallel file system (Lustre-based) with POSIX semantics. Competes with AWS FSx for Lustre and Azure Managed Lustre. | High-throughput parallel I/O | HPC workloads requiring POSIX; multi-node training with existing Lustre-based pipelines. | [Docs](https://cloud.google.com/parallelstore/docs/overview) |
| **HyperDisk** | High-performance block storage, powered by Titanium offload. Tunable IOPS and throughput. | Persistent block with tunable IOPS/throughput | Database workloads, PD-backed checkpoint storage (as in [TRT-LLM serving](https://cloud.google.com/kubernetes-engine/docs/tutorials/serve-gemma-gpu-vllm) pattern). | [Docs](https://cloud.google.com/compute/docs/disks/hyperdisks) |
| **Storage Transfer Service** | Managed data transfer from S3, Azure Blob, on-prem NFS, or between GCS buckets. GUI-driven, scheduled, bandwidth-controlled. | Petabyte-scale, scheduled, recurring | Cross-cloud migration, Google Drive → GCS staging, recurring dataset sync. | [Overview](https://cloud.google.com/storage-transfer/docs/overview) · [Decision guide](https://cloud.google.com/storage-transfer/docs/transfer-options) |
| **XLA Compilation Caching** | Cache JAX/XLA compiled programs to GCS to skip recompilation on restart. Set `JAX_COMPILATION_CACHE_DIR=gs://bucket/xla-cache` before running. **Requires [`gcsfs`](https://gcsfs.readthedocs.io/) package** — without it, JAX silently fails. This is standard GCS, not Rapid. XLA cache is small (tens of MB); the bottleneck is compilation time, not storage I/O. | **52% faster cold start** (573s → 275s on v6e-4). Saves 10-60 min per cold start. ~830 hours saved across 10K experiments (~$9,100). | Any JAX/TPU workload; critical for spot preemption recovery. | [JAX caching docs](https://jax.readthedocs.io/en/latest/persistent_compilation_cache.html) |

> **Naming Note**: "Anywhere Cache" was officially renamed to **Rapid Cache** in 2026. You may still see "Anywhere Cache" in some CLI tools and older documentation.

> **GCP Storage Trifecta**: All GPU machine families ([A3 Ultra](https://cloud.google.com/compute/docs/accelerator-optimized-machines#a3-ultra-vms), [A4](https://cloud.google.com/compute/docs/accelerator-optimized-machines#a4-vms), [A4X](https://cloud.google.com/compute/docs/accelerator-optimized-machines#a4x-vms)) advertise the same storage options: **Object ([GCS](https://cloud.google.com/storage/docs)), Block ([HyperDisk](https://cloud.google.com/compute/docs/disks/hyperdisks)), PFS ([ParallelStore](https://cloud.google.com/parallelstore/docs/overview))**. Front-end networking is x2 200Gbps (Diorite) but **storage is limited to x1 200Gbps**.

> Other clouds do not offer a managed transparent zonal SSD read cache like Rapid Cache. AWS [S3 Express One Zone](https://aws.amazon.com/s3/storage-classes/express-one-zone/) offers zonal object storage with single-digit ms latency and append support (vs Rapid Bucket's sub-ms latency, 15 TB/s, and 20M QPS).

---

## 2. Storage Feature × Workload Matrix

| Workload Pattern | GCSFuse (Basic) | GCSFuse + File Cache | Rapid Cache | Rapid Bucket | `gcloud storage cp` | ParallelStore | HyperDisk |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Large-Scale Training** (TB+ datasets, continuous I/O) | ✅ | ✅✅ | ✅✅ read-only | ✅✅✅ | | ✅✅ | |
| **Checkpointing** (periodic writes, resume-on-preemption) | ✅ | ✅ | ❌ read-only | ✅✅✅ appendable | ✅ | ✅ | ✅ |
| **Model Serving / Inference** (load weights at pod startup) | ✅ | ✅✅ | ✅✅✅ | ✅✅ | ✅ | ✅✅ | |
| **Small Dataset Fine-Tuning** (<10GB, one-time load) | ✅ | ✅ | — overkill | — overkill | ✅✅ | — | |
| **XLA Compilation Caching** | — | — | — | — | ✅ via `JAX_COMPILATION_CACHE_DIR` | — | — |
| **Google Drive Data Staging** | — | — | — | — | — | — | — |

> **Legend**: ✅✅✅ = ideal fit, ✅✅ = good fit, ✅ = works, — = not applicable/overkill, ❌ = incompatible

---

## 3. Google Drive → GCS Sync

There is **no native direct sync** between Google Drive and Cloud Storage. For research teams that stage data in Google Drive (common in academic/public sector):

| Method | Best For | How |
|--------|---------|-----|
| **[Storage Transfer Service](https://cloud.google.com/storage-transfer/docs/overview)** | Large datasets (>1TB), scheduled/recurring transfers | Managed service, GUI-driven. Supports S3, Azure, on-prem NFS, and between GCS buckets. [Decision guide](https://cloud.google.com/storage-transfer/docs/transfer-options). |
| **`gcloud storage cp`** | Small-to-medium transfers, ad hoc | CLI tool, suitable for < 1TB. `gcloud storage cp gs://source gs://dest` |
| **[rclone](https://rclone.org/)** | Google Drive ↔ GCS specifically | Open-source tool with native [Google Drive](https://rclone.org/drive/) and [GCS](https://rclone.org/googlecloudstorage/) backends. Supports incremental sync. `rclone sync gdrive: gcs:bucket/path` |

---

## 4. Other Cloud Contexts

| CSP | Object Storage | Block Storage | Parallel File System | Zonal Cache |
|-----|---------------|--------------|---------------------|-------------|
| **Google Cloud** | [GCS](https://cloud.google.com/storage/docs) | [HyperDisk](https://cloud.google.com/compute/docs/disks/hyperdisks) | [ParallelStore](https://cloud.google.com/parallelstore/docs/overview) | **[Rapid Cache](https://cloud.google.com/storage/docs/rapid/rapid-cache) (2.5 TB/s)** |
| **AWS** | S3 ([Express One Zone](https://aws.amazon.com/s3/storage-classes/express-one-zone/) for zonal) | EBS | FSx for Lustre | No transparent cache equivalent (S3 Express One Zone is zonal storage, not a cache) |
| **Azure** | Blob Storage | Managed Disks | Azure Managed Lustre | ❌ No equivalent |
| **OCI** | OCI Object Storage | Block Volume | File Storage with HPMT | ❌ No equivalent |

### GKE Storage Advantages

| Differentiator | Detail | Other Hyperscaler Equivalent |
|---------------|--------|----------------------|
| **7× faster pod startup** | [GCSFuse tuning](https://github.com/GoogleCloudPlatform/accelerated-platforms/blob/main/use-cases/inferencing/cost-optimization/gcsfuse/AchievingFasterPodStartup.md) (parallel downloads, file cache, prefetch) | No equivalent |
| **Rapid Cache** | [2.5 TB/s](https://cloud.google.com/storage/docs/rapid/rapid-cache) transparent zonal SSD read cache, auto-scaling | No transparent object storage cache on AWS/Azure/OCI |
| **Rapid Bucket** | [Sub-ms zonal storage](https://cloud.google.com/storage/docs/rapid/rapid-bucket), 15 TB/s, 20M QPS, appendable objects | AWS [S3 Express One Zone](https://aws.amazon.com/s3/storage-classes/express-one-zone/): single-digit ms, 2M QPS, append (10K cap) |
| **Image Streaming + GCSFuse** | Containers start while model streams in background | EKS/AKS: no native image streaming at scale |
| **GKE v1.33+ smart defaults** | [GCSFuse mountOptions](https://cloud.google.com/kubernetes-engine/docs/how-to/cloud-storage-fuse-csi-driver-perf) auto-configured for GPU/TPU families | ❌ Manual configuration required |
| **TPU + GPU in same cluster** | Unified orchestration with same storage backend | AWS EKS mixes GPU + Trainium/Inferentia natively; no TPU equivalent |
| **130,000 nodes per cluster** | [10× larger](https://cloud.google.com/blog/topics/developers-practitioners/supercharge-your-ai-gke-inference-reference-architecture-your-blueprint-for-production-ready-inference) than other Kubernetes services | EKS/AKS significantly smaller |

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies and review configurations before deploying in production environments.
