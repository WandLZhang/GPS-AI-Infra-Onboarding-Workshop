# AI Infrastructure Onboarding Workshop

Field-tested guides, scripts and labs for running AI and HPC workloads on Google Cloud GPUs and TPUs. Built by Google Public Sector for students, researchers and research computing teams. Each section says what we'd pick and why, links the official page, and gives the question to ask your agent's docs MCP for the current details.

## Start here

1. Set up your agent with [agentic-coder-setup](./01-foundational-tools/agentic-coder-setup/), and end with `claude-smoke-test`.
2. Find your job in the table, then read that section.
3. Before you quote a price or a zone, look it up live: [Look up facts that change](#look-up-facts-that-change).

```bash
git clone https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop.git
cd GPS-AI-Infra-Onboarding-Workshop
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_PROJECT_ID>
```

| I want to | Go to |
|---|---|
| Set up a coding agent that reads the docs, prices and my logs | [1. Set up your agent](#1-set-up-your-agent) |
| Estimate chips and time, and pick GPU or TPU | [2. Size the job and pick GPU or TPU](#2-size-the-job-and-pick-gpu-or-tpu) |
| Get GPUs or TPUs: Flex-start, Calendar mode, Spot, reservations | [3. Get capacity](#3-get-capacity) |
| Run MPI or Slurm jobs on H4D, Cloud RDMA and Managed Lustre | [4. Run HPC on Slurm](#4-run-hpc-on-slurm) |
| Train or serve models on GKE or Vertex AI | [5. Run AI on GKE and Vertex AI](#5-run-ai-on-gke-and-vertex-ai) |
| Move a model from GPU to TPU | [6. Port to TPU](#6-port-to-tpu) |
| Plan a landing zone for a research organization | [7. Landing zones](#7-landing-zones) |
| Find out why a job is slow, hung or dead | [8. Observe and debug](#8-observe-and-debug) |
| Keep the bill under control | [9. Control cost](#9-control-cost) |
| Help a campus research group get started | [10. Run a campus engagement](#10-run-a-campus-engagement) |

## 1. Set up your agent

**What we'd pick:** Claude Code on a Cloud Workstation, with the Google Developer Knowledge MCP, the `gcp-pricing` CLI and the Cloud Logging MCP. It answers from the current docs and live prices. Its hooks stop it before it clobbers a file or leaves a GPU running. Antigravity and Gemini CLI work too.

- Set it up: [agentic-coder-setup](./01-foundational-tools/agentic-coder-setup/). Its table lists what each rule, hook and setting prevents.
- Diagnose a hung or failed TPU job with an agent: the [ML Workload Debugging Wiki](https://github.com/google/ml-workload-debugging-wiki) ([doc](https://docs.cloud.google.com/tpu/docs/agent-wiki)).
- Port a PyTorch model with an agent: the [TPU agent suite](https://github.com/google-pytorch/tpu-agent-suite).
- Official page: [Developer Knowledge MCP server](https://developers.google.com/knowledge/mcp)
- Ask your agent: "How do I create an API key for the Developer Knowledge MCP server and add it to Claude Code?"

## 2. Size the job and pick GPU or TPU

**What we'd pick:** size the job before you pick the chip. Estimate FLOPs, memory and time with the scaling book's roofline math, then ask for the smallest machine or slice that answers your question.

- Pick TPU for models dominated by matrix math, with static shapes and no custom ops in the training loop: JAX and MaxText, or PyTorch through TorchTPU.
- Pick GPU when the code depends on custom CUDA kernels or CUDA-only libraries, or needs double precision (FP64).
- In this repo: the [accelerator guide](./01-foundational-tools/accelerator-guide/), with [Size a job](./01-foundational-tools/accelerator-guide/README.md#size-a-job-before-you-ask-for-chips), [FP64 science codes](./01-foundational-tools/accelerator-guide/README.md#double-precision-fp64-science-codes), [Fit matmuls to the MXU](./01-foundational-tools/accelerator-guide/README.md#tpu-fit-matmuls-to-the-mxu) and [Cloud TPU generations](./01-foundational-tools/accelerator-guide/README.md#cloud-tpu-generations).
- Read [How to Scale Your Model](https://jax-ml.github.io/scaling-book): the parts on rooflines, TPUs, sharded matmuls and transformers. GPU users add the GPU part.
- Official pages: [When to use TPUs](https://docs.cloud.google.com/tpu/docs/intro-to-tpu), [TPU versions by workload](https://docs.cloud.google.com/docs/compute-area/tpus)
- Ask your agent: "How do I choose between GPUs and TPUs for AI training and inference on Google Cloud?"

## 3. Get capacity

**What we'd pick**, by workload:

| Workload | Pick | Why |
|---|---|---|
| A batch job or experiment that can wait in a queue and runs up to seven days | DWS Flex-start | Discounted pay-as-you-go, with no reservation |
| A run with fixed dates, from 1 to 90 days | Calendar mode future reservation | The capacity is yours for that window |
| Work that checkpoints and can restart | Spot | A much lower price than on-demand, and it can be preempted at any time |
| Steady use for a year or more | Future reservation with a committed use discount | Assured capacity at a lower rate |

- Compare the options and the platforms that use them: [03-deploying-workloads](./03-deploying-workloads/README.md).
- Flex-start and Calendar mode, their quota and prices: [dws](./03-deploying-workloads/dws/). Find where you can book Calendar mode with [`discover-calendar-zones.py`](./03-deploying-workloads/dws/discover-calendar-zones.py).
- Score Spot zones before you request: [spot-capacity-advisor](./03-deploying-workloads/spot-capacity-advisor/). Keep training alive on Spot: [Training on Spot](./03-deploying-workloads/spot-capacity-advisor/README.md#keep-a-training-job-alive-on-spot).
- Book a future date: [compute-engine-future-reservations](./03-deploying-workloads/compute-engine-future-reservations/). Flex-start VMs through resize requests: [Managed Instance Groups](./03-deploying-workloads/compute-engine-Managed%20Instance%20Groups/).
- Spray requests across zones and poll: [spot-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-spray.sh), [flex-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-spray.sh), [flex-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-poll.sh), [calendar-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/calendar-poll.sh), [spot-obtainability-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-obtainability-poll.sh).
- Official pages: [Flex-start in GKE](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/dws), [TPU consumption options](https://docs.cloud.google.com/tpu/docs/plan-tpus)
- Ask your agent: "Which GPU and TPU machine types support Dynamic Workload Scheduler flex-start and calendar mode, and what is the maximum run duration for each?"

## 4. Run HPC on Slurm

**What we'd pick:** Cluster Director for a managed Slurm cluster when the team already works in Slurm, and Cluster Toolkit when you need your own blueprint. Run tightly coupled CPU codes on H4D VMs, which use Cloud RDMA at 200 Gbps. Use Managed Lustre as the parallel file system. H4D comes through a reserved capacity block from your account team, or through Flex-start for jobs of up to seven days.

- In this repo: [cluster-director](./03-deploying-workloads/cluster-director/), [cluster-toolkit](./03-deploying-workloads/cluster-toolkit/), [storage](./02-core-infrastructure/storage/) for Managed Lustre, and [disk-images](./02-core-infrastructure/disk-images/) for HPC images.
- One Slurm cluster across regions, with DWS and Spot partitions: [slurm-multi-region-gpu-public](https://github.com/WandLZhang/slurm-multi-region-gpu-public).
- Official page: [Create a Cloud RDMA-enabled Slurm cluster with H4D](https://docs.cloud.google.com/cluster-toolkit/docs/quickstarts/create-a-slurm-cluster-h4d)
- Ask your agent: "How do I create a Slurm cluster with H4D VMs, Cloud RDMA and Managed Lustre?"

## 5. Run AI on GKE and Vertex AI

**What we'd pick:** GKE when the team runs containers and shares accelerators across users. Queue multi-node jobs with Kueue and Flex-start with queued provisioning, and fall back across reservations, Flex-start, Spot and on-demand with Custom ComputeClasses. Pick Vertex AI custom training with the `FLEX_START` strategy when you want a managed job and no cluster; the docs now call the platform Gemini Enterprise Agent Platform. Use Colab Enterprise for notebooks, and XPK to run TPU training on GKE from the command line.

- In this repo: [gke](./03-deploying-workloads/gke/), including [Spot VMs for AI jobs](./03-deploying-workloads/gke/README.md#spot-vms-for-ai-jobs), [Custom ComputeClasses](./03-deploying-workloads/gke/README.md#fall-back-across-capacity-types-with-custom-computeclasses) and [RL post-training](./03-deploying-workloads/gke/README.md#rl-post-training-on-gke). Also [vertex-ai](./03-deploying-workloads/vertex-ai/), [colab-enterprise](./03-deploying-workloads/colab-enterprise/), [xpk](./03-deploying-workloads/xpk/), and [storage](./02-core-infrastructure/storage/) for loading model weights fast.
- Copy a working recipe before you write anything new: [tpu-recipes](https://github.com/AI-Hypercomputer/tpu-recipes), [gpu-recipes](https://github.com/AI-Hypercomputer/gpu-recipes), [accelerated-platforms](https://github.com/GoogleCloudPlatform/accelerated-platforms) for GKE reference architectures, and [MaxText](https://maxtext.readthedocs.io/en/latest/) for LLM training in JAX.
- Official pages: [Flex-start with queued provisioning and Kueue](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest), [Training jobs with Dynamic Workload Scheduler](https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/training/schedule-jobs-dws)
- Ask your agent: "How do I run a batch GPU training job on GKE with Kueue and Dynamic Workload Scheduler flex-start?"

## 6. Port to TPU

**What we'd pick:** TorchTPU for PyTorch. Google's [PyTorch on TPU](https://docs.cloud.google.com/tpu/docs/pytorch-on-tpu) page covers it, plus vLLM-TorchTPU and SGLang-TorchTPU for serving and TorchTitan for training. PyTorch/XLA is deprecated, and its repo is archived on November 15, 2026. The [TorchTPU docs](https://torchtpu.readthedocs.io/en/latest/) cover install and APIs. To run TorchTPU with Ray on GKE, start from Google's [fine-tuning](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/train-models-tpu-ray-torchtpu) and [serving](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/serve-llm-tpu-ray-torchtpu) tutorials. Serving recipes for vLLM-TorchTPU are in tpu-recipes for [Ironwood](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/ironwood/vLLM/vLLM-TorchTPU) and [Trillium](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/trillium/vLLM/vLLM-TorchTPU/Gemma4-26B).

What worked on our ports, in order:

1. Get it running before you make it fast. Expect the first number to lose to the GPU; that's normal for an untuned port.
2. Name the baseline you got. If you compared against a different GPU than planned, say so in every readout.
3. Sweep architecture choices before tuning flags. In vLLM's TPU backend, switching the MoE kernel backend moved throughput more than any command-line flag did.
4. When summary numbers stop helping, switch to profiles, which show where the time goes. tpu-inference ships [`tpu_profiling.py`](https://github.com/vllm-project/tpu-inference/blob/bec31b7cce132ed995daed8d39321b943d15be73/examples/tpu_profiling.py).
5. Profile prefill and decode separately. They have different bottlenecks, and averaging hides both.
6. Treat correctness, quantization and upstreaming as part of the port. For correctness, run several dozen prompts at temperature 0 against the GPU implementation and check every prompt where the tokens differ.

For a custom Pallas kernel, try [MaxKernel](https://github.com/AI-Hypercomputer/accelerator-agents/tree/main/maxkernel) before you write one by hand. It's an open-source agent that turns a JAX, CUDA or PyTorch kernel into a Pallas kernel, then compiles, tests, tunes and profiles it on a real TPU. It runs as a [Claude Code plugin](https://github.com/AI-Hypercomputer/accelerator-agents/blob/main/maxkernel/claude-code/README.md), and the method is in [the paper](https://arxiv.org/abs/2609.04523).

- Ask your agent: "How do I run PyTorch on Cloud TPU with TorchTPU?"

## 7. Landing zones

**What we'd pick:** for a research organization, the Fast Science L0 landing zone in [fast-science-0-stellar-engine](https://github.com/WandLZhang/fast-science-0-stellar-engine). Deploying it needs organization-level access, so start with its architecture. For a single project, keep VMs off the internet with IAP and no public IPs: [zero-trust-iap-access](./02-core-infrastructure/zero-trust-iap-access/).

- Official pages: [Landing zone design in Google Cloud](https://docs.cloud.google.com/architecture/landing-zones), [Enterprise foundations blueprint](https://docs.cloud.google.com/architecture/blueprints/security-foundations)
- Ask your agent: "How do I design a landing zone in Google Cloud: resource hierarchy, networking and security foundations?"

## 8. Observe and debug

**What we'd pick:** read logs through the Cloud Logging MCP in your agent. For TPU jobs on GKE, ML Diagnostics workload monitoring flags hangs and slowdowns from the TPU duty cycle. The TPU Monitoring Library gives per-chip metrics from JAX or TorchTPU. Profile with XProf before you tune flags. For a hung or failed TPU job, start with the [ML Workload Debugging Wiki](https://github.com/google/ml-workload-debugging-wiki).

- In this repo: [04-monitoring-observability](./04-monitoring-observability/), with [TPU hardware health](./04-monitoring-observability/README.md#tpu-hardware-health) and [Profile with XProf](./04-monitoring-observability/README.md#profile-with-xprof).
- Official pages: [TPU Monitoring Library](https://docs.cloud.google.com/tpu/docs/tpu-monitoring-library), [ML Diagnostics workload monitoring](https://docs.cloud.google.com/tpu/docs/ml-diagnostics/workload-monitoring), [TPU health monitoring](https://docs.cloud.google.com/tpu/docs/troubleshooting/tpu-health)
- Ask your agent: "How do I monitor TPU hardware health and profile a TPU workload with XProf?"

## 9. Control cost

**What we'd pick:** before you create anything with an accelerator, get its hourly and daily price from `gcp-pricing`. Set a budget, and remember that an alerts-only budget doesn't stop spending. A spend cap budget can, for the services that support it. Delete what you created as soon as the step that needed it is done. In Claude Code, the accelerator guard lists what's still running at the end of each turn.

- In this repo: [05-billing-usage](./05-billing-usage/), and the [accelerator guard](./01-foundational-tools/agentic-coder-setup/cli-agent/README.md#accelerator-guard).
- Official pages: [Create budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets), [Spend cap budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps), [Disable billing with notifications](https://docs.cloud.google.com/billing/docs/how-to/disable-billing-with-notifications)
- Ask your agent: "How do I create a Cloud Billing budget with alerts, and cap spending by disabling billing with Pub/Sub notifications?"

## 10. Run a campus engagement

**What we'd pick:** start with one research group and one real workload. Learn what the code is, which framework it uses, how much data it reads, and the deadline and budget. Run the first job on the smallest slice, with Flex-start or Spot. Meet with the group every two weeks, and set goals for 30, 60 and 90 days. Hand the researchers this repo, starting with section 1.

- Credits: [Google Cloud research credits](https://edu.google.com/programs/credits/research/), up to $5,000, and the [TPU Research Cloud](https://sites.research.google/trc/about/). In the United States, the Google Public Sector Program for Accelerated Research (GPAR) adds pricing for accelerators, early access, training and expert help; [Google Cloud for research](https://cloud.google.com/edu/researchers) describes it.
- Official pages: [Google Cloud for research](https://cloud.google.com/edu/researchers), [Higher education programs](https://cloud.google.com/edu)
- Ask your agent: "Which Google Cloud research credits and higher education programs can academic researchers apply for?"

## Read and watch

- [How to Scale Your Model](https://jax-ml.github.io/scaling-book): the reading order is in [section 2](#2-size-the-job-and-pick-gpu-or-tpu).
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
- **Compute for academic research:** see [section 10](#10-run-a-campus-engagement).

## Repository structure

```
GPS-AI-Infra-Onboarding-Workshop/
├── README.md                          # This file
├── LICENSE
├── CONTRIBUTING.md
│
├── 01-foundational-tools/
│   ├── accelerator-guide/             # Pick, size and checkpoint GPUs and TPUs
│   └── agentic-coder-setup/           # Claude Code, Gemini CLI, Antigravity and Cline setup, smoke test
│
├── 02-core-infrastructure/            # VMs, networking, storage, data pipeline
│   ├── zero-trust-iap-access/         # IAP setup, no-public-IP configs
│   ├── disk-images/                   # Images for GPU and HPC VMs, Packer templates
│   ├── storage/                       # Managed Lustre, GCSFuse, Rapid Cache, Rapid Bucket, Drive sync
│   └── data-pipeline/                 # BigQuery, Dataflow, BigQuery DataFrames for AI/ML
│
├── 03-deploying-workloads/            # Capacity and platforms
│   ├── dws/                           # Dynamic Workload Scheduler, prices, Calendar zone discovery
│   ├── gke/                           # GKE Autopilot and Standard (GPUs, DWS, Spot, RL)
│   ├── cluster-toolkit/               # AI-optimized GKE clusters with DWS
│   ├── cluster-director/              # Managed Slurm clusters
│   ├── compute-engine-Managed Instance Groups/   # Flex-start VMs via MIG resize requests
│   ├── compute-engine-future-reservations/       # Calendar-mode future reservations
│   ├── spot-capacity-advisor/         # Best zone, region and machine for Spot
│   ├── vertex-ai/                     # Vertex AI serverless training (FLEX_START)
│   ├── colab-enterprise/              # GPU notebooks, reservations, DWS patterns
│   └── xpk/                           # Accelerated Processing Kit
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
