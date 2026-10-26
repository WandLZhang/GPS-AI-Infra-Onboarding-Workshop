# AI Infrastructure Onboarding Workshop

Hands-on guides, scripts and labs for running AI and HPC workloads on Google Cloud GPUs and TPUs, from your first project to a profiled training job. Built by Google Public Sector for students, researchers and engineers.

## Start here

1. Clone the repo and sign in:

   ```bash
   git clone https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop.git
   cd GPS-AI-Infra-Onboarding-Workshop
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project <YOUR_PROJECT_ID>
   ```

2. Set up an AI coding agent that can read the current docs and your logs: [agentic-coder-setup](./01-foundational-tools/agentic-coder-setup/).
3. Learn how accelerators behave. Read the [scaling book](https://jax-ml.github.io/scaling-book) parts on rooflines, TPUs, sharded matmuls and transformers; GPU users add the GPU part. Then [pick an accelerator](./01-foundational-tools/accelerator-guide/).
4. Get capacity. Start with [how the options compare](./03-deploying-workloads/README.md), then [DWS](./03-deploying-workloads/dws/) for Flex-start and Calendar mode and the [Spot Capacity Advisor](./03-deploying-workloads/spot-capacity-advisor/) for Spot.
5. Run something. Start from a [recipe](#start-from-a-recipe), then deploy on [GKE](./03-deploying-workloads/gke/), [XPK](./03-deploying-workloads/xpk/), [Cluster Director](./03-deploying-workloads/cluster-director/) or [Vertex AI](./03-deploying-workloads/vertex-ai/).
6. Watch it: [monitoring and profiling](./04-monitoring-observability/).
7. Control what it costs: [budgets and billing](./05-billing-usage/).

You'll need these tools:

| Tool | Install |
|------|---------|
| `gcloud` CLI | [Install](https://cloud.google.com/sdk/docs/install) |
| `terraform` | [Install](https://developer.hashicorp.com/terraform/install) |
| `kubectl` | `gcloud components install kubectl` |
| `packer` | [Install](https://developer.hashicorp.com/packer/install) |
| `jq` | `apt-get install jq` |

## Where to look

| I want to | Go to |
|---|---|
| Set up Cline, Claude Code or Gemini CLI with docs and logging MCP servers | [agentic-coder-setup](./01-foundational-tools/agentic-coder-setup/) |
| Ask my agent for the current official answer | [Try the docs MCP](./01-foundational-tools/agentic-coder-setup/README.md#9-try-the-docs-mcp) |
| Get a machine type's current price | [gcp-pricing](./01-foundational-tools/agentic-coder-setup/README.md#8-install-the-gcp-pricing-cli) |
| Pick a GPU or TPU | [accelerator-guide](./01-foundational-tools/accelerator-guide/) |
| Compare TPU generations | [Cloud TPU generations](./01-foundational-tools/accelerator-guide/README.md#cloud-tpu-generations) |
| Run double-precision science code | [FP64 science codes](./01-foundational-tools/accelerator-guide/README.md#double-precision-fp64-science-codes) |
| Fit a model to the TPU matrix unit | [Fit matmuls to the MXU](./01-foundational-tools/accelerator-guide/README.md#tpu-fit-matmuls-to-the-mxu) |
| Estimate how many chips and how long | [Size a job](./01-foundational-tools/accelerator-guide/README.md#size-a-job-before-you-ask-for-chips) |
| Port a model to TPU and beat the GPU baseline | [Porting a model to TPU](#porting-a-model-to-tpu) |
| Port a PyTorch model with a coding agent | [TPU agent suite](https://github.com/google-pytorch/tpu-agent-suite) (Preview, Claude Code and Antigravity) |
| Choose between on-demand, Spot, Flex-start, Calendar mode and reservations | [Capacity vs. deployment](./03-deploying-workloads/README.md) |
| See which quota each capacity option uses | [Quota and pricing](./03-deploying-workloads/dws/README.md#7-quota--pricing) |
| See current prices by machine type | [Prices by machine type](./03-deploying-workloads/dws/README.md#prices-by-machine-type) |
| Find when and where I can book Calendar mode | [Check Calendar availability](./03-deploying-workloads/dws/README.md#check-calendar-availability-before-you-book) |
| Book capacity for a future date | [Future reservations](./03-deploying-workloads/compute-engine-future-reservations/) |
| Find the Spot zone most likely to land | [spot-capacity-advisor](./03-deploying-workloads/spot-capacity-advisor/) |
| Spray requests across zones and poll for capacity | [spot-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-spray.sh), [flex-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-spray.sh), [flex-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-poll.sh), [calendar-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/calendar-poll.sh), [spot-obtainability-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-obtainability-poll.sh) |
| Keep a training job alive on Spot | [Training on Spot](./03-deploying-workloads/spot-capacity-advisor/README.md#keep-a-training-job-alive-on-spot), [Spot VMs on GKE](./03-deploying-workloads/gke/README.md#spot-vms-for-ai-jobs) |
| Fall back across capacity types on GKE | [Custom ComputeClasses](./03-deploying-workloads/gke/README.md#fall-back-across-capacity-types-with-custom-computeclasses) |
| Load model weights fast, and pick storage | [storage](./02-core-infrastructure/storage/) |
| Build VM images and lock down networking | [disk-images](./02-core-infrastructure/disk-images/), [zero-trust-iap-access](./02-core-infrastructure/zero-trust-iap-access/) |
| Run RL post-training | [RL post-training on GKE](./03-deploying-workloads/gke/README.md#rl-post-training-on-gke) |
| See why a TPU job died | [TPU hardware health](./04-monitoring-observability/README.md#36-tpu-hardware-health-cloud-monitoring-beta) |
| Diagnose a hung or failed TPU job with a coding agent | [ML Workload Debugging Wiki](https://github.com/google/ml-workload-debugging-wiki) (Claude Code and Antigravity; [doc](https://docs.cloud.google.com/tpu/docs/agent-wiki)) |
| Profile a job with XProf | [XProf](./04-monitoring-observability/README.md#6-xprof--performance-profiling--visualization) |
| Set budgets and alerts | [billing](./05-billing-usage/) |
| Get help | [Get help](#get-help) |

## Start from a recipe

Copy a working recipe before you write anything new:

- [AI-Hypercomputer/tpu-recipes](https://github.com/AI-Hypercomputer/tpu-recipes): training and inference recipes for TPUs, including vLLM-TorchTPU serving on [Ironwood](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/ironwood/vLLM/vLLM-TorchTPU) and [Trillium](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/trillium/vLLM/vLLM-TorchTPU/Gemma4-26B).
- [AI-Hypercomputer/gpu-recipes](https://github.com/AI-Hypercomputer/gpu-recipes): the same for GPUs.
- [GoogleCloudPlatform/accelerated-platforms](https://github.com/GoogleCloudPlatform/accelerated-platforms): GKE reference architectures for inference and training.
- [MaxText](https://maxtext.readthedocs.io/en/latest/): LLM training in JAX on TPUs and GPUs.

## Porting a model to TPU

For PyTorch, start with TorchTPU. Google's [PyTorch on TPU](https://docs.cloud.google.com/tpu/docs/pytorch-on-tpu) page covers it, plus vLLM-TorchTPU and SGLang-TorchTPU for serving and TorchTitan for training, and the [TorchTPU docs](https://torchtpu.readthedocs.io/en/latest/) cover install and APIs. To run TorchTPU with Ray on GKE, start from Google's [fine-tuning](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/train-models-tpu-ray-torchtpu) and [serving](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/serve-llm-tpu-ray-torchtpu) tutorials.

What worked on our ports, in order:

1. Get it running before you make it fast. Expect the first number to lose to the GPU; that's normal for an untuned port.
2. Name the baseline you got. If you compared against a different GPU than planned, say so in every readout.
3. Sweep architecture choices before tuning flags. In vLLM's TPU backend, switching the MoE kernel backend moved throughput more than any command-line flag did.
4. When summary numbers stop helping, switch to profiles, which show where the time goes. tpu-inference ships [`tpu_profiling.py`](https://github.com/vllm-project/tpu-inference/blob/bec31b7cce132ed995daed8d39321b943d15be73/examples/tpu_profiling.py).
5. Profile prefill and decode separately. They have different bottlenecks, and averaging hides both.
6. Treat correctness, quantization and upstreaming as part of the port. For correctness, run several dozen prompts at temperature 0 against the GPU implementation and check every prompt where the tokens differ.

For a custom Pallas kernel, try [MaxKernel](https://github.com/AI-Hypercomputer/accelerator-agents/tree/main/maxkernel) before you write one by hand. It's an open-source agent that turns a JAX, CUDA or PyTorch kernel into a Pallas kernel, then compiles, tests, tunes and profiles it on a real TPU. It runs as a [Claude Code plugin](https://github.com/AI-Hypercomputer/accelerator-agents/blob/main/maxkernel/claude-code/README.md), and the method is in [the paper](https://arxiv.org/abs/2609.04523).

## Read and watch

- [How to Scale Your Model](https://jax-ml.github.io/scaling-book): the reading order is in [Start here](#start-here).
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

## Get help

- **Quota:** request an increase from the Quotas page ([how](https://cloud.google.com/docs/quotas/help/request_increase)).
- **Support:** [Google Cloud support](https://cloud.google.com/support).
- **Community:** [Google Developer forums](https://discuss.google.dev).
- **Compute for academic research:** [TPU Research Cloud](https://sites.research.google/trc/about/) and [Google Cloud research credits](https://cloud.google.com/edu/researchers).

## Sections

| # | Phase | What's in it |
|---|-------|-------------|
| 1 | [Foundational Tools & Access](./01-foundational-tools/) | Agentic coders, accelerator guide |
| 2 | [Core Infrastructure Setup](./02-core-infrastructure/) | Networking (IAP, no public IP), disk images (Packer), storage (GCSFuse, Rapid Cache, Rapid Bucket, Drive sync), data pipelines (BigQuery, Dataflow, BigQuery DataFrames) |
| 3 | [Deploying Workloads & Scheduling](./03-deploying-workloads/) | DWS, Spot, future reservations, GKE (Autopilot and Standard), Vertex AI, Colab Enterprise, Cluster Toolkit, Cluster Director, XPK |
| 4 | [Monitoring & Observability](./04-monitoring-observability/) | GKE AI/ML dashboards, TPU metrics and hardware health, alerts, XProf |
| 5 | [Billing & Usage](./05-billing-usage/) | Cost visibility, budgets, quotas and limits for AI workloads |

## Repository structure

```
GPS-AI-Infra-Onboarding-Workshop/
├── README.md                          # This file
├── LICENSE
├── CONTRIBUTING.md
│
├── 01-foundational-tools/
│   ├── accelerator-guide/             # Pick, size and checkpoint GPUs and TPUs
│   └── agentic-coder-setup/           # Cline, Claude Code, Gemini CLI setup
│
├── 02-core-infrastructure/            # VMs, Networking, Storage, Data Pipeline
│   ├── zero-trust-iap-access/         # IAP setup, no-public-IP configs
│   ├── disk-images/                   # Packer templates & Cloud Build
│   ├── storage/                       # GCSFuse, Rapid Cache, Rapid Bucket, GDrive sync
│   └── data-pipeline/                 # BigQuery, Dataflow, BigQuery DataFrames for AI/ML
│
├── 03-deploying-workloads/            # Workload scheduling & platforms
│   ├── dws/                           # Dynamic Workload Scheduler, prices, Calendar zone discovery
│   ├── gke/                           # GKE Autopilot & Standard (GPU deployment, DWS, Spot, RL)
│   ├── cluster-toolkit/               # AI-optimized GKE clusters with DWS
│   ├── cluster-director/              # Managed Slurm clusters
│   ├── compute-engine-Managed Instance Groups/   # Flex-start VMs via MIG resize requests
│   ├── compute-engine-future-reservations/       # Calendar-mode future reservations
│   ├── spot-capacity-advisor/         # Best zone, region and machine for Spot
│   ├── vertex-ai/                     # Vertex AI serverless training (FLEX_START)
│   ├── colab-enterprise/              # GPU-accelerated notebooks, reservations, DWS patterns
│   └── xpk/                           # Accelerated Processing Kit
│
├── 04-monitoring-observability/       # GKE dashboards, TPU metrics, alerts, XProf
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
