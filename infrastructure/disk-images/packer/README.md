# Build VM images with Packer

Packer boots a temporary Compute Engine VM from a base image, runs your install steps, saves the boot disk as a custom image, and deletes the VM. Reach for it when a lab or cluster needs the same software on every node. [Disk images for GPU and HPC VMs](../README.md) picks the base image.

## What we'd pick

- **Layer on a Google image.** Start from a Deep Learning VM image for GPUs or the HPC VM image for MPI. Add only your packages, and let Google maintain the driver, CUDA, and MPI tuning.
- **Keep the template in Git.** Rebuild from it rather than patch VMs by hand, so anyone on the team can review a change and rerun it.
- **Put a timestamp in every image name and set `image_family`.** VMs created from the family get the newest build, and older builds stay for rollback.
- **Rebuild monthly in Cloud Build.** Each run picks up the base image's latest patches.
- **Give the build VM no external IP.** Connect over IAP, and download packages through Cloud NAT.
- **Build Slurm images with Cluster Toolkit.** Its image-builder blueprint starts from the HPC VM image and creates the IAP firewall rule and Cloud NAT.
- **Build as a dedicated service account.** Grant it `roles/compute.instanceAdmin.v1` and `roles/iam.serviceAccountUser`, plus `roles/iap.tunnelResourceAccessor` for IAP.
- **Keep secrets out of the image.** Fetch them from Secret Manager at boot.
- **Test before you share.** Boot one VM from the new image, then run `nvidia-smi` and import your framework.

## Official docs

| Need | Page |
|---|---|
| Run Packer in Cloud Build | [Building VM images using Packer](https://docs.cloud.google.com/build/docs/building/build-vm-images-with-packer) |
| Build Slurm images in a Cluster Toolkit blueprint | [Build custom images with Packer](https://docs.cloud.google.com/cluster-toolkit/docs/modules/packer) |
| Look up a `googlecompute` option | [Google Cloud Platform Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute/latest/components/builder/googlecompute) |
| Write HCL templates | [HCL templates overview](https://developer.hashicorp.com/packer/docs/templates/hcl_templates) |
| Run shell steps on the build VM | [shell provisioner reference](https://developer.hashicorp.com/packer/docs/provisioners/shell) |
| Reach a build VM that has no external IP | [Use IAP for TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding) |
| Download packages without an external IP | [Cloud NAT overview](https://docs.cloud.google.com/nat/docs/overview) |
| Find the account Cloud Build runs as | [Default Cloud Build service account](https://docs.cloud.google.com/build/docs/cloud-build-service-account) |

## Ask your agent

Questions for the Google developer knowledge MCP:

- "How do I build a Compute Engine VM image with Packer and Cloud Build?"
- "Which service account does Cloud Build use by default, and which roles does it need to create Compute Engine VMs?"
- "How do I build a custom Slurm image with the Cluster Toolkit packer module?"
- "Which firewall rule lets IAP TCP forwarding reach SSH on a VM without an external IP?"
- "How do I set up Cloud NAT so VMs without external IP addresses can download packages from the internet?"

## Field notes

### GPU image template

`ai-ml-gpu.pkr.hcl` adds a PyTorch venv to the `common-cu129-ubuntu-2404-nvidia-580` Deep Learning VM image and connects over IAP. On 2026-11-05 it passed `packer fmt -check` and `packer validate` with Packer 1.15.3 and googlecompute plugin 1.2.6. We haven't run this version through a full build.

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

variable "subnetwork" {
  type    = string
  default = "default"
}

locals {
  image_date = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "googlecompute" "ai_ml_gpu" {
  project_id              = var.project_id
  zone                    = var.zone
  subnetwork              = var.subnetwork
  source_image_family     = "common-cu129-ubuntu-2404-nvidia-580"
  source_image_project_id = ["deeplearning-platform-release"]

  # The T4 lets the build check CUDA.
  machine_type        = "n1-standard-8"
  accelerator_type    = "projects/${var.project_id}/zones/${var.zone}/acceleratorTypes/nvidia-tesla-t4"
  accelerator_count   = 1
  on_host_maintenance = "TERMINATE"

  image_name   = "ai-ml-gpu-${local.image_date}"
  image_family = "ai-ml-gpu"
  image_labels = { built-by = "packer" }

  disk_size = 200
  disk_type = "pd-ssd"

  # No external IP: SSH over IAP, packages through Cloud NAT.
  use_iap          = true
  omit_external_ip = true
  use_internal_ip  = true

  ssh_username  = "packer"
  ssh_timeout   = "15m"
  state_timeout = "15m"
  metadata      = { enable-oslogin = "FALSE" }
}

build {
  sources = ["source.googlecompute.ai_ml_gpu"]

  provisioner "shell" {
    inline = [
      "for i in $(seq 1 60); do nvidia-smi && break; sleep 10; done",
      "nvidia-smi",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get -o DPkg::Lock::Timeout=600 update",
      "sudo apt-get -o DPkg::Lock::Timeout=600 install -y python3-venv git tmux htop",
      "sudo python3 -m venv /opt/ml-env",
      "sudo /opt/ml-env/bin/pip install --upgrade pip",
      "sudo /opt/ml-env/bin/pip install torch torchvision transformers datasets accelerate jupyterlab",
      "/opt/ml-env/bin/python -c 'import torch; print(torch.__version__, torch.cuda.is_available())'",
      "echo '. /opt/ml-env/bin/activate' | sudo tee /etc/profile.d/ml-env.sh",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/* /root/.cache/pip /tmp/*",
    ]
  }

  post-processor "manifest" {
    output     = "manifest-ai-ml-gpu.json"
    strip_path = true
  }
}
```

Build it from the template's directory.

```bash
packer init ai-ml-gpu.pkr.hcl
packer build -var="project_id=$PROJECT_ID" ai-ml-gpu.pkr.hcl
```

### Run it in Cloud Build

Build Google's community Packer builder once, as [Building VM images using Packer](https://docs.cloud.google.com/build/docs/building/build-vm-images-with-packer) describes. That builder sits on the Cloud SDK image, so `use_iap` finds gcloud. Set `_PACKER_IMAGE` to the path you pushed it to. Then run `gcloud builds submit --config=cloudbuild.yaml .` from the template's directory.

```yaml
timeout: 3600s
substitutions:
  _PACKER_IMAGE: us-central1-docker.pkg.dev/YOUR_PROJECT/YOUR_REPO/packer
steps:
  - name: ${_PACKER_IMAGE}
    entrypoint: bash
    args:
      - -c
      - |
        packer init ai-ml-gpu.pkr.hcl
        packer build -color=false -var="project_id=${PROJECT_ID}" ai-ml-gpu.pkr.hcl
```

The account that runs builds differs by project. Run `gcloud builds get-default-service-account`, then grant that account the roles in [What we'd pick](#what-wed-pick).

### Traps

- **`omit_external_ip = true` needs `use_internal_ip = true`.** Without it, `packer validate` fails with `'use_internal_ip' must be true if 'omit_external_ip' is true`.
- **`use_iap` needs gcloud where Packer runs and the IAP API turned on.** The build account needs the IAP-secured Tunnel User role. A firewall rule must allow TCP 22 from `35.235.240.0/20`.
- **A build VM with no external IP needs Cloud NAT.** Create the gateway in the build zone's region, or apt and pip can't reach the internet.
- **Inline steps run under `/bin/sh -e`, and `/bin/sh` on Ubuntu is dash.** Dash has no `source`, so the step fails. Call `/opt/ml-env/bin/pip` directly, or set `inline_shebang = "/bin/bash -e"`.
- **The SSH user isn't root.** Use `sudo` to write under `/opt` or `/etc`. The file provisioner can't write there either, so upload to `/tmp` and `sudo mv` the file.
- **GPU build VMs need two settings.** `accelerator_type` takes a URL with the zone, such as `projects/PROJECT/zones/ZONE/acceleratorTypes/nvidia-tesla-t4`. `on_host_maintenance` must be `TERMINATE`.
- **Packer waits `state_timeout` for the image to save.** The default is 5 minutes. The GPU template sets 15 minutes.
- **An org policy can require OS Login.** It then rejects `enable-oslogin = "FALSE"`. Remove that line and set `use_os_login = true`.
- **Debug a failed step with `packer build -on-error=abort`.** Packer leaves the VM up for SSH. Delete it afterward; build VMs are named `packer-<uuid>`. Set `PACKER_LOG=1` for detailed logs on stderr.
