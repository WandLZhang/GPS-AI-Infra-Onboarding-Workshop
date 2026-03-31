# Monitoring & Observability for AI Workloads

> A comprehensive guide to monitoring, observability, and performance profiling for AI/ML workloads on Google Cloud — covering TPU observability in the GKE AI/ML UI, proactive alerting, XProf performance profiling, and the TPU Monitoring Library.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [TPU Observability — GKE AI/ML UI](#2-tpu-observability--gke-aiml-ui)
3. [TPU Metrics Reference](#3-tpu-metrics-reference)
4. [Recommended Proactive Alerts](#4-recommended-proactive-alerts)
5. [Application Logs Access](#5-application-logs-access)
6. [XProf — Performance Profiling & Visualization](#6-xprof--performance-profiling--visualization)
7. [TPU Monitoring Library (LibTPU SDK)](#7-tpu-monitoring-library-libtpu-sdk)
8. [Enabling System Metrics on GKE](#8-enabling-system-metrics-on-gke)
9. [Best Practices](#9-best-practices)
10. [Troubleshooting](#10-troubleshooting)
11. [References](#11-references)

---

## 1. Overview

Monitoring and observability are critical for operating AI/ML workloads at scale on Google Cloud. Training jobs that run on TPUs and GPUs for days or weeks require continuous visibility into hardware health, workload performance, and resource utilization to ensure efficiency, minimize wasted compute, and quickly diagnose failures.

Google Cloud provides a layered observability stack for AI workloads:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 AI Workload Observability Stack                         │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 1: GKE AI/ML UI — Single-Pane View                      │   │
│  │  ├── JobSet Monitoring Dashboard (status, goodput, logs)        │   │
│  │  ├── TPU Node Pool Status Dashboard (health, availability)     │   │
│  │  └── Observability Tab (accelerator metrics, CPU, memory)      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 2: Cloud Monitoring — Metrics & Alerts                   │   │
│  │  ├── GKE System Metrics (TPU duty cycle, memory, utilization)  │   │
│  │  ├── JobSet Metrics (goodput, TBI, TTR, scheduling)            │   │
│  │  ├── Node/Node Pool Health Metrics (status, availability)      │   │
│  │  └── Proactive Alert Policies (PromQL-based)                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 3: XProf — Deep Performance Profiling                    │   │
│  │  ├── Trace Viewer (operation timeline on hardware units)        │   │
│  │  ├── HLO Op Profile (time breakdown by operation)              │   │
│  │  ├── Memory Viewer (allocation visualization)                  │   │
│  │  ├── Roofline Analysis (compute vs memory bound)               │   │
│  │  └── Graph Viewer (full HLO graph)                             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 4: TPU Monitoring Library — Hardware-Level Telemetry     │   │
│  │  ├── LibTPU SDK Metrics (duty cycle, HBM, network latency)    │   │
│  │  ├── TPU-Z Diagnostics (core state, hang detection)            │   │
│  │  └── HLO Execution Timing & Queue Monitoring                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### When to Use Each Layer

| Layer | Use Case | Audience |
|---|---|---|
| **GKE AI/ML UI** | Quick visual health check of JobSets and node pools | ML Engineers, Platform Engineers |
| **Cloud Monitoring** | Ongoing monitoring, alerting, and SLO tracking | Platform Engineers, SREs |
| **XProf** | Deep performance optimization of model training | ML Researchers, Performance Engineers |
| **TPU Monitoring Library** | Hardware-level debugging and real-time telemetry | ML Researchers, TPU Specialists |

---

## 2. TPU Observability — GKE AI/ML UI

The GKE AI/ML UI in the Google Cloud console provides a **single-pane view** for health and performance metrics of your AI workloads. It consolidates JobSet monitoring, node pool health, accelerator utilization, and application logs in one place.

### 2.1 JobSet Monitoring Dashboard

The JobSet monitoring dashboard provides comprehensive information about the health and performance of your training JobSets.

**Access the dashboard:**
- Navigate to: **Google Cloud Console → Kubernetes Engine → AI/ML → Jobs**
- Direct URL: [https://console.cloud.google.com/kubernetes/aiml/jobs](https://console.cloud.google.com/kubernetes/aiml/jobs)

The dashboard includes **three tabs**:

| Tab | Status | Description |
|---|---|---|
| **Overview** | GA | Shows JobSet infrastructure — status, replica readiness, replica state. Includes goodput metrics and infrastructure metrics (CPU, GPU, TPU, memory, storage). |
| **Training Goodput** | Preview | Comprehensive view of end-to-end operational efficiency — node pool health and workload execution. Provides **scheduling goodput** and **proxy runtime goodput** scores. |
| **Cloud ML Goodput** | Preview | Detailed insight into JobSet goodput including badput breakdowns at the application layer. Requires integration with the [Goodput Measurement API](https://github.com/AI-Hypercomputer/ml-goodput-measurement). |

```
┌─────────────────────────────────────────────────────────────────────────┐
│              JobSet Monitoring Dashboard                                │
│                                                                         │
│  ┌─────────────────────┐ ┌──────────────────┐ ┌─────────────────────┐  │
│  │     Overview Tab     │ │ Training Goodput │ │  Cloud ML Goodput   │  │
│  │                      │ │      Tab         │ │       Tab           │  │
│  │ • JobSet status      │ │                  │ │                     │  │
│  │ • Replica readiness  │ │ • Scheduling     │ │ • Application-layer │  │
│  │ • Replica state      │ │   goodput        │ │   goodput           │  │
│  │ • TPU/GPU metrics    │ │ • Proxy runtime  │ │ • Badput breakdown  │  │
│  │ • CPU/Memory         │ │   goodput        │ │ • Requires Goodput  │  │
│  │ • Storage metrics    │ │ • Node pool      │ │   Measurement API   │  │
│  │                      │ │   health         │ │   integration       │  │
│  └─────────────────────┘ └──────────────────┘ └─────────────────────┘  │
│                                                                         │
│  Features across all tabs:                                              │
│  • View child Jobs inside a JobSet                                      │
│  • Access logs, events, and visualizations                              │
│  • Drill down into individual pod status                                │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Viewing JobSets

To see your AI/ML workloads in the Google Cloud console:

1. Go to **Kubernetes Engine → AI/ML → Jobs**
2. Select your cluster and namespace
3. Click on a JobSet to see its details, child Jobs, and associated pods
4. Use the **Observability** section for metrics and the **Logs** tab for container logs

#### Monitoring JobSet Scheduling

You can monitor which node pools and nodes your JobSets are using:

```promql
# Node pools where each JobSet has scheduled Pods
avg_over_time(
  kubernetes_io:jobset_assigned_node_pools{
    monitored_resource="k8s_entity",
    cluster_name="CLUSTER_NAME"
  }[${__interval}]
)

# JobSets scheduled on a specific node pool
avg_over_time(
  kubernetes_io:node_pool_assigned_jobsets{
    monitored_resource="k8s_node_pool",
    cluster_name="CLUSTER_NAME",
    node_pool_name="NODE_POOL_NAME"
  }[${__interval}]
)
```

### 2.2 TPU Node Pool Status Dashboard

The TPU Node Pool Status dashboard provides insights into the health of your multi-host TPU node pools.

**Access the dashboard:**
- Navigate to: **Google Cloud Console → Monitoring → Dashboards → Integration → GKE TPU Node Pool Status**
- Direct URL: [https://console.cloud.google.com/monitoring/dashboards/integration/gke.gke-tpu-node-pool-status](https://console.cloud.google.com/monitoring/dashboards/integration/gke.gke-tpu-node-pool-status)

> **Prerequisite**: The TPU dashboard is populated only if you have [system metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics#system-metrics) enabled in your GKE cluster.

The dashboard shows:
- **Node pool status** (Provisioning, Running, Error, Reconciling, Stopping)
- **Node pool availability** for multi-host TPU node pools
- **Node conditions** (Ready, DiskPressure, MemoryPressure)
- **TPU utilization** across node pools

### 2.3 GKE Observability Tab

The GKE Clusters page also provides TPU observability metrics:

1. Go to **Google Cloud Console → Kubernetes Engine → Clusters**
2. Select your cluster
3. Click the **Observability** tab
4. Under **Accelerators → TPU**, view:
   - TPU duty cycle
   - TPU memory usage
   - TensorCore utilization
   - Memory bandwidth utilization

> **Note**: If you created a GKE cluster with XPK, use the Google Cloud console URLs provided in the XPK output to track cluster and workload metrics.

---

## 3. TPU Metrics Reference

### 3.1 Runtime Metrics

Available in GKE version **1.27.4-gke.900** or later for TPU workloads using JAX **0.4.14+** with `containerPort: 8431`.

| Metric | Schema | Description | Sampling |
|---|---|---|---|
| `accelerator/duty_cycle` | `k8s_node`, `k8s_container` | Percentage of time TensorCores were actively processing (60s window). Higher = better utilization. | 60 seconds |
| `accelerator/memory_used` | `k8s_node`, `k8s_container` | Accelerator memory allocated in bytes. | 60 seconds |
| `accelerator/memory_total` | `k8s_node`, `k8s_container` | Total accelerator memory in bytes. | 60 seconds |

**Full metric names:**

```
# Container-level
kubernetes.io/container/accelerator/duty_cycle
kubernetes.io/container/accelerator/memory_used
kubernetes.io/container/accelerator/memory_total

# Node-level
kubernetes.io/node/accelerator/duty_cycle
kubernetes.io/node/accelerator/memory_used
kubernetes.io/node/accelerator/memory_total
```

### 3.2 Host Metrics

Available in GKE version **1.28.1-gke.1066000** or later.

| Metric | Schema | Description | Sampling |
|---|---|---|---|
| `accelerator/tensorcore_utilization` | `k8s_node`, `k8s_container` | Percentage of TensorCore utilized (MXU + vector unit operations vs. peak capability). | 60 seconds |
| `accelerator/memory_bandwidth_utilization` | `k8s_node`, `k8s_container` | Percentage of accelerator memory bandwidth in use. | 60 seconds |

**Full metric names:**

```
# Container-level
kubernetes.io/container/accelerator/tensorcore_utilization
kubernetes.io/container/accelerator/memory_bandwidth_utilization

# Node-level
kubernetes.io/node/accelerator/tensorcore_utilization
kubernetes.io/node/accelerator/memory_bandwidth_utilization
```

### 3.3 Node & Node Pool Health Metrics

Available in GKE version **1.32.1-gke.1357001** or later.

| Metric | Resource Type | Description |
|---|---|---|
| `kubernetes.io/node/status_condition` | `k8s_node` | Reports node conditions: `Ready`, `DiskPressure`, `MemoryPressure`. Status: `True`, `False`, `Unknown`. |
| `kubernetes.io/node_pool/status` | `k8s_node_pool` | Node pool status: `Provisioning`, `Running`, `Error`, `Reconciling`, `Stopping`. Multi-host TPU pools only. |
| `kubernetes.io/node_pool/multi_host/available` | `k8s_node_pool` | Whether a multi-host TPU node pool is available. |
| `kubernetes.io/node/interruption_count` | `k8s_node` | Count of node interruptions for calculating MTBI. |

#### PromQL Queries for Node Health

```promql
# Check if a specific node is Ready
kubernetes_io:node_status_condition{
  monitored_resource="k8s_node",
  cluster_name="CLUSTER_NAME",
  node_name="NODE_NAME",
  condition="Ready",
  status="True"
}

# Find nodes that are NOT Ready
kubernetes_io:node_status_condition{
  monitored_resource="k8s_node",
  cluster_name="CLUSTER_NAME",
  condition="Ready",
  status="False"
}

# Find nodes with non-Ready conditions (DiskPressure, MemoryPressure, etc.)
kubernetes_io:node_status_condition{
  monitored_resource="k8s_node",
  cluster_name="CLUSTER_NAME",
  condition!="Ready",
  status="True"
}

# Fleet-wide node status overview
avg by (condition, status)(
  avg_over_time(
    kubernetes_io:node_status_condition{
      monitored_resource="k8s_node"
    }[${__interval}]
  )
)
```

#### PromQL Queries for Node Pool Status

```promql
# Verify a specific node pool has Running status
kubernetes_io:node_pool_status{
  monitored_resource="k8s_node_pool",
  cluster_name="CLUSTER_NAME",
  node_pool_name="NODE_POOL_NAME",
  status="Running"
}

# Count node pools grouped by status
count by (status)(
  count_over_time(
    kubernetes_io:node_pool_status{
      monitored_resource="k8s_node_pool"
    }[${__interval}]
  )
)
```

### 3.4 JobSet Metrics

| Metric | Type | Description |
|---|---|---|
| `kubernetes.io/jobset/scheduling_goodput` | GAUGE, DOUBLE | Fraction of time all required resources are available for the training JobSet. |
| `kubernetes.io/jobset/proxy_runtime_goodput` | GAUGE, DOUBLE | Fraction of time all required accelerators are productive (duty_cycle > 10). |
| `kubernetes.io/jobset/times_between_interruptions` | GAUGE, DISTRIBUTION | Distribution of durations between interruptions (TBI). |
| `kubernetes.io/jobset/times_to_recover` | GAUGE, DISTRIBUTION | Distribution of recovery period durations (TTR). |
| `kubernetes.io/jobset/uptime` | GAUGE | Time in seconds the JobSet has been up. |
| `kubernetes.io/jobset/assigned_node_pools` | GAUGE | Node pools where a JobSet has scheduled Pods. |
| `kubernetes.io/jobset/assigned_nodes` | GAUGE | Nodes where a JobSet has scheduled Pods. |

#### PromQL Queries for JobSet Goodput

```promql
# Scheduling goodput for a specific JobSet
avg_over_time(
  kubernetes_io:jobset_scheduling_goodput{
    monitored_resource="k8s_entity",
    entity_type="jobset",
    entity_name=~"my-training-.*",
    cluster_name="CLUSTER_NAME"
  }[${__interval}]
)

# Proxy runtime goodput for a specific JobSet
avg_over_time(
  kubernetes_io:jobset_proxy_runtime_goodput{
    monitored_resource="k8s_entity",
    entity_type="jobset",
    entity_name=~"my-training-.*",
    cluster_name="CLUSTER_NAME"
  }[${__interval}]
)
```

### 3.5 Mean Time Between Interruptions (MTBI)

Calculate the 7-day MTBI for TPU nodes in a cluster:

```promql
sum(
  count_over_time(
    kubernetes_io:node_memory_total_bytes{
      monitored_resource="k8s_node",
      node_name=~"gke-tpu.*|gk3-tpu.*",
      cluster_name="CLUSTER_NAME"
    }[7d]
  )
)
/
sum(
  sum_over_time(
    kubernetes_io:node_interruption_count{
      monitored_resource="k8s_node",
      node_name=~"gke-tpu.*|gk3-tpu.*",
      cluster_name="CLUSTER_NAME"
    }[7d]
  )
)
```

> This counts 60-second memory samples as a proxy for uptime in minutes, then divides by total interruptions.

---

## 4. Recommended Proactive Alerts

Set up the following alert policies in Cloud Monitoring to proactively detect issues with your AI workloads. Navigate to **Cloud Monitoring → Alerting → Create Policy** to configure these.

### 4.1 Node Health Alerts

| Alert | PromQL Condition | Threshold | Severity |
|---|---|---|---|
| **TPU Node Not Ready** | `kubernetes_io:node_status_condition{condition="Ready", status="False", node_name=~"gke-tpu.*"}` | Any data point > 0 for 5 min | Critical |
| **Node DiskPressure** | `kubernetes_io:node_status_condition{condition="DiskPressure", status="True"}` | Any data point > 0 for 5 min | Warning |
| **Node MemoryPressure** | `kubernetes_io:node_status_condition{condition="MemoryPressure", status="True"}` | Any data point > 0 for 5 min | Warning |

### 4.2 Node Pool Health Alerts

| Alert | PromQL Condition | Threshold | Severity |
|---|---|---|---|
| **Node Pool Error** | `kubernetes_io:node_pool_status{status="Error"}` | Any data point > 0 for 5 min | Critical |
| **Multi-Host Node Pool Unavailable** | `kubernetes_io:node_pool_multi_host_available == 0` | Absent for 10 min | Critical |
| **Node Pool Stuck Provisioning** | `kubernetes_io:node_pool_status{status="Provisioning"}` | Continuous for 30 min | Warning |

### 4.3 TPU Utilization Alerts

| Alert | PromQL Condition | Threshold | Severity |
|---|---|---|---|
| **Low TPU Duty Cycle** | `avg(kubernetes_io:node_accelerator_duty_cycle{node_name=~"gke-tpu.*"})` | < 10% for 15 min | Warning |
| **High HBM Utilization** | `kubernetes_io:node_accelerator_memory_used / kubernetes_io:node_accelerator_memory_total` | > 95% for 10 min | Warning |
| **Zero TensorCore Utilization** | `kubernetes_io:node_accelerator_tensorcore_utilization` | == 0 for 10 min (during active workload) | Warning |

### 4.4 JobSet Health Alerts

| Alert | PromQL Condition | Threshold | Severity |
|---|---|---|---|
| **Low Scheduling Goodput** | `kubernetes_io:jobset_scheduling_goodput` | < 0.5 for 30 min | Warning |
| **Low Runtime Goodput** | `kubernetes_io:jobset_proxy_runtime_goodput` | < 0.3 for 30 min | Warning |
| **Frequent JobSet Interruptions** | `rate(kubernetes_io:jobset_times_between_interruptions_count[1h])` | > 3 interruptions/hour | Critical |

### Creating an Alert Policy (Example)

```bash
# Create a notification channel (email)
gcloud monitoring channels create \
    --display-name="AI Platform Alerts" \
    --type=email \
    --channel-labels=email_address=team@example.com \
    --project=$PROJECT_ID

# List channels to get the channel ID
gcloud monitoring channels list --project=$PROJECT_ID --format="value(name)"
```

Then in the Cloud Console:

1. Go to **Monitoring → Alerting → Create Policy**
2. Click **Add Condition → MQL or PromQL**
3. Enter the PromQL query from the table above
4. Set the **Duration** and **Threshold**
5. Add your notification channel
6. Set the alert name and documentation (include runbook links)
7. Click **Create Policy**

---

## 5. Application Logs Access

### 5.1 Logs from GKE AI/ML UI

Access application logs directly from the JobSet monitoring dashboard:

1. Go to **Kubernetes Engine → AI/ML → Jobs**
2. Select a JobSet
3. Click the **Logs** tab to view container logs
4. Use the **Events** tab for Kubernetes events related to the JobSet

### 5.2 kubectl Log Commands

```bash
# View logs for a specific pod
kubectl logs <pod-name>

# Follow logs in real-time
kubectl logs -f <pod-name>

# View logs for all pods in a JobSet
kubectl logs -l jobset.sigs.k8s.io/jobset-name=my-training-job

# View logs for a specific container in a multi-container pod
kubectl logs <pod-name> -c <container-name>

# View previous container logs (after a restart)
kubectl logs <pod-name> --previous

# View logs with timestamps
kubectl logs <pod-name> --timestamps=true

# Tail the last 100 lines
kubectl logs <pod-name> --tail=100
```

### 5.3 Cloud Logging Queries

Access logs in Cloud Logging with these filters:

```
# All logs for a specific JobSet
resource.type="k8s_container"
resource.labels.cluster_name="CLUSTER_NAME"
labels."k8s-pod/jobset_sigs_k8s_io/jobset-name"="my-training-job"

# Error-level logs for TPU workloads
resource.type="k8s_container"
resource.labels.cluster_name="CLUSTER_NAME"
resource.labels.namespace_name="default"
severity>=ERROR

# Node-level system logs for TPU nodes
resource.type="k8s_node"
resource.labels.cluster_name="CLUSTER_NAME"
resource.labels.node_name=~"gke-.*tpu.*"
```

Navigate to: **Google Cloud Console → Logging → Logs Explorer** or use the direct URL:
[https://console.cloud.google.com/logs/query](https://console.cloud.google.com/logs/query)

---

## 6. XProf — Performance Profiling & Visualization

**XProf** (sometimes referred to as XPerf) is the core performance profiling tool for AI/ML workloads on Cloud TPU. It is available from the [OpenXLA/XProf](https://github.com/openxla/xprof) GitHub repository and supports profiling of all XLA-based frameworks including **JAX**, **PyTorch XLA**, and **TensorFlow/Keras**.

XProf is deeply integrated into both the JAX and TPU ecosystems, exploiting hardware features specifically designed for seamless profile collection with **less than 1% overhead**. This makes profiling a lightweight, iterative part of development.

### 6.1 Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| `gcloud` CLI | Google Cloud operations | [Install](https://cloud.google.com/sdk/docs/install) |
| `python3` (3.10+) | Run profiling tools | Pre-installed on most systems |
| `pip` | Install Python packages | Included with Python |
| GCS bucket | Store captured profiles | `gcloud storage buckets create gs://BUCKET_NAME` |

### 6.2 Installation

#### Option A: Install XProf + TensorBoard (Local/TPU VM)

```bash
# Create a virtual environment
python3 -m venv ~/xprof-env
source ~/xprof-env/bin/activate

# Install XProf and TensorBoard with the profile plugin
pip install xprof
pip install tensorboard tensorboard_plugin_profile
```

#### Option B: Install cloud-diagnostics-xprof (Recommended for Google Cloud)

The `cloud-diagnostics-xprof` library (aka **XProfiler**) provides a streamlined experience for hosting TensorBoard and visualizing profiles on Google Cloud.

```bash
# Create a virtual environment
python3 -m venv ~/xprof-env
source ~/xprof-env/bin/activate

# Install cloud-diagnostics-xprof (installs all XProf + TensorBoard dependencies)
pip install cloud-diagnostics-xprof
```

**Advantages of cloud-diagnostics-xprof over local TensorBoard:**

| Feature | Local TensorBoard | cloud-diagnostics-xprof |
|---|---|---|
| Setup complexity | Manual pip installs | Single `pip install` |
| Profile storage | Local disk (lost after run) | Cloud Storage (persistent) |
| Loading speed for large profiles | Slow (local resources) | Fast (dedicated VM/pod) |
| Sharing with team | Not built-in | Shareable URL |
| On-demand profiling | Manual | Built-in CLI + UI support |
| GKE integration | None | Native GKE pod hosting |

### 6.3 Capturing Profiles

There are two methods for capturing profiles:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Profile Capture Methods                               │
│                                                                         │
│  ┌─────────────────────────────┐  ┌──────────────────────────────────┐ │
│  │  Programmatic Capture       │  │  On-Demand Capture               │ │
│  │                             │  │                                  │ │
│  │  • Annotate model code      │  │  • Start XProf server in code   │ │
│  │  • Capture specific steps   │  │  • Trigger via TensorBoard UI   │ │
│  │  • API-based start/stop     │  │    or XProfiler CLI             │ │
│  │  • Context manager based    │  │  • Ad hoc profiling             │ │
│  │  • Best for planned         │  │  • Best for diagnosing issues   │ │
│  │    profiling                │  │    during runs                  │ │
│  └─────────────────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Programmatic Capture — JAX

```python
import jax
import jax.numpy as jnp

# Option 1: Using jax.profiler context manager
with jax.profiler.trace("gs://my-bucket/profiles/run-name"):
    # Your training steps to profile
    for step in range(3):
        result = train_step(params, batch)
        result.block_until_ready()

# Option 2: Using start/stop trace
jax.profiler.start_trace("gs://my-bucket/profiles/run-name")
for step in range(3):
    result = train_step(params, batch)
    result.block_until_ready()
jax.profiler.stop_trace()
```

#### Programmatic Capture — PyTorch XLA

```python
import torch_xla.debug.profiler as xp

# Start the profiler server (required for both programmatic and on-demand)
server = xp.start_server(9012)

# Start capturing the trace
xp.start_trace('/root/logs/')

# Run your training
train_mnist()

# Stop the trace
xp.stop_trace()
```

#### Programmatic Capture — MaxText

For MaxText, simply enable the profiler flag:

```bash
python3 -m MaxText.train MaxText/configs/base.yml \
    profiler=xplane \
    base_output_directory=gs://my-bucket/output \
    dataset_type=synthetic \
    per_device_batch_size=2 \
    steps=100
```

#### On-Demand Capture

On-demand capture requires the XProf server to be running in your workload:

**Step 1: Start the XProf server in your code**

```python
# JAX
jax.profiler.start_server(9012)

# PyTorch XLA
import torch_xla.debug.profiler as xp
server = xp.start_server(9012)
```

**Step 2: Trigger capture** (choose one method):

- **Via TensorBoard UI**: Click the **Capture Profile** button, select the device host
- **Via XProfiler CLI**: Use the `xprofiler capture` command (see Section 6.4)

### 6.4 Setting Up XProfiler (cloud-diagnostics-xprof) — Detailed Steps

The XProfiler library hosts TensorBoard on a dedicated Compute Engine VM or GKE pod, providing fast loading of large profiles and shareable URLs.

#### Step 1: Set Environment Variables

```bash
export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"
export GCS_PATH="gs://my-bucket/profiles"
```

#### Step 2: Ensure Profiles Are Stored in GCS

When capturing profiles, use a GCS path:

```python
# JAX
jax.profiler.start_trace("gs://my-bucket/profiles/run-name")

# Or set the output directory in your training script to GCS
```

Your profiles will be stored in the following structure:

```
gs://my-bucket/profiles/
├── run1/
│   └── plugins/
│       └── profile/
│           ├── session1/           # First capture (e.g., steps 1-3)
│           │   └── <profile.xplane.pb>
│           └── session2/           # Second capture (e.g., steps 8-10)
│               └── <profile.xplane.pb>
└── run2/
    └── plugins/
        └── profile/
            └── session1/
                └── <profile.xplane.pb>
```

#### Step 3: Create a TensorBoard Instance

**Option A: Host on a Compute Engine VM (default)**

```bash
xprofiler create -z $ZONE -l $GCS_PATH
```

This creates a `c4-highmem-8` VM by default. To use a different machine type:

```bash
xprofiler create -z $ZONE -l $GCS_PATH -m c4-highmem-16
```

**Option B: Host on a GKE Pod**

```bash
xprofiler create --GKE -z $ZONE -l $GCS_PATH
```

Hosting on a GKE pod is useful when you want to manage TensorBoard alongside your workloads on GKE.

#### Step 4: Access the TensorBoard UI

After running `xprofiler create`, you will see output like:

```
Instance for gs://<bucket> has been created.
You can access it via the following:
1. https://<id>-dot-us-<region>.notebooks.googleusercontent.com.
2. xprofiler connect -z <zone> -l gs://bucket-name -m ssh
Instance is hosted at xprof-97db0ee6-93f6-46d4-b4c4-6d024b34a99f VM.
```

- **Option 1**: Click the URL to open XProf/TensorBoard in your browser
- **Option 2**: Use SSH to connect:

```bash
xprofiler connect -z $ZONE -l $GCS_PATH -m ssh
```

> **Sharing**: The URL is shareable with your team. Access is controlled by the permissions set on the Cloud Storage bucket storing your profile data.

#### Step 5: On-Demand Profiling via XProfiler

If the XProf server is running in your workload (see Section 6.3), you can trigger on-demand captures:

**Via TensorBoard UI:**
1. Open the TensorBoard URL from Step 4
2. Click the **Capture Profile** button
3. Select the device host your workload is running on
4. Specify the capture duration
5. Click **Capture**

**Via XProfiler CLI:**

```bash
xprofiler capture \
    -z $ZONE \
    -l $GCS_PATH \
    --framework jax \
    --host <vm-or-pod-name> \
    --duration 5000      # Duration in milliseconds
```

#### Step 6: Load Multiple Profiles

Point XProfiler to the root directory containing all runs:

```bash
xprofiler create -z $ZONE -l gs://my-bucket/profiles/
```

In the TensorBoard UI, you will see all profiles organized as:
- `run1/session1`
- `run1/session2`
- `run2/session1`

This enables comparing profiles from different parts of your training (e.g., beginning vs. end).

### 6.5 XProf Visual Tools

Once profiles are loaded in TensorBoard, XProf provides a suite of powerful visualization tools:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      XProf Visual Tools Suite                           │
│                                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Trace      │  │  HLO Op     │  │   Memory    │  │  Roofline   │  │
│  │   Viewer     │  │  Profile    │  │   Viewer    │  │  Analysis   │  │
│  │              │  │             │  │             │  │             │  │
│  │ Timeline of  │  │ Time by     │  │ Memory      │  │ Compute vs  │  │
│  │ operations   │  │ operation   │  │ allocation  │  │ memory      │  │
│  │ on hardware  │  │ category    │  │ by ops      │  │ bound       │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
│                                                                         │
│                    ┌─────────────┐                                       │
│                    │   Graph     │                                       │
│                    │   Viewer    │                                       │
│                    │             │                                       │
│                    │ Full HLO    │                                       │
│                    │ graph view  │                                       │
│                    └─────────────┘                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Trace Viewer

The Trace Viewer provides an **operation timeline** view of execution on different hardware units (TensorCores, etc.).

**How to use:**
1. In TensorBoard, select **Profile** from the top menu
2. Select **Trace Viewer** from the **Tools** dropdown on the left
3. Navigate the trace:
   - **W** = Zoom in
   - **S** = Zoom out
   - **A** = Scroll left
   - **D** = Scroll right
   - **1** = Select mouse cursor tool
   - **M** = Measure time duration of selected events

**What you'll see:**
- **Event groups** on the vertical axis (CPU threads, GPU/TPU streams)
- **Colored rectangular blocks** representing trace events on horizontal tracks
- **Time** moving from left to right

**How to analyze:**
- Click on individual trace events to see start time, duration, and operation details
- Drag to select a group of events for a summary and event list
- Look for gaps between operations (indicating idle time)
- Compare CPU vs TPU execution overlap to identify host-bound bottlenecks

#### HLO Op Profile

Breaks down the **total execution time** into different categories of operations.

**How to use:**
1. Select **HLO Op Profile** from the Tools dropdown
2. View time spent per operation category (convolution, matmul, communication, etc.)
3. Sort by time or FLOPS to identify the most expensive operations

**What to look for:**
- Operations consuming disproportionate time
- Unexpected communication overhead
- Memory copy operations that could be optimized

#### Memory Viewer

Details **memory allocations** by different operations during the profiled window.

**How to use:**
1. Select **Memory Viewer** from the Tools dropdown
2. View peak memory usage and allocation timeline
3. Identify operations that allocate the most memory

**What to look for:**
- Peak memory usage approaching HBM limits
- Memory fragmentation patterns
- Opportunities to reduce batch size or use gradient checkpointing

#### Roofline Analysis

Helps you identify whether specific operations are **compute-bound** or **memory-bound** and how far they are from the hardware's peak capabilities.

**How to use:**
1. Select **Roofline** from the Tools dropdown
2. View operations plotted on the roofline chart:
   - **X-axis**: Operational intensity (FLOPS/byte)
   - **Y-axis**: Performance (FLOPS)
   - **Diagonal line**: Memory bandwidth limit
   - **Horizontal line**: Compute limit

**How to interpret:**
- Operations **below the roofline** have room for optimization
- Operations near the **diagonal** are memory-bound → optimize data movement
- Operations near the **horizontal** are compute-bound → optimize algorithms
- Operations **on the roofline** are running at peak efficiency

#### Graph Viewer

Provides a view into the **full HLO graph** executed by the hardware.

**How to use:**
1. Select **Graph Viewer** from the Tools dropdown
2. Navigate the computational graph
3. Click on nodes to see operation details, shapes, and execution time

**What to look for:**
- Graph structure and data flow patterns
- Unnecessary operations or redundant computations
- Communication patterns in distributed training

### 6.6 Visualizing Profiles on a TPU VM (Local)

If you captured profiles locally on a TPU VM:

```bash
# Install XProf and TensorBoard
pip install tensorboard_plugin_profile tensorboard xprof

# Launch TensorBoard pointing to your profiles
tensorboard --logdir=/profiles/run-name

# Or point to the root directory for all runs
tensorboard --logdir=/profiles
```

Open `http://localhost:6006` in your browser to access the XProf tools.

---

## 7. TPU Monitoring Library (LibTPU SDK)

The TPU Monitoring Library provides **hardware-level telemetry** directly from the TPU through the LibTPU SDK. It gives you more detailed information than GKE system metrics, including per-chip utilization, HBM capacity, network latency, and HLO execution timing.

### 7.1 Installation

The TPU Monitoring Library is included with LibTPU. Install via one of these methods:

```bash
# Option 1: Install LibTPU directly
pip install libtpu

# Option 2: Install JAX with TPU support (recommended — includes compatible LibTPU)
pip install -U "jax[tpu]"

# Option 3: Install PyTorch/XLA with TPU support
pip install torch~=2.6.0 'torch_xla[tpu]~=2.6.0' \
    -f https://storage.googleapis.com/libtpu-releases/index.html \
    -f https://storage.googleapis.com/libtpu-wheels/index.html
```

### 7.2 Getting Started

```python
from libtpu.sdk import tpumonitoring

# List all available functionality
tpumonitoring.help()

# List all supported metric names
metrics = tpumonitoring.list_supported_metrics()
print(metrics)
# Output: ["duty_cycle_pct", "tensorcore_util", "hbm_capacity_total", "hbm_capacity_usage", ...]
```

### 7.3 Available Metrics

| Metric | API Name | Description | Example Output |
|---|---|---|---|
| **TensorCore Utilization** | `tensorcore_util` | Percentage of TensorCore usage. Sampled 10μs every 1s. | `['1.11', '2.22', '3.33', '4.44']` (per accelerator) |
| **Duty Cycle %** | `duty_cycle_pct` | % time accelerator was actively processing (5s window). | `['10.00', '20.00', '30.00', '40.00']` |
| **HBM Capacity Total** | `hbm_capacity_total` | Total HBM capacity in bytes. | `['30000000000', ...]` |
| **HBM Capacity Usage** | `hbm_capacity_usage` | HBM usage in bytes (5s window). | `['100', '200', '300', '400']` |
| **Buffer Transfer Latency** | `buffer_transfer_latency` | Network transfer latencies for multislice traffic. | `["'8MB+', '2233.25', '2182.02', ..."]` (size, mean, p50, p90, p99, p99.9) |
| **HLO Execution Timing** | `hlo_exec_timing` | HLO binary execution time distribution. | `["'tensorcore-0', '10.00', '10.00', ..."]` (core, mean, p50, p90, p95, p999) |
| **HLO Queue Size** | `hlo_queue_size` | Number of HLO programs waiting for execution. | `["tensorcore-0: 1", "tensorcore-1: 2"]` |
| **Collective E2E Latency** | `collective_e2e_latency` | End-to-end collective latency over DCN (μs). | `["8MB+-ALL_REDUCE, 1000, 2000, ..."]` |
| **gRPC TCP Min RTT** | `grpc_tcp_min_round_trip_times` | Min Round Trip Times for multislice gRPC traffic. | `['27.63', '29.03', '38.52', ...]` (mean, p50, p90, p95, p99.9 in μs) |
| **gRPC TCP Delivery Rate** | `grpc_tcp_delivery_rates` | TCP throughput for multislice gRPC traffic. | `['11354.89', '10986.35', ...]` (mean, p50, p90, p95, p99.9) |

### 7.4 Reading Metrics

```python
from libtpu.sdk import tpumonitoring

# Read duty cycle metric
metric = tpumonitoring.get_metric("duty_cycle_pct")

print(metric.description())
# "The metric provides a list of duty cycle percentages, one for each
#  accelerator (from accelerator_0 to accelerator_x)..."

print(metric.data())
# ["45.32", "47.11", "44.98", "46.22"]  # Per-accelerator percentages
```

### 7.5 Monitoring During Training (Example)

```python
import jax
import jax.numpy as jnp
from libtpu.sdk import tpumonitoring
import time

# Your model and training setup here...
num_epochs = 10
log_interval_steps = 2

for epoch in range(num_epochs):
    for step in range(5):
        # Training step
        params = train_step(params, data_x, data_y, optimizer)

        if (step + 1) % log_interval_steps == 0:
            # Read TPU metrics
            duty_cycle = tpumonitoring.get_metric("duty_cycle_pct")
            hbm_usage = tpumonitoring.get_metric("hbm_capacity_usage")
            hbm_total = tpumonitoring.get_metric("hbm_capacity_total")

            print(f"Epoch {epoch+1}, Step {step+1}:")
            print(f"  Duty Cycle: {duty_cycle.data()}")
            print(f"  HBM Usage:  {hbm_usage.data()}")
            print(f"  HBM Total:  {hbm_total.data()}")

print("Training complete.")
```

### 7.6 TPU-Z — Diagnosing Hangs & Deadlocks

TPU-Z is a telemetry and debugging facility for diagnosing **hangs or deadlocks** in distributed TPU workloads. It provides runtime state information for all TPU cores.

```python
from libtpu import sdk

# Get core state summary
summary = sdk.tpuz.get_core_state_summary()
print(summary)

# Include HLO information for deeper analysis
summary = sdk.tpuz.get_core_state_summary(include_hlo_info=True)
print(summary)
```

**Output includes:**
- `core_id` — Global core ID, chip ID, core type
- `sequencer_info` — Program counter, program ID, run ID
- `program_fingerprint` — Fingerprint of executing program
- `queued_program_info` — Programs waiting for execution
- `error_message` — Any errors on the core
- `hlo_location` — HLO module and computation name (with `include_hlo_info=True`)

**Use case**: Connect to individual GKE pods or TPU VMs via SSH and compare the program counters, HLO locations, and run IDs across all cores to identify which core is stuck.

### 7.7 Checking TPU Monitoring Library Version

If metrics are missing, check your LibTPU version:

```bash
# Command line
pip show libtpu

# Python
import libtpu
print(libtpu.__version__)

# Update to latest
pip install --upgrade libtpu
```

---

## 8. Enabling System Metrics on GKE

The TPU dashboards and metrics in the GKE AI/ML UI require **system metrics** to be enabled on your GKE cluster.

### 8.1 Enable System Metrics

```bash
# When creating a new cluster
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --monitoring=SYSTEM

# For an existing cluster
gcloud container clusters update $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --monitoring=SYSTEM
```

### 8.2 Enable TPU Runtime Metrics in Your Workload

For TPU runtime metrics to be exported, your workload must:

1. Use **JAX 0.4.14+** (or equivalent PyTorch XLA / TensorFlow version)
2. Expose **containerPort 8431** in your pod spec

Example pod spec:

```yaml
spec:
  containers:
    - name: training
      image: your-training-image:latest
      ports:
        - containerPort: 8431    # Required for TPU runtime metrics
      resources:
        limits:
          google.com/tpu: 4
```

### 8.3 Enable JobSet Metrics

JobSet health metrics (kube-state-metrics) are supported in GKE version **1.32.1-gke.135700** or later:

- **New clusters**: JobSet metrics are enabled by default
- **Existing clusters**: Must be manually enabled after upgrading to a supported version

```bash
# Enable kube-state-metrics with JobSet metrics package
gcloud container clusters update $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --monitoring=SYSTEM,KSM
```

### 8.4 Enable Google Cloud Managed Prometheus

Google Cloud Managed Service for Prometheus is enabled by default for GKE clusters. Verify it's active:

```bash
gcloud container clusters describe $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --format="value(monitoringConfig)"
```

---

## 9. Best Practices

### Monitoring Checklist for Production TPU Workloads

| Step | Action | Details |
|---|---|---|
| 1 | **Enable system metrics** | Required for all TPU dashboards and metrics |
| 2 | **Expose containerPort 8431** | Required for TPU runtime metrics export |
| 3 | **Set up proactive alerts** | At minimum: node health, TPU utilization, JobSet interruptions |
| 4 | **Enable kube-state-metrics** | Required for JobSet health metrics (GKE 1.32.1+) |
| 5 | **Store profiles in GCS** | For long-term retention, sharing, and post-run analysis |
| 6 | **Profile early and often** | XProf has <1% overhead — profile during development, not just debugging |
| 7 | **Integrate Goodput Measurement** | For detailed application-layer goodput tracking |
| 8 | **Monitor network metrics** | Critical for multi-host and multislice workloads |

### When to Use Each Observability Tool

| Scenario | Recommended Tool |
|---|---|
| "Is my training job running?" | GKE AI/ML UI → JobSet Monitoring Dashboard |
| "Are my TPU nodes healthy?" | GKE AI/ML UI → TPU Node Pool Status Dashboard |
| "Why is my training slow?" | XProf → Trace Viewer + Roofline Analysis |
| "Am I using TPU memory efficiently?" | XProf → Memory Viewer + TPU Monitoring Library (HBM metrics) |
| "Is my workload compute or memory bound?" | XProf → Roofline Analysis |
| "My distributed training is hanging" | TPU-Z (LibTPU SDK) — compare core states across hosts |
| "What's my overall training efficiency?" | Cloud Monitoring → JobSet goodput metrics |
| "I need to alert when things go wrong" | Cloud Monitoring → Alert policies with PromQL |
| "What happened during a failure?" | Cloud Logging → Container and node logs |
| "Is my multislice network performing well?" | TPU Monitoring Library → network metrics (RTT, delivery rate) |

### Cost Optimization for Monitoring

| Strategy | Detail |
|---|---|
| **Use managed collection** | Google Cloud Managed Prometheus eliminates the need to run self-managed Prometheus servers |
| **Filter metrics** | Only enable the metric packages you need to reduce Cloud Monitoring costs |
| **Set appropriate sampling** | Use longer evaluation windows for non-critical alerts to reduce false positives |
| **Clean up XProfiler instances** | Delete XProfiler VMs/pods when not actively profiling to avoid idle compute charges |
| **Use GCS lifecycle policies** | Set expiration on old profile data to manage storage costs |

---

## 10. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|---|---|---|
| **TPU dashboard is empty** | System metrics not enabled | Enable system metrics: `gcloud container clusters update --monitoring=SYSTEM` |
| **No TPU runtime metrics** | Missing `containerPort: 8431` or old JAX version | Add port to pod spec; upgrade to JAX 0.4.14+ |
| **XProfiler create fails** | Missing gcloud auth or quota | Run `gcloud auth application-default login`; check Compute Engine quota |
| **Profile files not appearing in TensorBoard** | Wrong GCS path or directory structure | Verify profiles exist at `gs://bucket/run/plugins/profile/session/` |
| **TensorBoard loads slowly** | Large profiles on local machine | Use `xprofiler create` to host TensorBoard on a dedicated VM |
| **TPU Monitoring Library metrics are all zero** | LibTPU not initialized or no workload running | Metrics require an active TPU workload; ensure LibTPU is imported |
| **JobSet metrics missing** | GKE version too old or KSM not enabled | Upgrade to GKE 1.32.1+; enable KSM package |
| **Alert not firing** | Incorrect PromQL query or threshold | Test the query in Metrics Explorer before creating the alert |
| **"Permission denied" on GCS profile bucket** | Missing IAM roles | Grant `roles/storage.objectViewer` to users accessing profiles |

### Debugging Commands

```bash
# Check if system metrics are enabled
gcloud container clusters describe $CLUSTER_NAME \
    --zone=$ZONE --project=$PROJECT_ID \
    --format="value(monitoringConfig)"

# Verify TPU nodes are reporting metrics
kubectl top nodes -l cloud.google.com/gke-accelerator-type=tpu

# Check if containerPort 8431 is exposed
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].ports[*].containerPort}'

# Verify Managed Prometheus is collecting metrics
kubectl get pods -n gke-gmp-system

# Check XProfiler instance status
gcloud compute instances list --filter="name~xprof" --project=$PROJECT_ID

# View TPU Monitoring Library version
pip show libtpu
```

---

## 11. References

### GKE AI/ML UI & Dashboards

- [GKE AI/ML Jobs Dashboard](https://console.cloud.google.com/kubernetes/aiml/jobs) — JobSet monitoring in the Google Cloud console
- [GKE TPU Node Pool Status Dashboard](https://console.cloud.google.com/monitoring/dashboards/integration/gke.gke-tpu-node-pool-status) — TPU node pool health
- [View GKE Observability Metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/view-observability-metrics)
- [Best Practices for Batch Platform on GKE](https://cloud.google.com/kubernetes-engine/docs/best-practices/batch-platform-on-gke)

### TPU Observability

- [TPUs on GKE — Observability and Metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/tpus#observability-and-metrics)
- [TPUs on GKE Autopilot — Observe and Monitor](https://cloud.google.com/kubernetes-engine/docs/how-to/tpus-autopilot#observe-and-monitor-tpus)
- [GKE System Metrics](https://cloud.google.com/stackdriver/docs/solutions/gke/managing-metrics#system-metrics)
- [Kubernetes Metrics Reference](https://cloud.google.com/monitoring/api/metrics_kubernetes)
- [Configure GKE Metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics)
- [Kube-State-Metrics for JobSet](https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics#ksm-jobset-metrics)

### XProf (Performance Profiling)

- [Profile Your Model on Cloud TPU VMs](https://cloud.google.com/tpu/docs/profile-tpu-vm) — Official profiling guide
- [OpenXLA/XProf GitHub Repository](https://github.com/openxla/xprof) — XProf source code
- [cloud-diagnostics-xprof GitHub Repository](https://github.com/AI-Hypercomputer/cloud-diagnostics-xprof) — XProfiler library
- [XProf Documentation](https://openxla.org/xprof) — XProf official docs
- [JAX Profiling Guide](https://docs.jax.dev/en/latest/profiling.html)
- [TensorFlow Profiler Guide](https://www.tensorflow.org/guide/profiler)
- [Profile PyTorch XLA Workloads](https://cloud.google.com/tpu/docs/pytorch-xla-performance-profiling-tpu-vm)

### TPU Monitoring Library

- [TPU Monitoring Library Documentation](https://cloud.google.com/tpu/docs/tpu-monitoring-library) — LibTPU SDK metrics and TPU-Z
- [Cloud TPU Performance Guide](https://cloud.google.com/tpu/docs/performance-guide)
- [JAX & TPU AI Stack](https://cloud.google.com/tpu/docs/jax-ai-stack)

### ML Goodput

- [ML Goodput Measurement Library](https://github.com/AI-Hypercomputer/ml-goodput-measurement) — Instrument application-layer goodput
- [Introducing ML Productivity Goodput](https://cloud.google.com/blog/products/ai-machine-learning/goodput-metric-as-measure-of-ml-productivity) — Blog post on goodput as a metric

### Cloud Monitoring & Logging

- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [Managed Service for Prometheus](https://cloud.google.com/stackdriver/docs/managed-prometheus)
- [Creating Alert Policies](https://cloud.google.com/monitoring/alerts)

### Related Sections in This Repository

- [Deploying Workloads — XPK](../03-deploying-workloads/xpk/README.md) — XPK cluster creation and workload submission
- [Deploying Workloads — Cluster Toolkit](../03-deploying-workloads/gke-ai-hypercompute/cluster-toolkit/README.md) — Production GKE clusters
- [Deploying Workloads — DWS](../03-deploying-workloads/dws/README.md) — Dynamic Workload Scheduler
- [Storage for AI Workloads](../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache for profile storage

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Some features (Training Goodput, Cloud ML Goodput) are in Preview and subject to change. Always follow your organization's security policies and review monitoring costs before enabling extensive metric collection in production environments. Refer to the [official Google Cloud documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/tpus) for the latest information.
