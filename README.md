# AI Infrastructure Onboarding Workshop

Guides, scripts and labs for running AI and HPC work on Google Cloud GPUs and TPUs, built by Google Public Sector for students, researchers and research computing teams. Specs and prices change, so each guide links the official page and gives a docs MCP question or a `gcp-pricing` command instead of copying them.

## Start here

Set up your agent with [agentic-coder-setup](./01-foundational-tools/agentic-coder-setup/), then find your question below.

```bash
git clone https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop.git
cd GPS-AI-Infra-Onboarding-Workshop
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_PROJECT_ID>
```

## Where to look

### 01 Foundational tools

| Question | Where |
|---|---|
| Set up a coding agent that reads the docs, prices and my logs | [agentic-coder-setup](./01-foundational-tools/agentic-coder-setup/) |
| Pick GPU or TPU, size a job, plan checkpoints | [accelerator-guide](./01-foundational-tools/accelerator-guide/) |
| Port a PyTorch model to TPU | [accelerator-guide: Port a model to TPU](./01-foundational-tools/accelerator-guide/README.md#8-port-a-model-to-tpu) |

### 02 Core infrastructure

| Question | Where |
|---|---|
| VMs with no public IP, reached through IAP | [zero-trust-iap-access](./02-core-infrastructure/zero-trust-iap-access/) |
| Images for GPU and HPC VMs | [disk-images](./02-core-infrastructure/disk-images/) |
| Managed Lustre, GCSFuse, Rapid Cache | [storage](./02-core-infrastructure/storage/) |
| BigQuery and Dataflow for ML data | [data-pipeline](./02-core-infrastructure/data-pipeline/) |

### 03 Deploying workloads

| Question | Where |
|---|---|
| Flex-start and Calendar mode, and their prices | [dws](./03-deploying-workloads/dws/) |
| Which zones take Calendar requests | [discover-calendar-zones.py](./03-deploying-workloads/dws/discover-calendar-zones.py) |
| Best zone for Spot, and keeping training alive on Spot | [spot-capacity-advisor](./03-deploying-workloads/spot-capacity-advisor/) |
| Book capacity for future dates | [compute-engine-future-reservations](./03-deploying-workloads/compute-engine-future-reservations/) |
| Flex-start VMs through MIG resize requests | [compute-engine-Managed Instance Groups](./03-deploying-workloads/compute-engine-Managed%20Instance%20Groups/) |
| GPUs and TPUs on GKE: Spot, ComputeClasses, Kueue, RL | [gke](./03-deploying-workloads/gke/) |
| AI-optimized GKE clusters from Cluster Toolkit | [cluster-toolkit](./03-deploying-workloads/cluster-toolkit/) |
| Managed Slurm | [cluster-director](./03-deploying-workloads/cluster-director/) |
| TPU training on GKE from the command line | [xpk](./03-deploying-workloads/xpk/) |
| Vertex AI training with FLEX_START | [vertex-ai](./03-deploying-workloads/vertex-ai/) |
| GPU notebooks | [colab-enterprise](./03-deploying-workloads/colab-enterprise/) |

### 04 Monitoring and observability

| Question | Where |
|---|---|
| TPU health metrics, dashboards, XProf | [04-monitoring-observability](./04-monitoring-observability/) |

### 05 Billing and usage

| Question | Where |
|---|---|
| Budgets, spend caps, cost monitoring | [05-billing-usage](./05-billing-usage/) |

### Related repos

From the organization down to a single demo:

| Question | Where |
|---|---|
| A landing zone for a research organization | [fast-science-0-stellar-engine](https://github.com/WandLZhang/fast-science-0-stellar-engine) |
| A project for each researcher on that landing zone | [fast-science-1-researcher-lab](https://github.com/WandLZhang/fast-science-1-researcher-lab) |
| Workloads a researcher deploys into that project | [fast-science-2-workload-catalog](https://github.com/WandLZhang/fast-science-2-workload-catalog) |
| One Slurm cluster across regions, with DWS and Spot partitions | [slurm-multi-region-gpu-public](https://github.com/WandLZhang/slurm-multi-region-gpu-public) |
| A class sharing TPUs through a queue | [shared-tpu-notebooks](https://github.com/WandLZhang/shared-tpu-notebooks) |
| Protein folding bursting across GPU and TPU Slurm partitions | [ai-infra-demo-proteins](https://github.com/WandLZhang/ai-infra-demo-proteins) |
| A campus demo with a talk track | [ai-infra-demo-proteins-template](https://github.com/WandLZhang/ai-infra-demo-proteins-template) |
| Serve and inspect LLMs on TPU | [tpu-mech-interp](https://github.com/WandLZhang/tpu-mech-interp) |

### From Google

| Question | Where |
|---|---|
| Copy a working TPU training or serving recipe | [tpu-recipes](https://github.com/AI-Hypercomputer/tpu-recipes) |
| Copy a working GPU recipe | [gpu-recipes](https://github.com/AI-Hypercomputer/gpu-recipes) |
| GKE reference architectures for training and inference | [accelerated-platforms](https://github.com/GoogleCloudPlatform/accelerated-platforms) |
| Train LLMs in JAX | [MaxText](https://maxtext.readthedocs.io/en/latest/) |
| Diagnose a hung or failed TPU job with an agent | [ML Workload Debugging Wiki](https://github.com/google/ml-workload-debugging-wiki) |
| Port a PyTorch model with an agent | [TPU agent suite](https://github.com/google-pytorch/tpu-agent-suite) |

## Look up facts that change

Prices and zones change. This repo dates the numbers it prints. Get the current ones here:

| Fact | Get it now |
|---|---|
| Price of a machine type | `gcp-pricing accelerator --filter <machine-type>` or `gcp-pricing tpu --filter <generation>` |
| Which machine types take Flex-start and Calendar mode | Docs MCP: "Which GPU and TPU machine types support Dynamic Workload Scheduler flex-start and calendar mode?" |
| Zones that take Calendar requests | [`discover-calendar-zones.py`](./03-deploying-workloads/dws/discover-calendar-zones.py) |
| Spot obtainability by zone | [Capacity Advisor for Spot](./03-deploying-workloads/spot-capacity-advisor/) |
| GPU zones | [GPU regions and zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones) |
| TPU zones | [TPU regions and zones](https://docs.cloud.google.com/tpu/docs/regions-zones) |

## Read and watch

- [How to Scale Your Model](https://jax-ml.github.io/scaling-book): the parts on rooflines, TPUs, sharded matmuls and transformers. GPU users add the GPU part.
- [Ironwood at Hot Chips 2025](https://www.youtube.com/watch?v=Zy3LfsAxc64): Google engineers on the 9,216-chip pod.
- Google Cloud Next '26:
  - [The future of AI infrastructure](https://www.youtube.com/watch?v=PJQPMv8TqLA)
  - [What's new for AI on GKE: training, serving and agents](https://www.youtube.com/watch?v=XI726xo0a98)
  - [Unlock high-performance AI with the new Cloud TPU experience](https://www.youtube.com/watch?v=fUELeEaTLVs)
  - [AI Hypercomputer: resilient AI infrastructure at scale](https://www.youtube.com/watch?v=cvpasuzUB0Q)
  - [The GKE inference playbook](https://www.youtube.com/watch?v=WQlKo0D3Ofg)
  - [Beyond fine-tuning: training and RL on GKE](https://www.youtube.com/watch?v=GjQJepOZP7o)
  - [Stop wasting GPU FLOPs on cold starts](https://www.youtube.com/watch?v=EXQ3AksFXcM)
- [Inside the 8th-generation TPU](https://cloud.google.com/blog/products/compute/tpu-8t-and-tpu-8i-technical-deep-dive)
- [TorchTPU is now open source](https://cloud.google.com/blog/topics/ai-infrastructure/torchtpu-is-now-open-source-run-native-pytorch-on-tpus), with deep dives on [vLLM and SGLang](https://developers.googleblog.com/announcing-new-vllm-and-sglang-inference-engines-on-tpu/) and [TorchTitan](https://developers.googleblog.com/integrating-torchtpu-into-torchtitan-and-optimizing-models-for-tpu/), and the [TorchTPU paper](https://arxiv.org/abs/2610.24161).
- [Design storage for AI and ML workloads](https://docs.cloud.google.com/architecture/ai-ml/storage-for-ai-ml)
- [Kueue for AI: atomic admission and topology awareness](https://medium.com/google-cloud/kueue-for-ai-the-power-of-atomic-admission-topology-awareness-59c2fd1f86ed)

## Get help

- **Quota:** request an increase from the Quotas page ([how](https://cloud.google.com/docs/quotas/help/request_increase)).
- **Support:** [Google Cloud support](https://cloud.google.com/support).
- **Community:** [Google Developer forums](https://discuss.google.dev).
- **Compute for academic research:** [Google Cloud research credits](https://edu.google.com/programs/credits/research/), up to $5,000, and the [TPU Research Cloud](https://sites.research.google/trc/about/). In the United States, the Google Public Sector Program for Accelerated Research (GPAR) adds pricing for accelerators, early access, training and expert help; [Google Cloud for research](https://cloud.google.com/edu/researchers) describes it.

## Repository structure

```
GPS-AI-Infra-Onboarding-Workshop/
├── README.md                          # This file
├── LICENSE
├── CONTRIBUTING.md
│
├── 01-foundational-tools/
│   ├── agentic-coder-setup/           # Coding agent setup, rules, hooks, smoke test
│   └── accelerator-guide/             # Pick, size, checkpoint and port to TPU
│
├── 02-core-infrastructure/            # VMs, networking, storage, data pipeline
│   ├── zero-trust-iap-access/         # IAP setup, no-public-IP configs
│   ├── disk-images/                   # Images for GPU and HPC VMs, Packer templates
│   ├── storage/                       # Managed Lustre, GCSFuse, Rapid Cache, Rapid Bucket, Drive sync
│   └── data-pipeline/                 # BigQuery, Dataflow, BigQuery DataFrames for AI/ML
│
├── 03-deploying-workloads/            # Capacity and platforms
│   ├── dws/                           # Dynamic Workload Scheduler, prices, Calendar zone discovery
│   ├── spot-capacity-advisor/         # Best zone, region and machine for Spot
│   ├── compute-engine-future-reservations/       # Calendar-mode future reservations
│   ├── compute-engine-Managed Instance Groups/   # Flex-start VMs via MIG resize requests
│   ├── gke/                           # GKE Autopilot and Standard (GPUs, DWS, Spot, RL)
│   ├── cluster-toolkit/               # AI-optimized GKE clusters with DWS
│   ├── cluster-director/              # Managed Slurm clusters
│   ├── xpk/                           # Accelerated Processing Kit
│   ├── vertex-ai/                     # Vertex AI serverless training (FLEX_START)
│   └── colab-enterprise/              # GPU notebooks, reservations, DWS patterns
│
├── 04-monitoring-observability/       # Dashboards, TPU metrics and health, alerts, XProf
└── 05-billing-usage/                  # Cost monitoring and limits for AI workloads
```

## Contributing

1. Fork this repository.
2. Create a feature branch (`git checkout -b feature/new-artifact`).
3. Commit your changes (`git commit -m 'Add new artifact for ...'`).
4. Push to the branch (`git push origin feature/new-artifact`).
5. Open a pull request.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](./LICENSE) file for details.

> **Disclaimer:** This repository is for demonstration and enablement. Always follow your organization's security policies and review scripts before running them in production environments.
