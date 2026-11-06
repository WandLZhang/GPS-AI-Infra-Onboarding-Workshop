# Storage and network

Where your data, model weights and checkpoints live, how VMs reach the network without public IPs, and the images they boot from.

Put sensitive data in a separate project, not the sandbox project where you set up the harness. The harness setup resets that project's org policies, so its buckets can be made public and its VMs can get external IPs ([Org policies](../1-harness-setup/README.md#org-policies)).

| Folder | What's in it |
|---|---|
| [storage](./storage/) | Cloud Storage FUSE, Rapid Cache, Rapid Bucket, Managed Lustre and Google Drive sync, for loading weights fast and writing checkpoints |
| [private-vms](./private-vms/) | VMs with no public IPs, reached through Identity-Aware Proxy (IAP), with Cloud NAT for outbound traffic |
| [vm-images](./vm-images/) | Disk images for GPU and HPC VMs, and [Packer](./vm-images/packer/) templates to build your own |
| [data-prep](./data-prep/) | BigQuery, Dataflow and BigQuery DataFrames for preparing ML data |

[storage](./storage/) covers where checkpoints live. How often to save one, and the code that saves it, is in [checkpointing](../5-run/checkpointing.md).
