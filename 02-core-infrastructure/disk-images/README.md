# VM Disk Images, Snapshots & Startup Scripts for AI/ML/HPC Workloads

## Overview

When deploying AI, ML, and HPC workloads on Google Cloud, you rarely want to install software from scratch on every new VM. GCP provides multiple methods to create reusable VM configurations with pre-installed software components — from using Google-maintained public images to building fully customized golden images with Packer.

This guide covers **five methods** for creating VMs with reusable software configurations, explains how **startup scripts** work, and details **installation options for common AI/ML/HPC libraries**.

> **Looking for Packer?** See the dedicated [Packer Guide](./packer/README.md) for detailed templates, examples, and CI/CD integration for automated image building.

---

## Methods at a Glance

| Method | Source | Boot Time | Cost | Best For |
|--------|--------|-----------|------|----------|
| **Public Images** | Google-maintained | Fast | Free (no image cost) | Starting point, standard OS, Deep Learning VMs |
| **Custom Images** | You create from VM/disk | Fast | $0.050/GB/month (stored in project) | Golden images, reproducible environments, org-wide standards |
| **Snapshots** | Point-in-time disk copy | Fast | $0.026/GB/month (Standard) | Backup, cloning, incremental saves, disaster recovery |
| **Archive Snapshots** | Cold-storage snapshot | Slow (minutes to restore) | $0.0026/GB/month | Long-term retention, compliance, audit archives |
| **Existing Disks** | Attach/clone a disk | Instant (already provisioned) | Standard PD pricing | Quick cloning, dev/test from production disks |

---

## Architecture: VM Creation Methods

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        GCP VM Creation — Reusable Image Options                     │
│                                                                                     │
│  ┌─────────────────────┐    ┌──────────────────────┐    ┌────────────────────────┐  │
│  │   PUBLIC IMAGES      │    │   CUSTOM IMAGES       │    │   SNAPSHOTS            │  │
│  │                     │    │                      │    │                        │  │
│  │  Google-maintained  │    │  Your golden images  │    │  Point-in-time copies  │  │
│  │  OS & DL VM images  │    │  from VM, disk, or   │    │  of persistent disks   │  │
│  │                     │    │  other image          │    │                        │  │
│  │  • ubuntu-2404-lts  │    │                      │    │  • Standard (hot)      │  │
│  │  • debian-12        │    │  • Image families    │    │  • Archive (cold)      │  │
│  │  • rocky-linux-9    │    │  • Cross-project     │    │  • Incremental         │  │
│  │  • deep-learning-vm │    │  • Deprecation       │    │  • Scheduled           │  │
│  │  • hpc-vm-image     │    │    policies          │    │                        │  │
│  └────────┬────────────┘    └──────────┬───────────┘    └───────────┬────────────┘  │
│           │                            │                            │               │
│           ▼                            ▼                            ▼               │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                                                                             │    │
│  │                        ┌───────────────────┐                                │    │
│  │                        │   NEW GCE VM       │                                │    │
│  │                        │                   │                                │    │
│  │                        │  Boot Disk  ◄─────┼──── From any of the 5 sources  │    │
│  │                        │  + Startup Script  │                                │    │
│  │                        │                   │                                │    │
│  │                        └───────────────────┘                                │    │
│  │                                ▲                                             │    │
│  └────────────────────────────────┼─────────────────────────────────────────────┘    │
│                                   │                                                  │
│  ┌────────────────────────────────┴─────────────────────────────────────────────┐    │
│  │                      EXISTING DISKS                                          │    │
│  │                                                                              │    │
│  │   • Clone an existing persistent disk                                        │    │
│  │   • Attach a detached boot disk to a new VM                                  │    │
│  │   • Instant disk cloning (same zone)                                         │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │                      STARTUP SCRIPTS                                         │    │
│  │                                                                              │    │
│  │   Applied at boot time to ANY of the above sources                           │    │
│  │   • Inline metadata (--metadata startup-script=...)                          │    │
│  │   • GCS-hosted (--metadata startup-script-url=gs://...)                      │    │
│  │   • Install packages, configure services, mount storage                      │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Decision Flow: Which Method Should You Use?

```
                         ┌──────────────────────┐
                         │  Need a reusable VM   │
                         │  with custom software? │
                         └──────────┬─────────────┘
                                    │
                         ┌──────────▼─────────────┐
                         │ Is a Google public or   │
                    ┌─YES│ Deep Learning VM image  │NO──┐
                    │    │ sufficient?              │    │
                    │    └─────────────────────────┘    │
                    ▼                                    ▼
           ┌────────────────┐              ┌───────────────────────┐
           │ Use PUBLIC      │              │ Do you need to        │
           │ IMAGE           │              │ preserve exact disk   │
           │ + startup script│              │ state (data + OS)?    │
           │ for any extras  │         ┌─YES┤                       │NO──┐
           └────────────────┘         │    └───────────────────────┘    │
                                      ▼                                 ▼
                           ┌──────────────────┐            ┌───────────────────┐
                           │ Need long-term    │            │ Need fast, repeatable│
                           │ cold storage?     │            │ boot with all SW    │
                           │                  │            │ pre-installed?      │
                      ┌─YES┤                  │NO──┐  ┌─YES┤                     │NO─┐
                      │    └──────────────────┘    │  │    └───────────────────┘   │
                      ▼                            ▼  ▼                            ▼
             ┌──────────────┐          ┌──────────────────┐          ┌──────────────┐
             │ Use ARCHIVE   │          │ Use STANDARD     │          │ Use EXISTING  │
             │ SNAPSHOT      │          │ SNAPSHOT         │          │ DISK (clone   │
             │               │          │                  │          │ or attach)    │
             └──────────────┘          └──────────────────┘          └──────────────┘
                                                                            │
                                            ┌───────────────────────────────┘
                                            ▼
                                   ┌──────────────────┐
                                   │ Want to share     │
                                   │ across projects   │
                                   │ or automate with  │
                                   │ Packer/Cloud Build?│
                                   │                  │
                              ┌─YES┤                  │
                              │    └──────────────────┘
                              ▼
                     ┌──────────────────┐
                     │ Use CUSTOM IMAGE  │
                     │ (golden image)    │
                     └──────────────────┘
```

---

## Prerequisites

```bash
# Set environment variables
export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"
export REGION="us-central1"

# Authenticate and set project
gcloud auth login
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
```

---

## 1. Public Images

### What Are Public Images?

Public images are **Google-maintained operating system images** available to all GCP projects. Google updates these images regularly with security patches and driver updates. They serve as the foundation for most VM deployments.

### Available Image Families

#### Standard OS Images

| Image Project | Image Family | Description |
|---------------|-------------|-------------|
| `ubuntu-os-cloud` | `ubuntu-2404-lts-amd64` | Ubuntu 24.04 LTS |
| `ubuntu-os-cloud` | `ubuntu-2204-lts` | Ubuntu 22.04 LTS |
| `debian-cloud` | `debian-12` | Debian 12 (Bookworm) |
| `centos-cloud` | `centos-stream-9` | CentOS Stream 9 |
| `rocky-linux-cloud` | `rocky-linux-9` | Rocky Linux 9 |
| `rhel-cloud` | `rhel-9` | Red Hat Enterprise Linux 9 |
| `windows-cloud` | `windows-2022` | Windows Server 2022 |
| `suse-cloud` | `sles-15` | SUSE Linux Enterprise Server 15 |

#### Deep Learning VM Images (AI/ML Optimized)

These images come **pre-installed** with NVIDIA drivers, CUDA, cuDNN, NCCL, and ML frameworks:

| Image Project | Image Family | Pre-installed Software |
|---------------|-------------|----------------------|
| `deeplearning-platform-release` | `common-cu124-debian-11` | CUDA 12.4, cuDNN, NCCL (no framework) |
| `deeplearning-platform-release` | `pytorch-latest-gpu-debian-11` | PyTorch (latest) + CUDA + cuDNN |
| `deeplearning-platform-release` | `tf-latest-gpu-debian-11` | TensorFlow (latest) + CUDA + cuDNN |
| `deeplearning-platform-release` | `common-cu124-ubuntu-2204` | CUDA 12.4 on Ubuntu 22.04 |
| `deeplearning-platform-release` | `pytorch-2-4-cu124-debian-11` | PyTorch 2.4 + CUDA 12.4 |

#### HPC VM Images

| Image Project | Image Family | Pre-installed Software |
|---------------|-------------|----------------------|
| `cloud-hpc-image-public` | `hpc-rocky-linux-8` | Intel MPI, HPC tuning, libfabric, Slurm-ready |
| `cloud-hpc-image-public` | `hpc-centos-7` | HPC-optimized CentOS 7 |

### List Available Public Images

```bash
# List all image families from a project
gcloud compute images list \
    --project=deeplearning-platform-release \
    --no-standard-images \
    --format="table(name, family, status, diskSizeGb)"

# List Deep Learning VM images
gcloud compute images list \
    --project=deeplearning-platform-release \
    --no-standard-images \
    --filter="family~pytorch OR family~tf OR family~common-cu" \
    --format="table(name, family, creationTimestamp.date())"

# List HPC images
gcloud compute images list \
    --project=cloud-hpc-image-public \
    --no-standard-images \
    --format="table(name, family, status)"

# Get details of a specific image family
gcloud compute images describe-from-family pytorch-latest-gpu-debian-11 \
    --project=deeplearning-platform-release \
    --format="yaml(name, family, diskSizeGb, licenses, description)"
```

### Create a VM from a Public Image

```bash
# Basic VM from Ubuntu
gcloud compute instances create my-ubuntu-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=100GB \
    --boot-disk-type=pd-balanced

# GPU VM from Deep Learning VM image (PyTorch + CUDA pre-installed)
gcloud compute instances create my-dlvm \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --accelerator=type=nvidia-tesla-t4,count=1 \
    --image-family=pytorch-latest-gpu-debian-11 \
    --image-project=deeplearning-platform-release \
    --boot-disk-size=200GB \
    --boot-disk-type=pd-ssd \
    --maintenance-policy=TERMINATE \
    --metadata="install-nvidia-driver=True"

# HPC VM with HPC-optimized image
gcloud compute instances create my-hpc-vm \
    --zone=$ZONE \
    --machine-type=c2-standard-60 \
    --image-family=hpc-rocky-linux-8 \
    --image-project=cloud-hpc-image-public \
    --boot-disk-size=100GB \
    --boot-disk-type=pd-ssd
```

---

## 2. Custom Images

### What Are Custom Images?

Custom images are **your own VM images** stored in your GCP project. You create them by capturing the state of a VM's boot disk (or any persistent disk) into a reusable image. Custom images are ideal for creating **golden images** — standardized, pre-configured environments that can be deployed consistently across your organization.

### Image Lifecycle

```
 ┌────────────────┐     ┌────────────────┐     ┌────────────────┐     ┌───────────────┐
 │  Create Base   │     │  Install &     │     │  Create Custom │     │  Deploy New   │
 │  VM from       │────►│  Configure     │────►│  Image from    │────►│  VMs from     │
 │  Public Image  │     │  Software      │     │  VM Disk       │     │  Custom Image │
 └────────────────┘     └────────────────┘     └────────────────┘     └───────────────┘
                                                       │
                                                       ▼
                                               ┌────────────────┐
                                               │  Image Family  │
                                               │  (versioned)   │
                                               │  + Deprecation │
                                               │  Policy        │
                                               └────────────────┘
```

### Create a Custom Image from a VM

#### Step 1: Prepare the VM (Stop It First)

Stopping the VM ensures the disk is in a consistent state:

```bash
# Stop the VM to ensure disk consistency
gcloud compute instances stop my-configured-vm \
    --zone=$ZONE

# Alternatively, create from a running VM (not recommended for production)
# The image may have inconsistent filesystem state
```

#### Step 2: Create the Image

```bash
# Create image from the VM's boot disk
gcloud compute images create my-ai-image-v1 \
    --source-disk=my-configured-vm \
    --source-disk-zone=$ZONE \
    --family=my-ai-image \
    --description="AI/ML base image with PyTorch 2.4, CUDA 12.4, NCCL 2.21" \
    --storage-location=$REGION \
    --labels=team=ml-platform,env=production

# Create image from a standalone disk (not attached to a VM)
gcloud compute images create my-ai-image-v2 \
    --source-disk=my-data-disk \
    --source-disk-zone=$ZONE \
    --family=my-ai-image

# Create image from an existing image (e.g., to copy to a different region)
gcloud compute images create my-ai-image-v1-copy \
    --source-image=my-ai-image-v1 \
    --storage-location=europe-west1

# Create image from a snapshot
gcloud compute images create my-ai-image-from-snap \
    --source-snapshot=my-snapshot \
    --family=my-ai-image
```

### Image Families

Image families let you group related images and always point to the **latest non-deprecated** image in the family:

```bash
# Create a VM using the latest image in a family
gcloud compute instances create new-ml-vm \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --image-family=my-ai-image \
    --image-project=$PROJECT_ID

# List images in a family
gcloud compute images list \
    --filter="family=my-ai-image" \
    --format="table(name, family, status, creationTimestamp.date(), deprecated.state)"

# Get the latest image in a family
gcloud compute images describe-from-family my-ai-image \
    --project=$PROJECT_ID
```

### Deprecation Policies

Manage image lifecycle by deprecating old versions:

```bash
# Deprecate an old image (still usable but shows warning)
gcloud compute images deprecate my-ai-image-v1 \
    --state=DEPRECATED \
    --replacement=my-ai-image-v2

# Mark image as obsolete (cannot be used to create new VMs)
gcloud compute images deprecate my-ai-image-v1 \
    --state=OBSOLETE \
    --replacement=my-ai-image-v2

# Schedule automatic deprecation
gcloud compute images deprecate my-ai-image-v2 \
    --state=DEPRECATED \
    --replacement=my-ai-image-v3 \
    --deprecate-on="2026-06-01T00:00:00Z" \
    --obsolete-on="2026-09-01T00:00:00Z" \
    --delete-on="2026-12-01T00:00:00Z"
```

### Share Custom Images Across Projects

```bash
# Grant another project read access to your images
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/compute.imageUser"

# Grant access to a specific image
gcloud compute images add-iam-policy-binding my-ai-image-v1 \
    --member="user:alice@example.com" \
    --role="roles/compute.imageUser"

# Use a shared image from another project
gcloud compute instances create new-vm \
    --zone=$ZONE \
    --image=my-ai-image-v1 \
    --image-project=shared-images-project
```

### Manage Custom Images

```bash
# List all custom images in your project
gcloud compute images list \
    --no-standard-images \
    --format="table(name, family, status, diskSizeGb, creationTimestamp.date())"

# Get image details
gcloud compute images describe my-ai-image-v1 \
    --format="yaml(name, family, status, diskSizeGb, storageLocations, labels)"

# Delete an image
gcloud compute images delete my-ai-image-v1 --quiet

# Export an image to Cloud Storage (for sharing outside GCP)
gcloud compute images export \
    --image=my-ai-image-v1 \
    --destination-uri=gs://my-bucket/images/my-ai-image-v1.tar.gz \
    --export-format=vmdk

# Import an image from Cloud Storage
gcloud compute images import my-imported-image \
    --source-file=gs://my-bucket/images/my-image.vmdk \
    --os=ubuntu-2204
```

> **Tip:** For automated, repeatable image building, use **Packer** with the Google Cloud builder. See the [packer/](./packer/) subdirectory for templates and Cloud Build integration.

---

## 3. Snapshots (Standard)

### What Are Snapshots?

Snapshots are **point-in-time copies** of persistent disks. After the initial full snapshot, subsequent snapshots are **incremental** — they only store the blocks that changed since the previous snapshot, reducing storage costs and creation time.

### Snapshot Architecture

```
  Persistent Disk                  Snapshot Chain (Incremental)
 ┌──────────────┐
 │              │     Snapshot 1        Snapshot 2        Snapshot 3
 │  100 GB      │    ┌──────────┐     ┌──────────┐     ┌──────────┐
 │  Boot Disk   │───►│ Full     │────►│ Delta    │────►│ Delta    │
 │              │    │ 100 GB   │     │ 5 GB     │     │ 2 GB     │
 │              │    │ (stored) │     │ (changes │     │ (changes │
 └──────────────┘    │          │     │  only)   │     │  only)   │
                     └──────────┘     └──────────┘     └──────────┘

  Each snapshot is independently restorable — GCP manages the chain internally.
  Deleting Snapshot 1 redistributes its data to Snapshot 2 automatically.
```

### Create Snapshots

```bash
# Create a snapshot from a disk (VM can be running)
gcloud compute snapshots create my-ml-snapshot \
    --source-disk=my-ml-vm \
    --source-disk-zone=$ZONE \
    --description="ML VM snapshot before framework upgrade" \
    --labels=env=dev,team=ml \
    --storage-location=$REGION

# Create a snapshot from a running VM's boot disk
gcloud compute disks snapshot my-ml-vm \
    --zone=$ZONE \
    --snapshot-names=my-ml-snapshot-$(date +%Y%m%d)

# Create a snapshot with guest flush (Windows or apps with VSS support)
gcloud compute snapshots create my-snapshot-consistent \
    --source-disk=my-vm \
    --source-disk-zone=$ZONE \
    --guest-flush
```

### Create a VM from a Snapshot

```bash
# Create a new boot disk from snapshot, then create VM
gcloud compute disks create restored-boot-disk \
    --source-snapshot=my-ml-snapshot \
    --zone=$ZONE \
    --type=pd-ssd \
    --size=200GB

gcloud compute instances create restored-ml-vm \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --disk=name=restored-boot-disk,boot=yes

# Or create a VM directly with --source-snapshot on the boot disk
gcloud compute instances create restored-ml-vm \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --create-disk="boot=yes,source-snapshot=my-ml-snapshot,size=200,type=pd-ssd"
```

### Snapshot Schedules (Automated Snapshots)

```bash
# Create a snapshot schedule (daily at 2 AM UTC, keep 7 days)
gcloud compute resource-policies create snapshot-schedule my-daily-schedule \
    --region=$REGION \
    --max-retention-days=7 \
    --on-source-disk-delete=keep-auto-snapshots \
    --daily-schedule \
    --start-time=02:00 \
    --storage-location=$REGION

# Attach the schedule to a disk
gcloud compute disks add-resource-policies my-ml-vm \
    --zone=$ZONE \
    --resource-policies=my-daily-schedule

# Create a weekly schedule (every Monday at 3 AM)
gcloud compute resource-policies create snapshot-schedule my-weekly-schedule \
    --region=$REGION \
    --max-retention-days=30 \
    --weekly-schedule-from-file=weekly-schedule.json \
    --storage-location=$REGION

# List snapshot schedules
gcloud compute resource-policies list \
    --filter="region=$REGION" \
    --format="table(name, status, snapshotSchedulePolicy.schedule)"
```

### Manage Snapshots

```bash
# List all snapshots
gcloud compute snapshots list \
    --format="table(name, status, sourceDisk.scope(), diskSizeGb, storageBytes.size(), creationTimestamp.date())"

# Describe a snapshot
gcloud compute snapshots describe my-ml-snapshot \
    --format="yaml(name, status, diskSizeGb, storageBytes, storageLocations, snapshotType)"

# Delete a snapshot
gcloud compute snapshots delete my-ml-snapshot --quiet
```

---

## 4. Archive Snapshots

### What Are Archive Snapshots?

Archive snapshots are a **lower-cost, cold-storage** variant of standard snapshots. They are designed for **long-term retention** scenarios where you need to keep disk backups but don't need fast restore times.

### Archive vs. Standard Snapshots

| Feature | Standard Snapshot | Archive Snapshot |
|---------|------------------|-----------------|
| **Storage Cost** | ~$0.026/GB/month | ~$0.0026/GB/month (10x cheaper) |
| **Restore Time** | Minutes | Minutes to hours (depends on size) |
| **Minimum Storage Duration** | None | 90 days (early delete charges apply) |
| **Use Case** | Backup, DR, cloning | Compliance, audit, long-term retention |
| **Incremental** | Yes | Yes |
| **Create from Running VM** | Yes | Yes |
| **Cross-Region** | Yes | Yes |

### Create Archive Snapshots

```bash
# Create an archive snapshot
gcloud compute snapshots create my-archive-snapshot \
    --source-disk=my-ml-vm \
    --source-disk-zone=$ZONE \
    --snapshot-type=ARCHIVE \
    --description="Quarterly archive of ML training environment" \
    --labels=retention=quarterly,compliance=true \
    --storage-location=$REGION

# Verify it was created as archive type
gcloud compute snapshots describe my-archive-snapshot \
    --format="yaml(name, snapshotType, storageLocations, storageBytes, creationTimestamp)"
```

### Restore from an Archive Snapshot

Restoring from an archive snapshot works the same as standard snapshots, but may take longer:

```bash
# Create a disk from archive snapshot
gcloud compute disks create restored-from-archive \
    --source-snapshot=my-archive-snapshot \
    --zone=$ZONE \
    --type=pd-balanced

# Create a VM from the restored disk
gcloud compute instances create restored-archive-vm \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --disk=name=restored-from-archive,boot=yes
```

### When to Use Archive Snapshots

- **Regulatory compliance** — retain disk images for 1–7 years per policy requirements
- **Quarterly/annual backups** — keep a baseline of your environment at regular intervals
- **Pre-migration archives** — preserve the state of systems before major upgrades
- **Decommissioned project data** — keep a recoverable copy of project environments

> **Warning:** Archive snapshots have a 90-day minimum storage duration. Deleting an archive snapshot before 90 days incurs an early deletion fee.

---

## 5. Existing Disks

### What Are Existing Disks?

You can create new VMs by **attaching an existing persistent disk** as the boot disk, or by **cloning a disk** to create an independent copy. This is the fastest way to duplicate a VM's environment since the data is already on a persistent disk — no image creation or snapshot restore required.

### Clone a Disk (Instant)

Disk cloning creates an **instant copy** of a persistent disk in the same zone. The clone is a fully independent disk that shares no data with the source after creation:

```bash
# Clone a disk (instant — no need to stop the source VM)
gcloud compute disks create cloned-boot-disk \
    --source-disk=my-ml-vm \
    --source-disk-zone=$ZONE \
    --zone=$ZONE \
    --type=pd-ssd

# Create a VM from the cloned disk
gcloud compute instances create ml-vm-clone \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --disk=name=cloned-boot-disk,boot=yes,auto-delete=yes
```

### Attach an Existing Detached Disk

If a disk is not attached to any VM (e.g., the original VM was deleted with `--keep-disks=boot`), you can attach it to a new VM:

```bash
# Delete a VM but keep its boot disk
gcloud compute instances delete old-ml-vm \
    --zone=$ZONE \
    --keep-disks=boot

# Create a new VM using the orphaned boot disk
gcloud compute instances create new-ml-vm \
    --zone=$ZONE \
    --machine-type=n1-standard-16 \
    --disk=name=old-ml-vm,boot=yes,auto-delete=no

# Attach a data disk to an existing VM
gcloud compute instances attach-disk my-vm \
    --zone=$ZONE \
    --disk=my-data-disk \
    --mode=rw
```

### Create a VM with an Additional Existing Disk

```bash
# Create a VM with a boot disk from an image AND an existing data disk
gcloud compute instances create my-vm \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --disk=name=my-datasets-disk,mode=rw,auto-delete=no
```

### Use Cases for Existing Disks

| Scenario | Approach |
|----------|----------|
| Quick dev/test clone | `gcloud compute disks create --source-disk=...` |
| VM machine type upgrade | Delete VM (keep disk) → create new VM with old disk |
| Disaster recovery | Attach replicated disk in another zone |
| Shared read-only datasets | Attach disk in `ro` mode to multiple VMs |

---

## 6. Startup Scripts

### How Startup Scripts Work

Startup scripts run **automatically every time a VM boots** (initial boot and reboots). They execute as `root` on Linux and as `System` on Windows. GCP retrieves the script from the VM's **metadata service** and executes it via the guest agent.

### Startup Script Execution Lifecycle

```
  ┌────────────────────────────┐
  │  VM Instance Created /     │
  │  Rebooted                  │
  └─────────────┬──────────────┘
                │
                ▼
  ┌────────────────────────────┐
  │  GCE Guest Agent Starts    │
  │  (google-guest-agent)      │
  └─────────────┬──────────────┘
                │
                ▼
  ┌────────────────────────────┐
  │  Agent queries metadata    │
  │  server at 169.254.169.254 │
  │  for startup-script or     │
  │  startup-script-url        │
  └─────────────┬──────────────┘
                │
          ┌─────┴─────┐
          │            │
          ▼            ▼
  ┌──────────────┐  ┌────────────────────┐
  │ Inline       │  │ URL-based          │
  │ Script       │  │ (downloads from    │
  │ (metadata)   │  │ GCS bucket)        │
  └──────┬───────┘  └────────┬───────────┘
         │                   │
         └─────────┬─────────┘
                   │
                   ▼
  ┌────────────────────────────┐
  │  Script executes as root   │
  │  (Linux) or System (Win)   │
  │                            │
  │  stdout → serial port 1    │
  │  stderr → serial port 1    │
  └─────────────┬──────────────┘
                │
                ▼
  ┌────────────────────────────┐
  │  VM is ready               │
  │  (script exit code logged) │
  └────────────────────────────┘
```

### Inline Startup Script

Small scripts can be passed directly in the VM metadata:

```bash
# Inline startup script (Linux)
gcloud compute instances create my-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install -y python3-pip git
    pip3 install numpy pandas scikit-learn
    echo "Startup script completed at $(date)" >> /var/log/startup-script-status.log
    '
```

### Script from a File (Local)

For larger scripts, pass a local file:

```bash
# Pass a local script file
gcloud compute instances create my-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --metadata-from-file=startup-script=./scripts/setup-ml-env.sh
```

### Script from Cloud Storage (Recommended for Large Scripts)

For complex setups, store the script in GCS and reference it by URL:

```bash
# Upload script to GCS
gsutil cp ./scripts/setup-ml-env.sh gs://my-startup-scripts/setup-ml-env.sh

# Reference GCS URL in VM creation
gcloud compute instances create my-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --metadata=startup-script-url=gs://my-startup-scripts/setup-ml-env.sh \
    --scopes=storage-ro
```

### Windows Startup Scripts

```bash
# Windows PowerShell startup script
gcloud compute instances create win-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=windows-2022 \
    --image-project=windows-cloud \
    --metadata=windows-startup-script-ps1='
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    Write-Output "Startup script completed" | Out-File C:\startup-log.txt
    '

# Windows startup script from GCS
gcloud compute instances create win-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=windows-2022 \
    --image-project=windows-cloud \
    --metadata=windows-startup-script-url=gs://my-scripts/setup.ps1
```

### Update Startup Script on an Existing VM

```bash
# Update the startup script (runs on next boot)
gcloud compute instances add-metadata my-vm \
    --zone=$ZONE \
    --metadata-from-file=startup-script=./scripts/updated-setup.sh

# Remove a startup script
gcloud compute instances remove-metadata my-vm \
    --zone=$ZONE \
    --keys=startup-script
```

### Viewing Startup Script Output

```bash
# View serial port output (startup script logs go here)
gcloud compute instances get-serial-port-output my-vm \
    --zone=$ZONE

# Tail the serial port output (useful while script is running)
gcloud compute instances tail-serial-port-output my-vm \
    --zone=$ZONE

# SSH in and check the log directly
gcloud compute ssh my-vm --zone=$ZONE --command="sudo journalctl -u google-startup-scripts.service"

# Check if startup script succeeded
gcloud compute ssh my-vm --zone=$ZONE --command="sudo cat /var/log/syslog | grep startup-script"
```

### Startup Script Best Practices

| Practice | Why |
|----------|-----|
| **Make scripts idempotent** | Scripts run on every boot — use `apt-get install -y` (not interactive), check if software is already installed |
| **Use GCS for large scripts** | Inline metadata has a 256 KB limit; GCS scripts can be any size |
| **Log progress** | Write to a log file (e.g., `/var/log/startup-script-custom.log`) for debugging |
| **Use `set -e`** | Exit on first error to avoid partial configurations |
| **Signal completion** | Touch a file (e.g., `/tmp/startup-complete`) or write to metadata so other systems know the VM is ready |
| **Prefer custom images for heavy installs** | If startup takes >5 min, bake it into a custom image instead |

### Idempotent Startup Script Pattern

```bash
#!/bin/bash
set -euo pipefail

MARKER="/var/log/startup-script-v1-complete"

# Skip if already run (idempotent)
if [ -f "$MARKER" ]; then
    echo "Startup script v1 already completed. Skipping."
    exit 0
fi

echo "Starting first-boot configuration..."

# --- Your installation steps here ---
apt-get update
apt-get install -y python3-pip git htop
pip3 install torch torchvision

# --- Mark as complete ---
echo "Startup script v1 completed at $(date)" > "$MARKER"
echo "First-boot configuration complete."
```

---

## 7. AI/ML/HPC Software Installation Options

This section covers the most common software stacks for AI, ML, and HPC workloads, and how to install them — whether via startup scripts, custom images, or pre-built public images.

### Installation Methods Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│              AI/ML/HPC Software Installation Options                    │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │  PRE-BUILT        │  │  STARTUP SCRIPT   │  │  CUSTOM IMAGE        │  │
│  │  PUBLIC IMAGES    │  │  (Runtime Install) │  │  (Baked-in)          │  │
│  │                  │  │                  │  │                      │  │
│  │  ✓ Fastest boot  │  │  ✓ Flexible      │  │  ✓ Reproducible      │  │
│  │  ✓ Zero config   │  │  ✓ Version pin   │  │  ✓ Fast boot         │  │
│  │  ✗ Fixed versions│  │  ✗ Slow boot     │  │  ✓ Version control   │  │
│  │  ✗ Google's stack│  │  ✗ Network req'd │  │  ✗ Build pipeline    │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘  │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────────────────────────────────┐ │
│  │  CONTAINERS       │  │  ANSIBLE / CONFIGURATION MANAGEMENT         │ │
│  │  (NGC, DLC)       │  │                                              │ │
│  │                  │  │  ✓ Declarative       ✓ Multi-node            │ │
│  │  ✓ Portable      │  │  ✓ Idempotent        ✗ Requires tooling     │ │
│  │  ✓ Isolated      │  │                                              │ │
│  │  ✗ Overhead      │  │                                              │ │
│  └──────────────────┘  └──────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7a. NVIDIA GPU Drivers

GPU drivers are required for all NVIDIA GPU workloads. The Deep Learning VM images include drivers, but if you're using a plain OS image, install them manually:

```bash
#!/bin/bash
# install-nvidia-drivers.sh — Install NVIDIA GPU drivers on Ubuntu 22.04/24.04

set -euo pipefail

# Check if driver is already installed
if command -v nvidia-smi &>/dev/null; then
    echo "NVIDIA driver already installed:"
    nvidia-smi
    exit 0
fi

echo "Installing NVIDIA GPU drivers..."

# Add NVIDIA package repository
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Install the driver (headless — no X11/GUI)
apt-get update
apt-get install -y linux-headers-$(uname -r)
apt-get install -y nvidia-driver-550-server --no-install-recommends

# Load the driver
modprobe nvidia

echo "NVIDIA driver installation complete."
nvidia-smi
```

**Using the Google-provided installer (recommended for GCE):**

```bash
# When creating a VM from a Deep Learning base image, set this metadata flag:
gcloud compute instances create gpu-vm \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --accelerator=type=nvidia-tesla-t4,count=1 \
    --image-family=common-cu124-debian-11 \
    --image-project=deeplearning-platform-release \
    --maintenance-policy=TERMINATE \
    --metadata="install-nvidia-driver=True"
```

### 7b. CUDA Toolkit

```bash
#!/bin/bash
# install-cuda.sh — Install CUDA Toolkit 12.4

set -euo pipefail

CUDA_VERSION="12-4"

if [ -d "/usr/local/cuda-12.4" ]; then
    echo "CUDA 12.4 already installed."
    exit 0
fi

echo "Installing CUDA Toolkit 12.4..."

# Download and install CUDA keyring
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
rm cuda-keyring_1.1-1_all.deb

apt-get update
apt-get install -y cuda-toolkit-${CUDA_VERSION}

# Set environment variables
cat >> /etc/profile.d/cuda.sh << 'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF

source /etc/profile.d/cuda.sh

echo "CUDA Toolkit installation complete."
nvcc --version
```

### 7c. cuDNN (CUDA Deep Neural Network Library)

```bash
#!/bin/bash
# install-cudnn.sh — Install cuDNN for CUDA 12.x

set -euo pipefail

echo "Installing cuDNN..."

apt-get update
apt-get install -y libcudnn9-cuda-12 libcudnn9-dev-cuda-12

echo "cuDNN installation complete."
dpkg -l | grep cudnn
```

### 7d. NCCL (NVIDIA Collective Communications Library)

NCCL is essential for **multi-GPU and multi-node** distributed training:

```bash
#!/bin/bash
# install-nccl.sh — Install NCCL for multi-GPU communication

set -euo pipefail

echo "Installing NCCL..."

apt-get update
apt-get install -y libnccl2 libnccl-dev

# Verify installation
echo "NCCL installation complete."
dpkg -l | grep nccl

# Set environment variable for NCCL debugging (optional)
echo 'export NCCL_DEBUG=INFO' >> /etc/profile.d/nccl.sh
```

### 7e. ML Frameworks (PyTorch, TensorFlow, JAX)

```bash
#!/bin/bash
# install-ml-frameworks.sh — Install PyTorch, TensorFlow, and JAX

set -euo pipefail

# Install Python and pip
apt-get update
apt-get install -y python3 python3-pip python3-venv

# Create a virtual environment (recommended)
python3 -m venv /opt/ml-env
source /opt/ml-env/bin/activate

# --- PyTorch with CUDA 12.4 ---
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Verify PyTorch GPU support
python3 -c "import torch; print(f'PyTorch {torch.__version__}, CUDA available: {torch.cuda.is_available()}')"

# --- TensorFlow with GPU support ---
pip install tensorflow[and-cuda]

# Verify TensorFlow GPU support
python3 -c "import tensorflow as tf; print(f'TensorFlow {tf.__version__}, GPUs: {tf.config.list_physical_devices(\"GPU\")}')"

# --- JAX with CUDA support ---
pip install jax[cuda12]

# Verify JAX GPU support
python3 -c "import jax; print(f'JAX {jax.__version__}, Devices: {jax.devices()}')"

echo "ML frameworks installation complete."
```

### 7f. HPC Libraries

```bash
#!/bin/bash
# install-hpc-libs.sh — Install common HPC libraries

set -euo pipefail

apt-get update

# --- OpenMPI (Message Passing Interface) ---
apt-get install -y openmpi-bin libopenmpi-dev

# Verify
mpirun --version

# --- Intel MPI (via Intel oneAPI HPC Toolkit) ---
# Add Intel repository
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
    gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | \
    tee /etc/apt/sources.list.d/oneAPI.list
apt-get update
apt-get install -y intel-oneapi-mpi-devel

# --- libfabric (High-performance communication) ---
apt-get install -y libfabric-dev libfabric-bin

# --- UCX (Unified Communication X) ---
apt-get install -y libucx-dev ucx-utils

# --- numactl (NUMA-aware process placement) ---
apt-get install -y numactl hwloc

# --- Slurm (if building an HPC cluster) ---
# apt-get install -y slurm-wlm slurm-client

echo "HPC libraries installation complete."
```

### 7g. NVIDIA NGC Containers (Container-Based Approach)

Instead of installing frameworks directly, use NVIDIA's pre-built GPU-optimized containers:

```bash
#!/bin/bash
# setup-ngc-containers.sh — Set up Docker + NVIDIA Container Toolkit for NGC

set -euo pipefail

# Install Docker
apt-get update
apt-get install -y docker.io

# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "NVIDIA Container Toolkit setup complete."
echo ""
echo "Example: Run PyTorch NGC container:"
echo "  docker run --rm --gpus all nvcr.io/nvidia/pytorch:24.07-py3 python -c 'import torch; print(torch.cuda.is_available())'"
echo ""
echo "Example: Run TensorFlow NGC container:"
echo "  docker run --rm --gpus all nvcr.io/nvidia/tensorflow:24.07-tf2-py3 python -c 'import tensorflow as tf; print(tf.config.list_physical_devices(\"GPU\"))'"
```

**Common NGC Container Images:**

| Container | Image URI | Includes |
|-----------|-----------|----------|
| PyTorch | `nvcr.io/nvidia/pytorch:24.07-py3` | PyTorch, CUDA, cuDNN, NCCL, NEMO |
| TensorFlow | `nvcr.io/nvidia/tensorflow:24.07-tf2-py3` | TensorFlow 2, CUDA, cuDNN, TensorRT |
| RAPIDS | `nvcr.io/nvidia/rapidsai/rapidsai:24.06-cuda12.2-runtime-ubuntu22.04` | cuDF, cuML, cuGraph |
| Triton Inference Server | `nvcr.io/nvidia/tritonserver:24.07-py3` | Multi-framework model serving |
| NVIDIA HPC SDK | `nvcr.io/nvidia/nvhpc:24.7-devel-cuda12.5-ubuntu22.04` | HPC compilers, MPI, profilers |

### 7h. Google Deep Learning Containers (DLC)

Google maintains its own set of GPU-optimized containers, hosted on Artifact Registry:

```bash
# Pull and run a Google DL Container
docker pull us-docker.pkg.dev/deeplearning-platform-release/gcr.io/pytorch-gpu.2-4:latest

docker run --rm --gpus all \
    us-docker.pkg.dev/deeplearning-platform-release/gcr.io/pytorch-gpu.2-4:latest \
    python -c "import torch; print(f'PyTorch: {torch.__version__}, CUDA: {torch.cuda.is_available()}')"

# Available Google DL Containers:
# - pytorch-gpu.{VERSION}
# - tf2-gpu.{VERSION}
# - jax-gpu.{VERSION}
# - base-gpu (CUDA + drivers only)
```

### 7i. Complete Startup Script Example: Full AI/ML Stack

This example installs a complete ML development environment from a plain Ubuntu image:

```bash
#!/bin/bash
# startup-ml-full-stack.sh
# Complete ML development environment setup
# Use with: --metadata-from-file=startup-script=startup-ml-full-stack.sh

set -euo pipefail
exec > >(tee -a /var/log/startup-script-custom.log) 2>&1

MARKER="/var/log/startup-ml-stack-v1-complete"
if [ -f "$MARKER" ]; then
    echo "[$(date)] ML stack v1 already installed. Skipping."
    exit 0
fi

echo "[$(date)] ========== Starting ML Stack Installation =========="

# ---- System packages ----
echo "[$(date)] Installing system packages..."
apt-get update
apt-get install -y \
    build-essential \
    python3 python3-pip python3-venv \
    git wget curl htop tmux \
    linux-headers-$(uname -r)

# ---- NVIDIA Drivers (if GPU attached) ----
if lspci | grep -i nvidia > /dev/null 2>&1; then
    echo "[$(date)] GPU detected. Installing NVIDIA drivers..."
    
    # Install CUDA keyring
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
    rm cuda-keyring_1.1-1_all.deb
    
    apt-get update
    apt-get install -y cuda-toolkit-12-4
    apt-get install -y libcudnn9-cuda-12 libnccl2 libnccl-dev
    
    # Set CUDA environment
    cat >> /etc/profile.d/cuda.sh << 'CUDA_EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
CUDA_EOF
    source /etc/profile.d/cuda.sh
    
    echo "[$(date)] NVIDIA driver and CUDA installation complete."
    nvidia-smi || echo "nvidia-smi not available yet (may need reboot)"
else
    echo "[$(date)] No GPU detected. Skipping NVIDIA drivers."
fi

# ---- Python ML Environment ----
echo "[$(date)] Setting up Python ML environment..."
python3 -m venv /opt/ml-env

source /opt/ml-env/bin/activate

pip install --upgrade pip setuptools wheel

# Core ML libraries
pip install \
    numpy \
    pandas \
    scikit-learn \
    scipy \
    matplotlib \
    jupyterlab

# PyTorch with CUDA support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Additional ML tools
pip install \
    transformers \
    datasets \
    accelerate \
    tensorboard \
    wandb

# ---- Create activation helper ----
cat >> /etc/profile.d/ml-env.sh << 'ML_EOF'
# Activate ML environment for all users
if [ -d "/opt/ml-env" ]; then
    source /opt/ml-env/bin/activate
fi
ML_EOF

# ---- Docker + NVIDIA Container Toolkit (optional) ----
if lspci | grep -i nvidia > /dev/null 2>&1; then
    echo "[$(date)] Installing Docker + NVIDIA Container Toolkit..."
    apt-get install -y docker.io
    
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    apt-get update
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
fi

# ---- Mark as complete ----
echo "[$(date)] ========== ML Stack Installation Complete ==========" | tee "$MARKER"
```

**Use this startup script:**

```bash
gcloud compute instances create ml-workstation \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --accelerator=type=nvidia-tesla-t4,count=1 \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=200GB \
    --boot-disk-type=pd-ssd \
    --maintenance-policy=TERMINATE \
    --scopes=storage-ro \
    --metadata-from-file=startup-script=./startup-ml-full-stack.sh
```

---

## Comprehensive Comparison

### Choosing the Right Method

| Criteria | Public Image | Custom Image | Snapshot | Archive Snapshot | Existing Disk |
|----------|-------------|-------------|----------|-----------------|---------------|
| **Setup effort** | None | Medium (build pipeline) | Low (one command) | Low (one command) | None |
| **Boot speed** | Fast | Fast | Fast | Slow | Instant |
| **Reproducibility** | High (Google-maintained) | High (your version) | Medium | Medium | Low |
| **Cost (storage)** | Free | $0.050/GB/mo | $0.026/GB/mo | $0.0026/GB/mo | PD pricing |
| **Cross-project sharing** | Built-in | IAM-based | IAM-based | IAM-based | Same project only |
| **Cross-region** | All regions | Set at creation | Set at creation | Set at creation | Same zone |
| **Includes data** | No (OS only) | No (OS + software) | Yes (full disk) | Yes (full disk) | Yes (full disk) |
| **Versioning** | Image families | Image families | Manual naming | Manual naming | N/A |
| **Automation** | N/A | Packer, Cloud Build | Snapshot schedules | Manual | N/A |
| **Best for** | Quick start, standard envs | Golden images, org standards | Backup, DR, cloning | Compliance, archives | Dev/test, upgrades |

### Recommended Patterns for AI/ML/HPC

| Pattern | Implementation |
|---------|---------------|
| **Quick experimentation** | Use Deep Learning VM public image + startup script for extras |
| **Team-wide ML environment** | Build a custom image with [Packer](./packer/) → share via image family |
| **Pre-training checkpoint** | Snapshot the data disk before a long training run |
| **Compliance retention** | Archive snapshot of production ML environments quarterly |
| **Scale-out training cluster** | Custom image + MIG (Managed Instance Group) for identical nodes |
| **Containerized inference** | Plain VM + NVIDIA Container Toolkit + NGC containers |

---

## Best Practices

### Image Management

1. **Use image families** — Always create images within a family so that `--image-family` always points to the latest version
2. **Automate builds with [Packer](./packer/)** — Don't create images manually; use Packer or Cloud Build for reproducibility
3. **Version your images** — Include version numbers and dates in image names (e.g., `ml-base-v3-20260327`)
4. **Deprecate old images** — Set deprecation policies so teams naturally migrate to newer images
5. **Minimize image size** — Remove build dependencies, clean apt caches (`apt-get clean`), and use `--force-create` to avoid bloat

### Security

1. **Scan images for vulnerabilities** — Use Container Analysis or third-party tools on custom images
2. **Don't store secrets in images** — Use Secret Manager and retrieve secrets at runtime
3. **Enable OS Login** — Replace static SSH keys with identity-based authentication
4. **Patch regularly** — Rebuild custom images monthly to include latest security patches

### Performance

1. **Use SSD boot disks** (`pd-ssd` or `pd-balanced`) for GPU/TPU VMs — faster driver loading and library imports
2. **Bake heavy installs into images** — If startup script takes >5 minutes, create a custom image instead
3. **Use local SSD** for scratch space in training workloads — much faster than persistent disk
4. **Pre-download large models** into images or data disks to avoid startup delays

---

## Cleanup

```bash
# Delete custom images
gcloud compute images delete my-ai-image-v1 --quiet

# Delete snapshots
gcloud compute snapshots delete my-ml-snapshot --quiet

# Delete archive snapshots
gcloud compute snapshots delete my-archive-snapshot --quiet

# Delete orphaned disks
gcloud compute disks delete cloned-boot-disk --zone=$ZONE --quiet

# Delete VMs
gcloud compute instances delete my-vm --zone=$ZONE --quiet

# Delete snapshot schedules
gcloud compute resource-policies delete my-daily-schedule --region=$REGION --quiet
```

---

## References

- [Compute Engine Images Overview](https://cloud.google.com/compute/docs/images)
- [Public Images List](https://cloud.google.com/compute/docs/images/os-details)
- [Creating Custom Images](https://cloud.google.com/compute/docs/images/create-delete-deprecate-private-images)
- [Image Families](https://cloud.google.com/compute/docs/images/image-families-best-practices)
- [Persistent Disk Snapshots](https://cloud.google.com/compute/docs/disks/create-snapshots)
- [Archive Snapshots](https://cloud.google.com/compute/docs/disks/archive-snapshot)
- [Snapshot Schedules](https://cloud.google.com/compute/docs/disks/scheduled-snapshots)
- [Startup Scripts](https://cloud.google.com/compute/docs/instances/startup-scripts)
- [Deep Learning VM Images](https://cloud.google.com/deep-learning-vm/docs/images)
- [Deep Learning Containers](https://cloud.google.com/deep-learning-containers/docs/choosing-container)
- [HPC VM Images](https://cloud.google.com/compute/docs/instances/create-hpc-vm)
- [NVIDIA GPU Drivers on GCE](https://cloud.google.com/compute/docs/gpus/install-drivers-gpu)
- [NVIDIA NGC Catalog](https://catalog.ngc.nvidia.com/)
- [Building VM Images with Packer](https://cloud.google.com/build/docs/building/build-vm-images-with-packer)
- [Sharing Images Across Projects](https://cloud.google.com/compute/docs/images/sharing-images-across-projects)
