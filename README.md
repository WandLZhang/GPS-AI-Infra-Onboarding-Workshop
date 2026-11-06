# AI Infrastructure Onboarding Workshop

Hands-on guides, scripts and labs for running AI and HPC workloads on Google Cloud GPUs and TPUs, from your first project to a profiled training job. Built by Google Public Sector for students, researchers and engineers.

## Start here

Run the [harness setup](./harness-setup/). It builds a Cloud Workstation with two harnesses, agy and Claude Code. They read the current Google Cloud docs, price machines from the live pricing pages, read your logs and install any other tool a task needs. Then find your task below.

## Where to look

| Question | Go to |
|---|---|
| How do I set up a harness, and what can it look up for me? | [harness-setup](./harness-setup/) |
| Which GPU or TPU fits my job, and how many chips do I need? | [accelerators](./accelerators/) |
| How do I port a model to TPU? | [accelerators/port-to-tpu.md](./accelerators/port-to-tpu.md) |
| How do I get GPUs and TPUs: on-demand, Spot, Flex-start, Calendar mode or a reservation? | [capacity](./capacity/) |
| Where do I find today's prices and zones? | [capacity: Look up facts that change](./capacity/README.md#look-up-facts-that-change) |
| How do I set up networking, disk images, storage and data pipelines? | [infrastructure](./infrastructure/) |
| Where do I run training, serving and notebooks: GKE, Slurm, Vertex AI or Colab Enterprise? | [workloads](./workloads/) |
| Is there a working recipe to start from? | [workloads: Start from a recipe](./workloads/README.md#start-from-a-recipe) |
| How do I watch, debug and profile a job? | [monitoring](./monitoring/) |
| How do I control cost and quota? | [billing](./billing/) |
| What builds on this, from a research landing zone down to a single demo? | [related-repos](./related-repos/) |
| Where do I get help? | [SUPPORT.md](./SUPPORT.md) |

> **Disclaimer:** This repository is for demonstration and enablement. Always follow your organization's security policies and review scripts before running them in production environments.
