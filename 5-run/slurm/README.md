# Cluster Director

Cluster Director deploys a managed Slurm cluster on Google Cloud, with login nodes, a controller that Google runs, GPU, CPU or TPU (Preview) partitions, and shared storage. Reach for it when your group already works in Slurm and wants to run `sbatch` jobs without building the cluster.

## What we'd pick

- **Cluster Director for groups that already use Slurm.** Google runs the controller in a fault-tolerant setup. You keep `sbatch`, `srun`, `salloc` and SSH to the login nodes.
- **Cluster Toolkit when you need full control of `slurm.conf`.** Cluster Director exposes a fixed list of cluster, partition and nodeset settings.
- **GKE when the group works in containers and Kubernetes, or serves models next to training.** See [GKE](../kubernetes/).
- **H4D with Cloud RDMA for CPU-bound MPI codes, such as CFD, climate and molecular dynamics.** H4D carries Cloud RDMA at 200 Gbps between nodes. Build the cluster from Cluster Toolkit's `hpc-slurm-h4d` blueprint, which Google's H4D Slurm guides use. It boots the HPC VM image with the Cloud RDMA drivers and installs MPI.
- **A Falcon VPC network for RDMA traffic and a regular VPC network for everything else.** The IRDMA NIC can't be nic0. Falcon networks don't support Cloud NAT, Private Google Access or VPC Network Peering, so storage and internet traffic stay on the regular network.
- **A4 (B200) for double-precision GPU codes.** Keep them off A4X Max, whose GB300 has a small fraction of B200's FP64 throughput. See [FP64 science codes](../../2-choose-hardware/README.md#double-precision-fp64-science-codes).
- **Managed Lustre for scratch and shared datasets, and Filestore for `/home`.** Lustre throughput scales with capacity, from 125 to 1,000 MBps per TiB by tier. The docs point training at 1,000 MBps per TiB and a broad range of HPC work at 250.
- **Cloud Storage backups for Lustre results.** Managed Lustre has no undelete, and deleting an instance destroys its data. Exports are incremental, so run them on a schedule.
- **Flex-start for runs that fit in seven days, calendar mode for planned runs up to 90 days, and Spot for jobs that survive preemption.** Flex-start and calendar mode carry discounts up to 53%, and Spot up to 91%. Cluster Director deletes VMs when a calendar-mode reservation ends, even if you set them to stop, so keep checkpoints off the nodes.
- **One partition per GPU type and consumption option.** Each nodeset holds one compute configuration. Separate partitions let users pick hardware and capacity with `sbatch --partition`.
- **Dynamic nodes for bursty work.** Slurm powers down a dynamic GPU or CPU node after five idle minutes. Static nodes stay up as a baseline.
- **Containers before custom images.** Package per-job software as a container and run it with enroot and Pyxis, which the GPU images include. Use nodeset startup scripts for a few packages. Build a Packer image only for heavy or system-level changes.
- **Custom images from the Cluster Director family for your machine series.** Compute nodes can't run a newer Slurm than the controller, so match the image's Slurm version to the controller's. A family gets support for 12 months, then turns deprecated and later obsolete.
- **The N2 quickstart before any GPUs.** It builds a login node and two n2-standard-2 compute nodes with no reserved capacity. You learn the create, SSH and `sbatch` flow there.
- **IAP and OS Login for SSH, with no public IPs on login nodes.** Set `enablePublicIps=false` in `--slurm-login-node`, because the gcloud default is `true`. See [Zero Trust IAP access](../../4-storage-and-network/private-vms/README.md).

## Official docs

| Need | Page |
|---|---|
| What it is | [Cluster Director overview](https://docs.cloud.google.com/cluster-director/docs/overview) |
| First cluster | [Create a Slurm cluster](https://docs.cloud.google.com/cluster-director/docs/create/quickstart) |
| Your own compute, network and storage | [Create a custom cluster](https://docs.cloud.google.com/cluster-director/docs/create/custom-cluster) |
| Capacity type per partition | [Choose a consumption option](https://docs.cloud.google.com/cluster-director/docs/choose-consumption-option) |
| Images and end-of-support dates | [Supported OS images](https://docs.cloud.google.com/cluster-director/docs/os-images), [Image family release notes](https://docs.cloud.google.com/cluster-director/docs/image-family-release-notes) |
| Storage | [Supported storage services](https://docs.cloud.google.com/cluster-director/docs/storage) |
| How Slurm runs | [Slurm orchestration in Cluster Director](https://docs.cloud.google.com/cluster-director/docs/orchestration) |
| Slurm settings you can change | [Supported Slurm settings](https://docs.cloud.google.com/cluster-director/docs/slurm-settings) |
| A4X block topology and TPU slices | [Submit and monitor jobs](https://docs.cloud.google.com/cluster-director/docs/workloads/configure-slurm) |
| CLI flags and reference architectures | [gcloud cluster-director clusters create](https://docs.cloud.google.com/sdk/gcloud/reference/cluster-director/clusters/create) |
| What changed | [Cluster Director release notes](https://docs.cloud.google.com/cluster-director/docs/release-notes) |
| H4D Slurm cluster | [Create a Cloud RDMA-enabled HPC Slurm cluster with H4D instances](https://docs.cloud.google.com/cluster-toolkit/docs/quickstarts/create-a-slurm-cluster-h4d) |
| MPI on H4D | [Set up and scale MPI applications on H4D instances with Cloud RDMA](https://docs.cloud.google.com/cluster-toolkit/docs/setup/configure-mpi-application) |
| RDMA networks | [RDMA network profiles](https://docs.cloud.google.com/vpc/docs/rdma-network-profiles) |
| HPC images | [HPC VM images](https://docs.cloud.google.com/compute/docs/images/workload/hpc-vm-images) |
| Lustre tiers | [Managed Lustre performance tiers](https://docs.cloud.google.com/managed-lustre/docs/performance-tiers) |
| Lustre backups | [Back up Managed Lustre instance data](https://docs.cloud.google.com/managed-lustre/docs/back-up-instance-data) |

## Ask your harness

Questions for the Google developer knowledge MCP:

- "Which consumption options does Cluster Director support for each machine series?"
- "How do I create a Slurm cluster with Cluster Director?"
- "Which OS image families does Cluster Director support, and when does each reach end of support?"
- "Which storage services can I attach to a Cluster Director cluster?"
- "Which Slurm settings can I customize in a Cluster Director cluster?"
- "How do I set up and scale MPI applications on H4D instances with Cloud RDMA?"
- "Which Managed Lustre performance tier fits my workload?"
- "How do I back up Managed Lustre data to Cloud Storage?"

## Field notes

### Before you create a cluster

- Update the gcloud CLI to 550.0.0 or later. Cluster operations fail on older versions.
- Put compute, storage and subnets in one zone. Cluster Director doesn't support AI zones, whose names contain `-ai`.
- If your organization sets a trusted image policy, allow `projects/clusterdirector-public-images`. Check the effective policy:

```bash
gcloud resource-manager org-policies describe \
    compute.trustedImageProjects --project=PROJECT_ID --effective
```

### H4D in Cluster Director (read 2026-11-05)

`gcloud cluster-director clusters create` offers an `h4d-highmem-flex-start` reference architecture. It creates four h4d-highmem-192 nodes on Flex-start, an n2-standard-16 login node, Managed Lustre scratch and a Filestore share. The Cluster Director machine pages list only N2 and C4A as CPU machines. Ask the docs MCP about H4D in Cluster Director before you plan a cluster around it.

### Run containers with enroot and Pyxis

Enroot puts `#` between the registry host and the image path. Import the image on a compute node, which has more CPU and memory than the login node. Then run from the squashfs file:

```bash
srun -N 1 enroot import docker://nvcr.io#nvidia/pytorch:24.04-py3

srun --container-image=./nvidia+pytorch+24.04-py3.sqsh \
     --container-mounts=/data:/data \
     python /data/train.py
```

### Extend the base image with Packer

Start from the Cluster Director family for your machine series. Keep its Slurm version in step with the controller. This template uses the default family for A4, A3 Ultra and N2 on Slurm 25.05 (read 2026-11-05).

```hcl
packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.1.6"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

locals {
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "googlecompute" "cluster_director_custom" {
  project_id              = var.project_id
  zone                    = var.zone
  source_image_project_id = ["clusterdirector-public-images"]
  source_image_family     = "common-ubuntu-2204-amd64-nvidia-580-slurm-2505-v20251113"
  machine_type            = "n2-standard-8"
  disk_size               = 200
  ssh_username            = "packer"
  image_name              = "cluster-director-custom-${local.image_date}"
  image_family            = "cluster-director-custom"
  metadata = {
    "enable-oslogin" = "FALSE"
  }
}

build {
  sources = ["source.googlecompute.cluster_director_custom"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y htop tmux",
      "sudo apt-get clean",
    ]
  }
}
```

Build it with `packer init .` and `packer build -var="project_id=PROJECT_ID" .`. For Cloud Build pipelines, see the [Packer guide](../../4-storage-and-network/vm-images/packer/README.md). For H4D images, see [HPC VM images and Advanced Compute Images](../../4-storage-and-network/vm-images/README.md#hpc-vm-images-and-advanced-compute-images).
