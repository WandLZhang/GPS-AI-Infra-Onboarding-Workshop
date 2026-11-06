# AI Infrastructure Onboarding Workshop

Hands-on guides, scripts and labs for running AI and HPC workloads on Google Cloud GPUs and TPUs, from your first project to a profiled training job. Built by Google Public Sector for students, researchers and engineers.

## Start here

Set up a harness with [1-harness-setup](./1-harness-setup/). A harness is an AI assistant, such as Claude Code or agy, that reads docs, runs commands and edits files for you. The setup script builds a Cloud Workstation with both.

Run it in a dedicated sandbox project that holds no sensitive data. The script resets 37 org policy constraints to Google's default on that project only.

The script needs an org admin. If you aren't one, ask an admin to [build your workstation](./1-harness-setup/README.md#workstations-for-a-class), or [install the harness on a Linux machine you already use](./1-harness-setup/README.md#another-machine). If you have no billing account, apply for [research credits or the TPU Research Cloud](./SUPPORT.md).

## Overview

AI Hypercomputer is Google Cloud's name for its AI infrastructure. It covers NVIDIA GPUs and Cloud TPUs, networking and storage, open software such as PyTorch and JAX, and consumption options such as Flex-start, Spot and reservations. Start with two talks from Google Cloud Next '26 and the overview page:

- [The future of AI infrastructure](https://www.youtube.com/watch?v=PJQPMv8TqLA)
- [AI Hypercomputer: resilient AI infrastructure at scale](https://www.youtube.com/watch?v=cvpasuzUB0Q)
- [AI Hypercomputer overview](https://docs.cloud.google.com/ai-hypercomputer/docs/overview)

The journey below walks through each part.

## The journey

Each folder is one step, in the order you'll work.

| Step | Folder | What you do there |
|---|---|---|
| 1 | [1-harness-setup](./1-harness-setup/) | Build a workstation with a harness that reads the current docs, prices machines and reads your logs |
| 2 | [2-choose-hardware](./2-choose-hardware/) | Pick and size NVIDIA GPUs or Cloud TPUs, and benchmark and port a model to TPU |
| 3 | [3-get-capacity](./3-get-capacity/) | Get the chips with on-demand, Flex-start, Calendar mode, Spot or a reservation, and check your quota |
| 4 | [4-storage-and-network](./4-storage-and-network/) | Store data, weights and checkpoints, keep VMs off the public internet, and build VM images |
| 5 | [5-run](./5-run/) | Run the job on Slurm, Kubernetes (GKE), plain VMs, managed training on Vertex AI or notebooks, or share TPUs across a class |
| 6 | [6-debug-and-profile](./6-debug-and-profile/) | Watch GPU and TPU jobs, read their logs, find why one died, and profile it to speed it up |
| 7 | [7-cost](./7-cost/) | Look up today's prices, set budgets and alerts, and find what's still billing |
| 8 | [8-examples](./8-examples/) | Copy recipes and full projects, from a research landing zone down to a single demo |

## Glossary

| Term | Meaning |
|---|---|
| Harness | An AI assistant, such as Claude Code or agy, that reads docs, runs commands and edits files for you |
| agy | The Antigravity CLI, Google's harness that runs in a terminal |
| AI Hypercomputer | Google Cloud's name for its AI infrastructure as a whole: GPUs and TPUs, networking, storage, software and consumption options |
| DWS | Dynamic Workload Scheduler, the service behind two capacity options: Flex-start (queued, up to 7 days) and Calendar mode (fixed dates, 1 to 90 days) |
| Capacity blocks | A future reservation that your account team drafts for you, for a start date you pick and with no maximum length. You review and submit the draft. Calendar mode is the self-service kind: you check availability and book 1 to 90 days yourself. An AWS Capacity Block for ML works like Calendar mode |
| Account team | Your organization's contacts at Google Cloud. Capacity blocks, TPU7x access and GPU future reservations start with them. Without one, the docs send you to the [sales team](https://cloud.google.com/contact) |
| MIG | Managed instance group: a set of Compute Engine VMs made from one template. Not NVIDIA's Multi-Instance GPU |
| IAP | Identity-Aware Proxy, which lets you SSH to a VM that has no public IP address |
| XPK | Accelerated Processing Kit, a command-line tool that creates GKE clusters for TPUs and GPUs and submits jobs to them |

## Where to look

| Question | Go to |
|---|---|
| What does Google Cloud offer for AI and HPC? | [Overview](#overview) |
| How do I set up a harness, and what can it look up for me? | [1-harness-setup](./1-harness-setup/) |
| Can I run the harness on my own Linux machine? | [1-harness-setup: Another machine](./1-harness-setup/README.md#another-machine) |
| Which GPU or TPU fits my job, and how many do I need? | [2-choose-hardware](./2-choose-hardware/) |
| How do I benchmark a model on GPU and TPU, and port it to TPU? | [2-choose-hardware/benchmark-and-port-to-tpu.md](./2-choose-hardware/benchmark-and-port-to-tpu.md) |
| How do I get GPUs or TPUs for a run, and raise my quota? | [3-get-capacity](./3-get-capacity/) |
| Where do I keep data, weights and checkpoints, and how do I keep VMs private? | [4-storage-and-network](./4-storage-and-network/) |
| Where do I run my job: Slurm, Kubernetes, VMs, managed training or notebooks? | [5-run](./5-run/) |
| How do I share accelerators across a class? | [5-run/classroom](./5-run/classroom/) |
| Why is my job slow, hung or dead? | [6-debug-and-profile](./6-debug-and-profile/) |
| What does a GPU or TPU cost today, and how do I stop paying for one I forgot? | [7-cost](./7-cost/) |
| Is there a recipe or a full project to copy? | [8-examples](./8-examples/) |
| Where do I get help, credits or academic compute? | [SUPPORT.md](./SUPPORT.md) |

> **Disclaimer:** This repository is for demonstration and enablement. Always follow your organization's security policies and review scripts before running them in production environments.
