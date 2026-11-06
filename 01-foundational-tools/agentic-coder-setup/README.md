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

# Agentic Coder Setup

## ▶ [Slides](https://wandlzhang.github.io/GPS-AI-Infra-Onboarding-Workshop/slides.html)

---

This sets up Claude Code the way we run it for AI infrastructure work. It reads the current Google Cloud docs, prices machines from the live pricing pages and reads your Cloud Logging entries. It also stops before it clobbers a file or leaves a GPU billing. Antigravity and Gemini CLI work too: see [Other agents](#other-agents).

1. [Pick your machine](#1-pick-your-machine)
2. [Turn on Claude and get your keys](#2-turn-on-claude-and-get-your-keys)
3. [Run setup.sh](#3-run-setupsh)
4. [Run the smoke test](#4-run-the-smoke-test)
5. [What the setup gives you](#what-the-setup-gives-you)

## 1. Pick your machine

| You have | Do this |
|---|---|
| A Cloud Workstation in your own project | Open it in the browser, open a terminal, and use your project ID below. |
| A Cloud Workstation your instructor shares for the day | Use the project ID your instructor gives you. |
| Another Linux machine, such as a cloudtop, a GCE VM or a laptop | Log in to gcloud with the account that can use the project, then run setup.sh with `NO_VSCODE=1` and use Claude Code in the terminal. |
| A Mac | Use a Cloud Workstation. setup.sh and the smoke test target Linux: on a Mac the GitHub MCP binary and the `timeout` command are missing. |

To create a workstation, follow [Create a workstation](https://cloud.google.com/workstations/docs/create-workstation).

On any machine, log in first:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <PROJECT_ID>
```

A Cloud Workstation runs gcloud and Claude as its service account until you log in. To run gcloud as yourself and keep Claude on the service account, run `ws-login` after setup.

## 2. Turn on Claude and get your keys

1. Turn on Claude Opus 5.5 for the project in [Model Garden](https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-opus-5-5). Enable the Vertex AI API if the console asks. Claude bills per token, and a budget alert doesn't stop spending: see [Cost](./cli-agent/README.md#cost).
2. Grant the account Claude runs as these roles on the project: Vertex AI User (`roles/aiplatform.user`), Logs Viewer (`roles/logging.viewer`) and, for the smoke test, Logs Writer (`roles/logging.logWriter`).
3. Create a Developer Knowledge API key, restricted to that API:

   ```bash
   gcloud services enable developerknowledge.googleapis.com --project=<PROJECT_ID>
   gcloud services api-keys create --project=<PROJECT_ID> --display-name="DK API Key"
   # Copy keyString and name from the output, then restrict the key:
   gcloud services api-keys update <name> --api-target=service=developerknowledge.googleapis.com
   ```

4. Optional: a GitHub personal access token with read access, for the GitHub MCP, and a Hugging Face read token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens), for the Hugging Face MCP.

Keep keys and tokens in environment variables. Never paste them into a file you commit.

## 3. Run setup.sh

```bash
git clone https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop.git
cd GPS-AI-Infra-Onboarding-Workshop/01-foundational-tools/agentic-coder-setup/cli-agent/claude-code
GOOGLE_DEV_KNOWLEDGE_API_KEY=<keyString> \
  GITHUB_PERSONAL_ACCESS_TOKEN=<token> \
  HF_TOKEN=<token> \
  ./setup.sh <PROJECT_ID>
source ~/.bashrc
```

Only the project ID is required. Each token you leave out skips its MCP server. On a machine without Code OSS, put `NO_VSCODE=1` in front. The script takes a few minutes and ends with one request to Claude. If that request fails, the script prints the fix for the error code. [cli-agent/README.md](./cli-agent/README.md) explains each step.

## 4. Run the smoke test

```bash
claude-smoke-test <PROJECT_ID>
```

The script writes one log entry, then gives Claude three tasks. Each check passes only when Claude used the right tool, so an answer from memory fails.

```
Smoke test in project my-project
  wrote log entry smoke-student-1793916369 to logs/claude-smoke-test
  docs     ok    ($0.37; tools: ToolSearch, mcp__google-dev-knowledge__get_documents, mcp__google-dev-knowledge__search_documents)
  pricing  ok    ($0.12; tools: Bash)
  logging  ok    ($0.15; tools: ToolSearch, mcp__google-cloud-logging__list_log_entries)
  total cost $0.64
  All 3 checks passed. Your agent can read the docs, price a machine and read your logs.
```

### If a check fails

| Check | Usual cause | Fix |
|---|---|---|
| docs | The key is missing, expired or not restricted to the Developer Knowledge API, or the API is off | Create a key (step 2), then `claude mcp remove google-dev-knowledge -s user` and run setup.sh again with the new key |
| pricing | `gcp-pricing` isn't on your PATH | Open a new terminal, or run `curl -fsSL https://raw.githubusercontent.com/WandLZhang/gcp-pricing-scraper/main/install.sh \| bash` |
| logging | The account lacks a logging role, or gcloud points at another project | Grant the roles in step 2 and check `gcloud config get-value project` |
| all three | Claude itself fails | Run `claude -p "Reply with the single word ok."` and read the error |

## What the setup gives you

Each piece exists because something went wrong without it.

### Rules: [`CLAUDE.md`](./cli-agent/claude-code/CLAUDE.md)

| Rule | What it prevents |
|---|---|
| Change an existing `.md` file with the Edit tool, never a shell write | A shell rewrite skipped the staleness check and destroyed hand edits made in the editor, and nobody noticed. |
| Fix the broken script; no `enhanced_` or `v2_` copies | Agents added copies beside broken scripts instead of fixing them. |
| Run the steps instead of writing instructions for you | Agents wrote how-to files instead of doing the deployment. |
| Test real systems; no mock data | Mock data makes a broken pipeline look like it works. |
| Log the full payload between functions | Debugging blind when one function hands another a bad payload. |
| Never truncate output | A `head` or `tail` hides the line that explains the failure. |
| Run heavy compute on a VM, not your workstation | Local JAX compilation ran a workstation out of memory and killed it. |
| Look up the current model ID before you hardcode one | A stale preview model ID stayed hardcoded in three setup repos. |
| Let an LLM parse natural language, not regex | A regex parser misses the next phrasing a person types. |
| Put the answer in the final message | An answer written between tool calls was missed during fast slide edits, and the question came back. |
| A short OK covers only what it names | A one-line OK was read as approval for two other open questions. |
| A deletion is an instruction | An agent put the same deleted sentence back into a draft three times. |
| Show wording changes before writing them | An agent rewrote four slides before the author had read the new copy. |
| Check what's installed before saying "can't" | An agent said a chat app was unreachable while its client ran in a local container. |
| One paragraph per line in anything that leaves the terminal | A plain-text email draft was hard-wrapped at about 70 characters, so every sentence broke in the middle. |
| No AI attribution | The harness adds a `Co-Authored-By` trailer by default, and a later history scrub had to clean 81 of 84 commits. |
| No secrets in commits, and no tokens in remote URLs | A GitHub token committed to a shared repo had to be scrubbed from its history. A token in a remote URL printed in plain text the first time an agent ran `git remote -v`. |
| Draft before posting on GitHub | Other people read a comment the moment it posts. |
| Say the cost per hour and per day; delete what you created; use the smallest machine | A Spot request for several nodes granted all of them at once, and each node billed from that moment. |
| Spell bit and byte units as the source does | On a call with a university HPC team, a terabit-for-terabyte slip drew a correction. That's an 8x error. |
| Check your work: one item first, `tmux` for long runs, read the source, test the premise | Reports of success that nobody checked, long jobs lost with an SSH session, and answers built on a guessed definition. |
| `CLOUDSDK_CORE_DISABLE_PROMPTS=1` in scripts | A setup script hung for 10 minutes on a gcloud "y/N" question. |
| Writing style: contractions, short sentences, no filler | Drafts that read as machine-written and run twice as long as they need to. |

### Settings: [`settings.json`](./cli-agent/claude-code/settings.json)

| Setting | What it prevents |
|---|---|
| Reads run without asking; writes, deletes and new tools ask first | A delete you didn't mean, in a project you share. |
| `/tmp` as an additional directory | Every `gcp-pricing` capture in `/tmp` stopped for a permission prompt. |
| `attribution` off | The default `Co-Authored-By` trailer on every commit. |
| `cleanupPeriodDays: 3650` | Claude Code deletes conversations older than 30 days at startup by default. |
| `promptCacheTtl: 1h` | After a pause of more than 5 minutes, the next request wrote the whole conversation to the cache again. |
| Opus 5.5 with 1M context for the main model, subagents and quick tasks | A model alias that isn't turned on in Model Garden returns 404. |
| `effortLevel: xhigh`, with `max` from the launchers | `effortLevel: max` fails the setting's check, and Claude Code silently drops to `high`. |
| The project ID and region in `env` | Debian's `.bashrc` returns early in a non-interactive shell, so `claude -p` from a script stopped with "No projectId was given". |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS: 1800000` | A max-effort turn went quiet while it thought. Claude Code gave up after 300 seconds and retried, and Vertex AI billed every abandoned attempt: about 445K output tokens. |
| The superpowers plugin | Adds skills for systematic debugging, planning a big change, and checking the result before calling it done. |

### Hooks: [`hooks/`](./cli-agent/claude-code/hooks/)

| Hook | What it prevents |
|---|---|
| `md_write_guard.py`, before each shell command | The clobbered `.md` above. It denies shell writes to an existing `.md` and allows reads, new files and `/tmp`. `tests/test_md_write_guard.py` covers it. |
| `accelerator_guard.py`, before Claude ends a turn | GPUs and TPUs that kept billing after the step that needed them. It lists what's still running and never deletes anything. |

### Skills and MCP servers

| Tool | What it prevents |
|---|---|
| Google Developer Knowledge MCP | Answers from stale training data. A support matrix we kept as a spreadsheet still called TPU7x "preview" while the docs page listed its flex-start and calendar mode support. |
| `gcp-pricing` skill and CLI | An agent quoted an on-demand B200 rate that doesn't exist. The pricing page lists A4 on-demand as N/A, and a page fetched by URL comes back as an empty JavaScript shell. |
| Cloud Logging MCP | Pasting a failed job's logs into the chat by hand. |
| GitHub MCP | Guessing at a library's behavior instead of reading its source and issues. |
| Hugging Face MCP, over native HTTP | An `npx mcp-remote` bridge left orphaned processes that stalled tool discovery for about 300 seconds per session. |
| `no-ai-slop` skill | Run `/no-ai-slop` on a draft for a full editing pass. |

### Commands: [`bin/`](./cli-agent/claude-code/bin/)

| Command | What it prevents |
|---|---|
| `claude-start`, and `claude-vscode-wrapper` for the VS Code panel | Sessions at the default effort instead of `max`. |
| `claude-smoke-test` | Finding out mid-lab that a tool doesn't work. |
| `ws-login` | Switching Application Default Credentials to an account without Vertex AI access, which stops Claude cold. It changes only the gcloud CLI account unless you pass `--adc`. |
| `claude-backup gs://BUCKET` | Deleting a workstation deletes its conversations and memory. |
| The boot hook, `workstation/customize_environment` | A restart removed `gh`, and every `git push` then failed with what looked like an auth error. |
| The `keep-claude-sessions` extension | The Claude Code panel archives conversations idle for 14 days. |

## Ask your agent

With the Developer Knowledge MCP set up, your agent answers questions like these from the current docs:

- "Which GPU and TPU machine types support Dynamic Workload Scheduler flex-start and calendar mode?"
- "How do I request a calendar mode future reservation for GPUs, and what does reservation-bound provisioning mean?"
- "Which GPU types does Vertex AI custom training support, and which ones does Colab Enterprise offer?"
- "How do I create a G4 VM with a fractional vGPU?"
- "How do I speed up GKE node startup for accelerator workloads with secondary boot disks?"
- "How does dynamic resource allocation (DRA) work for GPUs and TPUs on GKE?"
- "How do I serve an LLM with vLLM on TPUs in GKE?"
- "What tensor dimensions and batch sizes does the Cloud TPU performance guide recommend?"

For a price, ask it to run `gcp-pricing`, for example `gcp-pricing tpu --filter Trillium`. Pricing pages render in JavaScript, so a plain fetch returns an empty page. The CLI captures every table and region to a file the agent can search.

## Other agents

- **Antigravity.** In the Agent panel, open MCP Servers, search for Google Developer Knowledge and install it; it uses your Google credentials, so it needs no key. Copy [`gemini-cli/GEMINI.md`](./cli-agent/gemini-cli/GEMINI.md) to `~/.gemini/GEMINI.md` for the rules.
- **Gemini CLI.** Install it with `npm install -g @google/gemini-cli` and start it with `gemini --model gemini-4-argon`. [cli-agent/README.md](./cli-agent/README.md#gemini-cli) has the rules and MCP config.

## What's in this folder

```
agentic-coder-setup/
├── README.md                              # This file
├── slides/                                # The slides linked at the top
├── cli-agent/                             # Claude Code and Gemini CLI
│   ├── README.md                          # Each setup step, cost, gotchas
│   ├── claude-code/
│   │   ├── setup.sh                       # One-shot install, ends with a check
│   │   ├── CLAUDE.md                      # Global rules
│   │   ├── settings.json                  # Permissions, model, hooks, plugin
│   │   ├── bin/claude-start               # Terminal launcher (max effort)
│   │   ├── bin/claude-vscode-wrapper      # VS Code launch wrapper (max effort)
│   │   ├── bin/claude-smoke-test          # Checks the docs MCP, gcp-pricing and logging
│   │   ├── bin/ws-login                   # Runs gcloud as you instead of the service account
│   │   ├── bin/claude-backup              # Copies conversations and memory to your bucket
│   │   ├── hooks/md_write_guard.py        # Denies shell writes over existing .md files
│   │   ├── hooks/accelerator_guard.py     # Lists running GPUs and TPUs before a turn ends
│   │   ├── tests/test_md_write_guard.py   # Tests for the guard
│   │   ├── vscode/                        # Machine settings and keep-claude-sessions
│   │   └── workstation/customize_environment  # Boot hook for Cloud Workstations and Cloud Shell
│   ├── gemini-cli/
│   │   └── GEMINI.md                      # Rules for Gemini CLI and Antigravity
│   └── shared/
│       └── google-cloud-logging/proxy.mjs # Cloud Logging MCP proxy
└── cloud-workstation/
    ├── create_workstation.sh              # Builds the workstation and sets it up, in one run
    └── box_setup.sh                       # The part that runs on the workstation
```
