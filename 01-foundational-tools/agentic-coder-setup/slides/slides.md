---
marp: true
html: true
theme: gps-onboarding
paginate: true
title: Agentic Coder Setup → fast-science L0
---

<!--
Copyright 2026 Google LLC
Licensed under the Apache License, Version 2.0
-->

<!-- _class: title -->

# Agentic Coder Setup
## → fast-science L0 in 3 installs + 1 prompt

Google Cloud × *<your university>*
*<date>* · *<presenter>*

---

<!-- _class: compact -->

## What we're doing — *you* (yellow) → *cline* (blue)

| | | |
|:-:|:-:|:-:|
| | 🟡 **Prereqs** — GCP Org · Workspace · Billing · 5 IAM groups · ≤7-char prefix | |
| | ↓ ↓ ↓ | |
| 🟡 Install gcloud SDK<br/>+ `auth login` + ADC | 🟡 Install VS Code<br/>+ Cline extension | 🟡 Enable Claude Opus 4.6<br/>in Vertex Model Garden |
| ↘ | ↓ | ↙ |
| | 🟡 **Configure Cline → Vertex AI**<br/>Project ID · region · model | |
| | ↓ | |
| | ⭐ **ONE pasted prompt** | |
| | ↓ ↓ ↓ | |
| 🔵 Cline wires MCPs<br/>from template | 🔵 Cline installs<br/>Claude Code CLI | 🔵 Cline drives fast-science L0<br/>questionnaire + `terraform apply` 0→3 |

---

<!-- _class: section yellow -->

# Before you arrive

## Bring your own GCP Org

---

## Prereqs (links only — not taught here)

You need an existing **GCP Organization** with all of the below in place. If any are missing, email your contact so they can sort it before the day.

- **Verified domain** (e.g. `university.edu`) tied to **Google Workspace** or **Cloud Identity** — [setup checklist](https://cloud.google.com/docs/enterprise/setup-checklist)
- **Billing account** linked and accessible — [console.cloud.google.com/billing](https://console.cloud.google.com/billing)
- **Five IAM groups** in your domain: `gcp-billing-admins`, `gcp-devops`, `gcp-vpc-network-admins`, `gcp-organization-admins`, `gcp-security-admins`
- **Bootstrap "seed" project** in the org, billing linked, you're an `Owner`
- **A ≤7-character alphanumeric prefix** chosen (e.g. `univ`) — flows through every resource name automatically

---

<!-- _class: section green -->

# Live install

## ~15 minutes · three things in parallel

---

## 1 · Install gcloud SDK + auth

Install per OS: [cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)

Then authenticate **both ways** — ADC is required by the Cloud Logging and GCS MCPs later. Don't skip the second line:

```bash
gcloud auth login
gcloud auth application-default login
```

Verify you can see your Org:

```bash
gcloud organizations list
gcloud config set project <YOUR_BOOTSTRAP_PROJECT_ID>
```

---

## 2 · Install VS Code + Cline extension

Install **VS Code** ([code.visualstudio.com](https://code.visualstudio.com/)) — or use **Cloud Workstations** Code OSS in the browser.

Inside VS Code:

1. Open Extensions (`Ctrl+Shift+X` / `Cmd+Shift+X`)
2. Search **`Cline`** — publisher must be **`saoudrizwan`**
3. Click **Install**

<img src="visuals/cline-settings.png" width="320" style="border:1px solid #ccc; border-radius:4px;" />

---

## 3 · Enable Claude in Vertex Model Garden

Open [Anthropic Claude Opus 4.6 in Model Garden](https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-opus-4-6).

Enable the Vertex AI API if prompted, then fill out the access form on the Anthropic listing.

Approval can take **minutes to hours** — start this **first** so it's ready by the time you finish 1 and 2.

> *Cline-on-Vertex uses **Claude Opus 4.6** (latest in Model Garden). The Claude Code CLI uses **Opus 4.7** via the same Vertex backend. Different surfaces, different model IDs — expected.*

---

## Configure Cline → Vertex AI

Open Cline in the side panel. Click **"I have my own API key"**, then the gear icon to open settings.

Set:

- **Provider**: `Vertex AI`
- **Project ID**: your bootstrap project ID
- **Region**: `us-east5` (or `global` if approved)
- **Model**: `claude-opus-4-6`
- **Terminal → Background Exec**: ON

<img src="visuals/cline-terminal-settings.png" width="320" style="border:1px solid #ccc; border-radius:4px;" />

---

<!-- _class: section -->

# Cline takes the wheel

## You stop typing. The agent installs the rest, then deploys the landing zone.

---

<!-- _class: compact -->

## The prompt — paste verbatim

Open this repo (`GPS-AI-Infra-Onboarding-Workshop`) in VS Code, then paste into a new Cline task:

> **Set up MCP servers, install Claude Code CLI, then deploy a fast-science L0 landing zone.**
>
> 1. Read `01-foundational-tools/agentic-coder-setup/cline/cline_mcp_settings.template.json` and wire each MCP server per its `_install` field. Ask me for the HuggingFace read token, GitHub PAT, and Google Dev Knowledge API key as needed. Generate the final `cline_mcp_settings.json`.
>
> 2. Run `01-foundational-tools/agentic-coder-setup/cli-agent/claude-code/setup.sh <MY_PROJECT_ID>` to install the Claude Code CLI on the Vertex AI backend (region `global`, model `claude-opus-4-7[1m]`).
>
> 3. Clone `https://github.com/WandLZhang/fast-science-0-stellar-engine`. Walk me through its 18-row Deployment Questionnaire interactively. Write my answers into `terraform.tfvars` and `data/*.yaml`, then run `terraform apply` for stages 0 → 3, including the two-pass `bootstrap_user` flow on stage 0.
>
> Stop and ask me before any `terraform apply` and before anything destructive.

---

<!-- _class: compact -->

## What you should see — Cline asks for these in order

| Cline asks | Maps to |
|------------|---------|
| HuggingFace read token | `huggingface` MCP env |
| GitHub PAT | `github-mcp-server` env |
| Google Dev Knowledge API key | `google-dev-knowledge` MCP env |
| **Prefix** (≤7 chars, alphanumeric) | `prefix` |
| **Org ID, customer ID, domain** | `organization.{id, customer_id, domain}` |
| **Billing account ID** | `billing_account.id` |
| **Primary + secondary region** | `regions.{primary, secondary}` |
| **Alert email** | `alert_email` |
| **Compliance regime** (`FEDRAMP_HIGH` / `IL5` / `IL4` / `_UNSPECIFIED`) | `assured_workloads.regime` |
| **Bootstrap project ID** | `bootstrap_project` |
| **5 IAM group names** | `groups.{billing-admins, devops, vpc-network-admins, organization-admins, security-admins}` |
| **Environments** (`Prod` only vs `Prod + Int + Test`) | `envs_folders` (stage 1) |
| **Networking topology** (`NCC` recommended, `NVA` if L7 inspection) | stage 2 dataset choice |
| **On-prem connectivity?** (`N` / VPN / Interconnect) | stage 2 VPN/VLAN config |

Being prompted **is** the happy path. If Cline starts inventing values, stop it and re-paste.

---

<!-- _class: compact -->

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Path `01a-agentic-coder-setup/...` not found" | README has a stale `01a-` prefix. The real folder is `agentic-coder-setup/` (no prefix). Use the corrected path in the prompt above. |
| `github-mcp-server` install fails on Mac / Apple Silicon | Upstream binary is **Linux x86_64-only**. Skip github-mcp on Mac, or run via Cloud Workstation. |
| Vertex Model Garden form is "pending" | Approval can take hours. Continue to **Configure Cline** anyway — it'll fail at first agent call, retry once approved. |
| Stage 0 `terraform apply` errors on group lookups | Your 5 IAM groups don't exist in the domain yet. Create them in [admin.google.com](https://admin.google.com) (Workspace) or the Cloud Identity console, then re-apply. |
| Cline tries to use API key auth | Switch back to "I have my own API key" → gear → Vertex AI provider. The Cloud Logging + GCS MCPs need ADC, not an API key. |
| Stage 0 errors on `bootstrap_user` not removed | The two-pass flow: first apply *with* `bootstrap_user = "user@domain"`, then remove that line and re-apply. |

<script>document.querySelectorAll('a[href^="http"]').forEach(a=>a.target='_blank')</script>
