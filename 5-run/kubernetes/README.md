# GKE for AI and ML workloads

Google Kubernetes Engine (GKE) runs containerized training and serving on GPU and TPU nodes. Reach for it when your code already ships as containers, or when you want queued batch jobs and model serving on one cluster.

## What we'd pick

- **Autopilot for the first cluster.** You request GPUs in the Pod spec, and GKE installs the drivers and creates the nodes. GPU Pods use node-based billing, so you pay for the node's hardware plus a management premium.
- **Standard for privileged Pods or node settings that Autopilot blocks.** GPUDirect RDMA on A4 and A3 Ultra works in Autopilot and in Standard.
- **Cluster Toolkit for multi-node GPU training.** Its GKE blueprints create the RDMA networks, GPU node pools and Kueue in one `gcluster deploy`. See [Cluster Toolkit](../cluster-toolkit/).
- **XPK for a quick proof of concept.** Its Python CLI wraps cluster creation (`xpk cluster create`) and job submission (`xpk workload create`). See [XPK](../xpk/).
- **Flex-start for single-node jobs that can wait.** GKE creates flex-start nodes one at a time. They run for up to seven days at Dynamic Workload Scheduler prices, with discounts up to 53%.
- **Flex-start with queued provisioning and Kueue for multi-node jobs that must start together.** GKE allocates every requested node at once, in one zone. Kueue creates and tracks the provisioning requests.
- **No auto-repair on flex-start node pools.** These nodes don't support automatic repair, and a repair evicts every Pod on the node. Create the pool with `--no-enable-autorepair`. Set maintenance windows and exclusions around long runs.
- **Checkpoints in Cloud Storage on a timer.** GKE preempts flex-start nodes when `maxRunDurationSeconds` ends, and Pod retries spend the same clock.
- **Workload Identity Federation for GKE for bucket access.** Autopilot turns it on by default, and Pods need no key files.
- **One GPU before many nodes.** Run the image and the training script on one GPU before you queue a multi-node job.
- **Scale idle serving to zero.** If a model server sits idle for hours, give its Deployment an `autoscaling/v2` HPA with `minReplicas: 0`. Drive it with an External or Object metric, such as a Pub/Sub backlog. This needs GKE 1.37 or later on the control plane and nodes.
- **Cluster Director for MPI jobs under Slurm.** If your group already submits work with `sbatch`, use [Cluster Director](../cluster-director/).

### Spot VMs for AI jobs

Pick Spot for elastic or independent jobs. Tightly gang-scheduled training suits it less, because a synchronous job waits until every lost node comes back.

From the [GKE Spot VMs page](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/spot-vms) (read 2026-11-05):

- After the preemption notice, your Pods get 15 seconds, then critical system Pods get 15 seconds.
- You can extend the total to 120 seconds. Standard node pools need control plane 1.35.0-gke.1171000 or later. Custom ComputeClasses need 1.36.0-gke.3204000 or later.
- PodDisruptionBudgets don't cover Spot reclamation, so expect more disruption than your PDB allows.
- Preemption deletes the data on the node, including Local SSD, so the replacement node stages it again.
- GKE adds the `nvidia.com/gpu=present:NoSchedule` taint to a Spot GPU node pool only when the cluster already has a non-GPU node pool of standard VMs. Create that pool first, or system Pods can land on the GPU nodes.
- Stateful workloads should finish shutting down within 25 seconds to avoid persistent volume corruption.
- Spot VMs don't expire. The older preemptible VMs stop after 24 hours.

For training, finish a checkpoint inside the shutdown window. Otherwise, checkpoint on a timer and accept losing the steps since the last one. More in [Keep a training job alive on Spot](../../capacity/spot-capacity-advisor/README.md#keep-a-training-job-alive-on-spot).

### Fall back across capacity types with custom ComputeClasses

Pick a custom [ComputeClass](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/about-custom-compute-classes) when one workload can run on more than one kind of capacity. It lists node configurations in priority order, for example a reservation, then flex-start, then Spot, then on-demand. When GKE can't create the first configuration, it tries the next one. With active migration, GKE moves workloads back to a preferred configuration when that configuration becomes available. ComputeClasses work on Autopilot, and on Standard from GKE 1.30.3-gke.1451000.

ComputeClasses don't support queued provisioning. For a reservation that falls back to queued provisioning, use the Kueue setup on the [queued provisioning page](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest). It attaches the provisioning check to the DWS flavor only, with `admissionChecksStrategy` and `onFlavors`.

For how Kueue admits a whole job at once and places it by topology, read [Kueue for AI: atomic admission and topology awareness](https://medium.com/google-cloud/kueue-for-ai-the-power-of-atomic-admission-topology-awareness-59c2fd1f86ed).

### RL post-training on GKE

- Start from Google's [verl on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/scaling-rl-verl-gke) tutorial. It runs GRPO on Qwen2.5-32B-Instruct with Ray on A4X, A4 or A3 Ultra. The [NeMo RL on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/nemo-rl-gke) tutorial reuses that cluster.
- On TPU, start from [multi-host RL training with TPUs and SkyRL](https://discuss.google.dev/t/tutorial-multi-host-training-with-tpus-and-skyrl-on-gke/343771) or [verl GRPO on Cloud TPU](https://github.com/verl-project/verl/tree/main/examples/tpu/grpo). The verl example runs a TorchTitan trainer on one TPU slice and a vLLM rollout on another, in a KubeRay cluster.
- Run tool calls, generated code and reward checks in [Agent Sandbox on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/machine-learning/agent-sandbox). It isolates each sandbox with gVisor or microVMs and needs no specific machine type, so CPU nodes can run it next to GPU or TPU training.
- To share GPUs across several RL jobs, try [llm-d RL time-slicing](https://github.com/llm-d-incubation/llm-d-rl-time-slicing). Jobs hand the accelerators over at phase boundaries. Its roadmap lists TPU support as future work. The [launch post](https://cloud.google.com/blog/products/containers-kubernetes/introducing-co-operative-time-slicing-for-rl-in-llm-d) reports aggregate duty cycles of about 40% before and up to 70% after.

## Official docs

| Need | Page |
|---|---|
| GPUs in Autopilot and Standard | [About GPUs in GKE](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/gpus) |
| Pick a mode | [Choose a GKE mode of operation](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/choose-cluster-mode) |
| Request GPUs in Autopilot | [Deploy GPU workloads on Autopilot](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/autopilot-gpus) |
| GPU node pools in Standard | [Run GPUs on Standard node pools](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/gpus) |
| Flex-start | [About flex-start in GKE](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/dws) |
| Multi-node jobs that start together | [Run a large-scale workload with flex-start with queued provisioning](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest) |
| Spot | [Spot VMs](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/spot-vms) |
| Fallback across capacity types | [About custom ComputeClasses](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/about-custom-compute-classes) |
| GPUDirect RDMA | [Create an AI-optimized GKE cluster with A4 or A3 Ultra](https://docs.cloud.google.com/ai-hypercomputer/docs/create/gke-create-a4-a3-ultra) |
| Keep upgrades out of a run | [Maintenance windows and exclusions](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/maintenance-windows-and-exclusions) |
| Scale serving to zero | [Scale GKE workloads to and from zero using HPA](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/scale-to-from-zero-hpa) |
| RL post-training | [Fine-tune and scale reinforcement learning with verl on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/scaling-rl-verl-gke), [NeMo RL on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/nemo-rl-gke) |
| Sandboxed tool calls | [About Agent Sandbox on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/machine-learning/agent-sandbox) |
| Bucket access from Pods | [Workload Identity Federation for GKE](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity) |
| Prices | [Google Kubernetes Engine pricing](https://cloud.google.com/kubernetes-engine/pricing) |

## Talks

From Google Cloud Next '26:

- [What's new for AI on GKE: training, serving and agents](https://www.youtube.com/watch?v=XI726xo0a98)
- [The GKE inference playbook](https://www.youtube.com/watch?v=WQlKo0D3Ofg), for serving LLMs
- [Beyond fine-tuning: training and RL on GKE](https://www.youtube.com/watch?v=GjQJepOZP7o)
- [Stop wasting GPU FLOPs on cold starts](https://www.youtube.com/watch?v=EXQ3AksFXcM)

## Ask your harness

Questions for the Google developer knowledge MCP:

- "How do I choose between GKE Autopilot and Standard for GPU workloads?"
- "How does flex-start work in GKE, and when do I add queued provisioning?"
- "How long do Pods get to shut down when GKE preempts a Spot VM, and how do I extend it?"
- "How do I set fallback priorities across reservations, flex-start and Spot with a custom ComputeClass in GKE?"
- "How do I create a GKE cluster with GPUDirect RDMA on A4 or A3 Ultra?"
- "How do I scale a GKE Deployment to zero with the horizontal Pod autoscaler?"
- "How do I run GRPO reinforcement learning with verl or NeMo RL on GKE?"

## Field notes

### Find out why a GPU Pod is pending

```bash
# Read the Events section for scheduling and scale-up messages
kubectl describe pod POD_NAME

# GPUs and accelerator type on each node
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,TYPE:.metadata.labels.cloud\.google\.com/gke-accelerator'

# Kueue admission and queued provisioning requests
kubectl get workloads -A
kubectl get provisioningrequests -A
```

### Related pages in this repo

- [DWS](../../capacity/dws/) compares Flex-start and calendar mode across products, lists prices, and covers [data residency](../../capacity/dws/README.md#5-data-residency--compliance-considerations).
- [Spot Capacity Advisor](../../capacity/spot-capacity-advisor/) ranks zones for Spot.
- [Storage](../../infrastructure/storage/README.md) compares Cloud Storage FUSE, Rapid Cache, Rapid Bucket and Managed Lustre for training data.
- [Monitoring](../../monitoring/) covers the GKE AI/ML dashboards.
