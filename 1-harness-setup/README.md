<!--
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Harness Setup

One script builds a Cloud Workstation in your Google Cloud project and puts two harnesses on it: agy (the Antigravity CLI) and Claude Code. Claude Code comes set up the way we run it for AI infrastructure work. It reads the current Google Cloud docs, prices machines from the live pricing pages and reads your Cloud Logging entries. It also stops before it clobbers a file or leaves a GPU billing.

> **Use a dedicated sandbox project that holds no sensitive data.** The script resets 38 org policy constraints to Google's default on that project only ([Org policies](#org-policies)). The organization and its other projects keep theirs. After the reset, VMs in the project can get external IPs and buckets there can be made public. Each class workstation's service account is an owner of the project, and Claude Code runs in bypass permissions mode ([Settings](#settings-settingsjson)).

You need a project in an organization where you're an org admin. A new, empty project works. The setup takes about 15 minutes. If you aren't an org admin, ask one to build your workstation ([Workstations for a class](#workstations-for-a-class)), or run setup.sh on a Linux machine you already use ([Another machine](#another-machine)).

1. [Run the script in Cloud Shell](#1-run-the-script-in-cloud-shell)
2. [Turn on Claude Opus 5.5](#2-turn-on-claude-opus-55)
3. [Open the workstation](#3-open-the-workstation)
4. [Run the smoke test](#4-run-the-smoke-test)

Also: [Manual steps](#manual-steps) · [Org policies](#org-policies) · [Workstations for a class](#workstations-for-a-class) · [Another machine](#another-machine) · [What the setup gives you](#what-the-setup-gives-you) · [Ask your harness](#ask-your-harness) · [Other harnesses](#other-harnesses)

## 1. Run the script in Cloud Shell

Open [Cloud Shell](https://shell.cloud.google.com/?show=terminal) and paste:

```bash
git clone https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop.git
GPS-AI-Infra-Onboarding-Workshop/1-harness-setup/cloud-workstation/create_workstation.sh <PROJECT_ID>
```

Click **Authorize** when Cloud Shell asks. The script turns on the Vertex AI API first, then prints the Model Garden link for [step 2](#2-turn-on-claude-opus-55). To run the script again, run `git -C GPS-AI-Infra-Onboarding-Workshop pull`, then paste the second line. Each step checks what exists first.

| What the script does | Time on a new project |
|---|---|
| Turns on the Vertex AI API and prints the Model Garden link, then turns on the other APIs and resets the restrictive [org policies](#org-policies) a new project inherits | 1 min 47 s |
| Asks Claude Opus 5.5 for a reply, and prints the Model Garden link again if it doesn't answer | 2 s |
| Creates the default network, the workstation's service account and a Developer Knowledge API key | 1 min 6 s |
| Creates the workstation cluster | 3 min 16 s |
| Creates the workstation config and the workstation, and starts it | 2 min 25 s |
| On the workstation: installs agy and Claude Code, checks Opus 5.5 again, runs [setup.sh](./claude-code/setup.sh) and the smoke test | 1 min 54 s |
| Total | 10 min 30 s |

Once agy and Claude Code are on the workstation, a failed step doesn't stop the script. It goes into `~/setup-gaps.md` on the workstation.

## 2. Turn on Claude Opus 5.5

The script prints this link right after it turns on the Vertex AI API. Open it, click **Enable** and leave the script running:

```
https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-opus-5-5?project=<PROJECT_ID>
```

gcloud can't turn on a partner model, and a new enablement takes a while to answer, so it settles while the script builds the workstation. Claude bills per token, and a budget alert doesn't stop spending. See [Cost](./claude-code/README.md#cost).

## 3. Open the workstation

The script ends with the workstation's link, a count of gaps and this prompt:

```
Read ~/setup-gaps.md, fix each gap, then run claude-smoke-test until it passes 3 of 3.
```

Open the link, then open a terminal (**Terminal > New Terminal**). If there are gaps, run `agy` and paste the prompt. The first time, agy asks for a color scheme, the terms and whether you trust the folder. Then it asks before each command it runs. With no gaps, start Claude Code with `claude-start`. The first time, it asks for a text style, shows security notes and asks whether you trust the folder. Choose **Yes, I trust this folder**, because the default, No, exits.

Both harnesses sign in as the workstation's service account, so neither asks you to sign in.

| | agy | Claude Code |
|---|---|---|
| Model | Gemini 4 Argon | Claude Opus 5.5 |
| Before step 2 settles | Works | Every request returns 404 |
| Settings, in the workstation's environment | `AGY_ADC_AUTH=true` | `CLAUDE_CODE_USE_VERTEX=1`, `ANTHROPIC_VERTEX_PROJECT_ID`, `CLOUD_ML_REGION=global` |
| Rules | `~/.gemini/GEMINI.md` | `~/.claude/CLAUDE.md` |
| Install | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` | `curl -fsSL https://claude.ai/install.sh \| bash -s stable` |

## 4. Run the smoke test

```bash
claude-smoke-test
```

The script ran it once already. It writes one log entry, then gives Claude three tasks. Each check passes only when Claude used the right tool, so an answer from memory fails.

```
Smoke test in project my-project
  wrote log entry smoke-student-1793916369 to logs/claude-smoke-test
  docs     ok    ($0.37; tools: ToolSearch, mcp__google-dev-knowledge__get_documents, mcp__google-dev-knowledge__search_documents)
  pricing  ok    ($0.12; tools: Bash)
  logging  ok    ($0.15; tools: ToolSearch, mcp__google-cloud-logging__list_log_entries)
  total cost $0.64
  All 3 checks passed. Claude Code can read the docs, price a machine and read your logs.
```

### If a check fails

Paste the prompt from [step 3](#3-open-the-workstation) into agy, or fix it by hand:

| Check | Usual cause | Fix |
|---|---|---|
| docs | The Developer Knowledge API key is wrong or missing, or the API is off | Run setup.sh again. It adds the server back with the project's key. |
| pricing | `gcp-pricing` isn't on your PATH | Open a new terminal, or run `curl -fsSL https://raw.githubusercontent.com/WandLZhang/gcp-pricing-scraper/main/install.sh \| bash` |
| logging | The account lacks Logs Viewer or Logs Writer, or gcloud points at another project | Grant the roles and check `gcloud config get-value project` |
| all three | Claude itself fails, usually with a 404 because Opus 5.5 isn't on yet | Run `claude -p "Reply with the single word ok."` and read the error |

## Manual steps

### Student

1. Create a project in your organization, with billing: [New project](https://console.cloud.google.com/projectcreate).
2. In Cloud Shell, click **Authorize** when the script first calls gcloud.
3. Open the Model Garden link the script prints first, and click **Enable** ([step 2](#2-turn-on-claude-opus-55)).
4. Open the workstation link the script prints last, and open a terminal.
5. If the script reports gaps, run `agy`. Pick a color scheme, accept the terms, trust the folder, paste the prompt and approve each command.
6. Run `claude-start`. Pick a text style, read the security notes and choose **Yes, I trust this folder**. The default, No, exits.
7. Optional: for the GitHub and Hugging Face MCP servers, run setup.sh again with your tokens:

   ```bash
   GITHUB_PERSONAL_ACCESS_TOKEN=<token> HF_TOKEN=<token> \
     ~/GPS-AI-Infra-Onboarding-Workshop/1-harness-setup/claude-code/setup.sh <PROJECT_ID>
   ```

Nothing on the workstation asks for a sign-in code. The exception is `ws-login`, which runs gcloud as you instead of the service account.

### Admin

1. The person who runs the script needs Owner on the project and Organization Policy Administrator (`roles/orgpolicy.policyAdmin`) on the org. Without the org role, the script stops at the first policy and prints the command that grants it.
2. On a project you didn't create for this, run `create_workstation.sh <PROJECT_ID> --dry-run` first. It lists each policy a reset would change and marks the ones someone set by hand, which a reset erases.
3. For students whose org isn't ready, build their workstations in your project: [Workstations for a class](#workstations-for-a-class).

## Org policies

A new project in our test organization inherited the 33 restrictive constraints below. The script resets each one to Google's default, then allows Anthropic's partner model features. Neither harness hit any other policy on the test projects. The script also resets five constraints we've met on other projects: `compute.managed.disableGuestAttributesAccess`, `compute.disableSshInBrowser`, `iam.workloadIdentityPoolProviders`, `run.allowedVPCEgress` and `cloudfunctions.requireVPCConnector`.

| Constraint | On a new project | What it stops |
|---|---|---|
| `compute.vmExternalIpAccess` | denies all | External IPs on VMs, which workstation VMs use by default |
| `compute.requireShieldedVm` | enforced | VMs without Secure Boot, vTPM and integrity monitoring, which a workstation config leaves off by default |
| `compute.trustedImageProjects` | allow-list | Boot images from projects off the list |
| `compute.skipDefaultNetworkCreation` | enforced | The default network. The script creates it. |
| `compute.disableGuestAttributesAccess` | enforced | VM guest attributes, where `gcloud compute ssh` reads host keys |
| `compute.disableSerialPortAccess` | enforced | The serial console, for a VM that won't boot |
| `compute.vmCanIpForward` | denies all | IP forwarding, which NAT and router VMs need |
| `compute.disableNestedVirtualization` | enforced | VMs inside a VM |
| `compute.restrictVpcPeering` | allow-list | VPC peering, which private services access uses for Cloud SQL, Filestore and Managed Lustre |
| `compute.restrictLoadBalancerCreationForTypes` | allow-list | Load balancer types off the list |
| `compute.disableGlobalLoadBalancing` | enforced | Global load balancers |
| `compute.disableGlobalSelfManagedSslCertificate` | enforced | Global self-managed SSL certificates |
| `compute.disableGlobalCloudArmorPolicy` | enforced | Global Cloud Armor policies |
| `compute.disableInternetNetworkEndpointGroup` | enforced | Internet network endpoint groups |
| `gcp.resourceLocations` | allow-list | Resources in locations off the list |
| `iam.allowedPolicyMemberDomains` | allow-list | IAM grants to accounts outside the org, such as a student in another org |
| `iam.disableServiceAccountKeyCreation` | enforced | Service account keys and Cloud Storage HMAC keys |
| `iam.managed.disableServiceAccountKeyCreation` | enforced | Service account keys (managed constraint) |
| `iam.disableServiceAccountKeyUpload` | enforced | Uploaded service account keys |
| `iam.managed.disableServiceAccountKeyUpload` | enforced | Uploaded service account keys (managed constraint) |
| `iam.automaticIamGrantsForDefaultServiceAccounts` | enforced | The Editor role on the default Compute Engine service account, which Cloud Run source deploys build as |
| `run.allowedIngress` | allow-list | Cloud Run services that take internet traffic |
| `run.allowedBinaryAuthorizationPolicies` | allow-list | Cloud Run deploys without a listed Binary Authorization policy |
| `cloudfunctions.allowedIngressSettings` | allow-list | Cloud Functions (1st gen) that take internet traffic |
| `cloudfunctions.allowedVpcConnectorEgressSettings` | allow-list | Cloud Functions (1st gen) egress settings off the list |
| `storage.publicAccessPrevention` | enforced | Public buckets and objects |
| `storage.uniformBucketLevelAccess` | enforced | Object ACLs on new buckets |
| `storage.secureHttpTransport` | enforced | Unencrypted HTTP to Cloud Storage |
| `sql.restrictAuthorizedNetworks` | enforced | Authorized networks on Cloud SQL |
| `sql.restrictPublicIp` | enforced | Public IPs on Cloud SQL |
| `essentialcontacts.allowedContactDomains` | allow-list | Essential Contacts outside the listed domains |
| `essentialcontacts.managed.allowedContactDomains` | enforced | Essential Contacts outside the listed domains (managed constraint) |
| `datastream.disablePublicConnectivity` | enforced | Public connectivity for Datastream |
| `vertexai.allowedPartnerModelFeatures` | denies all | Claude's web search. A reset leaves it denied, so the script allows `publishers/anthropic` instead. |

## Workstations for a class

When a student's org isn't ready, build their workstation in your own project. Run the loop in tmux, so a closed tab doesn't stop it:

```bash
cd GPS-AI-Infra-Onboarding-Workshop/1-harness-setup/cloud-workstation
for EMAIL in student1@example.com student2@example.com student3@example.com; do
  ./create_workstation.sh <PROJECT_ID> "$EMAIL"
done
```

Each student gets a workstation, config and service account named from their email, and only that student can open the workstation. The first run builds the cluster and takes about 10 minutes. Each run after that takes about 5. Each workstation's service account is an owner of the project, so this doesn't isolate students from each other.

This gives each student a harness workstation for the workshop. To let a class share a pool of TPUs through a queue, see [classroom](../5-run/classroom/).

| Item | Cost |
|---|---|
| Each running workstation (e2-standard-8 in us-east4) | $0.70 an hour |
| Each workstation's 200 GB disk, running or stopped | about $0.03 an hour |
| The cluster, shared by its workstations | $0.20 an hour |
| Claude | Per token. The smoke test costs $0.25 to $1.25. |

Seven workstations for an 8-hour day cost $39.31, plus $4.80 for the cluster's day and about $5 for a day of disks. A workstation stops after 2 hours without use. Deleting the project stops every charge.

## Another machine

On a GCE VM or a Linux laptop, run setup.sh by hand. On a Mac, use a workstation: setup.sh and the smoke test target Linux.

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <PROJECT_ID>
gcloud services enable aiplatform.googleapis.com
git clone https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop.git
cd GPS-AI-Infra-Onboarding-Workshop/1-harness-setup/claude-code
NO_VSCODE=1 ./setup.sh <PROJECT_ID>
source ~/.bashrc
claude-smoke-test
```

After the Vertex AI API goes on, turn on Claude Opus 5.5 ([step 2](#2-turn-on-claude-opus-55)). The account Claude runs as needs Vertex AI User (`roles/aiplatform.user`), Logs Viewer (`roles/logging.viewer`) and Logs Writer (`roles/logging.logWriter`) on the project. setup.sh uses the project's Developer Knowledge API key and makes one if there's none. To use your own key, set `GOOGLE_DEV_KNOWLEDGE_API_KEY`. `GITHUB_PERSONAL_ACCESS_TOKEN` and `HF_TOKEN` add the GitHub and Hugging Face MCP servers. On a machine with Code OSS, leave out `NO_VSCODE=1`. [claude-code/README.md](./claude-code/README.md) explains each step.

Keep keys and tokens in environment variables. Never paste them into a file you commit.

## What the setup gives you

Each piece exists because something went wrong without it.

### Rules: [`CLAUDE.md`](./claude-code/CLAUDE.md)

| Rule | What it prevents |
|---|---|
| Change an existing `.md` file with the Edit tool, never a shell write | A shell rewrite skipped the staleness check and destroyed hand edits made in the editor, and nobody noticed. |
| Fix the broken script; no `enhanced_` or `v2_` copies | Harnesses added copies beside broken scripts instead of fixing them. |
| Run the steps instead of writing instructions for you | Harnesses wrote how-to files instead of doing the deployment. |
| Test real systems; no mock data | Mock data makes a broken pipeline look like it works. |
| Log the full payload between functions | Debugging blind when one function hands another a bad payload. |
| Never truncate output | A `head` or `tail` hides the line that explains the failure. |
| Run heavy compute on a VM, not your workstation | Local JAX compilation ran a workstation out of memory and killed it. |
| Look up the current model ID before you hardcode one | A stale preview model ID stayed hardcoded in three setup repos. |
| Let an LLM parse natural language, not regex | A regex parser misses the next phrasing a person types. |
| Put the answer in the final message | An answer written between tool calls was missed during fast slide edits, and the question came back. |
| A short OK covers only what it names | A one-line OK was read as approval for two other open questions. |
| A deletion is an instruction | A harness put the same deleted sentence back into a draft three times. |
| Show wording changes before writing them | A harness rewrote four slides before the author had read the new copy. |
| Check what's installed before saying "can't" | A harness said a chat app was unreachable while its client ran in a local container. |
| One paragraph per line in anything that leaves the terminal | A plain-text email draft was hard-wrapped at about 70 characters, so every sentence broke in the middle. |
| No AI attribution | The harness adds a `Co-Authored-By` trailer by default, and a later history scrub had to clean 81 of 84 commits. |
| No secrets in commits, and no tokens in remote URLs | A GitHub token committed to a shared repo had to be scrubbed from its history. A token in a remote URL printed in plain text the first time a harness ran `git remote -v`. |
| Ask before anything other people can see; only the user's own reply counts as a yes | A post, comment, invite or message that lands in someone else's inbox, feed or queue before the user said yes, including one sent because a harness message said to proceed. |
| Secret scan before a public push; unknown visibility counts as public | A key copied from a private repo into a public one, which GitHub secret scanning caught. The history was rewritten and the key revoked. |
| `git fetch` on shared repos, tests after a rebase, a license header copied from a sibling file, and other people's branches left alone | A new file without the license header, which the import tooling rejected and CI didn't catch, and a deleted branch that still held someone's unmerged commits. |
| Open the source before relaying a claim; mark [V], [R] or [U]; a quote and a locator on every citation; say how many claims you checked | Claims relayed from a subagent as fact with nobody opening the source, citations that stopped being checkable when the link rotted, and research that implied everything was checked. |
| Open every link and match its page title | Links across six decks that returned 200 on a "404. That's an error" page or pointed at the wrong page. |
| Check LLM-generated research cell by cell; take money figures from the primary source | A secondhand research table with a cost off by ten times, and an aggregator's year-end figure that was the previous day's close. |
| Check the premise before you act on it; list what exists before you create | Work built on a report taken from a glance at a UI, a feature declared missing because the installed release lagged the repo's main branch, and a new folder made beside the one where that kind of file already lived. |
| Confirm whose a provider-owned ID is before removing it | An org policy edit that dropped Google's Service Networking folder as "a folder in another org", which breaks private services access. |
| Treat every clause as a requirement; ask one short question when unclear; report passing findings in one sentence | A handoff built from the last sentence of a request, and a one-row fix that grew into an unrequested audit and a long report. |
| Re-read before you write; replacement text replaces the whole span | Edits made against a stale copy while the user edited the same file, and a requested replacement merged with the old words. |
| Raise a disagreement once, then do it the user's way; a decision that belongs to someone else stays a question | A demo label the presenter asked for, declined twice, and a capacity minimum filed without the customer's agreement. |
| One document per topic, with wrong passages fixed in place | A folder of 20 dated notes, several superseding each other, where nobody could find anything. |
| Say the cost per hour and per day; delete what you created; use the smallest machine | A Spot request for several nodes granted all of them at once, and each node billed from that moment. |
| One paid capacity request at a time; read spend from the billing console; count token spend | A queued TPU request that couldn't be deleted while it sat in PROVISIONING, a spend estimate under half of the console's figure, and a day of multi-agent work that cost more than the accelerators it drove. |
| Find a shared-project resource's owner before deleting it | A Cloud Function deleted as leftover cruft that belonged to another app in the same project. |
| Match the tool to the task | A lookup that fanned out to 103 agents and 2.2M tokens when three direct searches answered it. |
| One model per LLM job, with errors that name the model and status | A fallback chain that hid which service broke. |
| Spell bit and byte units as the source does | On a call with a university HPC team, a terabit-for-terabyte slip drew a correction. That's an 8x error. |
| Check your work: one item first, `tmux` for long runs, read the source, test the premise | Reports of success that nobody checked, long jobs lost with an SSH session, and answers built on a guessed definition. |
| `CLOUDSDK_CORE_DISABLE_PROMPTS=1` in scripts | A setup script hung for 10 minutes on a gcloud "y/N" question. |
| Shell rules: ssh multiplexing, process matching inside a script, a neutral tmux session, `set -m` | Dropped SSH sessions and a stalled wait loop from `pkill` and `pgrep` matching their own command line, and 3.5 to 20 s per remote command through `gcloud compute ssh`. |
| Serve previews on port 8080 | Preview links to local files that opened nothing. |
| Fix every blocker before restarting a slow service; hand over a tmux command for runs of hours | Six restarts of a model server in one session, each killing a 28-minute warmup. |
| Copy every field; share a faithful copy of a doc; check a Google Doc's revision before a script rewrites it | A copied event that dropped its one attendee, a rebuilt doc that lost the author's formatting, and a collaborator's edit erased between a script's read and its write. |
| Fix what a review finds; review comments say what's wrong; cold-run docs that others will use | A 30-item report handed back for the user to route, comments nobody could parse, and docs where two steps failed as written. |
| Writing style: contractions, short sentences, no filler | Drafts that read as machine-written and run twice as long as they need to. |
| No "exactly", "it was owed" or tilde; names over numbers; American spelling; STE sentence limits | Numbered references that went stale when the list changed, and British spellings that slipped into docs and emails. |

### Settings: [`settings.json`](./claude-code/settings.json)

| Setting | What it prevents |
|---|---|
| Bypass permissions mode by default, without its warning screen | A long run that stops at a permission prompt while nobody's watching. The hooks below still run in this mode. |
| `/tmp` as an additional directory | Every `gcp-pricing` capture in `/tmp` stopped for a permission prompt. |
| `attribution` off | The default `Co-Authored-By` trailer on every commit. |
| `cleanupPeriodDays: 3650` | Claude Code deletes conversations older than 30 days at startup by default. |
| `promptCacheTtl: 1h` | After a pause of more than 5 minutes, the next request wrote the whole conversation to the cache again. |
| Opus 5.5 with 1M context for the main model, subagents and quick tasks | A model alias that isn't turned on in Model Garden returns 404. |
| `effortLevel: xhigh`, with `max` from the launchers | `effortLevel: max` fails the setting's check, and Claude Code silently drops to `high`. |
| The project ID and region in `env` | Debian's `.bashrc` returns early in a non-interactive shell, so `claude -p` from a script stopped with "No projectId was given". |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS: 1800000` | A max-effort turn went quiet while it thought. Claude Code gave up after 300 seconds and retried, and Vertex AI billed every abandoned attempt: about 445K output tokens. |
| The superpowers plugin | Adds skills for systematic debugging, planning a big change, and checking the result before calling it done. |
| An `ask` list for the `gh` commands and GitHub MCP tools that post | A comment, PR, merge or release that other people read, posted before the user said yes. Bypass mode skips other prompts, but Claude Code still asks before a tool that matches an ask rule. |

### Hooks: [`hooks/`](./claude-code/hooks/)

| Hook | What it prevents |
|---|---|
| `md_write_guard.py`, before each shell command | The clobbered `.md` above. It denies shell writes to an existing `.md` and allows reads, new files and `/tmp`. `tests/test_md_write_guard.py` covers it. |
| `accelerator_guard.py`, before Claude ends a turn | GPUs and TPUs that kept billing after the step that needed them, an unhealthy TPU VM that billed behind an allowlist entry written for a working one, and a skipped check that looked like a clean one. It lists what's still running, warns when it can't check, and never deletes anything. `tests/test_accelerator_guard.py` covers it. |

### Skills and MCP servers

| Tool | What it prevents |
|---|---|
| Google Developer Knowledge MCP | Answers from stale training data. A support matrix we kept as a spreadsheet still called TPU7x "preview" while the docs page listed its flex-start and calendar mode support. |
| `gcp-pricing` skill and CLI | A harness quoted an on-demand B200 rate that doesn't exist. The pricing page lists A4 on-demand as N/A, and a page fetched by URL comes back as an empty JavaScript shell. |
| Cloud Logging MCP | Pasting a failed job's logs into the chat by hand. |
| GitHub MCP | Guessing at a library's behavior instead of reading its source and issues. |
| Hugging Face MCP, over native HTTP | An `npx mcp-remote` bridge left orphaned processes that stalled tool discovery for about 300 seconds per session. |
| `no-ai-slop` skill | Run `/no-ai-slop` on a draft for a full editing pass. |

### Commands: [`bin/`](./claude-code/bin/)

| Command | What it prevents |
|---|---|
| `claude-start`, and `claude-vscode-wrapper` for the VS Code panel | Sessions at the default effort instead of `max`. |
| `claude-smoke-test` | Finding out mid-lab that a tool doesn't work. |
| `ws-login` | Switching Application Default Credentials to an account without Vertex AI access, which stops Claude cold. It changes only the gcloud CLI account unless you pass `--adc`. |
| `claude-backup gs://BUCKET` | Deleting a workstation deletes its conversations and memory. |
| The boot hook, `workstation/customize_environment` | A restart removed `gh`, and every `git push` then failed with what looked like an auth error. |
| The `keep-claude-sessions` extension | The Claude Code panel archives conversations idle for 14 days. |

## Ask your harness

With the Developer Knowledge MCP set up, your harness answers questions like these from the current docs:

- "Which GPU and TPU machine types support Dynamic Workload Scheduler flex-start and calendar mode?"
- "How do I request a calendar mode future reservation for GPUs, and what does reservation-bound provisioning mean?"
- "Which GPU types does Vertex AI custom training support, and which ones does Colab Enterprise offer?"
- "How do I create a G4 VM with a fractional vGPU?"
- "How do I speed up GKE node startup for accelerator workloads with secondary boot disks?"
- "How does dynamic resource allocation (DRA) work for GPUs and TPUs on GKE?"
- "How do I serve an LLM with vLLM on TPUs in GKE?"
- "What tensor dimensions and batch sizes does the Cloud TPU performance guide recommend?"

For a price, ask it to run [`gcp-pricing`](https://github.com/WandLZhang/gcp-pricing-scraper): `gcp-pricing accelerator --filter <machine-type>` or `gcp-pricing tpu --filter <generation>`, for example `gcp-pricing tpu --filter Trillium`. Pricing pages render in JavaScript, so a plain fetch returns an empty page. The CLI captures every table and region to a file the harness can search. For zones, capacity options and the other facts that change, see [Look up facts that change](../3-get-capacity/README.md#look-up-facts-that-change).

## Other harnesses

- **Antigravity.** In the Agent panel, open MCP Servers, search for Google Developer Knowledge and install it; it uses your Google credentials, so it needs no key. It reads the same rules as agy, from `~/.gemini/GEMINI.md`, which setup.sh installs.
- **Gemini CLI.** Install it with `npm install -g @google/gemini-cli` and start it with `gemini --model gemini-4-argon`. [gemini-cli/README.md](./gemini-cli/README.md) has the rules and MCP config.

## What's in this folder

```
1-harness-setup/
├── README.md                              # This file
├── cloud-workstation/
│   ├── create_workstation.sh              # Builds the workstation and sets it up, in one run
│   └── box_setup.sh                       # The part that runs on the workstation
├── claude-code/
│   ├── README.md                          # Each setup step, cost, gotchas
│   ├── setup.sh                           # One-shot install, ends with a check
│   ├── CLAUDE.md                          # Global rules
│   ├── settings.json                      # Permissions, model, hooks, plugin
│   ├── bin/claude-start                   # Terminal launcher (max effort)
│   ├── bin/claude-vscode-wrapper          # VS Code launch wrapper (max effort)
│   ├── bin/claude-smoke-test              # Checks the docs MCP, gcp-pricing and logging
│   ├── bin/ws-login                       # Runs gcloud as you instead of the service account
│   ├── bin/claude-backup                  # Copies conversations and memory to your bucket
│   ├── hooks/md_write_guard.py            # Denies shell writes over existing .md files
│   ├── hooks/accelerator_guard.py         # Lists running GPUs and TPUs before a turn ends
│   ├── tests/                             # Tests for both hooks
│   ├── vscode/                            # Machine settings and keep-claude-sessions
│   └── workstation/customize_environment  # Boot hook for Cloud Workstations and Cloud Shell
├── gemini-cli/
│   ├── README.md                          # Install, rules and MCP config for Gemini CLI
│   └── GEMINI.md                          # Rules for Gemini CLI, agy and Antigravity
├── logging-mcp-proxy/
│   └── proxy.mjs                          # Cloud Logging MCP proxy
└── own-machine-deck/                      # An earlier deck: VS Code and agy on your own machine
```
