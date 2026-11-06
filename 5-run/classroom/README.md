# Classroom: share accelerators across a class

A class or a team that shares a few GPUs or TPUs needs a queue, so nobody holds a chip while their notebook sits idle.

## What we'd pick

- **A class that uses TPUs from notebooks:** [shared-tpu-notebooks](https://github.com/WandLZhang/shared-tpu-notebooks). Each student gets a CPU-only JupyterLab notebook on GKE Autopilot. TPU work leaves the notebook as a Kubernetes Job, and [Kueue](https://kueue.sigs.k8s.io/) queues it for a shared pool of chips. A student holds a chip only while a job runs. In a test run, 300 students shared 64 v5e chips. The run took 12.4 minutes and cost $11.93.
- **A class that needs GPUs:** shared-tpu-notebooks queues TPU jobs only; its README doesn't cover GPUs. On a shared GKE cluster, cap GPUs per team with a Kueue ClusterQueue, as in [Cap GPU use per team with Kueue](../kubernetes/README.md#cap-gpu-use-per-team-with-kueue). For a small class, use [Colab Enterprise](../notebooks/) GPU runtimes.

## Classroom or Workstations for a class?

This page shares a pool of accelerators across a class through a queue. [Workstations for a class](../../1-harness-setup/README.md#workstations-for-a-class) gives each student their own Cloud Workstation with a harness, which an admin builds in their project for the workshop. A course can use both.

## How big a class can get

The shared-tpu-notebooks README gives the limits for project default quota in one region. About 374 notebooks can be open at the same time, under the default `CPUS` quota of 1,500. Up to 512 TPU v5e chips can run at the same time. A class of 30 fits well inside both. The class size isn't the number of chips you need, because each student holds a chip only while a job runs.

## Before class

```bash
git clone https://github.com/WandLZhang/shared-tpu-notebooks.git
cd shared-tpu-notebooks
make preflight PROJECT=<PROJECT_ID>   # read-only, costs nothing
make demo      PROJECT=<PROJECT_ID>   # cluster, hub and one TPU job, about 20 minutes, and it bills
```

`make teardown` lists each cluster, TPU VM and queued resource that remains. If the three lists are empty, nothing bills.

## Official docs

- [GKE Autopilot overview](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Kueue](https://kueue.sigs.k8s.io/)

## Ask your harness

- "How does Kueue share a pool of TPUs across several namespaces with a cohort?"
- "How do I give each student a GPU notebook in Colab Enterprise with idle shutdown?"
