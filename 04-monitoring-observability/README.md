# Observe and debug GPU and TPU jobs

Watch GPU and TPU jobs with dashboards and alerts, read their logs, and profile them with XProf. Come here when a job runs slow, hangs or dies.

## What we'd pick

- Start at the **AI/ML** section of Kubernetes Engine in the Google Cloud console. Its JobSet dashboard shows status, replica readiness, goodput and GPU or TPU metrics in one place.
- Leave GKE system metrics on and set `containerPort: 8431` in TPU pod specs. The duty cycle and HBM charts need both. Cloud Monitoring doesn't charge to ingest GKE system metrics.
- Set alerts before a long run. A hung job keeps billing until someone notices. Start with [our five](#alerts-we-set-first).
- When a TPU job dies, check [hardware health](#tpu-hardware-health) before you debug code. The ICI link, HBM and PCIe metrics show whether the hardware failed.
- For a hung or failed TPU job on GKE, run the [ML Workload Debugging Wiki](https://github.com/google/ml-workload-debugging-wiki) in your coding agent. It matches the job's logs against known failure modes and names the culprit hosts.
- Read logs through the Cloud Logging remote MCP server. The [agentic coder setup](../01-foundational-tools/agentic-coder-setup/) connects it, so your agent queries a job's logs itself.
- Profile early with XProf. Its collection overhead on TPU is under 1%, so profile during development too.
- Write profiles to Cloud Storage. Local profiles go away when the run ends. XProfiler reads from the bucket.
- Open large profiles on an XProfiler VM, then delete the VM. It loads big profiles faster than a local TensorBoard. It bills while it runs.
- Add a lifecycle rule that deletes old profiles. Each capture adds another session to the bucket.

## Official docs

| Need | Page |
|---|---|
| Watch JobSets, goodput and badput | [Monitor goodput with the ML Goodput Measurement library](https://docs.cloud.google.com/tpu/docs/goodput) |
| Read the GKE Observability tab, including GPU, TPU and DCGM charts | [View observability metrics](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/view-observability-metrics) |
| Turn on GKE metric packages | [Configure metrics collection](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics) |
| Get JobSet metrics from kube state metrics | [Collect and view kube state metrics](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics) |
| TPU runtime metrics and node pool health on GKE | [Deploy TPU workloads in GKE Standard](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/tpus) |
| GPU metrics on GKE | [Collect and view DCGM metrics](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/dcgm-metrics) |
| GPU metrics on Compute Engine VMs | [Monitoring GPU performance on Linux VMs](https://docs.cloud.google.com/compute/docs/gpus/monitor-gpus) |
| TPU VM metrics, including hardware health | [Monitor TPU VMs](https://docs.cloud.google.com/tpu/docs/monitor-tpu) |
| TPU health status and its causes | [Monitor Cloud TPU health](https://docs.cloud.google.com/tpu/docs/troubleshooting/tpu-health) |
| TPU metrics from inside a job | [TPU Monitoring Library](https://docs.cloud.google.com/tpu/docs/tpu-monitoring-library) |
| TPU metrics and core state from a shell | [Monitor with tpu-info CLI](https://docs.cloud.google.com/tpu/docs/tpu-info-cli) |
| Alerts written in PromQL | [Create PromQL-based alerting policies (Console)](https://docs.cloud.google.com/monitoring/promql/create-promql-alerts-console) |
| Log queries for GKE and TPU jobs | [Sample queries](https://docs.cloud.google.com/logging/docs/view/query-library) |
| Logs in your coding agent | [Use the Cloud Logging remote MCP server](https://docs.cloud.google.com/logging/docs/use-logging-mcp) |
| Debug a TPU job with a coding agent | [Troubleshoot with the ML Workload Debugging Wiki](https://docs.cloud.google.com/tpu/docs/agent-wiki) |
| Automatic hang and slowdown detection for JAX on TPU | [Workload monitoring with ML Diagnostics](https://docs.cloud.google.com/tpu/docs/ml-diagnostics/workload-monitoring) |
| TPU errors and log queries on GKE | [Troubleshoot TPUs in GKE](https://docs.cloud.google.com/kubernetes-engine/docs/troubleshooting/tpus) |
| Profile with XProf and XProfiler | [Profile your model on Cloud TPU VMs](https://docs.cloud.google.com/tpu/docs/profile-tpu-vm) |

## Ask your agent

Questions for the Google developer knowledge MCP:

- "How do I monitor JobSet health and goodput for training workloads in the GKE AI/ML console dashboard?"
- "How do I enable TPU runtime metrics like duty cycle for TPU workloads on GKE?"
- "How do I check whether a node or node pool interruption caused my GKE TPU training job to fail?"
- "How do I turn on JobSet metrics from kube-state-metrics on an existing GKE cluster?"
- "How do I collect NVIDIA DCGM metrics from GPU nodes in GKE?"
- "How do I monitor GPU usage and memory on a Compute Engine GPU VM in Cloud Monitoring?"
- "Which TPU hardware health metrics does Cloud Monitoring report for TPU VMs?"
- "Why is a TPU instance marked UNHEALTHY, and what does each cause mean?"
- "How do I create a PromQL-based alerting policy in Cloud Monitoring?"
- "Which Cloud Logging query shows the error logs for one GKE JobSet?"
- "How do I connect a coding agent to the Cloud Logging remote MCP server?"
- "How do I use the ML Workload Debugging Wiki with a coding agent to debug a hung TPU job?"
- "How do I detect and diagnose a hang or slowdown in a TPU training job on GKE with ML Diagnostics?"
- "How do I find which TPU core is stuck when a multi-host TPU job hangs?"
- "How do I read TPU metrics with the TPU Monitoring Library in libtpu?"
- "How do I capture a profile of a JAX workload on a Cloud TPU VM and view it in XProf?"

## Field notes

### TPU hardware health

TPU VMs report hardware health to Cloud Monitoring. Use these metrics to tell a hardware fault from a bug in your code. They're all Beta and listed on [Monitor TPU VMs](https://docs.cloud.google.com/tpu/docs/monitor-tpu) (read 2026-11-05). Prefix each name with `compute.googleapis.com/`.

| What it catches | Metric |
|---|---|
| Throttling | `instance/tpu/accelerator/core_throttling_indicator` |
| Temperature | `instance/tpu/accelerator/core_temperature`, `mxu_temperature`, `hbm_temperature`, `tray_temperature` |
| Power | `instance/tpu/accelerator/power_draw`, `hbm_power_draw`, `tray_power` |
| ICI link health | `instance/tpu/accelerator/network/ici_link_health`, 0 to 10: 1 to 5 is brief flapping, 6 to 9 persistent degradation, and 10 a fatal link failure that evicts running workloads |
| ICI link flaps | `instance/tpu/accelerator/network/ici_link_flaps` |
| HBM errors | `instance/tpu/accelerator/hbm_uncorrectable_count`, fatal |
| PCIe errors | `instance/tpu/accelerator/pcie_fatal_error_count`, `pcie_nonfatal_error_count` |
| Host network drops | `tpu/network/nic_packets_dropped_count_rx`, `nic_packets_dropped_count_tx` |
| Predicted failure | `instance/tpu/failure_prediction_status`: chance the machine degrades in the next 5 hours (`NO_DEGRADATION_PREDICTED`, `POSSIBLE_DEGRADATION_PREDICTED` or `DEGRADATION_PREDICTED`). Data can lag up to 540 seconds |
| Overall instance health | `instance/tpu/infra_health`: `HEALTHY`, `DEGRADED`, `UNHEALTHY` or `UNKNOWN`. Data can lag up to 420 seconds |

When a job dies, check `ici_link_health`, `hbm_uncorrectable_count` and the PCIe counters for that window before you debug your code. In PromQL, `ici_link_health` is `compute_googleapis_com:instance_tpu_accelerator_network_ici_link_health`.

### Alerts we set first

Set these five on any GKE cluster with TPU node pools. A PromQL alerting policy holds one condition, so create one policy per row. Run each query in Metrics Explorer before you save it. If the project has more than one cluster, filter each query on its cluster label.

| Alert | PromQL condition | Fire after |
|---|---|---|
| TPU node not Ready | `kubernetes_io:node_status_condition{condition="Ready", status="False", node_name=~"gke-tpu.*"} > 0` | 5 minutes |
| Multi-host TPU node pool in Error | `kubernetes_io:node_pool_status{status="Error"} > 0` | 5 minutes |
| Multi-host TPU node pool unavailable | `kubernetes_io:node_pool_multi_host_available == 0` | 10 minutes |
| Job stalled | `avg(kubernetes_io:node_accelerator_duty_cycle{node_name=~"gke-tpu.*"}) < 10` | 15 minutes |
| JobSet restarting often | `delta(kube_jobset_restarts[1h]) > 3` | 1 minute |

The last row needs the `JOBSET` kube state metrics package.

### Debug a hung or failed job

For a TPU job on GKE that runs JAX, XLA or Pathways, start with the [ML Workload Debugging Wiki](https://github.com/google/ml-workload-debugging-wiki). Start Claude Code or Antigravity in the wiki's repo root and run `/troubleshoot JOBSET_NAME`. Give it the project ID and a time range that covers the whole run. It needs Logs Viewer, Kubernetes Engine Viewer, Compute Viewer and Monitoring Viewer on the project. Its checks are read-only by default, and it asks before any step that changes the cluster. Setup is on [Troubleshoot with the ML Workload Debugging Wiki](https://docs.cloud.google.com/tpu/docs/agent-wiki).

To check by hand, work in this order:

1. Chart the [TPU hardware health](#tpu-hardware-health) metrics for the failure window.
2. On GKE, chart `kubernetes.io/node/interruption_count` for the same window. Its `interruption_type` and `interruption_reason` labels name the cause, such as `PreemptionEvent` or `HostError`.
3. Ask your coding agent for the job's ERROR logs. It reads them through the Cloud Logging remote MCP server.
4. If a multi-host TPU job hangs, run `tpu-info --metric sequencer_state_detailed` on every host. Look for a core whose program counter, HLO location or run ID differs from the rest. That core's host is the suspect.

### Profile with XProf

Write the trace to Cloud Storage. Call `block_until_ready()` before you stop the trace, because JAX dispatches work asynchronously.

```python
jax.profiler.start_trace("gs://BUCKET/run-1")
for _ in range(3):
    state, loss = train_step(state, batch)
loss.block_until_ready()
jax.profiler.stop_trace()
```

In MaxText, set `profiler=xplane`. For PyTorch, follow the TorchTPU [XProf guide](https://torchtpu.readthedocs.io/en/latest/performance_profiling_with_xprof/).

View the profiles with XProfiler. Point it at the bucket root to compare runs and sessions.

```bash
pip install cloud-diagnostics-xprof
xprofiler create -z $ZONE -l gs://BUCKET   # c4-highmem-8 VM unless you pass -m
xprofiler delete -z $ZONE -l gs://BUCKET   # delete the VM when you're done
```

Pick the tool by the question you have:

| Question | XProf tool | Look for |
|---|---|---|
| Where does step time go? | Trace Viewer | Gaps between ops, and TensorCores idle while the host works |
| Which ops cost the most time? | HLO Op Profile | Ops with an outsized share, and copies or collectives you didn't expect |
| How close am I to the HBM limit? | Memory Viewer | Peak allocation against the chip's HBM |
| Is an op compute-bound or memory-bound? | Roofline Analysis | Ops near the slanted line are memory-bound; ops near the flat line are compute-bound |
| What did XLA run? | Graph Viewer | Redundant ops and the communication pattern |

### Traps and fixes

| Symptom | Fix |
|---|---|
| TPU charts on GKE are empty | Check that system metrics are on and the pod spec sets `containerPort: 8431`. The runtime metrics need JAX 0.4.14 or later. |
| A `--monitoring` update dropped a metric package | The flag replaces the whole list. Name every package each time, for example `--monitoring=SYSTEM,POD,DEPLOYMENT,JOBSET`. |
| JobSet metrics are missing on an upgraded cluster | Add the `JOBSET` package. Only clusters created on 1.32.1-gke.1357001 or later get it by default. |
| The TPU Monitoring Library returns empty lists or zeros | It returns empty lists until the TPU runtime starts in the same process. It returns zeros while the runtime idles. From another shell, run `tpu-info`. |
| A TPU Monitoring Library metric is missing | Your libtpu is too old. Upgrade JAX with `pip install -U "jax[tpu]"` to get a matching libtpu. |
| Metrics are missing on a TPU VM with a custom OS image | Install and run the AI Telemetry Collector. Google's TPU-optimized Ubuntu images run it at boot. |
| XProf doesn't list your profiles | It looks for `plugins/profile/<session>/` under the path you give it. Point it at the bucket root. |
| An alert never fires | Run its query in Metrics Explorer and confirm it returns data. |
