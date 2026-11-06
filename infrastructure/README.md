# Infrastructure

Network access, boot images, storage and the data pipeline under a GPU or TPU job.

| Folder | What's in it |
|---|---|
| [zero-trust-iap-access](./zero-trust-iap-access/) | VMs with no public IPs, reached through Identity-Aware Proxy, with Cloud NAT for outbound traffic |
| [disk-images](./disk-images/) | Disk images for GPU and HPC VMs, and [Packer](./disk-images/packer/) templates to build your own |
| [storage](./storage/) | Cloud Storage FUSE, Rapid Cache, Rapid Bucket, Managed Lustre and Google Drive sync, for loading weights and writing checkpoints |
| [data-pipeline](./data-pipeline/) | BigQuery, Dataflow and BigQuery DataFrames for preparing ML data |
