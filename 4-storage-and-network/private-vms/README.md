# Zero Trust VM Access with No Public IPs & Identity-Aware Proxy (IAP)

## Overview

This guide covers how to configure GCP VMs with **no public (external) IP addresses** and use **Identity-Aware Proxy (IAP)** to enable secure, zero trust access for SSH and RDP. This approach eliminates direct internet exposure while providing authenticated, authorized, and audited access to every VM.

---

## Benefits of Configuring VMs with No Public IPs

| Benefit | Description |
|---|---|
| **Reduced Attack Surface** | VMs without public IPs are not reachable from the internet, eliminating port scanning, brute-force SSH/RDP attacks, and exploitation of exposed services. |
| **Defense in Depth** | Even if a firewall rule is misconfigured, a VM without a public IP cannot be reached externally — a second layer of protection beyond VPC firewall rules. |
| **No IP-Based Trust** | Public IPs are static targets. Removing them forces access through controlled, authenticated channels rather than fragile IP allowlists. |
| **Simplified Firewall Management** | No need to manage ingress firewall rules for administrative access from the internet. |
| **Compliance** | Many frameworks (PCI-DSS, HIPAA, SOC 2) recommend or require that compute resources are not directly internet-accessible. |
| **Controlled Egress** | VMs can reach the internet through Cloud NAT (centralized, auditable outbound access) and Google APIs via Private Google Access — without any inbound exposure. |

---

## How IAP Enables Zero Trust Access

**Identity-Aware Proxy (IAP) TCP Forwarding** replaces traditional VPN and public IP access with identity-based, per-resource authorization:

```
Developer's Machine
       │
       ▼
   gcloud compute ssh vm-name --tunnel-through-iap
       │
       ▼
  Google's IAP Proxy (edge infrastructure)
       │  ── Authenticates user (Google Identity)
       │  ── Checks IAM policy (roles/iap.tunnelResourceAccessor)
       │  ── Authorizes per-resource, per-user
       │
       ▼
  Encrypted tunnel → VM's internal IP (no public IP needed)
```

### Zero Trust Principles Enforced by IAP

| Principle | How IAP Implements It |
|---|---|
| **Verify identity** | Every connection is authenticated against the user's Google identity |
| **Least privilege** | `roles/iap.tunnelResourceAccessor` is granted per-user, per-VM |
| **No implicit network trust** | No VPN, no public IP — access is not based on network location |
| **Device trust** | Integrates with Access Context Manager for device posture checks |
| **Continuous audit** | Every tunnel connection is logged in Cloud Audit Logs |
| **Short-lived credentials** | With OS Login, SSH uses short-lived certificates instead of static keys |

### Traditional vs. Zero Trust Comparison

| Traditional (Public IP + VPN) | Zero Trust (No Public IP + IAP) |
|---|---|
| Network perimeter = trust boundary | No implicit trust from any network |
| VPN grants broad network access | Each resource requires explicit authorization |
| Static SSH keys | Identity-based auth with short-lived credentials |
| IP allowlists | Context-aware policies (identity + device + location) |
| Limited audit trail | Full audit logging of every access attempt |

---

## Prerequisites

- A GCP project with billing enabled
- The following APIs enabled:
  ```bash
  gcloud services enable compute.googleapis.com \
      iap.googleapis.com \
      cloudresourcemanager.googleapis.com
  ```
- Sufficient IAM roles:
  - `roles/compute.admin` (or `roles/compute.networkAdmin` + `roles/compute.instanceAdmin`)
  - `roles/iap.admin` (to configure IAP policies)
- `gcloud` CLI installed and authenticated

### Set Environment Variables

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export NETWORK_NAME="zero-trust-vpc"
export SUBNET_NAME="zero-trust-subnet"
export SUBNET_RANGE="10.0.0.0/24"
export ROUTER_NAME="zero-trust-router"
export NAT_NAME="zero-trust-nat"

gcloud config set project $PROJECT_ID
```

---

## Step 1: Create a VPC Network

Create a custom-mode VPC network with a single subnet. Custom mode gives you full control over IP ranges and avoids automatically created subnets in every region.

```bash
# Create the VPC network (custom mode — no auto-created subnets)
gcloud compute networks create $NETWORK_NAME \
    --subnet-mode=custom \
    --bgp-routing-mode=regional

# Create a subnet with Private Google Access enabled
gcloud compute networks subnets create $SUBNET_NAME \
    --network=$NETWORK_NAME \
    --region=$REGION \
    --range=$SUBNET_RANGE \
    --enable-private-ip-google-access
```

> **Note:** `--enable-private-ip-google-access` allows VMs without public IPs to reach Google APIs and services (e.g., Cloud Storage, Container Registry, Artifact Registry) without going through the internet.

---

## Step 2: Configure Firewall Rules

### 2a. Allow SSH Access via IAP

This rule allows IAP's IP range (`35.235.240.0/20`) to reach port 22 (SSH) on all VMs in the network. This is the **only** ingress rule needed for SSH access.

```bash
gcloud compute firewall-rules create allow-iap-ssh \
    --network=$NETWORK_NAME \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --description="Allow SSH access from IAP tunnel"
```

### 2b. Allow RDP Access via IAP

This rule allows IAP's IP range to reach port 3389 (RDP) for Windows VMs.

```bash
gcloud compute firewall-rules create allow-iap-rdp \
    --network=$NETWORK_NAME \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:3389 \
    --source-ranges=35.235.240.0/20 \
    --description="Allow RDP access from IAP tunnel"
```

### 2c. Allow Internal VM-to-VM Communication

This rule allows all VMs within the VPC subnet to communicate with each other on all ports and protocols. This is essential for multi-tier applications, distributed systems, and cluster communication.

```bash
# Allow all internal traffic within the subnet range
gcloud compute firewall-rules create allow-internal \
    --network=$NETWORK_NAME \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=all \
    --source-ranges=$SUBNET_RANGE \
    --description="Allow all internal traffic between VMs in the VPC"
```

> **Tip:** For tighter security, you can restrict internal communication to specific ports and protocols instead of `all`. For example, to allow only TCP on ports 80, 443, and 8080:
> ```bash
> gcloud compute firewall-rules create allow-internal-restricted \
>     --network=$NETWORK_NAME \
>     --direction=INGRESS \
>     --action=ALLOW \
>     --rules=tcp:80,tcp:443,tcp:8080,icmp \
>     --source-ranges=$SUBNET_RANGE \
>     --description="Allow specific internal traffic between VMs"
> ```

### 2d. Allow ICMP for Internal Diagnostics (Optional)

Allow ping between VMs for network troubleshooting.

```bash
gcloud compute firewall-rules create allow-internal-icmp \
    --network=$NETWORK_NAME \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=icmp \
    --source-ranges=$SUBNET_RANGE \
    --description="Allow ICMP (ping) between internal VMs"
```

### Verify Firewall Rules

```bash
gcloud compute firewall-rules list \
    --filter="network=$NETWORK_NAME" \
    --format="table(name, direction, sourceRanges.list():label=SRC_RANGES, allowed[].map().firewall_rule().list():label=ALLOW)"
```

---

## Step 3: Configure Cloud NAT for Outbound Internet Access

VMs without public IPs cannot reach the internet by default. **Cloud NAT** provides outbound-only internet access (no inbound) through a managed NAT gateway.

### 3a. Create a Cloud Router

Cloud NAT requires a Cloud Router to manage routing.

```bash
gcloud compute routers create $ROUTER_NAME \
    --network=$NETWORK_NAME \
    --region=$REGION
```

### 3b. Create the Cloud NAT Gateway

```bash
gcloud compute routers nats create $NAT_NAME \
    --router=$ROUTER_NAME \
    --region=$REGION \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips
```

| Flag | Purpose |
|---|---|
| `--nat-all-subnet-ip-ranges` | Apply NAT to all subnets in the VPC |
| `--auto-allocate-nat-external-ips` | Automatically allocate external IPs for NAT (GCP manages the pool) |

> **Note:** Cloud NAT is **outbound-only**. It does not allow unsolicited inbound connections from the internet. This is a key security advantage over assigning public IPs to VMs.

### Verify Cloud NAT

```bash
gcloud compute routers nats describe $NAT_NAME \
    --router=$ROUTER_NAME \
    --region=$REGION
```

---

## Step 4: Create VMs with No Public IP

### Linux VM (SSH Access)

```bash
gcloud compute instances create linux-vm-01 \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --network=$NETWORK_NAME \
    --subnet=$SUBNET_NAME \
    --no-address \
    --image-family=ubuntu-2404-lts-amd64 \
    --image-project=ubuntu-os-cloud \
    --metadata=enable-oslogin=TRUE \
    --tags=linux-vm
```

### Windows VM (RDP Access)

```bash
gcloud compute instances create windows-vm-01 \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --network=$NETWORK_NAME \
    --subnet=$SUBNET_NAME \
    --no-address \
    --image-family=windows-2022 \
    --image-project=windows-cloud \
    --tags=windows-vm
```

> **Key flags:**
> - `--no-address` — Creates the VM with no external IP address
> - `--metadata=enable-oslogin=TRUE` — Enables OS Login for identity-based SSH (recommended for Linux VMs)

### Verify VMs Have No External IP

```bash
gcloud compute instances list \
    --filter="networkInterfaces[0].network~$NETWORK_NAME" \
    --format="table(name, zone, status, networkInterfaces[0].networkIP:label=INTERNAL_IP, networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"
```

The `EXTERNAL_IP` column should be empty for all VMs.

---

## Step 5: Configure IAP Access (IAM)

Grant the `roles/iap.tunnelResourceAccessor` role to users or groups who need to access VMs via IAP. This is the **authorization** step — without this role, even authenticated users cannot tunnel through IAP.

### Grant Access to a Specific User (All VMs in the Project)

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:alice@example.com" \
    --role="roles/iap.tunnelResourceAccessor"
```

### Grant Access to a Google Group (Recommended)

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="group:vm-admins@example.com" \
    --role="roles/iap.tunnelResourceAccessor"
```

### Grant Access to a Specific VM Only

For more granular control, grant the role at the instance level:

```bash
gcloud compute instances add-iam-policy-binding linux-vm-01 \
    --zone=$ZONE \
    --member="user:alice@example.com" \
    --role="roles/iap.tunnelResourceAccessor"
```

### Grant Access for a Service Account

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:ci-pipeline@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/iap.tunnelResourceAccessor"
```

### Verify IAP IAM Bindings

```bash
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.role=roles/iap.tunnelResourceAccessor" \
    --format="table(bindings.members)"
```

---

## Step 6: Connect to VMs via IAP

### SSH to a Linux VM

```bash
gcloud compute ssh linux-vm-01 \
    --zone=$ZONE \
    --tunnel-through-iap
```

### SSH with Port Forwarding (e.g., Jupyter Notebook on Port 8888)

```bash
gcloud compute ssh linux-vm-01 \
    --zone=$ZONE \
    --tunnel-through-iap \
    -- -L 8888:localhost:8888
```

### RDP to a Windows VM

First, create an IAP tunnel to port 3389, then connect your RDP client to `localhost:13389`:

```bash
gcloud compute start-iap-tunnel windows-vm-01 3389 \
    --zone=$ZONE \
    --local-host-port=localhost:13389
```

Then open your RDP client and connect to `localhost:13389`.

### SCP File Transfer Through IAP

```bash
gcloud compute scp local-file.txt linux-vm-01:~/remote-file.txt \
    --zone=$ZONE \
    --tunnel-through-iap
```

### Verify IAP Tunnel is Working

If you encounter issues, test the tunnel directly:

```bash
gcloud compute start-iap-tunnel linux-vm-01 22 \
    --zone=$ZONE \
    --local-host-port=localhost:2222
```

Then in another terminal:

```bash
ssh -p 2222 localhost
```

---

## Architecture Diagram

```
                            ┌─────────────────────────────────────────────────┐
                            │              Google Cloud Project               │
                            │                                                 │
 ┌───────────────┐          │  ┌──────────────────────────────────────────┐   │
 │  Developer    │          │  │        VPC: zero-trust-vpc               │   │
 │  Workstation  │          │  │        (Custom Mode)                     │   │
 │               │          │  │                                          │   │
 │  gcloud ssh   │─────┐    │  │  ┌────────────┐    ┌────────────┐       │   │
 │  --tunnel-    │     │    │  │  │ linux-vm-01│◄──►│ linux-vm-02│       │   │
 │  through-iap  │     │    │  │  │ 10.0.0.2   │    │ 10.0.0.3   │       │   │
 └───────────────┘     │    │  │  │ No Pub IP  │    │ No Pub IP  │       │   │
                       │    │  │  └─────┬──────┘    └─────┬──────┘       │   │
                       ▼    │  │        │    Internal      │             │   │
              ┌─────────────┤  │        │◄──Communication──►│             │   │
              │   IAP       │  │        │  (allow-internal) │             │   │
              │  Proxy      │  │  ┌─────┴──────┐    ┌─────┴──────┐       │   │
              │             │  │  │windows-vm  │    │  app-vm    │       │   │
              │ ✓ Identity  │──┼─►│ 10.0.0.4   │    │ 10.0.0.5   │       │   │
              │ ✓ IAM Check │  │  │ No Pub IP  │    │ No Pub IP  │       │   │
              │ ✓ Audit Log │  │  └────────────┘    └─────┬──────┘       │   │
              └─────────────┤  │                          │              │   │
                            │  │                    ┌─────▼──────┐       │   │
                            │  │                    │ Cloud NAT  │───────┼───┼──► Internet
                            │  │                    │ (Outbound  │       │   │   (outbound only)
                            │  │                    │  Only)     │       │   │
                            │  │                    └────────────┘       │   │
                            │  │                                          │   │
                            │  │  Private Google Access ──────────────────┼───┼──► Google APIs
                            │  │  (Storage, Artifact Registry, etc.)     │   │   (no internet)
                            │  └──────────────────────────────────────────┘   │
                            └─────────────────────────────────────────────────┘
```

---

## Firewall Rules Summary

| Rule Name | Direction | Source | Ports | Purpose |
|---|---|---|---|---|
| `allow-iap-ssh` | INGRESS | `35.235.240.0/20` | TCP:22 | SSH via IAP tunnel |
| `allow-iap-rdp` | INGRESS | `35.235.240.0/20` | TCP:3389 | RDP via IAP tunnel |
| `allow-internal` | INGRESS | `10.0.0.0/24` (subnet) | ALL | VM-to-VM communication |
| `allow-internal-icmp` | INGRESS | `10.0.0.0/24` (subnet) | ICMP | Ping between VMs |

---

## Best Practices

### Enable OS Login

OS Login integrates SSH access with Google IAM, replacing static SSH keys with short-lived certificates:

```bash
# Enable OS Login at the project level
gcloud compute project-info add-metadata \
    --metadata enable-oslogin=TRUE

# Grant SSH access to a user via IAM
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:alice@example.com" \
    --role="roles/compute.osLogin"

# For sudo access, use:
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:alice@example.com" \
    --role="roles/compute.osAdminLogin"
```

### Enforce No Public IPs with Organization Policy

Prevent any VM in the project (or organization) from being created with a public IP:

```bash
# Set the organization policy constraint (requires org-level permissions)
gcloud resource-manager org-policies enable-enforce \
    constraints/compute.vmExternalIpAccess \
    --project=$PROJECT_ID
```

### Context-Aware Access with Access Context Manager

Combine IAP with device and context checks for stronger zero trust:

```bash
# Create an access level that requires corporate-managed devices
gcloud access-context-manager levels create corp-device-only \
    --title="Corporate Devices Only" \
    --basic-level-spec=access-level-spec.yaml \
    --policy=POLICY_ID
```

Example `access-level-spec.yaml`:

```yaml
conditions:
  - devicePolicy:
      requireCorpOwned: true
      osConstraints:
        - osType: DESKTOP_CHROME_OS
        - osType: DESKTOP_LINUX
        - osType: DESKTOP_MAC
        - osType: DESKTOP_WINDOWS
      requireScreenlock: true
```

### Audit Logging

IAP tunnel connections are automatically logged. To view them:

```bash
gcloud logging read \
    'resource.type="gce_instance" AND protoPayload.methodName="AuthorizeUser"' \
    --project=$PROJECT_ID \
    --limit=20 \
    --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, resource.labels.instance_id)"
```

---

## Cleanup

To remove all resources created in this guide:

```bash
# Delete VMs
gcloud compute instances delete linux-vm-01 windows-vm-01 \
    --zone=$ZONE --quiet

# Delete Cloud NAT
gcloud compute routers nats delete $NAT_NAME \
    --router=$ROUTER_NAME \
    --region=$REGION --quiet

# Delete Cloud Router
gcloud compute routers delete $ROUTER_NAME \
    --region=$REGION --quiet

# Delete firewall rules
gcloud compute firewall-rules delete \
    allow-iap-ssh allow-iap-rdp allow-internal allow-internal-icmp \
    --quiet

# Delete subnet
gcloud compute networks subnets delete $SUBNET_NAME \
    --region=$REGION --quiet

# Delete VPC network
gcloud compute networks delete $NETWORK_NAME --quiet
```

---

## References

- [IAP TCP Forwarding Overview](https://cloud.google.com/iap/docs/tcp-forwarding-overview)
- [Using IAP for TCP Forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Cloud NAT Overview](https://cloud.google.com/nat/docs/overview)
- [VPC Firewall Rules](https://cloud.google.com/vpc/docs/firewalls)
- [OS Login](https://cloud.google.com/compute/docs/instances/managing-instance-access)
- [BeyondCorp Enterprise](https://cloud.google.com/beyondcorp-enterprise/docs/overview)
- [Private Google Access](https://cloud.google.com/vpc/docs/private-google-access)
