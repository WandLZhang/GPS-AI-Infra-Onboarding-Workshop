# Disk images for GPU and HPC VMs

The boot image sets the OS, NVIDIA driver, CUDA, and MPI stack that a VM starts with. Start from a Google image, and build your own only when every VM in a lab or cluster needs the same extra software.

## What we'd pick

- **Start GPU VMs from a Deep Learning VM image.** The `pytorch-2-9-cu129` families ship the NVIDIA 580 driver, CUDA 12.9, and PyTorch 2.9, so you skip the driver install. The `common-cu129` families leave out PyTorch for when you bring your own framework.
- **On A3 Ultra, A4, and A4X Slurm clusters, keep the image Cluster Toolkit installs.** Its Slurm blueprints for these machines install the GPU Advanced Compute Images (Preview). [Cluster Director](../../03-deploying-workloads/cluster-director/) covers the cluster side.
- **Start CPU MPI nodes from the HPC VM image.** `hpc-rocky-linux-8` and `hpc-rocky-linux-9` carry Google's kernel and network tuning for MPI. Pick Rocky 8 for Slurm or for Cloud RDMA on H4D. The Rocky-based Advanced Compute Images add Slurm builds and are in Preview.
- **On a plain OS image, install drivers with Google's `cuda_installer.pyz`.** Its default mode installs from NVIDIA's repository with DKMS, which rebuilds the driver after a kernel update. Its `build_image` command makes a Secure Boot image with signed drivers.
- **Bake heavy installs into an image.** If a startup script takes more than 5 minutes, build a custom image instead. Keep startup scripts for small per-VM settings.
- **Build custom images with [Packer](./packer/README.md), and rebuild monthly in Cloud Build.** A template in Git rebuilds the same stack on demand, and each rebuild picks up security patches. Hand-built images drift.
- **Put each custom image in a family.** Name it with a version and a date, such as `ml-base-v3-20260327`. Point dev VMs at the family. Pin one image name for a cluster, so every node boots the same build.
- **Deprecate old builds** so teams move to the new one. To roll back, deprecate the newest image, and the family points at the one before it. Deprecation can't be undone.
- **Keep shared images in one image project.** Grant `roles/compute.imageUser` on each image to the groups that need it.

## Official docs

| Need | Page |
|---|---|
| Pick a Deep Learning VM image family | [Choose an image](https://docs.cloud.google.com/deep-learning-vm/docs/images) |
| See what the HPC VM image tunes | [Overview of HPC-ready VM images](https://docs.cloud.google.com/compute/docs/images/workload/hpc-vm-images) |
| Create an HPC VM with MPI tuning | [Create an HPC-ready VM instance](https://docs.cloud.google.com/compute/docs/instances/create-hpc-vm) |
| Find Advanced Compute Images families by machine series | [Overview of Advanced Compute Images](https://docs.cloud.google.com/compute/docs/images/workload/aci-images) |
| Version and roll back custom images | [Image families best practices](https://docs.cloud.google.com/compute/docs/images/image-families-best-practices) |
| Deprecate an old build | [Deprecate a custom image](https://docs.cloud.google.com/compute/docs/images/deprecate-custom) |
| Share images with other projects and MIGs | [Manage access to custom images](https://docs.cloud.google.com/compute/docs/images/managing-access-custom-images) |
| Install NVIDIA drivers on a plain OS image | [Install GPU drivers](https://docs.cloud.google.com/compute/docs/gpus/install-drivers-gpu) |
| Run small setup steps at boot | [About startup scripts](https://docs.cloud.google.com/compute/docs/instances/startup-scripts) |
| Plan an image pipeline | [Image management best practices](https://docs.cloud.google.com/compute/docs/images/image-management-best-practices) |

## Ask your agent

Questions for the Google developer knowledge MCP:

- "Which Deep Learning VM image families are current, and which NVIDIA driver and CUDA versions do they include?"
- "What kernel and network tuning does the HPC VM image apply for MPI workloads?"
- "Which Advanced Compute Images families support A4 GPUs and H4D CPUs?"
- "How do I roll an image family back to the previous image?"
- "How do I let a managed instance group in another project use my custom image?"
- "How do I install NVIDIA GPU drivers on a Compute Engine VM with the cuda_installer script?"

## Field notes

### List the families before you pin one

Google retires image families. On 2026-11-05, families from older guides, such as `pytorch-latest-gpu-debian-11` and `common-cu124-debian-11`, returned `was not found`. List the live families with this loop.

```bash
for p in deeplearning-platform-release cloud-hpc-image-public advanced-compute-images; do
  gcloud compute images list --project="$p" --no-standard-images \
    --format="table(family, name, creationTimestamp.date())"
done
```

On 2026-11-05 the three projects held these families.

| Project | Families |
|---|---|
| `deeplearning-platform-release` | `common-cu129-ubuntu-2204-nvidia-580`, `common-cu129-ubuntu-2404-nvidia-580`, `pytorch-2-9-cu129-ubuntu-2204-nvidia-580`, `pytorch-2-9-cu129-ubuntu-2404-nvidia-580` |
| `cloud-hpc-image-public` | `hpc-rocky-linux-8`, `hpc-rocky-linux-9`, `slurm-gcp-6-11-hpc-rocky-linux-8` |
| `advanced-compute-images` | 14 `aci-*` families for CPU, GPU, and TPU, plus `slurm-gcp-6-12-debian-12` |

### HPC VM images and Advanced Compute Images

- For Cloud RDMA on H4D, start from `hpc-rocky-linux-8` version 20250917 or later, or from a Rocky-based Advanced Compute Images family.
- Turn on Cloud RDMA when you create the VM. You can't add it to an existing VM.
- The Advanced Compute Images page lists `aci-cpu-rocky-linux-8-slurm-2605-amd64`. On 2026-11-05, `gcloud compute images describe-from-family` returned `was not found` for it. The Rocky 9 Slurm family, `aci-cpu-rocky-linux-9-slurm-2605-amd64`, resolved.

### Make startup scripts safe to rerun

Compute Engine runs a Linux startup script as root on every boot. A marker file turns the later runs into no-ops.

```bash
#!/bin/bash
set -euo pipefail
MARKER=/var/log/startup-v1-complete
if [ -f "$MARKER" ]; then exit 0; fi

apt-get update
apt-get install -y python3-venv git
python3 -m venv /opt/ml-env
/opt/ml-env/bin/pip install numpy pandas

date > "$MARKER"
```
