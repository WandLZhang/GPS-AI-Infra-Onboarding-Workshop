# Billing & Usage Report — Cost Monitoring and Limits for AI Workloads

> A comprehensive guide to monitoring costs, setting budgets and alerts, enforcing quotas, and optimizing spend for GPU and TPU workloads on Google Cloud — covering every project in your organization.

---

## 📋 Table of Contents

1. [Overview](#1-overview)
2. [Billing Reports & Cost Visibility](#2-billing-reports--cost-visibility)
3. [Billing Export to BigQuery](#3-billing-export-to-bigquery)
4. [Budgets & Alerts](#4-budgets--alerts)
5. [Programmatic Cost Controls](#5-programmatic-cost-controls)
6. [Quotas & Resource Limits](#6-quotas--resource-limits)
7. [Committed Use Discounts (CUDs)](#7-committed-use-discounts-cuds)
8. [Cost Optimization for AI Workloads](#8-cost-optimization-for-ai-workloads)
9. [Per-Project Cost Monitoring Checklist](#9-per-project-cost-monitoring-checklist)
10. [References](#10-references)

---

## 1. Overview

AI infrastructure workloads on Google Cloud — especially GPU and TPU training jobs — can generate significant costs. A single 256-chip TPU v5p pod costs over **$100/hour on-demand**, and a multi-node A3 Ultra cluster can exceed **$10,000/day**. Without proactive cost monitoring, a misconfigured job or forgotten cluster can result in tens of thousands of dollars in unplanned spend.

Google Cloud provides a layered cost management stack to monitor, alert, and control spending:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  Cost Management Stack for AI Workloads                  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 1: Visibility — Know What You're Spending                │   │
│  │  ├── Cloud Billing Reports (console dashboards)                │   │
│  │  ├── FinOps Hub (optimization score, recommendations)          │   │
│  │  ├── Anomaly Detection (auto-detect cost spikes)               │   │
│  │  └── Gemini Cloud Assist (AI-powered cost insights)            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 2: Analytics — Understand Where Costs Come From          │   │
│  │  ├── BigQuery Billing Export (standard + detailed + pricing)   │   │
│  │  ├── Labels & Tags (allocate costs to teams/workloads)         │   │
│  │  └── CUD Metadata Export (commitment utilization)              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 3: Guardrails — Prevent Overspend                        │   │
│  │  ├── Budgets & Alerts (per-project, per-service thresholds)    │   │
│  │  ├── Quotas (GPU/TPU core limits per project per zone)         │   │
│  │  ├── Programmatic Controls (auto-disable billing via Pub/Sub)  │   │
│  │  └── API Usage Caps (request rate limits)                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Layer 4: Optimization — Reduce Unit Costs                      │   │
│  │  ├── Committed Use Discounts (CUDs) — up to 57% savings       │   │
│  │  ├── DWS Flex-Start — up to 53% discount on GPUs/TPUs         │   │
│  │  ├── Spot/Preemptible VMs — up to 91% discount                │   │
│  │  ├── Right-Sizing & Idle Resource Cleanup                      │   │
│  │  └── Storage Tiering & XLA Compilation Caching                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### When to Use Each Layer

| Layer | Use Case | Audience |
|---|---|---|
| **Billing Reports / FinOps Hub** | Quick visual overview of costs, trends, and savings | Finance, Engineering Leads |
| **BigQuery Export** | Deep cost analytics, chargebacks, custom dashboards | FinOps Engineers, Data Analysts |
| **Budgets & Alerts** | Proactive notification when spend approaches limits | Project Owners, Platform Engineers |
| **Quotas & Programmatic Controls** | Hard guardrails to prevent runaway costs | Cloud Admins, Security Teams |
| **CUDs / DWS / Spot** | Reducing per-unit cost for planned workloads | FinOps Engineers, Procurement |

---

## 2. Billing Reports & Cost Visibility

### 2.1 Cloud Billing Reports

Cloud Billing Reports provide a visual dashboard for analyzing cost trends.

**Access the reports:**
- Navigate to: **Google Cloud Console → Billing → Reports**
- Direct URL: [https://console.cloud.google.com/billing/reports](https://console.cloud.google.com/billing/reports)

**Key capabilities:**

| Feature | Description |
|---|---|
| **Group by** | Project, Service, SKU, Location, Label, Tag |
| **Filters** | Time range, projects, services, SKUs, labels, credits |
| **Credits toggle** | Show/hide CUD credits, sustained use discounts, promotional credits |
| **Cost forecast** | Projected spend based on historical trends |
| **Saved reports** | Save and share custom report configurations |
| **Bar/line chart** | Toggle between chart views |

**Recommended report configurations for AI workloads:**

```
Report 1: GPU/TPU Spend by Project
├── Group by: Project
├── Filter: Services = "Compute Engine", "Kubernetes Engine"
├── Filter: SKU contains "GPU" OR "TPU" OR "A3" OR "A4" OR "H100" OR "H200"
└── Time: Last 30 days

Report 2: Storage Costs for Training Data
├── Group by: Service
├── Filter: Services = "Cloud Storage", "Persistent Disk"
├── Filter: Labels = team:ml-training
└── Time: Last 90 days

Report 3: Networking Costs (Multi-Host Training)
├── Group by: SKU
├── Filter: Services = "Compute Engine"
├── Filter: SKU contains "Network" OR "Egress" OR "GPUDirect"
└── Time: Last 30 days
```

### 2.2 FinOps Hub

The FinOps Hub is a centralized dashboard that summarizes savings, surfaces recommendations, and calculates your FinOps score.

**Access the FinOps Hub:**
- Navigate to: **Google Cloud Console → Billing → Optimize (FinOps hub)**
- Direct URL: [https://console.cloud.google.com/billing/optimize](https://console.cloud.google.com/billing/optimize)

**Key metrics on the FinOps Hub:**

| Metric | Description |
|---|---|
| **Last month's realized savings** | Total savings from CUDs, right-sizing, and idle resource removal |
| **Active recommendations** | Number of Google Cloud-recommended optimizations available |
| **Potential savings per month** | Estimated savings from applying all recommendations |
| **CUD optimization rate** | Percentage of CUD-eligible usage covered by commitments |
| **FinOps score** | Composite score based on monitoring, allocation, optimization, and automation practices |

**AI-relevant recommenders in the FinOps Hub:**

| Recommender | ID | What It Does |
|---|---|---|
| **Idle VM** | `google.compute.instance.IdleResourceRecommender` | Flags GPU/TPU VMs with no activity |
| **VM machine type** | `google.compute.instance.MachineTypeRecommender` | Right-size GPU VM machine types |
| **Idle GKE cluster** | `google.container.DiagnosisRecommender` (CLUSTER_IDLE) | Flags unused GKE clusters (common after PoCs) |
| **Overprovisioned GKE cluster** | `google.container.DiagnosisRecommender` (CLUSTER_OVERPROVISIONED) | Right-size GKE clusters |
| **Idle persistent disk** | `google.compute.disk.IdleResourceRecommender` | Remove unused disks (leftover from training) |
| **Idle reservation** | `google.compute.IdleResourceRecommender` | Remove unused GPU/TPU reservations |
| **CUD recommender** | `google.compute.commitment.UsageCommitmentRecommender` | Purchase resource-based CUDs |
| **Spend-based CUD** | `google.cloudbilling.commitment.SpendBasedCommitmentRecommender` | Purchase spend-based / Compute flexible CUDs |

### 2.3 Anomaly Detection

Anomaly Detection (GA) automatically identifies cost spikes that deviate from your historical spend patterns.

**Access Anomaly Detection:**
- Navigate to: **Google Cloud Console → Billing → Cost Management → Anomalies**

**Key features:**

| Feature | Description |
|---|---|
| **Auto-generated thresholds** | Updated daily based on your usage patterns |
| **Deviation percentage** | Configurable threshold for anomaly sensitivity |
| **Root cause analysis** | Identifies top services, regions, and SKUs contributing to the spike |
| **Email alerts** | Automatically set up for Billing administrators |

> **AI workload tip:** GPU/TPU workloads are naturally bursty. Configure anomaly thresholds with a higher deviation percentage (e.g., 50–100%) for projects running DWS flex-start or Spot workloads to avoid false positives.

### 2.4 Gemini Cloud Assist in Cloud Billing

If enabled, Gemini Cloud Assist provides AI-powered insights in Billing Reports:

- **Find or create reports** using natural language (e.g., "Show me GPU costs by project for Q1")
- **Summarize reports** with key cost trends and insights
- **Optimization insights** surfaced in the FinOps Hub

**Enable Gemini Cloud Assist:**

```bash
# Enable the Gemini for Google Cloud API in your project
gcloud services enable cloudaicompanion.googleapis.com \
    --project=$PROJECT_ID
```

---

## 3. Billing Export to BigQuery

Billing Export to BigQuery gives you full programmatic access to your cost data for custom analytics, chargebacks, and dashboards.

### 3.1 Enable Billing Export

```bash
# Step 1: Create a BigQuery dataset for billing data
bq mk --dataset \
    --description "Cloud Billing export data" \
    --location US \
    $PROJECT_ID:billing_export

# Step 2: Enable export in the console
# Navigate to: Billing → Billing export → BigQuery export
# Select the dataset and enable:
#   - Standard usage cost
#   - Detailed usage cost
#   - Pricing data
```

**Available export types:**

| Export Type | Description | Use Case |
|---|---|---|
| **Standard usage cost** | Daily cost data with project, service, SKU, labels, credits | Cost reporting, chargebacks |
| **Detailed usage cost** | Hourly granularity with resource-level detail (`resource.name`) | Per-resource cost tracking |
| **Pricing data** | SKU-level pricing including contract rates | Cost estimation, unit economics |
| **CUD metadata** | Daily snapshot of spend-based CUD commitments | CUD utilization analysis |

### 3.2 Example BigQuery Queries for AI Workloads

#### GPU/TPU Spend by Project (Last 30 Days)

```sql
SELECT
  project.id AS project_id,
  project.name AS project_name,
  SUM(cost) AS total_cost,
  SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) AS total_credits,
  SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) AS net_cost
FROM
  `PROJECT_ID.billing_export.gcp_billing_export_v1_XXXXXX_XXXXXX_XXXXXX`
WHERE
  _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND service.description IN ('Compute Engine', 'Kubernetes Engine')
  AND (
    LOWER(sku.description) LIKE '%gpu%'
    OR LOWER(sku.description) LIKE '%tpu%'
    OR LOWER(sku.description) LIKE '%a3%'
    OR LOWER(sku.description) LIKE '%a4%'
    OR LOWER(sku.description) LIKE '%h100%'
    OR LOWER(sku.description) LIKE '%h200%'
    OR LOWER(sku.description) LIKE '%b200%'
  )
GROUP BY project.id, project.name
ORDER BY net_cost DESC;
```

#### Daily Cost Trend by Service

```sql
SELECT
  DATE(usage_start_time) AS usage_date,
  service.description AS service,
  SUM(cost) AS daily_cost
FROM
  `PROJECT_ID.billing_export.gcp_billing_export_v1_XXXXXX_XXXXXX_XXXXXX`
WHERE
  _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  AND project.id = 'my-ai-project'
GROUP BY usage_date, service
ORDER BY usage_date DESC, daily_cost DESC;
```

#### Top 10 Most Expensive SKUs

```sql
SELECT
  sku.description AS sku,
  service.description AS service,
  SUM(cost) AS total_cost,
  SUM(usage.amount) AS total_usage,
  usage.unit AS usage_unit
FROM
  `PROJECT_ID.billing_export.gcp_billing_export_v1_XXXXXX_XXXXXX_XXXXXX`
WHERE
  _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND project.id = 'my-ai-project'
GROUP BY sku, service, usage_unit
ORDER BY total_cost DESC
LIMIT 10;
```

#### Costs by Label (Team Chargeback)

```sql
SELECT
  labels.value AS team,
  project.id AS project_id,
  SUM(cost) AS total_cost
FROM
  `PROJECT_ID.billing_export.gcp_billing_export_v1_XXXXXX_XXXXXX_XXXXXX`,
  UNNEST(labels) AS labels
WHERE
  _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND labels.key = 'team'
GROUP BY team, project_id
ORDER BY total_cost DESC;
```

### 3.3 Using Labels and Tags for Cost Allocation

Labels and Tags are essential for attributing costs to teams, workloads, and environments.

**Apply labels to resources:**

```bash
# Label a GKE cluster
gcloud container clusters update $CLUSTER_NAME \
    --zone=$ZONE \
    --update-labels=team=ml-training,env=production,workload=llm-pretraining

# Label a Compute Engine instance
gcloud compute instances add-labels $INSTANCE_NAME \
    --zone=$ZONE \
    --labels=team=ml-inference,model=gemma-27b

# Label a GCS bucket
gcloud storage buckets update gs://$BUCKET_NAME \
    --update-labels=team=ml-data,purpose=training-data
```

**Recommended label schema for AI workloads:**

| Label Key | Example Values | Purpose |
|---|---|---|
| `team` | `ml-training`, `ml-inference`, `data-eng` | Chargeback to team |
| `env` | `dev`, `staging`, `prod` | Environment separation |
| `workload` | `llm-pretraining`, `fine-tuning`, `inference` | Workload type |
| `model` | `gemma-27b`, `llama-405b` | Model being trained/served |
| `experiment` | `exp-042`, `baseline-v3` | Experiment tracking |
| `cost-center` | `cc-1234` | Finance chargeback code |

---

## 4. Budgets & Alerts

Budgets are the primary mechanism to monitor spending and receive alerts when costs approach or exceed thresholds. **Every project running AI workloads should have at least one budget.**

> **Important:** Budgets trigger alerts — they do **not** automatically cap usage or spending. To automatically control spending, see [Section 5: Programmatic Cost Controls](#5-programmatic-cost-controls).

### 4.1 Create a Per-Project Budget (Console)

1. Go to **Billing → Budgets & alerts** → [https://console.cloud.google.com/billing/budgets](https://console.cloud.google.com/billing/budgets)
2. Click **Create budget**
3. Configure:
   - **Name**: e.g., `ai-training-project-monthly`
   - **Scope**: Select the target project(s) and optionally filter by service (Compute Engine, Kubernetes Engine)
   - **Amount**: Set to a specific dollar amount or base on previous period's spend
   - **Thresholds**: Set alert rules at 50%, 75%, 90%, and 100% of budget
   - **Notifications**: Add email recipients and optionally connect a Pub/Sub topic

### 4.2 Create a Per-Project Budget (gcloud CLI)

```bash
# Set variables
export BILLING_ACCOUNT_ID="YOUR_BILLING_ACCOUNT_ID"
export PROJECT_ID="my-ai-project"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Create a monthly budget of $10,000 scoped to a specific project
gcloud billing budgets create \
    --billing-account=$BILLING_ACCOUNT_ID \
    --display-name="AI Training Project - Monthly Budget" \
    --budget-amount=10000.00USD \
    --filter-projects="projects/$PROJECT_NUMBER" \
    --filter-services="services/6F81-5844-456A,services/152E-C115-5142" \
    --threshold-rule=percent=0.5 \
    --threshold-rule=percent=0.75 \
    --threshold-rule=percent=0.9 \
    --threshold-rule=percent=1.0 \
    --threshold-rule=percent=1.0,basis=forecasted-spend
```

> **Service IDs**: `6F81-5844-456A` = Compute Engine, `152E-C115-5142` = Kubernetes Engine. Find service IDs with `gcloud billing budgets describe` or in the console.

### 4.3 Create Budgets at Scale (Budget API)

For organizations with many projects, use the Cloud Billing Budget API to create budgets programmatically:

```bash
# List all budgets for a billing account
gcloud billing budgets list --billing-account=$BILLING_ACCOUNT_ID

# Describe a specific budget
gcloud billing budgets describe BUDGET_ID --billing-account=$BILLING_ACCOUNT_ID

# Update a budget amount
gcloud billing budgets update BUDGET_ID \
    --billing-account=$BILLING_ACCOUNT_ID \
    --budget-amount=15000.00USD
```

> **Limit**: You can create up to **50,000 budgets** per Cloud Billing account using the API.

### 4.4 Alert Notification Channels

| Channel | How to Configure | Use Case |
|---|---|---|
| **Email to Billing Admins** | Default — automatically sends to Billing Account Administrators and Users | Basic alerting |
| **Email to Project Owners** | Enable "Email alerts to Project Owners" in budget settings (single-project budgets only) | Project-level awareness |
| **Cloud Monitoring email** | Link a Monitoring notification channel to the budget | Custom recipients (e.g., project managers) |
| **Pub/Sub** | Connect a Pub/Sub topic to the budget | Programmatic responses (auto-disable, Slack, PagerDuty) |

**Set up a Pub/Sub notification channel:**

```bash
# Create a Pub/Sub topic for budget alerts
gcloud pubsub topics create billing-alerts \
    --project=$PROJECT_ID

# Create a subscription for processing
gcloud pubsub subscriptions create billing-alerts-sub \
    --topic=billing-alerts \
    --project=$PROJECT_ID

# Link the topic to your budget (via console or API)
# In the budget settings, select "Connect a Pub/Sub topic"
# and enter: projects/$PROJECT_ID/topics/billing-alerts
```

### 4.5 Recommended Budget Structure for AI Projects

| Budget | Scope | Amount | Thresholds | Notifications |
|---|---|---|---|---|
| **Org-wide GPU/TPU** | All projects, Compute Engine + GKE services | Based on quarterly plan | 50%, 75%, 90%, 100%, 100% forecasted | Billing admins + Pub/Sub |
| **Per-project monthly** | Single project, all services | Project-specific allocation | 50%, 75%, 90%, 100% | Project owners + Pub/Sub |
| **Per-project GPU-only** | Single project, Compute Engine (GPU SKUs) | GPU budget allocation | 75%, 90%, 100% | Engineering lead + Pub/Sub |
| **Dev/Experiment guard** | Dev/sandbox projects | Lower limit (e.g., $500) | 80%, 100% | Project owner + auto-disable via Pub/Sub |

---

## 5. Programmatic Cost Controls

### 5.1 Auto-Disable Billing When Budget Is Exceeded

You can use Pub/Sub notifications from budgets to trigger a Cloud Function that automatically disables billing on a project — effectively shutting down all paid resources.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Budget     │────▶│   Pub/Sub    │────▶│   Cloud      │────▶│  Billing     │
│   Alert      │     │   Topic      │     │   Function   │     │  Disabled    │
│  (100%)      │     │              │     │ (disable     │     │  on Project  │
│              │     │              │     │  billing)    │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

**Cloud Function to disable billing (Python):**

```python
import json
import base64
from googleapiclient import discovery

PROJECT_ID = "my-ai-project"
PROJECT_NAME = f"projects/{PROJECT_ID}"

def stop_billing(data, context):
    """Cloud Function triggered by Pub/Sub to disable billing."""
    pubsub_data = base64.b64decode(data['data']).decode('utf-8')
    pubsub_json = json.loads(pubsub_data)

    cost_amount = pubsub_json['costAmount']
    budget_amount = pubsub_json['budgetAmount']

    if cost_amount <= budget_amount:
        print(f"No action needed. Cost: {cost_amount}, Budget: {budget_amount}")
        return

    billing = discovery.build('cloudbilling', 'v1', cache_discovery=False)

    # Disable billing on the project
    billing.projects().updateBillingInfo(
        name=PROJECT_NAME,
        body={'billingAccountName': ''}  # Empty string disables billing
    ).execute()

    print(f"Billing disabled for {PROJECT_ID}. Cost: {cost_amount} exceeded budget: {budget_amount}")
```

> **⚠️ Warning:** Disabling billing stops all paid resources immediately. This is appropriate for dev/sandbox projects but **not for production workloads**. For production, use alerts + manual review instead.

### 5.2 Capping API Usage

For services billed by API call count (e.g., Vertex AI predictions), set API usage caps:

```bash
# View current API quotas
gcloud services list --project=$PROJECT_ID --available

# Set a quota override (example: limit Compute Engine API calls)
# Navigate to: APIs & Services → Dashboard → Select API → Quotas → Edit
```

### 5.3 GKE Cost Controls with Kueue

For GKE AI workloads, [Kueue](https://kueue.sigs.k8s.io/) provides workload-level resource quotas:

```yaml
# ClusterQueue with GPU resource limits
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: gpu-training-queue
spec:
  resourceGroups:
    - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
      flavors:
        - name: a3-ultra-spot
          resources:
            - name: "nvidia.com/gpu"
              nominalQuota: 16        # Max 16 GPUs
            - name: "cpu"
              nominalQuota: 208
            - name: "memory"
              nominalQuota: 1872Gi
---
# ResourceQuota per namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
  namespace: ml-training
spec:
  hard:
    requests.nvidia.com/gpu: "8"     # Max 8 GPUs for this namespace
    requests.cpu: "104"
    requests.memory: "936Gi"
```

---

## 6. Quotas & Resource Limits

Quotas are hard limits on how many resources a project can consume. They are the most effective guard against runaway GPU/TPU costs.

### 6.1 View Current Quotas

```bash
# View all Compute Engine quotas for a project
gcloud compute project-info describe --project=$PROJECT_ID \
    --format="table(quotas.metric,quotas.limit,quotas.usage)"

# View GPU-specific quotas
gcloud compute project-info describe --project=$PROJECT_ID \
    --format="table(quotas.metric,quotas.limit,quotas.usage)" \
    | grep -i gpu

# View quotas for a specific region
gcloud compute regions describe us-central1 \
    --project=$PROJECT_ID \
    --format="table(quotas.metric,quotas.limit,quotas.usage)" \
    | grep -i gpu

# View TPU quotas
gcloud services quota list \
    --service=tpu.googleapis.com \
    --project=$PROJECT_ID
```

### 6.2 Key GPU/TPU Quotas

| Quota | Scope | Description |
|---|---|---|
| `NVIDIA_H100_GPUS` | Per region | Max H100 GPUs in a region |
| `NVIDIA_H200_GPUS` | Per region | Max H200 GPUs in a region |
| `NVIDIA_A100_GPUS` | Per region | Max A100 GPUs in a region |
| `NVIDIA_L4_GPUS` | Per region | Max L4 GPUs in a region |
| `GPUS_ALL_REGIONS` | Global | Max GPUs across all regions |
| `PREEMPTIBLE_NVIDIA_H100_GPUS` | Per region | Max Spot/preemptible H100 GPUs |
| `TPU v6e cores per project per zone` | Per zone | Max TPU v6e cores |
| `TPU v5p cores per project per zone` | Per zone | Max TPU v5p cores |
| `TPU v5 lite pod cores per project per zone` | Per zone | Max TPU v5e cores |

### 6.3 Request Quota Increases

```bash
# Request a GPU quota increase via the console
# Navigate to: IAM & Admin → Quotas → Filter by "GPU"
# Select the quota → Edit Quotas → Enter new limit → Submit

# Direct URL
# https://console.cloud.google.com/iam-admin/quotas?project=$PROJECT_ID
```

> **Best Practice:** Request only the quota you need. Lower quotas act as a natural spending cap — you physically cannot spin up more GPUs/TPUs than your quota allows.

### 6.4 Default TPU Quotas

| TPU Version | On-Demand Default | Preemptible Default |
|---|---|---|
| **v6e** | 512 cores/zone | 1,536 cores/zone |
| **v5p** | 128 cores/zone | 768 cores/zone |
| **v5e** | 512 cores/zone | 1,536 cores/zone |
| **v4** | 0 cores/zone | 0 cores/zone |

> **Note:** TPU v4 requires manual quota approval. All TPU v6e and v5p on-demand quota increases require manual approval (auto-approve threshold is 0).

### 6.5 Monitor Quota Usage with Alerts

Set up alerts when quota usage approaches the limit:

```bash
# Create a Cloud Monitoring alert for GPU quota usage
# Navigate to: Monitoring → Alerting → Create Policy

# PromQL for GPU quota utilization
# serviceruntime.googleapis.com/quota/allocation/usage
# filtered by quota_metric containing "gpu"
```

**Recommended quota alerts:**

| Alert | Condition | Threshold | Action |
|---|---|---|---|
| **GPU quota > 80%** | Usage / Limit > 0.8 | Warning | Request quota increase proactively |
| **GPU quota > 95%** | Usage / Limit > 0.95 | Critical | Immediate review — jobs may fail |
| **TPU quota > 80%** | Usage / Limit > 0.8 | Warning | Request quota increase proactively |

---

## 7. Committed Use Discounts (CUDs)

For sustained AI workloads, CUDs provide significant cost savings in exchange for a 1-year or 3-year commitment.

### 7.1 CUD Types

| CUD Type | Discount | Commitment | Best For |
|---|---|---|---|
| **Resource-based** | Up to **57%** (3-year) | Specific vCPU + memory in a region | Dedicated GPU clusters with known, steady utilization |
| **Spend-based** | Up to **52%** (3-year) | Minimum hourly spend on a service | Variable workloads across services (GKE, Cloud Run, etc.) |
| **Compute flexible** | Up to **46%** (3-year) | Spend commitment, flexible across machine families | Mixed GPU types or evolving infrastructure |

### 7.2 CUD Recommendations from FinOps Hub

The FinOps Hub provides automated CUD recommendations based on your historical usage:

1. Go to **Billing → Optimize (FinOps hub)** → [https://console.cloud.google.com/billing/optimize](https://console.cloud.google.com/billing/optimize)
2. Review the **CUD optimization rate** — this shows what percentage of eligible spend is covered
3. Click on CUD recommendations to see projected savings
4. Use the **Simulate scenarios** feature to model different commitment levels

### 7.3 CUD Analysis Dashboard

Analyze the effectiveness of your existing CUDs:

- Navigate to: **Billing → Commitments**
- Direct URL: [https://console.cloud.google.com/billing/commitments](https://console.cloud.google.com/billing/commitments)

**Key metrics to monitor:**

| Metric | Target | Action If Below Target |
|---|---|---|
| **CUD utilization rate** | > 90% | Reduce commitment or increase workload |
| **CUD coverage rate** | > 70% of eligible spend | Purchase additional CUDs |
| **Unused commitment fees** | $0 | Investigate underutilization |

### 7.4 CUD Attribution

Understand how CUD fees and credits are attributed across projects:

| Attribution Model | How It Works | Use Case |
|---|---|---|
| **Proportional** (default) | CUD fees distributed proportionally based on each project's usage | Multi-project billing accounts |
| **Prioritized** | CUD credits applied to specified projects first | When specific projects should receive discounts first |

---

## 8. Cost Optimization for AI Workloads

### 8.1 Optimization Strategies

```
┌─────────────────────────────────────────────────────────────────────────┐
│              AI Workload Cost Optimization Strategies                    │
│                                                                         │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐  │
│  │  Compute          │  │  Scheduling       │  │  Storage          │  │
│  │                   │  │                   │  │                   │  │
│  │ • CUDs (57%)      │  │ • DWS Flex-Start  │  │ • GCSFuse tuning  │  │
│  │ • Spot VMs (91%)  │  │   (53% discount)  │  │ • Rapid Cache     │  │
│  │ • Right-sizing    │  │ • Kueue priority  │  │ • Storage tiering │  │
│  │ • Idle cleanup    │  │   queues          │  │ • XLA cache       │  │
│  │ • Reservation     │  │ • Preemption-     │  │ • Lifecycle       │  │
│  │   optimization    │  │   aware checkpts  │  │   policies on GCS │  │
│  └───────────────────┘  └───────────────────┘  └───────────────────┘  │
│                                                                         │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐  │
│  │  Monitoring       │  │  Networking       │  │  Governance       │  │
│  │                   │  │                   │  │                   │  │
│  │ • Delete XProf    │  │ • Minimize cross- │  │ • Labels/Tags     │  │
│  │   VMs when idle   │  │   region traffic  │  │ • Per-project     │  │
│  │ • Filter metrics  │  │ • Use zonal       │  │   budgets         │  │
│  │   packages        │  │   storage         │  │ • Quota limits    │  │
│  │ • GCS lifecycle   │  │ • Same-zone       │  │ • Regular reviews │  │
│  │   for profiles    │  │   training        │  │ • Chargeback      │  │
│  └───────────────────┘  └───────────────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Compute Savings

| Strategy | Savings | Trade-off | When to Use |
|---|---|---|---|
| **Spot / Preemptible VMs** | Up to 91% | Can be preempted with 30s notice | Fault-tolerant training with checkpointing |
| **DWS Flex-Start** | Up to 53% | No guaranteed start time; queued | Training jobs that can wait for capacity |
| **CUDs (3-year)** | Up to 57% | Locked into commitment | Steady-state production workloads |
| **CUDs (1-year)** | Up to 46% | Locked into commitment | Workloads with 1+ year visibility |
| **Right-sizing VMs** | 10–40% | Requires profiling | Overprovisioned VMs (check FinOps Hub) |
| **Idle resource cleanup** | 100% of idle cost | Requires process/automation | Forgotten dev clusters, unused disks |

### 8.3 Storage Savings

| Strategy | How | Savings |
|---|---|---|
| **GCS lifecycle policies** | Auto-delete old checkpoints, profiles, logs after N days | Significant for multi-TB checkpoint data |
| **Storage class downgrade** | Move cold data from Standard to Nearline/Coldline/Archive | 50–95% on storage costs |
| **XLA compilation caching** | Cache to GCS; skip recompilation on restart | ~$9,100 saved per 10K experiments |
| **Rapid Cache** | Use managed zonal SSD cache instead of duplicating data | Lower operation charges + no cross-region fees |
| **Clean up XProfiler VMs** | Delete XProfiler instances when not profiling | Avoid idle compute charges |

**Set up a GCS lifecycle policy for checkpoints:**

```bash
# Create a lifecycle rule to delete objects older than 30 days
cat > /tmp/lifecycle.json << 'EOF'
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 30, "matchesPrefix": ["checkpoints/"]}
    },
    {
      "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
      "condition": {"age": 7, "matchesPrefix": ["profiles/"]}
    }
  ]
}
EOF

gcloud storage buckets update gs://$BUCKET_NAME \
    --lifecycle-file=/tmp/lifecycle.json
```

### 8.4 Monitoring Cost Savings

| Strategy | How | Savings |
|---|---|---|
| **Filter metric packages** | Only enable the metric packages you need on GKE | Reduces Cloud Monitoring costs |
| **Set appropriate sampling** | Use longer evaluation windows for non-critical alerts | Reduces false positives and metric volume |
| **Use Managed Prometheus** | Use Google Cloud Managed Prometheus instead of self-hosted | Eliminates Prometheus server costs |
| **Clean up dashboards and alerts** | Remove unused alert policies and dashboards | Reduces Cloud Monitoring SKU charges |

---

## 9. Per-Project Cost Monitoring Checklist

Every project running AI workloads should implement the following. Use this as a checklist during project setup and during periodic reviews.

### Setup Checklist

| # | Action | Command / Console Path | Priority |
|---|---|---|---|
| 1 | **Create a per-project budget** | `gcloud billing budgets create --filter-projects=projects/PROJECT_NUMBER ...` | 🔴 Critical |
| 2 | **Set alert thresholds** at 50%, 75%, 90%, 100% | Include `--threshold-rule` flags in budget creation | 🔴 Critical |
| 3 | **Enable Billing Export to BigQuery** | Billing → Billing export → BigQuery export | 🔴 Critical |
| 4 | **Apply labels** to all resources (team, env, workload) | `gcloud compute instances add-labels ...` | 🔴 Critical |
| 5 | **Review and set GPU/TPU quotas** | IAM & Admin → Quotas → Filter "GPU" or "TPU" | 🟡 High |
| 6 | **Connect Pub/Sub** to budget for programmatic alerts | Create topic + link to budget | 🟡 High |
| 7 | **Enable Anomaly Detection** email alerts | Billing → Cost Management → Anomalies | 🟡 High |
| 8 | **Review FinOps Hub recommendations** | Billing → Optimize (FinOps hub) | 🟡 High |
| 9 | **Set up GCS lifecycle policies** for checkpoints/profiles | `gcloud storage buckets update --lifecycle-file=...` | 🟢 Medium |
| 10 | **Evaluate CUD opportunities** | FinOps Hub → CUD recommendations + Simulate scenarios | 🟢 Medium |
| 11 | **Configure Kueue resource quotas** (for GKE) | Apply ClusterQueue + ResourceQuota manifests | 🟢 Medium |
| 12 | **Enable Gemini Cloud Assist** for billing insights | Enable `cloudaicompanion.googleapis.com` | 🔵 Optional |

### Periodic Review Checklist (Monthly)

| # | Review Item | What to Check |
|---|---|---|
| 1 | **Budget vs. actual** | Are any projects exceeding their budget? |
| 2 | **Idle resources** | FinOps Hub → Any idle VMs, clusters, disks, reservations? |
| 3 | **Right-sizing** | FinOps Hub → Any overprovisioned VMs or clusters? |
| 4 | **CUD utilization** | Are purchased CUDs being fully consumed? |
| 5 | **Anomalies** | Were any cost anomalies detected? Root cause? |
| 6 | **Quota headroom** | Is any project close to its GPU/TPU quota limit? |
| 7 | **Storage growth** | Is checkpoint/profile storage growing unbounded? |
| 8 | **Label compliance** | Are new resources being created with required labels? |
| 9 | **DWS/Spot utilization** | Are workloads that could use DWS/Spot doing so? |

### Quick-Start: Minimum Viable Cost Controls

For teams that want the fastest path to cost visibility and guardrails:

```bash
# 1. Set your project
export PROJECT_ID="my-ai-project"
export BILLING_ACCOUNT_ID="YOUR_BILLING_ACCOUNT_ID"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# 2. Create a $5,000/month budget with alerts
gcloud billing budgets create \
    --billing-account=$BILLING_ACCOUNT_ID \
    --display-name="${PROJECT_ID}-monthly" \
    --budget-amount=5000.00USD \
    --filter-projects="projects/$PROJECT_NUMBER" \
    --threshold-rule=percent=0.5 \
    --threshold-rule=percent=0.75 \
    --threshold-rule=percent=0.9 \
    --threshold-rule=percent=1.0

# 3. Label the project
gcloud projects update $PROJECT_ID \
    --update-labels=team=ml-training,env=dev

# 4. Check current GPU quotas
gcloud compute project-info describe --project=$PROJECT_ID \
    --format="table(quotas.metric,quotas.limit,quotas.usage)" \
    | grep -i gpu

# 5. View current spend
# Open: https://console.cloud.google.com/billing/reports
```

---

## 10. References

### Budgets & Alerts

- [Create Cloud Billing Budgets](https://cloud.google.com/billing/docs/how-to/budgets) — Console and API budget creation
- [Cloud Billing Budget API Overview](https://cloud.google.com/billing/docs/how-to/budget-api-overview) — Programmatic budget management at scale
- [Customize Budget Alert Recipients](https://cloud.google.com/billing/docs/how-to/budgets-notification-recipients) — Email, Monitoring, Pub/Sub
- [Programmatic Budgets Notifications](https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications) — Pub/Sub integration
- [Disable Billing with Notifications](https://cloud.google.com/billing/docs/how-to/disable-billing-with-notifications) — Auto-disable billing via Cloud Functions

### Cost Visibility & Analytics

- [Cloud Billing Reports](https://cloud.google.com/billing/docs/how-to/reports) — Console-based cost reporting
- [Export Billing Data to BigQuery](https://cloud.google.com/billing/docs/how-to/export-data-bigquery) — Standard, detailed, and pricing exports
- [BigQuery Export Schema — Standard Usage](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage) — Schema and query examples
- [BigQuery Export Schema — Detailed Usage](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/detailed-usage) — Resource-level detail
- [Anomaly Detection](https://cloud.google.com/billing/docs/how-to/manage-anomalies) — Auto-detect cost spikes

### FinOps Hub & Optimization

- [FinOps Hub](https://cloud.google.com/billing/docs/how-to/finops-hub) — Centralized cost optimization dashboard
- [Gemini Cloud Assist in Cloud Billing](https://cloud.google.com/billing/docs/how-to/gemini/overview) — AI-powered billing insights
- [Google Cloud Well-Architected Framework: Cost Optimization](https://cloud.google.com/architecture/framework/cost-optimization) — Best practices

### Committed Use Discounts

- [Committed Use Discounts Overview](https://cloud.google.com/docs/cuds) — CUD types and pricing
- [CUD Analysis Dashboard](https://cloud.google.com/billing/docs/how-to/cud-analysis) — Analyze CUD effectiveness
- [CUD Attribution](https://cloud.google.com/docs/cuds-attribution) — Proportional and prioritized attribution
- [CUD Metadata Export](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/cud-export) — Export CUD data to BigQuery

### Quotas

- [Compute Engine Quotas & Limits](https://cloud.google.com/compute/quotas-limits) — GPU quotas per region
- [Cloud TPU Quotas](https://cloud.google.com/tpu/docs/quota) — TPU core quotas per zone
- [Request a Quota Increase](https://cloud.google.com/docs/quotas/help/request_increase) — How to request more
- [Quota Adjuster](https://cloud.google.com/docs/quotas/quota-adjuster) — Automate quota adjustments
- [Cloud Quotas Overview](https://cloud.google.com/docs/quotas/overview) — How quotas work

### Related Sections in This Repository

- [Accelerator Guide](../01-foundational-tools/accelerator-guide/README.md) — GPU selection and sizing (impacts cost)
- [DWS Guide](../03-deploying-workloads/dws/README.md) — DWS Flex-Start for up to 53% discount
- [Cluster Toolkit](../03-deploying-workloads/gke-ai-hypercompute/cluster-toolkit/README.md) — Reservation-bound and Spot GKE clusters
- [Storage Guide](../02-core-infrastructure/storage/README.md) — GCSFuse, Rapid Cache, storage tiering
- [Monitoring & Observability](../04-monitoring-observability/README.md) — Monitoring cost optimization strategies

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Setting a budget does **not** automatically cap Google Cloud usage or spending — budgets only trigger alerts. Always follow your organization's financial governance policies and review configurations before deploying in production environments. Refer to the [official Google Cloud Billing documentation](https://cloud.google.com/billing/docs) for the latest information.
