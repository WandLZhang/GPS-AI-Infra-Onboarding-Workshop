# AI Infrastructure Onboarding Workshop

Hands-on guides, scripts and labs for running AI and HPC workloads on Google Cloud GPUs and TPUs, from your first project to a profiled training job. Built by Google Public Sector for students, researchers and engineers.

## Start here

Run the [agentic coder setup](./01-foundational-tools/agentic-coder-setup/). It builds a Cloud Workstation with two coding agents, agy and Claude Code. They read the current Google Cloud docs, price machines from the live pricing pages, read your logs and install any other tool a task needs. Then find your task below.

## Where to look

### [01 Foundational tools](./01-foundational-tools/)

| I want to | Go to |
|---|---|
| See what Google Cloud offers for AI infrastructure | [The future of AI infrastructure](https://www.youtube.com/watch?v=PJQPMv8TqLA) and [AI Hypercomputer: resilient AI infrastructure at scale](https://www.youtube.com/watch?v=cvpasuzUB0Q) (Next '26) |
| Set up a coding agent with docs and logging MCP servers | [agentic-coder-setup](./01-foundational-tools/agentic-coder-setup/) |
| Ask my agent for the current official answer | [Ask your agent](./01-foundational-tools/agentic-coder-setup/README.md#ask-your-agent) |
| Get a machine type's price today | [gcp-pricing](https://github.com/WandLZhang/gcp-pricing-scraper): `gcp-pricing accelerator --filter <machine-type>` or `gcp-pricing tpu --filter <generation>` |
| Learn how accelerators behave | [How to Scale Your Model](https://jax-ml.github.io/scaling-book): the parts on rooflines, TPUs, sharded matmuls and transformers. GPU users add the GPU part. |
| Pick a GPU or TPU | [accelerator-guide](./01-foundational-tools/accelerator-guide/) |
| Compare TPU generations | [Cloud TPU generations](./01-foundational-tools/accelerator-guide/README.md#cloud-tpu-generations) |
| Learn what's new in TPUs | [Inside the 8th-generation TPU](https://cloud.google.com/blog/products/compute/tpu-8t-and-tpu-8i-technical-deep-dive), [the new Cloud TPU experience](https://www.youtube.com/watch?v=fUELeEaTLVs) (Next '26) and [Ironwood at Hot Chips 2025](https://www.youtube.com/watch?v=Zy3LfsAxc64) |
| Run double-precision science code | [FP64 science codes](./01-foundational-tools/accelerator-guide/README.md#double-precision-fp64-science-codes) |
| Fit a model to the TPU matrix unit | [Fit matmuls to the MXU](./01-foundational-tools/accelerator-guide/README.md#tpu-fit-matmuls-to-the-mxu) |
| Estimate how many chips and how long | [Size a job](./01-foundational-tools/accelerator-guide/README.md#size-a-job-before-you-ask-for-chips) |
| Port a PyTorch model to TPU | [PyTorch on TPU](https://docs.cloud.google.com/tpu/docs/pytorch-on-tpu) (TorchTPU, vLLM-TorchTPU, SGLang-TorchTPU and TorchTitan) and the [TorchTPU docs](https://torchtpu.readthedocs.io/en/latest/) |
| Learn how TorchTPU works | The [launch post](https://cloud.google.com/blog/topics/ai-infrastructure/torchtpu-is-now-open-source-run-native-pytorch-on-tpus), deep dives on [vLLM and SGLang](https://developers.googleblog.com/announcing-new-vllm-and-sglang-inference-engines-on-tpu/) and [TorchTitan](https://developers.googleblog.com/integrating-torchtpu-into-torchtitan-and-optimizing-models-for-tpu/), and the [paper](https://arxiv.org/abs/2610.24161) |
| Fine-tune or serve with TorchTPU and Ray on GKE | Google's [fine-tuning](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/train-models-tpu-ray-torchtpu) and [serving](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/serve-llm-tpu-ray-torchtpu) tutorials |
| Port a model to TPU and beat the GPU baseline | [Port a model to TPU](./01-foundational-tools/accelerator-guide/README.md#8-port-a-model-to-tpu): what worked on our ports, in order |
| Port a PyTorch model with a coding agent | [TPU agent suite](https://github.com/google-pytorch/tpu-agent-suite) (Preview, Claude Code and Antigravity) |
| Turn a JAX, CUDA or PyTorch kernel into a Pallas kernel | [MaxKernel](https://github.com/AI-Hypercomputer/accelerator-agents/tree/main/maxkernel), which runs as a [Claude Code plugin](https://github.com/AI-Hypercomputer/accelerator-agents/blob/main/maxkernel/claude-code/README.md) ([paper](https://arxiv.org/abs/2609.04523)) |

### [02 Core infrastructure](./02-core-infrastructure/)

| I want to | Go to |
|---|---|
| Build VM images and lock down networking | [disk-images](./02-core-infrastructure/disk-images/), [zero-trust-iap-access](./02-core-infrastructure/zero-trust-iap-access/) |
| Load model weights fast, and pick storage | [storage](./02-core-infrastructure/storage/), [Design storage for AI and ML workloads](https://docs.cloud.google.com/architecture/ai-ml/storage-for-ai-ml) |
| Move ML data with BigQuery and Dataflow | [data-pipeline](./02-core-infrastructure/data-pipeline/) |

### [03 Deploying workloads](./03-deploying-workloads/)

| I want to | Go to |
|---|---|
| Choose between on-demand, Spot, Flex-start, Calendar mode and reservations | [Capacity vs. deployment](./03-deploying-workloads/README.md) |
| Get Flex-start or Calendar mode capacity | [dws](./03-deploying-workloads/dws/) |
| See which machine types take Flex-start and Calendar mode | [Ask your agent](./01-foundational-tools/agentic-coder-setup/README.md#ask-your-agent): "Which GPU and TPU machine types support Dynamic Workload Scheduler flex-start and calendar mode?" |
| See which quota each capacity option uses | [Quota and pricing](./03-deploying-workloads/dws/README.md#7-quota--pricing) |
| See current prices by machine type | [Prices by machine type](./03-deploying-workloads/dws/README.md#prices-by-machine-type) |
| Find when and where I can book Calendar mode | [Check Calendar availability](./03-deploying-workloads/dws/README.md#check-calendar-availability-before-you-book), [`discover-calendar-zones.py`](./03-deploying-workloads/dws/discover-calendar-zones.py) |
| Book capacity for a future date | [Future reservations](./03-deploying-workloads/compute-engine-future-reservations/) |
| Get Flex-start VMs through managed instance groups | [Managed Instance Groups](./03-deploying-workloads/compute-engine-Managed%20Instance%20Groups/) |
| Find which zones offer a GPU or TPU | [GPU regions and zones](https://cloud.google.com/compute/docs/regions-zones/gpu-regions-zones), [TPU regions and zones](https://docs.cloud.google.com/tpu/docs/regions-zones) |
| Find the Spot zone most likely to land | [spot-capacity-advisor](./03-deploying-workloads/spot-capacity-advisor/) |
| Spray requests across zones and poll for capacity | [spot-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-spray.sh), [flex-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-spray.sh), [flex-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-poll.sh), [calendar-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/calendar-poll.sh), [spot-obtainability-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-obtainability-poll.sh) |
| Keep a training job alive on Spot | [Training on Spot](./03-deploying-workloads/spot-capacity-advisor/README.md#keep-a-training-job-alive-on-spot), [Spot VMs on GKE](./03-deploying-workloads/gke/README.md#spot-vms-for-ai-jobs) |
| Start from a working TPU recipe | [tpu-recipes](https://github.com/AI-Hypercomputer/tpu-recipes), including vLLM-TorchTPU serving on [Ironwood](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/ironwood/vLLM/vLLM-TorchTPU) and [Trillium](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/trillium/vLLM/vLLM-TorchTPU/Gemma4-26B) |
| Start from a working GPU recipe | [gpu-recipes](https://github.com/AI-Hypercomputer/gpu-recipes) |
| Train an LLM in JAX on TPUs or GPUs | [MaxText](https://maxtext.readthedocs.io/en/latest/) |
| Start from a GKE reference architecture for training or inference | [accelerated-platforms](https://github.com/GoogleCloudPlatform/accelerated-platforms) |
| Run GPU and TPU workloads on GKE | [gke](./03-deploying-workloads/gke/), [What's new for AI on GKE](https://www.youtube.com/watch?v=XI726xo0a98) (Next '26) |
| Fall back across capacity types on GKE | [Custom ComputeClasses](./03-deploying-workloads/gke/README.md#fall-back-across-capacity-types-with-custom-computeclasses) |
| Queue jobs on GKE with all-or-nothing admission | [Kueue for AI: atomic admission and topology awareness](https://medium.com/google-cloud/kueue-for-ai-the-power-of-atomic-admission-topology-awareness-59c2fd1f86ed) |
| Serve LLMs on GKE | [The GKE inference playbook](https://www.youtube.com/watch?v=WQlKo0D3Ofg) (Next '26) |
| Run RL post-training | [RL post-training on GKE](./03-deploying-workloads/gke/README.md#rl-post-training-on-gke), [Beyond fine-tuning: training and RL on GKE](https://www.youtube.com/watch?v=GjQJepOZP7o) (Next '26) |
| Cut GPU cold starts | [Stop wasting GPU FLOPs on cold starts](https://www.youtube.com/watch?v=EXQ3AksFXcM) (Next '26) |
| Build an AI-optimized GKE cluster | [cluster-toolkit](./03-deploying-workloads/cluster-toolkit/) |
| Run a managed Slurm cluster | [cluster-director](./03-deploying-workloads/cluster-director/) |
| Run TPU training on GKE from the command line | [xpk](./03-deploying-workloads/xpk/) |
| Train on Vertex AI without a cluster | [vertex-ai](./03-deploying-workloads/vertex-ai/) |
| Use GPU notebooks | [colab-enterprise](./03-deploying-workloads/colab-enterprise/) |

### [04 Monitoring and observability](./04-monitoring-observability/)

| I want to | Go to |
|---|---|
| Watch jobs with GKE dashboards, TPU metrics and alerts | [04-monitoring-observability](./04-monitoring-observability/) |
| See why a TPU job died | [TPU hardware health](./04-monitoring-observability/README.md#tpu-hardware-health) |
| Diagnose a hung or failed TPU job with a coding agent | [ML Workload Debugging Wiki](https://github.com/google/ml-workload-debugging-wiki) (Claude Code and Antigravity; [doc](https://docs.cloud.google.com/tpu/docs/agent-wiki)) |
| Profile a job with XProf | [XProf](./04-monitoring-observability/README.md#profile-with-xprof) |
| Profile vLLM serving on TPU | [`tpu_profiling.py`](https://github.com/vllm-project/tpu-inference/blob/bec31b7cce132ed995daed8d39321b943d15be73/examples/tpu_profiling.py) in tpu-inference |

### [05 Billing and usage](./05-billing-usage/)

| I want to | Go to |
|---|---|
| Set budgets and alerts | [billing](./05-billing-usage/) |
| Raise a quota | [Request a quota increase](https://cloud.google.com/docs/quotas/help/request_increase) |
| Get compute for academic research | [TPU Research Cloud](https://sites.research.google/trc/about/), [Google Cloud research credits](https://cloud.google.com/edu/researchers) |

### Related repos

From the organization down to a single demo:

| I want to | Go to |
|---|---|
| Build a landing zone for a research organization | [fast-science-0-stellar-engine](https://github.com/WandLZhang/fast-science-0-stellar-engine) |
| Give each researcher a project on that landing zone | [fast-science-1-researcher-lab](https://github.com/WandLZhang/fast-science-1-researcher-lab) |
| Deploy a researcher's workload into that project | [fast-science-2-workload-catalog](https://github.com/WandLZhang/fast-science-2-workload-catalog) |
| Run one Slurm cluster across regions, with DWS and Spot partitions | [slurm-multi-region-gpu-public](https://github.com/WandLZhang/slurm-multi-region-gpu-public) |
| Let a class share TPUs through a queue | [shared-tpu-notebooks](https://github.com/WandLZhang/shared-tpu-notebooks) |
| Burst protein folding across GPU and TPU Slurm partitions | [ai-infra-demo-proteins](https://github.com/WandLZhang/ai-infra-demo-proteins) |
| Run a campus demo from a talk track | [ai-infra-demo-proteins-template](https://github.com/WandLZhang/ai-infra-demo-proteins-template) |
| Serve and inspect LLMs on TPU | [tpu-mech-interp](https://github.com/WandLZhang/tpu-mech-interp) |

### Get help

| I want to | Go to |
|---|---|
| Open a support case | [Google Cloud support](https://cloud.google.com/support) |
| Ask other developers | [Google Developer forums](https://discuss.google.dev) |

> **Disclaimer:** This repository is for demonstration and enablement. Always follow your organization's security policies and review scripts before running them in production environments.
