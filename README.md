# AI Infrastructure Onboarding Workshop

Hands-on guides, scripts and labs for running AI and HPC workloads on Google Cloud GPUs and TPUs, from your first project to a profiled training job. Built by Google Public Sector for students, researchers and engineers.

## Start here

Set up a harness with [1-setup](./1-setup/). A harness is an AI assistant, such as Claude Code or agy, that reads docs, runs commands and edits files for you. The setup script builds a Cloud Workstation with both, and it needs an org admin. If you aren't one, ask an admin to [build your workstation](./1-setup/README.md#workstations-for-a-class), or [install the harness on a Linux machine you already use](./1-setup/README.md#another-machine).

## The journey

Each folder is one step, in the order you'll work. Together they cover what Google Cloud offers for AI and HPC.

| Step | Folder | What you do there |
|---|---|---|
| 1 | [1-setup](./1-setup/) | Build a workstation with a harness that reads the current docs, prices machines and reads your logs |
| 2 | [2-choose-hardware](./2-choose-hardware/) | Pick and size NVIDIA GPUs or Cloud TPUs, and port a model to TPU |
| 3 | [3-get-capacity](./3-get-capacity/) | Get the chips with on-demand, Flex-start, Calendar mode, Spot or a reservation, and check your quota |
| 4 | [4-storage-and-network](./4-storage-and-network/) | Store data, weights and checkpoints, keep VMs off the public internet, and build VM images |
| 5 | [5-run](./5-run/) | Run the job on Slurm, Kubernetes (GKE), plain VMs, Vertex AI or notebooks, or share chips across a class |
| 6 | [6-debug-and-profile](./6-debug-and-profile/) | Watch jobs, read their logs, find why one died, and profile it to speed it up |
| 7 | [7-cost](./7-cost/) | Look up today's prices, set budgets and alerts, and cut spend |
| 8 | [8-examples](./8-examples/) | Copy recipes and full projects, from a research landing zone down to a single demo |

## Glossary

| Term | Meaning |
|---|---|
| Harness | An AI assistant, such as Claude Code or agy, that reads docs, runs commands and edits files for you |
| DWS | Dynamic Workload Scheduler, the service behind two capacity options: Flex-start (queued, up to 7 days) and Calendar mode (fixed dates, 1 to 90 days) |
| MIG | Managed instance group: a set of Compute Engine VMs made from one template. Not NVIDIA's Multi-Instance GPU |
| IAP | Identity-Aware Proxy, which lets you SSH to a VM that has no public IP address |
| XPK | Accelerated Processing Kit, a command-line tool that creates GKE clusters for TPUs and GPUs and submits jobs to them |

## Where to look

| Question | Go to |
|---|---|
| What does Google Cloud offer for AI and HPC? | [The journey](#the-journey) |
| How do I set up a harness, and what can it look up for me? | [1-setup](./1-setup/) |
| Which GPU or TPU fits my job, and how many do I need? | [2-choose-hardware](./2-choose-hardware/) |
| How do I benchmark a model on GPU and TPU, and port it to TPU? | [2-choose-hardware/port-to-tpu.md](./2-choose-hardware/port-to-tpu.md) |
| How do I get GPUs or TPUs for a run, and raise my quota? | [3-get-capacity](./3-get-capacity/) |
| Where do I keep data, weights and checkpoints, and how do I keep VMs private? | [4-storage-and-network](./4-storage-and-network/) |
| Where do I run my job: Slurm, Kubernetes, VMs, Vertex AI or notebooks? | [5-run](./5-run/) |
| How do I share accelerators across a class? | [5-run/classroom](./5-run/classroom/) |
| Why is my job slow, hung or dead? | [6-debug-and-profile](./6-debug-and-profile/) |
| What does a GPU or TPU cost today, and how do I cap spend? | [7-cost](./7-cost/) |
| Is there a recipe or a full project to copy? | [8-examples](./8-examples/) |
| Where do I get help? | [SUPPORT.md](./SUPPORT.md) |

> **Disclaimer:** This repository is for demonstration and enablement. Always follow your organization's security policies and review scripts before running them in production environments.
