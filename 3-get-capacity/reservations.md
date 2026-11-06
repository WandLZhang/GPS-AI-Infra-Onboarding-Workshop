# Reservations: Affinity, Topology & Dense Allocation

How VMs and node pools consume reserved capacity, and how to place them close together for distributed training. For when a reservation is the right option, see [Choose an option](./README.md#choose-an-option).

## Understanding Reservation Affinity

When creating GPU node pools or VMs, you configure **reservation affinity** to control how your workload consumes reserved capacity:

| Affinity Type | When to Use | How It Works |
|---|---|---|
| **Specific reservation** | You have a named reservation | VMs target that specific reservation. Required for A4X Max, A4X. |
| **Any matching reservation** | You have reservations and want automatic matching | VMs consume any reservation that matches the machine type and zone. |
| **No reservation** | Using DWS flex-start or Spot | VMs do not consume reservations. Required for DWS node pools. |

## Machine Type Topology

Different machine types have different physical topology characteristics that affect workload performance:

| Machine Type | NVLink Domain | GPU Interconnect Topology | Inter-Node Network | Placement |
|---|---|---|---|---|
| **A4X Max / A4X** | 72 GPUs (18 instances) | NVL72 rack-scale, NVLink-C2C | RoCE, 8-way (A4X Max) / 4-way (A4X) rail-aligned | Always dense |
| **A4** | 8 GPUs (1 instance) | All-to-all NVLink within node | RoCE, 4-way rail-aligned | Dense available |
| **A3 Ultra** | 8 GPUs (1 instance) | All-to-all NVLink within node | RoCE, 4-way rail-aligned | Dense available |
| **A3 Mega** | 8 GPUs (1 instance) | All-to-all NVLink within node | GPUDirect-TCPXO | Dense available |
| **A3 High** (8g) | 8 GPUs (1 instance) | All-to-all NVLink within node | GPUDirect-TCPX | Compact placement optional |
| **A3 High** (1g/2g/4g) | Within VM only | NVLink within allocated GPUs | Standard | Standard |
| **G4** | Within VM only | PCIe Gen 5 with P2P | Standard | Standard |
| **G2** | Within VM only | PCIe | Standard | Compact placement optional |

## Dense Allocation

For distributed training, **dense allocation** ensures your VMs are placed physically close together, minimizing network hops and latency:

- **Automatically dense:** A4X Max, A4X (always provisioned as dense NVL72 domains)
- **Dense via reservation/DWS:** A4, A3 Ultra, A3 Mega, A3 High (8g), A3 Edge — request dense allocation through reservations or DWS resize requests
- **Compact placement policy:** A3 High, A2, G2 — use `--placement-policy` to request close placement (contact your account team for A3 with max distance)

## Topology-Aware Scheduling (TAS) on GKE

For GKE clusters with A4, A3 Ultra, A3 Mega, or A4X machine types, enable [Topology-Aware Scheduling](https://cloud.google.com/ai-hypercomputer/docs/workloads/schedule-gke-workloads-tas) to let GKE's scheduler place pods on nodes that are topologically close:

```yaml
# Example: Request topology-aware scheduling in a JobSet
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  annotations:
    alpha.jobset.sigs.k8s.io/exclusive-topology: cloud.google.com/gke-topology-block
spec:
  replicatedJobs:
    - name: workers
      template:
        spec:
          template:
            spec:
              nodeSelector:
                cloud.google.com/gke-accelerator: nvidia-b200
              topologySpreadConstraints:
                - maxSkew: 1
                  topologyKey: cloud.google.com/gke-topology-block
                  whenUnsatisfiable: DoNotSchedule
```

## References

- [Topology-Aware Scheduling on GKE](https://cloud.google.com/ai-hypercomputer/docs/workloads/schedule-gke-workloads-tas) — Schedule pods on topologically-close nodes
- [Compact Placement Policies](https://cloud.google.com/compute/docs/instances/placement-policies-overview#about-compact-policies) — Control VM physical placement
- [Kubernetes on GKE](../5-run/kubernetes/) — GPU node pools, Kueue and fallback across capacity types
