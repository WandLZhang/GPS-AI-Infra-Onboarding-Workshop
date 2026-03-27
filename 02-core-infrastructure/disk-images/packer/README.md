# Building VM Images with Packer on Google Cloud

## Table of Contents

- [Overview](#overview)
- [What is Packer?](#what-is-packer)
- [Why Use Packer Instead of Manual Image Creation?](#why-use-packer-instead-of-manual-image-creation)
- [Architecture: How Packer Works on GCP](#architecture-how-packer-works-on-gcp)
- [Prerequisites](#prerequisites)
- [Packer Template Anatomy (HCL2)](#packer-template-anatomy-hcl2)
- [Example 1: Basic Ubuntu Image](#example-1-basic-ubuntu-image)
- [Example 2: AI/ML GPU Image with CUDA & PyTorch](#example-2-aiml-gpu-image-with-cuda--pytorch)
- [Example 3: HPC Image with MPI & libfabric](#example-3-hpc-image-with-mpi--libfabric)
- [Example 4: Multi-Provisioner Build with Ansible](#example-4-multi-provisioner-build-with-ansible)
- [Example 5: Image Families & Versioning](#example-5-image-families--versioning)
- [Provisioners Deep Dive](#provisioners-deep-dive)
- [Variables & Parameterization](#variables--parameterization)
- [Packer with Cloud Build (CI/CD)](#packer-with-cloud-build-cicd)
- [Image Management & Lifecycle](#image-management--lifecycle)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Command Reference](#command-reference)
- [References](#references)

---

## Overview

This guide provides a comprehensive, hands-on walkthrough of using **HashiCorp Packer** to build custom VM images (golden images) on Google Cloud. It covers everything from basic concepts through production-grade CI/CD pipelines, with concrete examples for AI/ML and HPC workloads.

For a broader overview of all GCP VM image creation methods (public images, custom images, snapshots, startup scripts), see the parent [disk-images README](../README.md).

---

## What is Packer?

[Packer](https://www.packer.io/) is an open-source tool by HashiCorp that automates the creation of machine images. Instead of manually creating a VM, installing software, and then capturing an image, Packer lets you define the entire process **as code** in a declarative template file.

Key characteristics:

| Feature | Description |
|---------|-------------|
| **Infrastructure as Code** | Image definitions are version-controlled `.pkr.hcl` files |
| **Multi-platform** | Same tool builds images for GCP, AWS, Azure, VMware, Docker, etc. |
| **Reproducible** | Every build produces an identical image from the same template |
| **Parallel builds** | Can build images for multiple platforms simultaneously |
| **Provisioner agnostic** | Supports Shell, Ansible, Chef, Puppet, PowerShell, and more |
| **Plugin ecosystem** | Extensible via plugins (the `googlecompute` builder is a plugin) |

### Packer vs. Manual Image Creation

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Manual Image Creation                                      │
│                                                                                     │
│   1. gcloud compute instances create temp-vm ...                                    │
│   2. gcloud compute ssh temp-vm                                                     │
│   3. (manually install software, configure, etc.)                                   │
│   4. gcloud compute instances stop temp-vm                                          │
│   5. gcloud compute images create my-image --source-disk=temp-vm                    │
│   6. gcloud compute instances delete temp-vm                                        │
│                                                                                     │
│   Problems: Not reproducible, error-prone, no version control, slow                 │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Packer Image Creation                                      │
│                                                                                     │
│   1. Write a .pkr.hcl template (one-time)                                           │
│   2. packer build template.pkr.hcl                                                  │
│                                                                                     │
│   Benefits: Reproducible, version-controlled, automated, fast, auditable            │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Why Use Packer Instead of Manual Image Creation?

| Concern | Manual | Packer |
|---------|--------|--------|
| **Reproducibility** | ❌ Depends on who runs the steps and when | ✅ Identical output every time from the same template |
| **Version control** | ❌ Steps live in a wiki or someone's head | ✅ Templates are `.pkr.hcl` files tracked in Git |
| **Auditability** | ❌ No record of what was installed or configured | ✅ Full provenance: template + build logs |
| **Speed** | ❌ 30–60 min of manual SSH and typing | ✅ Fully automated, hands-off build |
| **CI/CD integration** | ❌ Hard to trigger from a pipeline | ✅ `packer build` runs in Cloud Build, GitHub Actions, etc. |
| **Multi-environment** | ❌ Must repeat for each project/region | ✅ Parameterize with variables, build once for many targets |
| **Testing** | ❌ Hope it works when you deploy | ✅ Validate templates, test images post-build |
| **Team collaboration** | ❌ One person knows how to build the image | ✅ Anyone can review, modify, and build from the template |

---

## Architecture: How Packer Works on GCP

When you run `packer build`, here's exactly what happens behind the scenes:

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                     Packer Build Lifecycle on Google Cloud                            │
│                                                                                      │
│  ┌─────────────┐                                                                     │
│  │  Developer   │                                                                     │
│  │  runs:       │                                                                     │
│  │  packer build│                                                                     │
│  │  template.   │                                                                     │
│  │  pkr.hcl     │                                                                     │
│  └──────┬──────┘                                                                     │
│         │                                                                             │
│         │ Step 1: Packer reads the template                                           │
│         │ and authenticates with GCP                                                  │
│         ▼                                                                             │
│  ┌──────────────────────────────────────────┐                                         │
│  │  Step 2: CREATE TEMPORARY VM              │                                         │
│  │                                          │                                         │
│  │  Packer calls the Compute Engine API to  │                                         │
│  │  create a temporary VM instance using    │                                         │
│  │  the source image you specified.         │                                         │
│  │                                          │                                         │
│  │  • Uses your specified machine type      │                                         │
│  │  • Uses your specified source image      │                                         │
│  │  • Creates in the specified zone         │                                         │
│  │  • Assigns a temporary SSH key           │                                         │
│  │  • Assigns a temp service account        │                                         │
│  └──────────────┬───────────────────────────┘                                         │
│                 │                                                                      │
│                 ▼                                                                      │
│  ┌──────────────────────────────────────────┐                                         │
│  │  Step 3: PROVISION THE VM                 │                                         │
│  │                                          │                                         │
│  │  Packer SSHs into the temporary VM       │                                         │
│  │  and runs your provisioners:             │                                         │
│  │                                          │                                         │
│  │  • Shell scripts (apt install, pip, etc.)│                                         │
│  │  • File uploads (configs, scripts)       │                                         │
│  │  • Ansible playbooks                     │                                         │
│  │  • Chef cookbooks                        │                                         │
│  │  • Any combination of the above          │                                         │
│  └──────────────┬───────────────────────────┘                                         │
│                 │                                                                      │
│                 ▼                                                                      │
│  ┌──────────────────────────────────────────┐                                         │
│  │  Step 4: STOP THE VM                      │                                         │
│  │                                          │                                         │
│  │  Packer stops the temporary VM to        │                                         │
│  │  ensure the disk is in a consistent      │                                         │
│  │  state before capturing the image.       │                                         │
│  └──────────────┬───────────────────────────┘                                         │
│                 │                                                                      │
│                 ▼                                                                      │
│  ┌──────────────────────────────────────────┐                                         │
│  │  Step 5: CREATE THE IMAGE                 │                                         │
│  │                                          │                                         │
│  │  Packer calls the Compute Engine API     │                                         │
│  │  to create a custom image from the       │                                         │
│  │  temporary VM's boot disk.               │                                         │
│  │                                          │                                         │
│  │  • Sets the image name you specified     │                                         │
│  │  • Sets the image family (if specified)  │                                         │
│  │  • Applies labels and description        │                                         │
│  │  • Stores in the specified location      │                                         │
│  └──────────────┬───────────────────────────┘                                         │
│                 │                                                                      │
│                 ▼                                                                      │
│  ┌──────────────────────────────────────────┐                                         │
│  │  Step 6: CLEANUP                          │                                         │
│  │                                          │                                         │
│  │  Packer deletes the temporary VM and     │                                         │
│  │  its boot disk. Only the custom image    │  ──►  ┌──────────────────────┐          │
│  │  remains.                                │       │  OUTPUT:              │          │
│  │                                          │       │  Custom GCE Image     │          │
│  │  If the build fails, Packer still        │       │  ready to use with:   │          │
│  │  cleans up (unless you set               │       │  gcloud compute       │          │
│  │  skip_clean = true for debugging).       │       │  instances create     │          │
│  └──────────────────────────────────────────┘       │  --image=my-image     │          │
│                                                      └──────────────────────┘          │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

### Network Flow During Build

```
┌───────────────┐         SSH (port 22)          ┌────────────────────┐
│  Packer       │ ─────────────────────────────► │  Temporary VM      │
│  (your machine│         or                     │  (GCE Instance)    │
│  or Cloud     │    IAP Tunnel (port 22)        │                    │
│  Build)       │ ─────────────────────────────► │  • Runs provisioners│
│               │                                │  • Installs software│
└───────────────┘                                └────────────────────┘
                                                          │
                                                          │ Provisioners may
                                                          │ download from:
                                                          ▼
                                                 ┌────────────────────┐
                                                 │  Internet / GCS    │
                                                 │  • apt repos       │
                                                 │  • pip packages    │
                                                 │  • NVIDIA repos    │
                                                 │  • Your GCS bucket │
                                                 └────────────────────┘
```

---

## Prerequisites

### 1. Install Packer

```bash
# Option A: Download from HashiCorp (recommended)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install packer

# Option B: Binary download
PACKER_VERSION="1.11.2"
wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
unzip packer_${PACKER_VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/
rm packer_${PACKER_VERSION}_linux_amd64.zip

# Verify installation
packer version
```

### 2. Enable Required GCP APIs

```bash
export PROJECT_ID="your-project-id"

gcloud services enable \
    compute.googleapis.com \
    iam.googleapis.com \
    cloudbuild.googleapis.com \
    --project=$PROJECT_ID
```

### 3. Authentication

Packer needs credentials to interact with GCP. There are several methods:

```bash
# Method 1: Application Default Credentials (recommended for local development)
gcloud auth application-default login

# Method 2: Service account key file (for CI/CD — see account_file in template)
# Create a service account and download the key:
gcloud iam service-accounts create packer-builder \
    --display-name="Packer Image Builder" \
    --project=$PROJECT_ID

# Grant required roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:packer-builder@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:packer-builder@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

# Method 3: Workload Identity (for Cloud Build — no key needed)
# Cloud Build service account gets roles automatically
```

### 4. Required IAM Roles

The account running Packer needs these roles at minimum:

| IAM Role | Purpose |
|----------|---------|
| `roles/compute.instanceAdmin.v1` | Create/delete temporary VMs and disks |
| `roles/iam.serviceAccountUser` | Use a service account on the temporary VM |
| `roles/compute.imageUser` | (Optional) Use source images from other projects |
| `roles/compute.imageAdmin` | (Optional) Create images in shared image projects |
| `roles/iap.tunnelResourceAccessor` | (Optional) Use IAP tunnel instead of public IP |

### 5. Environment Setup

```bash
# Set common environment variables (used throughout this guide)
export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"
export REGION="us-central1"
export NETWORK="default"
export SUBNET="default"
```

---

## Packer Template Anatomy (HCL2)

Packer templates use **HCL2** (HashiCorp Configuration Language 2), the same language used by Terraform. A template has four main sections:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Packer Template Structure                        │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  packer { }                                                  │    │
│  │  Required plugins and Packer settings                        │    │
│  │  • Declares which builder plugins to download                │    │
│  │  • Sets minimum Packer version                               │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                      │
│                              ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  variable { }  /  locals { }                                 │    │
│  │  Input variables and computed values                         │    │
│  │  • Parameterize the template for reuse                       │    │
│  │  • Compute derived values (e.g., image names with dates)     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                      │
│                              ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  source "googlecompute" "name" { }                           │    │
│  │  Defines WHERE and HOW to build                              │    │
│  │  • Project, zone, network, machine type                      │    │
│  │  • Source image (base OS)                                    │    │
│  │  • Output image name, family, labels                         │    │
│  │  • SSH configuration                                         │    │
│  │  • Disk configuration                                        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                      │
│                              ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  build { }                                                   │    │
│  │  Defines WHAT to install                                     │    │
│  │  • References one or more sources                            │    │
│  │  • Contains provisioner blocks (shell, file, ansible, etc.)  │    │
│  │  • Contains post-processor blocks (optional)                 │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Minimal Template Explained

```hcl
# ──────────────────────────────────────────────────────────────
# 1. PACKER BLOCK — Plugin requirements
# ──────────────────────────────────────────────────────────────
packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.1.6"
    }
  }
}

# ──────────────────────────────────────────────────────────────
# 2. VARIABLES — Inputs to parameterize the template
# ──────────────────────────────────────────────────────────────
variable "project_id" {
  type        = string
  description = "GCP project ID where the image will be created"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "GCP zone for the temporary build VM"
}

# ──────────────────────────────────────────────────────────────
# 3. LOCALS — Computed values
# ──────────────────────────────────────────────────────────────
locals {
  # Generate a unique image name with a timestamp
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
  image_name = "my-image-${local.image_date}"
}

# ──────────────────────────────────────────────────────────────
# 4. SOURCE — Where and how to build (the "builder")
# ──────────────────────────────────────────────────────────────
source "googlecompute" "example" {
  project_id          = var.project_id
  zone                = var.zone
  machine_type        = "e2-standard-4"

  # Base image to start from
  source_image_family = "ubuntu-2404-lts-amd64"
  source_image_project_id = ["ubuntu-os-cloud"]

  # Output image settings
  image_name          = local.image_name
  image_family        = "my-custom-image"
  image_description   = "My custom image built with Packer"
  image_labels = {
    "built-by" = "packer"
    "os"       = "ubuntu-2404"
  }

  # Disk settings
  disk_size           = 50
  disk_type           = "pd-ssd"

  # SSH settings (Packer needs SSH to run provisioners)
  ssh_username        = "packer"
  ssh_timeout         = "10m"

  # Network settings
  network             = "default"
  subnetwork          = "default"

  # Tags for firewall rules (ensure SSH is allowed)
  tags                = ["packer-build"]
}

# ──────────────────────────────────────────────────────────────
# 5. BUILD — What to install (provisioners)
# ──────────────────────────────────────────────────────────────
build {
  sources = ["source.googlecompute.example"]

  # Update system packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y git curl wget htop jq",
      "sudo apt-get clean",
    ]
  }

  # Upload a configuration file
  provisioner "file" {
    source      = "configs/my-config.conf"
    destination = "/tmp/my-config.conf"
  }

  # Move the file to its final location (file provisioner can't write to root-owned dirs)
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/my-config.conf /etc/my-app/my-config.conf",
    ]
  }

  # Print build info
  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}
```

### Key `source "googlecompute"` Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `project_id` | Yes | GCP project for the build VM and output image | `"my-project"` |
| `zone` | Yes | Zone for the temporary build VM | `"us-central1-a"` |
| `source_image_family` | Yes* | Base image family to build from | `"ubuntu-2404-lts-amd64"` |
| `source_image` | Yes* | Specific base image name (alternative to family) | `"ubuntu-2404-..."` |
| `source_image_project_id` | No | Project(s) containing the source image | `["ubuntu-os-cloud"]` |
| `machine_type` | No | Machine type for the build VM | `"e2-standard-4"` |
| `image_name` | Yes | Name of the output image | `"my-image-v1"` |
| `image_family` | No | Image family for the output image | `"my-custom-image"` |
| `image_labels` | No | Labels to apply to the output image | `{"env"="prod"}` |
| `image_description` | No | Description of the output image | `"Built by Packer"` |
| `image_storage_locations` | No | Where to store the image | `["us-central1"]` |
| `disk_size` | No | Boot disk size in GB | `50` |
| `disk_type` | No | Boot disk type | `"pd-ssd"` |
| `network` | No | VPC network for the build VM | `"default"` |
| `subnetwork` | No | Subnet for the build VM | `"default"` |
| `ssh_username` | No | SSH user for provisioning | `"packer"` |
| `ssh_timeout` | No | How long to wait for SSH | `"10m"` |
| `tags` | No | Network tags for the build VM | `["packer"]` |
| `use_iap` | No | Use IAP tunnel instead of public IP | `true` |
| `omit_external_ip` | No | Don't assign a public IP (requires IAP or Cloud NAT) | `true` |
| `service_account_email` | No | Service account for the build VM | `"sa@project.iam..."` |
| `scopes` | No | OAuth scopes for the build VM | `["cloud-platform"]` |
| `accelerator_type` | No | GPU type (for GPU image builds) | `"nvidia-tesla-t4"` |
| `accelerator_count` | No | Number of GPUs | `1` |
| `on_host_maintenance` | No | Must be `"TERMINATE"` for GPU VMs | `"TERMINATE"` |
| `state_timeout` | No | Max time to wait for image creation | `"15m"` |
| `skip_create_image` | No | Set `true` to debug without creating image | `false` |
| `metadata` | No | Instance metadata key-value pairs | `{"enable-oslogin"="FALSE"}` |

> \* Either `source_image` or `source_image_family` is required (not both).

---

## Example 1: Basic Ubuntu Image

A minimal example that creates an Ubuntu image with common development tools pre-installed.

**File: [`examples/basic-ubuntu.pkr.hcl`](examples/basic-ubuntu.pkr.hcl)**

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
  type        = string
  description = "GCP project ID"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "network" {
  type    = string
  default = "default"
}

variable "subnetwork" {
  type    = string
  default = "default"
}

locals {
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "googlecompute" "ubuntu_base" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = "e2-standard-4"
  source_image_family     = "ubuntu-2404-lts-amd64"
  source_image_project_id = ["ubuntu-os-cloud"]

  image_name              = "ubuntu-dev-${local.image_date}"
  image_family            = "ubuntu-dev"
  image_description       = "Ubuntu 24.04 LTS with common development tools"
  image_labels = {
    "built-by" = "packer"
    "os"       = "ubuntu-2404"
    "purpose"  = "development"
  }
  image_storage_locations = ["us"]

  disk_size  = 50
  disk_type  = "pd-balanced"
  network    = var.network
  subnetwork = var.subnetwork
  tags       = ["packer-build"]

  ssh_username = "packer"
  ssh_timeout  = "10m"

  metadata = {
    "enable-oslogin" = "FALSE"
  }
}

build {
  sources = ["source.googlecompute.ubuntu_base"]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y build-essential git curl wget htop tmux vim jq unzip tree python3 python3-pip python3-venv docker.io ca-certificates gnupg lsb-release",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo systemctl enable docker",
      "sudo usermod -aG docker $USER",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*",
    ]
  }

  post-processor "manifest" {
    output     = "manifest-ubuntu-dev.json"
    strip_path = true
  }
}
```

### Build and Use

```bash
# Initialize plugins (first time only)
packer init examples/basic-ubuntu.pkr.hcl

# Validate the template
packer validate -var="project_id=$PROJECT_ID" examples/basic-ubuntu.pkr.hcl

# Build the image
packer build -var="project_id=$PROJECT_ID" examples/basic-ubuntu.pkr.hcl

# Create a VM from the new image
gcloud compute instances create dev-vm \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --image-family=ubuntu-dev \
    --image-project=$PROJECT_ID
```

---

## Example 2: AI/ML GPU Image with CUDA & PyTorch

This example builds a GPU-ready image with NVIDIA drivers, CUDA toolkit, cuDNN, NCCL, and PyTorch pre-installed. It starts from a Google Deep Learning VM base image (which already has drivers) and layers on additional software.

**File: [`examples/ai-ml-gpu.pkr.hcl`](examples/ai-ml-gpu.pkr.hcl)**

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

variable "machine_type" {
  type    = string
  default = "n1-standard-8"
}

variable "accelerator_type" {
  type        = string
  default     = "projects/your-project-id/zones/us-central1-a/acceleratorTypes/nvidia-tesla-t4"
  description = "Full GPU accelerator type path"
}

variable "accelerator_count" {
  type    = number
  default = 1
}

variable "network" {
  type    = string
  default = "default"
}

variable "subnetwork" {
  type    = string
  default = "default"
}

variable "pytorch_version" {
  type    = string
  default = "2.4"
}

locals {
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "googlecompute" "ai_ml_gpu" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = var.machine_type
  source_image_family     = "common-cu124-debian-11"
  source_image_project_id = ["deeplearning-platform-release"]

  accelerator_type    = var.accelerator_type
  accelerator_count   = var.accelerator_count
  on_host_maintenance = "TERMINATE"

  image_name        = "ai-ml-gpu-cuda124-pt${replace(var.pytorch_version, ".", "")}-${local.image_date}"
  image_family      = "ai-ml-gpu"
  image_description = "AI/ML GPU image: CUDA 12.4, cuDNN, NCCL, PyTorch ${var.pytorch_version}"
  image_labels = {
    "built-by"        = "packer"
    "cuda-version"    = "12-4"
    "pytorch-version" = replace(var.pytorch_version, ".", "-")
    "purpose"         = "ai-ml-training"
  }
  image_storage_locations = ["us"]

  disk_size  = 200
  disk_type  = "pd-ssd"
  network    = var.network
  subnetwork = var.subnetwork
  tags       = ["packer-build", "gpu"]

  ssh_username  = "packer"
  ssh_timeout   = "15m"
  state_timeout = "15m"

  metadata = {
    "enable-oslogin"        = "FALSE"
    "install-nvidia-driver" = "True"
  }
}

build {
  sources = ["source.googlecompute.ai_ml_gpu"]

  # Wait for NVIDIA drivers to install (DLVM does this on first boot)
  provisioner "shell" {
    inline = [
      "echo 'Waiting for NVIDIA driver installation...'",
      "for i in $(seq 1 60); do",
      "  if nvidia-smi > /dev/null 2>&1; then",
      "    echo 'NVIDIA drivers ready.'",
      "    nvidia-smi",
      "    break",
      "  fi",
      "  echo \"Waiting... (attempt $i/60)\"",
      "  sleep 10",
      "done",
      "nvidia-smi || { echo 'ERROR: NVIDIA drivers not available'; exit 1; }",
    ]
  }

  # Install system dependencies + CUDA libraries
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y build-essential git curl wget htop tmux vim jq python3 python3-pip python3-venv libcudnn9-cuda-12 libcudnn9-dev-cuda-12 libnccl2 libnccl-dev",
    ]
  }

  # Create Python virtual environment and install ML frameworks
  provisioner "shell" {
    inline = [
      "python3 -m venv /opt/ml-env",
      "source /opt/ml-env/bin/activate",
      "pip install --upgrade pip setuptools wheel",
      "pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124",
      "pip install numpy pandas scikit-learn scipy matplotlib transformers datasets accelerate tensorboard jupyterlab wandb",
      "python3 -c \"import torch; print(f'PyTorch {torch.__version__}, CUDA: {torch.cuda.is_available()}, Devices: {torch.cuda.device_count()}')\"",
    ]
  }

  # Create activation helper for all users
  provisioner "shell" {
    inline = [
      "sudo tee /etc/profile.d/ml-env.sh > /dev/null << 'EOF'",
      "if [ -d \"/opt/ml-env\" ]; then",
      "    source /opt/ml-env/bin/activate",
      "fi",
      "export PATH=/usr/local/cuda/bin:$PATH",
      "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH",
      "EOF",
    ]
  }

  # Install Docker + NVIDIA Container Toolkit
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y docker.io",
      "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg",
      "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list",
      "sudo apt-get update",
      "sudo apt-get install -y nvidia-container-toolkit",
      "sudo nvidia-ctk runtime configure --runtime=docker",
      "sudo systemctl enable docker",
      "sudo systemctl restart docker",
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/* /tmp/*",
      "echo 'AI/ML GPU image build complete.'",
    ]
  }

  post-processor "manifest" {
    output     = "manifest-ai-ml-gpu.json"
    strip_path = true
  }
}
```

### Build and Use

```bash
# Initialize and validate
packer init examples/ai-ml-gpu.pkr.hcl
packer validate \
    -var="project_id=$PROJECT_ID" \
    -var="accelerator_type=projects/${PROJECT_ID}/zones/${ZONE}/acceleratorTypes/nvidia-tesla-t4" \
    examples/ai-ml-gpu.pkr.hcl

# Build (GPU builds take 15-30 minutes)
packer build \
    -var="project_id=$PROJECT_ID" \
    -var="accelerator_type=projects/${PROJECT_ID}/zones/${ZONE}/acceleratorTypes/nvidia-tesla-t4" \
    examples/ai-ml-gpu.pkr.hcl

# Create a GPU VM from the new image
gcloud compute instances create ml-workstation \
    --zone=$ZONE \
    --machine-type=n1-standard-8 \
    --accelerator=type=nvidia-tesla-t4,count=1 \
    --image-family=ai-ml-gpu \
    --image-project=$PROJECT_ID \
    --maintenance-policy=TERMINATE \
    --boot-disk-size=200GB \
    --boot-disk-type=pd-ssd
```

---

## Example 3: HPC Image with MPI & libfabric

This example builds an image optimized for High-Performance Computing workloads with OpenMPI, Intel MPI, libfabric, and tuned kernel parameters.

**File: [`examples/hpc-image.pkr.hcl`](examples/hpc-image.pkr.hcl)**

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

variable "network" {
  type    = string
  default = "default"
}

variable "subnetwork" {
  type    = string
  default = "default"
}

locals {
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "googlecompute" "hpc" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = "c2-standard-60"
  source_image_family     = "hpc-rocky-linux-8"
  source_image_project_id = ["cloud-hpc-image-public"]

  image_name        = "hpc-custom-${local.image_date}"
  image_family      = "hpc-custom"
  image_description = "Custom HPC image with OpenMPI, Intel MPI, libfabric, kernel tuning"
  image_labels = {
    "built-by" = "packer"
    "os"       = "rocky-8"
    "purpose"  = "hpc"
  }
  image_storage_locations = ["us"]

  disk_size  = 100
  disk_type  = "pd-ssd"
  network    = var.network
  subnetwork = var.subnetwork
  tags       = ["packer-build", "hpc"]

  ssh_username = "packer"
  ssh_timeout  = "10m"

  metadata = {
    "enable-oslogin" = "FALSE"
  }
}

build {
  sources = ["source.googlecompute.hpc"]

  # Install HPC packages
  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y gcc gcc-c++ gcc-gfortran make cmake git wget curl hwloc hwloc-devel numactl numactl-devel rdma-core rdma-core-devel libibverbs libibverbs-devel libfabric libfabric-devel ucx ucx-devel openmpi openmpi-devel python3 python3-pip python3-devel htop iotop sysstat perf",
    ]
  }

  # Configure OpenMPI environment
  provisioner "shell" {
    inline = [
      "sudo tee /etc/profile.d/openmpi.sh > /dev/null << 'EOF'",
      "export PATH=/usr/lib64/openmpi/bin:$PATH",
      "export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH",
      "export MPI_HOME=/usr/lib64/openmpi",
      "EOF",
    ]
  }

  # Kernel tuning for HPC workloads
  provisioner "shell" {
    inline = [
      "sudo tee /etc/sysctl.d/99-hpc-tuning.conf > /dev/null << 'EOF'",
      "kernel.shmmax = 68719476736",
      "kernel.shmall = 4294967296",
      "fs.file-max = 2097152",
      "net.core.rmem_max = 16777216",
      "net.core.wmem_max = 16777216",
      "net.core.rmem_default = 16777216",
      "net.core.wmem_default = 16777216",
      "net.core.optmem_max = 16777216",
      "net.core.netdev_max_backlog = 30000",
      "net.ipv4.tcp_rmem = 4096 87380 16777216",
      "net.ipv4.tcp_wmem = 4096 65536 16777216",
      "net.ipv4.tcp_no_metrics_save = 1",
      "vm.nr_hugepages = 0",
      "EOF",
      "sudo sysctl -p /etc/sysctl.d/99-hpc-tuning.conf",
    ]
  }

  # Set ulimits for HPC
  provisioner "shell" {
    inline = [
      "sudo tee /etc/security/limits.d/99-hpc.conf > /dev/null << 'EOF'",
      "* soft nofile 1048576",
      "* hard nofile 1048576",
      "* soft nproc  unlimited",
      "* hard nproc  unlimited",
      "* soft memlock unlimited",
      "* hard memlock unlimited",
      "* soft stack   unlimited",
      "* hard stack   unlimited",
      "EOF",
    ]
  }

  # Install Python scientific computing stack
  provisioner "shell" {
    inline = [
      "python3 -m venv /opt/hpc-env",
      "source /opt/hpc-env/bin/activate",
      "pip install --upgrade pip",
      "pip install numpy scipy mpi4py h5py netCDF4",
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "sudo dnf clean all",
      "sudo rm -rf /tmp/*",
      "echo 'HPC image build complete.'",
    ]
  }

  post-processor "manifest" {
    output     = "manifest-hpc.json"
    strip_path = true
  }
}
```

### Build and Use

```bash
packer init examples/hpc-image.pkr.hcl
packer build -var="project_id=$PROJECT_ID" examples/hpc-image.pkr.hcl

gcloud compute instances create hpc-node-01 \
    --zone=$ZONE \
    --machine-type=c2-standard-60 \
    --image-family=hpc-custom \
    --image-project=$PROJECT_ID \
    --boot-disk-size=100GB \
    --boot-disk-type=pd-ssd
```

---

## Example 4: Multi-Provisioner Build with Ansible

For complex configurations, you can use Ansible playbooks as provisioners. This provides better structure, idempotency, and reuse compared to long shell scripts.

```hcl
packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.1.6"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
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

source "googlecompute" "ansible_build" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = "e2-standard-4"
  source_image_family     = "ubuntu-2404-lts-amd64"
  source_image_project_id = ["ubuntu-os-cloud"]

  image_name        = "ansible-built-${local.image_date}"
  image_family      = "ansible-built"
  image_description = "Image built with Packer + Ansible provisioner"
  image_labels = {
    "built-by"    = "packer"
    "provisioner" = "ansible"
  }

  disk_size    = 50
  disk_type    = "pd-balanced"
  ssh_username = "packer"
  ssh_timeout  = "10m"

  metadata = {
    "enable-oslogin" = "FALSE"
  }
}

build {
  sources = ["source.googlecompute.ansible_build"]

  # Step 1: Upload configuration files first
  provisioner "file" {
    source      = "configs/"
    destination = "/tmp/configs"
  }

  # Step 2: Run an Ansible playbook
  provisioner "ansible" {
    playbook_file = "ansible/playbook.yml"
    extra_arguments = [
      "--extra-vars", "env=production",
      "--extra-vars", "cuda_version=12.4",
    ]
    user = "packer"
  }

  # Step 3: Run a final validation shell script
  provisioner "shell" {
    script = "scripts/validate-image.sh"
  }
}
```

**Example Ansible playbook (`ansible/playbook.yml`):**

```yaml
---
- name: Configure VM image
  hosts: all
  become: yes

  vars:
    packages:
      - git
      - curl
      - wget
      - htop
      - docker.io
      - python3-pip

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install system packages
      apt:
        name: "{{ packages }}"
        state: present

    - name: Enable Docker service
      systemd:
        name: docker
        enabled: yes
        state: started

    - name: Create application directory
      file:
        path: /opt/myapp
        state: directory
        mode: '0755'

    - name: Copy configuration files
      copy:
        src: /tmp/configs/
        dest: /etc/myapp/
        remote_src: yes

    - name: Clean up apt cache
      apt:
        autoclean: yes
        autoremove: yes
```

---

## Example 5: Image Families & Versioning

Image families allow you to maintain a rolling "latest" pointer while keeping old versions available for rollback.

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

variable "image_version" {
  type        = string
  default     = "1"
  description = "Semantic version number for the image (e.g., 1, 2, 3)"
}

variable "team" {
  type    = string
  default = "ml-platform"
}

locals {
  image_date = formatdate("YYYYMMDD", timestamp())
  image_name = "ml-base-v${var.image_version}-${local.image_date}"
}

source "googlecompute" "versioned" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = "e2-standard-4"
  source_image_family     = "ubuntu-2404-lts-amd64"
  source_image_project_id = ["ubuntu-os-cloud"]

  # image_family ensures --image-family=ml-base always gets the latest
  image_name        = local.image_name
  image_family      = "ml-base"
  image_description = "ML base image v${var.image_version}, built ${local.image_date}"
  image_labels = {
    "built-by" = "packer"
    "version"  = var.image_version
    "team"     = var.team
    "date"     = local.image_date
  }

  disk_size    = 50
  disk_type    = "pd-balanced"
  ssh_username = "packer"

  metadata = {
    "enable-oslogin" = "FALSE"
  }
}

build {
  sources = ["source.googlecompute.versioned"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3 python3-pip python3-venv git curl",
      "sudo apt-get clean",
      "echo 'ML base v${var.image_version} build complete.'",
    ]
  }
}
```

### Versioning Workflow

```bash
# Build version 1
packer build -var="project_id=$PROJECT_ID" -var="image_version=1" template.pkr.hcl

# Build version 2 (image_family=ml-base now points to v2)
packer build -var="project_id=$PROJECT_ID" -var="image_version=2" template.pkr.hcl

# Build version 3
packer build -var="project_id=$PROJECT_ID" -var="image_version=3" template.pkr.hcl

# Users always get the latest:
gcloud compute instances create my-vm \
    --image-family=ml-base \
    --image-project=$PROJECT_ID \
    --zone=$ZONE

# List all versions:
gcloud compute images list \
    --filter="family=ml-base" \
    --format="table(name, family, status, creationTimestamp.date())" \
    --sort-by="~creationTimestamp"

# Deprecate an old version:
gcloud compute images deprecate ml-base-v1-20260327 \
    --state=DEPRECATED \
    --replacement=ml-base-v3-20260327
```

---

## Provisioners Deep Dive

Provisioners are the workhorses of Packer — they define what gets installed and configured on the image. Packer runs provisioners **in order**, and if any provisioner fails (non-zero exit code), the build fails.

### Shell Provisioner

The most common provisioner. Runs shell commands or scripts on the build VM.

```hcl
# Inline commands
provisioner "shell" {
  inline = [
    "sudo apt-get update",
    "sudo apt-get install -y nginx",
  ]
}

# Script file (uploaded and executed)
provisioner "shell" {
  script = "scripts/install-cuda.sh"
}

# Multiple script files (executed in order)
provisioner "shell" {
  scripts = [
    "scripts/01-base-packages.sh",
    "scripts/02-nvidia-drivers.sh",
    "scripts/03-ml-frameworks.sh",
    "scripts/04-cleanup.sh",
  ]
}

# With environment variables
provisioner "shell" {
  environment_vars = [
    "CUDA_VERSION=12.4",
    "PYTORCH_VERSION=2.4",
    "INSTALL_DIR=/opt/ml",
  ]
  script = "scripts/install-ml-stack.sh"
}

# Execute command (doesn't wrap in /bin/sh -c)
provisioner "shell" {
  execute_command = "chmod +x {{ .Path }}; sudo {{ .Vars }} {{ .Path }}"
  script          = "scripts/install.sh"
}

# Expect a non-zero exit code
provisioner "shell" {
  inline           = ["some-command-that-may-fail || true"]
  valid_exit_codes = [0, 1]
}

# Pause before running (wait for services to start)
provisioner "shell" {
  pause_before = "10s"
  inline       = ["sudo systemctl status nginx"]
}
```

### File Provisioner

Uploads files or directories from the build machine to the build VM.

```hcl
# Upload a single file
provisioner "file" {
  source      = "configs/nginx.conf"
  destination = "/tmp/nginx.conf"
}

# Upload an entire directory
provisioner "file" {
  source      = "configs/"         # Trailing slash = upload contents
  destination = "/tmp/configs"
}

# Upload generated content
provisioner "file" {
  content     = "ENVIRONMENT=production\nVERSION=${var.image_version}\n"
  destination = "/tmp/env.conf"
}
```

> **Important:** The file provisioner uploads as the SSH user (e.g., `packer`), so you cannot upload directly to root-owned directories like `/etc/`. Upload to `/tmp/` first, then use a shell provisioner with `sudo mv` to move files.

### Ansible Provisioner

For complex, multi-step configurations, Ansible provides structure and idempotency.

```hcl
# Basic Ansible provisioner
provisioner "ansible" {
  playbook_file = "ansible/site.yml"
}

# With extra variables and verbosity
provisioner "ansible" {
  playbook_file   = "ansible/site.yml"
  extra_arguments = [
    "--extra-vars", "cuda_version=12.4 env=production",
    "-vvv",
  ]
  user = "packer"
  ansible_env_vars = [
    "ANSIBLE_HOST_KEY_CHECKING=False",
  ]
}
```

### Shell-Local Provisioner

Runs commands on the **build machine** (not the build VM). Useful for post-build notifications.

```hcl
provisioner "shell-local" {
  inline = [
    "echo 'Image built successfully!'",
    "curl -X POST https://hooks.slack.com/services/... -d '{\"text\": \"New image built: ${local.image_name}\"}'",
  ]
}
```

### Breakpoint Provisioner (Debugging)

Pauses the build so you can SSH into the build VM and debug interactively.

```hcl
provisioner "breakpoint" {
  disable = false  # Set to true to skip in production
  note    = "Paused for debugging. SSH into the build VM to inspect."
}
```

### Provisioner Execution Order

```
┌─────────────────────────────┐
│  provisioner "shell" { }    │  ← Runs first
│  (install base packages)    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  provisioner "file" { }     │  ← Runs second
│  (upload config files)      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  provisioner "ansible" { }  │  ← Runs third
│  (run playbook)             │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  provisioner "shell" { }    │  ← Runs fourth
│  (validate & cleanup)       │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  post-processor { }         │  ← Runs after image is created
│  (manifest, notifications)  │
└─────────────────────────────┘
```

---

## Variables & Parameterization

Variables make templates reusable across projects, environments, and teams.

### Variable Definition

```hcl
# Required variable (no default — must be provided)
variable "project_id" {
  type        = string
  description = "GCP project ID where the image will be created"
}

# Optional variable (has a default)
variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "GCP zone for the build VM"
}

# Validated variable
variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# Sensitive variable (won't be shown in logs)
variable "api_key" {
  type        = string
  sensitive   = true
  description = "API key for package repository"
}

# Complex variable types
variable "labels" {
  type = map(string)
  default = {
    "team" = "ml-platform"
    "env"  = "dev"
  }
}

variable "packages" {
  type    = list(string)
  default = ["git", "curl", "wget", "htop"]
}
```

### Providing Variable Values

There are **four ways** to provide variable values, in order of precedence (highest to lowest):

#### 1. Command-line flags (highest precedence)

```bash
packer build \
    -var="project_id=my-project" \
    -var="zone=europe-west1-b" \
    -var="environment=production" \
    template.pkr.hcl
```

#### 2. Variable definition files (`.pkrvars.hcl`)

**File: [`examples/variables.pkrvars.hcl`](examples/variables.pkrvars.hcl)**

```hcl
project_id  = "my-gcp-project-id"
zone        = "us-central1-a"
network     = "my-vpc"
subnetwork  = "my-subnet"
```

```bash
# Use a var file
packer build -var-file="examples/variables.pkrvars.hcl" template.pkr.hcl

# Auto-loaded files: *.auto.pkrvars.hcl are loaded automatically
```

#### 3. Environment variables

```bash
# Prefix variable name with PKR_VAR_
export PKR_VAR_project_id="my-project"
export PKR_VAR_zone="us-central1-a"
export PKR_VAR_api_key="secret-key-value"

packer build template.pkr.hcl
```

#### 4. Default values (lowest precedence)

```hcl
variable "zone" {
  type    = string
  default = "us-central1-a"  # Used only if no other value is provided
}
```

### Variable Precedence Diagram

```
┌───────────────────────────────────────────────────────────┐
│                    Variable Precedence                     │
│             (highest precedence wins)                     │
│                                                           │
│  1. -var="key=value"        (command-line)     ← HIGHEST │
│  2. -var-file="file.pkrvars.hcl"               │         │
│  3. *.auto.pkrvars.hcl      (auto-loaded)      │         │
│  4. PKR_VAR_name             (environment var)  │         │
│  5. default = "value"        (in variable {})   ← LOWEST │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### Locals (Computed Values)

Locals let you compute values from variables or other expressions:

```hcl
locals {
  # Timestamp for unique image names
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())

  # Constructed image name
  image_name = "${var.team}-${var.environment}-v${var.version}-${local.image_date}"

  # Conditional values
  disk_size = var.environment == "production" ? 200 : 50

  # Merged labels
  common_labels = merge(var.labels, {
    "built-by"    = "packer"
    "build-date"  = local.image_date
    "environment" = var.environment
  })
}
```

---

## Packer with Cloud Build (CI/CD)

Automate image builds using Cloud Build so every commit or scheduled trigger produces a fresh, tested image.

### Architecture

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                        CI/CD Image Build Pipeline                                 │
│                                                                                   │
│  ┌──────────┐     ┌──────────────┐     ┌──────────────┐     ┌────────────────┐   │
│  │  Git Push │────►│ Cloud Build  │────►│ Packer Build │────►│ Custom Image   │   │
│  │  (trigger)│     │  Trigger     │     │              │     │ in GCE         │   │
│  └──────────┘     └──────────────┘     └──────────────┘     └────────────────┘   │
│                                                                      │            │
│                                                                      ▼            │
│                                                             ┌────────────────┐    │
│                                                             │ Deploy VMs     │    │
│                                                             │ via MIG / GKE  │    │
│                                                             │ using new image│    │
│                                                             └────────────────┘    │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### Cloud Build Configuration

**File: [`examples/cloudbuild.yaml`](examples/cloudbuild.yaml)**

```yaml
# cloudbuild.yaml — Build a Packer image using Cloud Build
#
# Usage:
#   gcloud builds submit . \
#       --config=examples/cloudbuild.yaml \
#       --substitutions=_PROJECT_ID=$PROJECT_ID,_ZONE=us-central1-a

timeout: "3600s"

substitutions:
  _PROJECT_ID: "your-project-id"
  _ZONE: "us-central1-a"
  _PACKER_VERSION: "1.11.2"
  _IMAGE_FAMILY: "ml-base"
  _NETWORK: "default"
  _SUBNETWORK: "default"

options:
  logging: CLOUD_LOGGING_ONLY
  machineType: "E2_HIGHCPU_8"

steps:
  # Step 1: Install Packer
  - name: "gcr.io/cloud-builders/curl"
    id: "download-packer"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        curl -fsSL https://releases.hashicorp.com/packer/${_PACKER_VERSION}/packer_${_PACKER_VERSION}_linux_amd64.zip \
          -o /workspace/packer.zip
        cd /workspace && unzip packer.zip && chmod +x packer

  # Step 2: Initialize Packer plugins
  - name: "gcr.io/cloud-builders/gcloud"
    id: "packer-init"
    entrypoint: "bash"
    args:
      - "-c"
      - /workspace/packer init examples/basic-ubuntu.pkr.hcl

  # Step 3: Validate the template
  - name: "gcr.io/cloud-builders/gcloud"
    id: "packer-validate"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        /workspace/packer validate \
          -var="project_id=${_PROJECT_ID}" \
          -var="zone=${_ZONE}" \
          -var="network=${_NETWORK}" \
          -var="subnetwork=${_SUBNETWORK}" \
          examples/basic-ubuntu.pkr.hcl

  # Step 4: Build the image
  - name: "gcr.io/cloud-builders/gcloud"
    id: "packer-build"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        /workspace/packer build \
          -var="project_id=${_PROJECT_ID}" \
          -var="zone=${_ZONE}" \
          -var="network=${_NETWORK}" \
          -var="subnetwork=${_SUBNETWORK}" \
          -color=false \
          examples/basic-ubuntu.pkr.hcl
```

### Cloud Build IAM Setup

```bash
# Get the Cloud Build service account
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant required roles to the Cloud Build service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CB_SA" \
    --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CB_SA" \
    --role="roles/iam.serviceAccountUser"
```

### Trigger the Build

```bash
# Manual trigger
gcloud builds submit . \
    --config=examples/cloudbuild.yaml \
    --substitutions=_PROJECT_ID=$PROJECT_ID,_ZONE=$ZONE

# Create a trigger (runs on every push to main)
gcloud builds triggers create github \
    --name="build-ml-image" \
    --repo-name="ai-infra-onboarding" \
    --repo-owner="your-org" \
    --branch-pattern="^main$" \
    --build-config="02-core-infrastructure/disk-images/packer/examples/cloudbuild.yaml" \
    --substitutions="_PROJECT_ID=$PROJECT_ID,_ZONE=$ZONE"

# Create a scheduled trigger (weekly image refresh)
gcloud builds triggers create manual \
    --name="weekly-ml-image-build" \
    --build-config="02-core-infrastructure/disk-images/packer/examples/cloudbuild.yaml" \
    --substitutions="_PROJECT_ID=$PROJECT_ID,_ZONE=$ZONE"
```

### Using the HashiCorp Packer Cloud Builder

Instead of downloading Packer manually, you can use the community Cloud Builder image:

```yaml
# Alternative cloudbuild.yaml using the Packer community builder
steps:
  - name: "hashicorp/packer:1.11"
    entrypoint: "packer"
    args: ["init", "examples/basic-ubuntu.pkr.hcl"]

  - name: "hashicorp/packer:1.11"
    entrypoint: "packer"
    args:
      - "build"
      - "-var=project_id=${_PROJECT_ID}"
      - "-var=zone=${_ZONE}"
      - "-color=false"
      - "examples/basic-ubuntu.pkr.hcl"
```

---

## Image Management & Lifecycle

### Post-Build Validation

After building an image, validate it before promoting to production:

```bash
#!/bin/bash
# validate-image.sh — Test a newly built image

IMAGE_NAME="$1"
PROJECT_ID="$2"
ZONE="us-central1-a"
TEST_VM="image-test-$(date +%s)"

echo "Testing image: $IMAGE_NAME"

# Create a test VM from the image
gcloud compute instances create $TEST_VM \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --image=$IMAGE_NAME \
    --image-project=$PROJECT_ID \
    --quiet

# Wait for the VM to be ready
sleep 30

# Run validation tests
gcloud compute ssh $TEST_VM --zone=$ZONE --command="
    set -e
    echo '=== Checking installed packages ==='
    python3 --version
    git --version
    docker --version

    echo '=== Checking GPU (if applicable) ==='
    nvidia-smi 2>/dev/null || echo 'No GPU (expected for non-GPU image)'

    echo '=== Checking ML environment (if applicable) ==='
    if [ -d /opt/ml-env ]; then
        source /opt/ml-env/bin/activate
        python3 -c 'import torch; print(f\"PyTorch: {torch.__version__}\")'
    fi

    echo '=== All validation checks passed ==='
"

RESULT=$?

# Cleanup test VM
gcloud compute instances delete $TEST_VM --zone=$ZONE --quiet

if [ $RESULT -eq 0 ]; then
    echo "Image validation PASSED: $IMAGE_NAME"
else
    echo "Image validation FAILED: $IMAGE_NAME"
    exit 1
fi
```

### Image Deprecation & Rotation

```bash
# List all images in a family with their status
gcloud compute images list \
    --filter="family=ml-base" \
    --format="table(name, family, status, deprecated.state, creationTimestamp.date())" \
    --sort-by="~creationTimestamp"

# Deprecate old images (they still work but show a warning)
gcloud compute images deprecate ml-base-v1-20260101 \
    --state=DEPRECATED \
    --replacement=ml-base-v3-20260327

# Make old images obsolete (cannot be used for new VMs)
gcloud compute images deprecate ml-base-v1-20260101 \
    --state=OBSOLETE \
    --replacement=ml-base-v3-20260327

# Schedule automatic lifecycle transitions
gcloud compute images deprecate ml-base-v2-20260201 \
    --state=ACTIVE \
    --deprecate-on="2026-05-01T00:00:00Z" \
    --obsolete-on="2026-08-01T00:00:00Z" \
    --delete-on="2026-11-01T00:00:00Z" \
    --replacement=ml-base-v3-20260327
```

### Sharing Images Across Projects

```bash
# Grant image access to another project's service account
gcloud compute images add-iam-policy-binding ml-base-v3-20260327 \
    --project=$PROJECT_ID \
    --member="serviceAccount:SA@other-project.iam.gserviceaccount.com" \
    --role="roles/compute.imageUser"

# Use a shared image from another project
gcloud compute instances create my-vm \
    --image-family=ml-base \
    --image-project=shared-images-project \
    --zone=$ZONE
```

---

## Best Practices

### Template Organization

```
packer/
├── README.md                           # This file
├── examples/
│   ├── basic-ubuntu.pkr.hcl           # Basic Ubuntu image
│   ├── ai-ml-gpu.pkr.hcl             # AI/ML GPU image
│   ├── hpc-image.pkr.hcl             # HPC image
│   ├── variables.pkrvars.hcl         # Shared variable values
│   └── cloudbuild.yaml               # Cloud Build config
├── scripts/                            # Shell scripts for provisioners
│   ├── install-cuda.sh
│   ├── install-ml-frameworks.sh
│   ├── install-hpc-libs.sh
│   ├── cleanup.sh
│   └── validate-image.sh
├── ansible/                            # Ansible playbooks (if used)
│   ├── playbook.yml
│   └── roles/
└── configs/                            # Configuration files to upload
    ├── sysctl.conf
    └── limits.conf
```

### Security Best Practices

| Practice | Implementation |
|----------|---------------|
| **Never store secrets in images** | Use Secret Manager; retrieve secrets at runtime via startup scripts |
| **Use IAP for SSH** | Set `use_iap = true` and `omit_external_ip = true` in the source block |
| **Minimize attack surface** | Remove build-time dependencies, disable unnecessary services |
| **Scan images** | Integrate vulnerability scanning (e.g., `trivy`, Container Analysis) into your CI/CD pipeline |
| **Use dedicated service accounts** | Create a `packer-builder` service account with least-privilege roles |
| **Enable OS Login** | Use `metadata = { "enable-oslogin" = "TRUE" }` in production |
| **Audit image access** | Use IAM policies and Cloud Audit Logs to track who creates and uses images |

### Using IAP (No Public IP)

For security-hardened environments where build VMs shouldn't have public IPs:

```hcl
source "googlecompute" "secure_build" {
  project_id              = var.project_id
  zone                    = var.zone
  machine_type            = "e2-standard-4"
  source_image_family     = "ubuntu-2404-lts-amd64"
  source_image_project_id = ["ubuntu-os-cloud"]

  image_name   = "secure-image-${local.image_date}"
  image_family = "secure-image"

  # Security settings
  use_iap          = true     # Use IAP tunnel for SSH
  omit_external_ip = true     # No public IP on build VM
  network          = "my-private-vpc"
  subnetwork       = "my-private-subnet"

  ssh_username = "packer"

  metadata = {
    "enable-oslogin" = "FALSE"
  }
}
```

> **Note:** When using `omit_external_ip = true`, the build VM needs outbound internet access via **Cloud NAT** to download packages, or use a private package mirror.

### Performance Tips

| Tip | Why |
|-----|-----|
| **Use `pd-ssd` for build disks** | Faster package installation, especially for large installs like CUDA |
| **Use a larger machine type for builds** | More CPUs = faster compilation. `e2-standard-8` builds faster than `e2-standard-2` |
| **Break scripts into stages** | If a late provisioner fails, you can debug faster by commenting out early stages |
| **Use `skip_create_image = true` for debugging** | Avoids waiting for image creation while testing provisioners |
| **Cache packages in GCS** | Download large files (CUDA, models) from a GCS bucket instead of the internet |
| **Clean up at the end** | `apt-get clean`, `rm -rf /var/lib/apt/lists/*`, and `rm -rf /tmp/*` reduce image size |

### Image Size Reduction

```hcl
# Add this as the LAST provisioner in your build
provisioner "shell" {
  inline = [
    # Remove apt cache
    "sudo apt-get autoremove -y",
    "sudo apt-get clean",
    "sudo rm -rf /var/lib/apt/lists/*",

    # Remove pip cache
    "sudo rm -rf /root/.cache/pip",
    "sudo rm -rf /home/*/.cache/pip",

    # Remove temporary files
    "sudo rm -rf /tmp/*",
    "sudo rm -rf /var/tmp/*",

    # Remove logs
    "sudo rm -rf /var/log/*.gz",
    "sudo rm -rf /var/log/*.1",
    "sudo journalctl --vacuum-time=1d",

    # Remove SSH host keys (regenerated on first boot)
    "sudo rm -f /etc/ssh/ssh_host_*",

    "echo 'Cleanup complete. Image is ready.'",
  ]
}
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. SSH Connection Timeout

```
Error: Timeout waiting for SSH
```

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Firewall blocks port 22 | Add firewall rule: `gcloud compute firewall-rules create allow-packer-ssh --allow=tcp:22 --target-tags=packer-build` |
| OS Login conflicts with Packer | Set `metadata = { "enable-oslogin" = "FALSE" }` |
| VM takes long to boot (GPU) | Increase `ssh_timeout = "20m"` |
| No external IP + no IAP | Set `use_iap = true` or ensure the VM has a public IP |
| Wrong SSH username | Try `ssh_username = "packer"` or `ssh_username = "ubuntu"` |

#### 2. Image Name Already Exists

```
Error: The resource 'projects/.../global/images/my-image-v1' already exists
```

**Solution:** Use timestamps in image names:

```hcl
locals {
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
}
# image_name = "my-image-${local.image_date}"
```

#### 3. Quota Exceeded

```
Error: Quota 'GPUS_ALL_REGIONS' exceeded
```

**Solution:** Check and request quota:

```bash
gcloud compute regions describe $REGION \
    --format="table(quotas.filter(metric:NVIDIA_T4_GPUS).limit, quotas.filter(metric:NVIDIA_T4_GPUS).usage)"
```

#### 4. Permission Denied

```
Error: Required 'compute.instances.create' permission
```

**Solution:** Grant the required IAM roles:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:your-email@example.com" \
    --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:your-email@example.com" \
    --role="roles/iam.serviceAccountUser"
```

#### 5. Provisioner Script Fails

**Debug approach:**

```hcl
# 1. Add a breakpoint before the failing provisioner
provisioner "breakpoint" {
  note = "Debug: SSH into the VM to inspect before next step"
}

# 2. Or use skip_create_image to avoid waiting for image creation
source "googlecompute" "debug" {
  # ...
  skip_create_image = true
}

# 3. Or add verbose logging
provisioner "shell" {
  inline = [
    "set -x",  # Print every command before executing
    "# ... your commands ...",
  ]
}
```

#### 6. Build VM Not Cleaned Up

If a build is interrupted (Ctrl+C, network loss), the temporary VM may remain:

```bash
# Find orphaned Packer VMs (they have "packer-" prefix by default)
gcloud compute instances list --filter="name~packer-" --format="table(name, zone, status)"

# Delete them
gcloud compute instances delete packer-XXXXX --zone=$ZONE --quiet
```

### Debug Mode

Run Packer with debug logging:

```bash
# Enable debug output
PACKER_LOG=1 packer build template.pkr.hcl

# Save debug output to a file
PACKER_LOG=1 PACKER_LOG_PATH=packer-debug.log packer build template.pkr.hcl

# Step-by-step mode (pauses between each step)
packer build -debug template.pkr.hcl
```

---

## Command Reference

| Command | Description | Example |
|---------|-------------|---------|
| `packer init` | Download required plugins | `packer init template.pkr.hcl` |
| `packer validate` | Check template syntax and configuration | `packer validate -var="project_id=X" template.pkr.hcl` |
| `packer fmt` | Format template files (like `terraform fmt`) | `packer fmt -recursive .` |
| `packer inspect` | Show template components (variables, builders) | `packer inspect template.pkr.hcl` |
| `packer build` | Build the image | `packer build -var="project_id=X" template.pkr.hcl` |
| `packer build -debug` | Build with step-by-step pauses | `packer build -debug template.pkr.hcl` |
| `packer build -on-error=ask` | On error, ask whether to clean up or abort | `packer build -on-error=ask template.pkr.hcl` |
| `packer build -on-error=abort` | On error, leave the VM running for debugging | `packer build -on-error=abort template.pkr.hcl` |
| `packer build -only=...` | Build only specified sources | `packer build -only="googlecompute.ubuntu" template.pkr.hcl` |
| `packer build -except=...` | Skip specified sources | `packer build -except="googlecompute.hpc" template.pkr.hcl` |
| `packer build -parallel-builds=1` | Limit parallel builds | `packer build -parallel-builds=1 template.pkr.hcl` |
| `packer build -force` | Force build even if image exists (overwrites) | `packer build -force template.pkr.hcl` |
| `packer build -timestamp-ui` | Prefix output with timestamps | `packer build -timestamp-ui template.pkr.hcl` |
| `packer plugins installed` | List installed plugins | `packer plugins installed` |

### Typical Workflow

```bash
# 1. Format the template
packer fmt examples/basic-ubuntu.pkr.hcl

# 2. Initialize plugins (downloads googlecompute plugin)
packer init examples/basic-ubuntu.pkr.hcl

# 3. Validate the template
packer validate \
    -var-file="examples/variables.pkrvars.hcl" \
    examples/basic-ubuntu.pkr.hcl

# 4. Inspect the template (see variables, builders, provisioners)
packer inspect examples/basic-ubuntu.pkr.hcl

# 5. Build the image
packer build \
    -var-file="examples/variables.pkrvars.hcl" \
    -timestamp-ui \
    examples/basic-ubuntu.pkr.hcl

# 6. Verify the image was created
gcloud compute images list \
    --filter="family=ubuntu-dev" \
    --format="table(name, family, status, diskSizeGb, creationTimestamp.date())"
```

---

## References

- [Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Packer Google Compute Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute/latest/components/builder/googlecompute)
- [Packer HCL2 Templates](https://developer.hashicorp.com/packer/docs/templates/hcl_templates)
- [Packer Provisioners](https://developer.hashicorp.com/packer/docs/provisioners)
- [Building VM Images with Packer on Cloud Build](https://cloud.google.com/build/docs/building/build-vm-images-with-packer)
- [GCE Custom Images](https://cloud.google.com/compute/docs/images/create-delete-deprecate-private-images)
- [GCE Image Families Best Practices](https://cloud.google.com/compute/docs/images/image-families-best-practices)
- [Deep Learning VM Images](https://cloud.google.com/deep-learning-vm/docs/images)
- [NVIDIA GPU Drivers on GCE](https://cloud.google.com/compute/docs/gpus/install-drivers-gpu)
- [IAP TCP Forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
