# Checkpointing

Save training state often enough that an interruption costs minutes, not days. On Spot, also read [Keep a training job alive on Spot](../3-get-capacity/spot/README.md#keep-a-training-job-alive-on-spot).

## Why Checkpointing is Critical

GPU workloads are **always at risk of interruption**. Without checkpointing, you lose all training progress when:

| Event | Risk Level | Impact |
|---|---|---|
| **DWS run duration expires** (max 7 days) | 🔴 Guaranteed | VMs are deleted at expiry — all in-memory state is lost |
| **Spot VM preemption** | 🔴 High | Can happen at any time with no guarantee of advance warning |
| **Host maintenance** | 🟡 Scheduled | 7–90 day advance notification depending on machine type |
| **Hardware failure** | 🟡 Rare | GPU or host failures can occur during long training runs |
| **Software crash** | 🟡 Variable | OOM, NCCL timeout, NaN divergence |

> **Rule of Thumb:** The cost of lost work = `(hourly_GPU_cost × hours_since_last_checkpoint × GPU_count)`. For a 64-GPU A3 Mega cluster, losing 6 hours of training can cost **thousands of dollars** in wasted compute.

## Checkpointing Strategy Decision Tree

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
  Rapid     GCS +       HyperDisk    Managed
  Bucket    GCSFuse     (block)      Lustre
    │         │             │              │
  Best for  Good for     Good for     Good for
  largest   most cases   single-node  HPC/POSIX
  scale                  recovery     workloads
```

## Storage Options for Checkpointing

| Storage | Write Throughput | Latency | Append Support | Best For | Cost Tier |
|---|---|---|---|---|---|
| **[Rapid Bucket](../4-storage-and-network/storage/README.md)** | Up to 15 TB/s | Sub-ms | ✅ Appendable objects | Largest-scale training, streaming checkpoint writes | $$ |
| **GCS (standard)** | High | Low ms | ❌ Full rewrite | Most workloads — simple, durable, widely supported | $ |
| **GCS + GCSFuse** | High (with tuning) | Low ms | ❌ Full rewrite | K8s-native workloads via CSI driver | $ |
| **HyperDisk** | Tunable IOPS/throughput | Sub-ms | N/A (block) | Single-node checkpoint to persistent block storage | $$ |
| **[Managed Lustre](https://cloud.google.com/managed-lustre/docs/overview)** | Very high parallel I/O | Low | N/A (POSIX) | HPC workloads, existing Lustre-based pipelines | $$$ |
| **Local SSD** | Highest (local) | Lowest | N/A | Temp scratch during training; **NOT durable** — do NOT rely on for checkpoints | Included |

> **⚠️ Critical:** Never use Local SSD as your only checkpoint destination. Local SSD data is **lost** when the VM is deleted (DWS expiry, Spot preemption, maintenance). Always checkpoint to durable storage (GCS, Rapid Bucket, HyperDisk).

## Recommended Checkpointing Patterns

### Pattern 1: Synchronous Checkpointing to GCS (Most Common)

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

### Pattern 2: Asynchronous Checkpointing with Orbax (JAX/Flax)

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

### Pattern 3: Checkpoint to Rapid Bucket with Append (Largest Scale)

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

## Checkpointing Frequency Guidelines

| Workload Duration | GPU Count | Recommended Interval | Rationale |
|---|---|---|---|
| **< 4 hours** | Any | Every 30 min or every epoch | Short runs — minimal checkpoint overhead relative to total time |
| **4–24 hours** | 1–8 | Every 1 hour | Balance between lost-work cost and checkpoint I/O overhead |
| **4–24 hours** | 8–64 | Every 30 min | More GPUs = higher cost of lost work |
| **1–7 days (DWS)** | Any | Every 30 min – 1 hour | DWS VMs are deleted at `maxRunDurationSeconds` — checkpoint well before expiry |
| **> 7 days (reserved)** | Any | Every 1–2 hours | Long runs with maintenance windows — checkpoint before maintenance |
| **Spot VMs** | Any | Every 15–30 min | High preemption risk — frequent checkpoints minimize lost work |

## Checkpoint Size Estimation

| Model Size | Checkpoint Size (FP16) | Checkpoint Size (FP32) | Notes |
|---|---|---|---|
| 1B params | ~2 GB | ~4 GB | + optimizer state (Adam: ~8 GB FP32) |
| 7B params | ~14 GB | ~28 GB | + optimizer state (~56 GB) |
| 70B params | ~140 GB | ~280 GB | + optimizer state (~560 GB) |
| 405B params | ~810 GB | ~1,620 GB | + optimizer state (~3,240 GB). Use async checkpointing. |

> **Tip:** Use **mixed-precision checkpointing** — save model weights in FP16/BF16 and optimizer states in FP32. This halves checkpoint size for weights while preserving optimizer precision.

## Framework-Specific Checkpointing Reference

| Framework | Checkpointing Library | GCS Support | Async Support | Key Config |
|---|---|---|---|---|
| **PyTorch** | `torch.save()` / `torch.distributed.checkpoint` | Via GCSFuse mount or `fsspec` | `torch.distributed.checkpoint` supports async | Set `CHECKPOINT_DIR=gs://...` |
| **JAX/Flax** | [Orbax](https://github.com/google/orbax) | Native GCS support | ✅ `AsyncCheckpointer` | `ocp.CheckpointManager(gs://...)` |
| **TensorFlow** | `tf.train.Checkpoint` | Native GCS support | ✅ Via `experimental_io_device` | `checkpoint.write(gs://...)` |
| **DeepSpeed** | `model.save_checkpoint()` | Via GCSFuse mount | ✅ Via `async_checkpoint` | `ds_config.json`: `"checkpoint": {"async": true}` |
| **Megatron-LM** | Built-in checkpointing | Via GCSFuse mount | ✅ Via `--async-save` flag | `--save gs://... --save-interval 500` |

## XLA Compilation Caching (JAX/TPU)

For JAX workloads, also enable **XLA compilation caching** to avoid recompilation on restart (which can add 10–60 minutes to recovery time):

```bash
# Set before running JAX workload
export JAX_COMPILATION_CACHE_DIR=gs://my-bucket/xla-cache

# Requires gcsfs package
pip install gcsfs
```

> This is separate from model checkpointing — it caches compiled XLA programs. See [Storage README](../4-storage-and-network/storage/README.md) for details.

## References

- [Orbax Checkpointing (JAX)](https://github.com/google/orbax) — Async checkpointing for JAX/Flax
- [PyTorch Distributed Checkpoint](https://pytorch.org/docs/stable/distributed.checkpoint.html) — Distributed checkpointing for PyTorch
- [DeepSpeed Checkpointing](https://www.deepspeed.ai/docs/config-json/#checkpoint-options) — Async checkpointing configuration
- [JAX Compilation Cache](https://jax.readthedocs.io/en/latest/persistent_compilation_cache.html) — XLA compilation caching
