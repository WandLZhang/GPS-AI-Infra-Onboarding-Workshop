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

# CLI Agentic Coding — Claude Code & Gemini CLI

Terminal-based AI coding assistants. Both support MCP servers and can read/write/execute across your project.

## Claude Code

**Defaults provisioned by this setup:**
- Model: `claude-opus-5-5[1m]` (Claude Opus 5.5 with 1M context window)
- Effort: `max`, passed as `--effort max` by both launchers (see [Effort](#effort-why-max-needs-a-wrapper))
- Backend: Vertex AI, region `global` (Anthropic Claude global endpoint)
- Subagent + small-fast model: also `claude-opus-5-5[1m]`
- Prompt cache: 1 hour for the main conversation, 5 minutes for subagents (see [Prompt cache TTL](#prompt-cache-ttl))
- Accelerator check: before Claude ends a turn, a Stop hook lists the GPUs and TPUs still running in your project (see [Accelerator guard](#accelerator-guard))
- Restarts: Claude Code installs under `$HOME`, and a boot hook puts back `gh` and `tmux` on Cloud Workstations and Cloud Shell (see [Boot hook](#boot-hook))
- VS Code Claude Code extension: same model, same effort, via the launch wrapper

### Quick install (one-shot)

```bash
cd 01-foundational-tools/agentic-coder-setup/cli-agent/claude-code
GOOGLE_DEV_KNOWLEDGE_API_KEY=AIza... \
  GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx \
  ./setup.sh <YOUR_GCP_PROJECT_ID>
```

The script installs Node 20 + Claude Code CLI, writes the Vertex env vars to `~/.bashrc`, drops the `claude-start` launcher and the `claude-vscode-wrapper` into `~/bin`, copies CLI rules + permissions to `~/.claude/`, writes the VS Code extension defaults (Code OSS Machine settings), installs the Cloud Logging proxy + GitHub MCP binary, and registers all three MCP servers. It ends with one request to Claude through Vertex AI, about $0.06. If that fails, it prints the fix for the error code, such as turning on Claude in Model Garden.

### Manual install (step-by-step)

```bash
# Native build, installed under ~/.local. Current npm releases need Node 22,
# and on older Node npm installs a release too old to run Opus 5.5.
curl -fsSL https://claude.ai/install.sh | bash -s stable
```

Add to your `~/.bashrc`:

```bash
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="<YOUR_PROJECT_ID>"
export CLOUD_ML_REGION="global"   # use a regional value (e.g. us-east5) only if your project lacks global Anthropic access
export ANTHROPIC_SMALL_FAST_MODEL="claude-opus-5-5[1m]"
export CLAUDE_CODE_SUBAGENT_MODEL="claude-opus-5-5[1m]"
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
```

Then `source ~/.bashrc`.

#### Install config files

```bash
# System prompt
mkdir -p ~/.claude
cp claude-code/CLAUDE.md ~/.claude/CLAUDE.md

# Permissions, model, effort and hooks. settings.json names its hooks by
# absolute path, so put your home directory in place of __HOME__.
# (It grants /tmp as an additional directory so `gcp-pricing` captures can be
#  written and grepped without a prompt on every run.)
sed "s|__HOME__|$HOME|g" claude-code/settings.json > ~/.claude/settings.json
mkdir -p ~/.claude/hooks
cp claude-code/hooks/*.py ~/.claude/hooks/

# Launcher scripts (Opus 5.5, max effort)
mkdir -p ~/bin
cp claude-code/bin/claude-start ~/bin/claude-start
cp claude-code/bin/claude-vscode-wrapper ~/bin/claude-vscode-wrapper
chmod +x ~/bin/claude-start ~/bin/claude-vscode-wrapper
```

#### Register MCP servers

```bash
# Google Cloud Logging (uses gcloud auth, no API key needed)
mkdir -p ~/mcp/google-cloud-logging
cp shared/google-cloud-logging/proxy.mjs ~/mcp/google-cloud-logging/proxy.mjs
claude mcp add -s user google-cloud-logging -- node ~/mcp/google-cloud-logging/proxy.mjs

# Google Dev Knowledge (HTTP, needs API key from console.cloud.google.com/apis/credentials)
claude mcp add -s user --transport http \
    google-dev-knowledge \
    "https://developerknowledge.googleapis.com/mcp" \
    --header "X-Goog-Api-Key:<YOUR_API_KEY>"

# GitHub MCP Server (download binary + register)
mkdir -p ~/mcp/github-mcp-server
LATEST=$(curl -s https://api.github.com/repos/github/github-mcp-server/releases/latest | grep tag_name | cut -d'"' -f4)
curl -sL "https://github.com/github/github-mcp-server/releases/download/${LATEST}/github-mcp-server_Linux_x86_64.tar.gz" | tar xz -C ~/mcp/github-mcp-server/
chmod +x ~/mcp/github-mcp-server/github-mcp-server
claude mcp add -s user -e "GITHUB_PERSONAL_ACCESS_TOKEN=<YOUR_GITHUB_PAT>" \
    github-mcp -- ~/mcp/github-mcp-server/github-mcp-server stdio
```

### Launch

```bash
claude-start
```

---

## Effort: why `max` needs a wrapper

`effortLevel` in `settings.json` accepts `low`, `medium`, `high` and `xhigh` only. `max` fails that enum, the loader drops it, and the session falls back to the model default of `high` — silently, with no warning. Verify it on any box: with `"effortLevel": "max"` in `~/.claude/settings.json`, `claude -p 'run: echo $CLAUDE_EFFORT'` prints `high`.

So `claude-code/settings.json` pins `xhigh`, the highest value that key can hold, and both launchers pass `--effort max` on the command line, which does accept it:

- terminal — `claude-start` runs `claude --effort max`
- VS Code — `claudeCode.claudeProcessWrapper` points at `~/bin/claude-vscode-wrapper`, which strips any `--effort` the extension passes and appends `--effort max`

The extension invokes the wrapper as `claude-vscode-wrapper <claude-binary> <args...>` — it puts the real binary in `executableArgs`, ahead of everything else.

## Prompt cache TTL

Claude Code caches the conversation, so each request reads most of its context from the cache at a small fraction of the input price. On Vertex AI the cache lasts 5 minutes by default. After a longer pause, the next request writes the whole context to the cache again. `"promptCacheTtl": "1h"` in `claude-code/settings.json` makes the main conversation's cache last an hour. A 1-hour cache write costs 1.6x a 5-minute write. A return within the hour then reads the context from the cache instead of writing all of it again. Subagents rarely pause, so they keep the 5-minute default. To change either one for a single shell, set `CLAUDE_CODE_PROMPT_CACHE_TTL` or `CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL` to `5m` or `1h`.

## Cost

Claude on Vertex AI bills per token. A Cloud Billing budget sends alerts, but it doesn't stop spending, so watch the cost yourself. These are the Claude Opus 5.5 prices on the global endpoint, per million tokens, from the Vertex AI pricing page in October 2026:

| Tokens | Price |
|---|---|
| Input | $4.00 |
| Cache read | $0.20 |
| 1-hour cache write | $8.00 |
| Output, thinking included | $20.00 |

Every request sends the whole conversation again, and Claude reads most of it from the cache. A request that carries 800K tokens of conversation costs $0.16 to read before Claude writes a word. One that carries 100K costs $0.02. So start a new conversation for each topic. At max effort, one hard question can produce 30K output tokens, about $0.60.

`/usage` (also `/cost`) shows what the session has cost so far. `/context` shows how full the conversation is.

## Accelerator guard

`claude-code/hooks/accelerator_guard.py` runs as a Stop hook, when Claude is about to end a turn. It looks for these in your project:

- Compute Engine VMs with GPUs or accelerator machine types
- TPU VMs, and queued TPU requests, which bill once granted
- GKE node pools with GPUs or TPUs that keep nodes or wait for capacity
- Vertex AI endpoints that serve a model on GPUs or TPUs

If it finds any, it sends the list back to Claude, and Claude tells you what's still running before it hands the turn back. It blocks once per turn, takes about 2 seconds, and never deletes anything.

It checks the active gcloud project. List more projects, one per line, in `~/.claude/accelerator-guard-projects`. To keep a resource running on purpose, add a dated line to `~/.claude/accelerator-allowlist`:

```
my-finetune-vm  2026-11-06  fine-tuning run for the course project
```

That line silences resources whose names contain `my-finetune-vm` through November 6 (UTC). An undated line silences nothing.

## Boot hook

Cloud Workstations and Cloud Shell rebuild everything outside `$HOME` at each start, so a tool installed with `apt` is gone after a restart. When that happens to `gh`, every `git push` fails with what looks like an auth error, because `gh` is git's credential helper. setup.sh copies `claude-code/workstation/customize_environment` to the path each one runs at boot:

- Cloud Workstations: `~/.workstation/customize_environment`, run as `user`
- Cloud Shell: `~/.customize_environment`, run as root

It reinstalls `gh` and `tmux`, then runs each executable script in `~/.workstation/startup.d` as you. Its log is `~/.customize_environment.log`. setup.sh installs Claude Code under `~/.local`, so `claude` is still there after a restart.

## Memory and backups

Claude Code keeps each conversation as a file in `~/.claude/projects/<folder-path>/`. Its memory sits in the `memory/` folder next to them: notes about you and your projects, with an index in `MEMORY.md` that Claude reads at the start of every session. Ask Claude to remember something, and it writes a note. `settings.json` sets `cleanupPeriodDays` to 3650, so Claude Code keeps conversations instead of deleting them after 30 days.

All of it lives on the machine's disk, and deleting the workstation deletes it. Copy it to a bucket you own first:

```bash
claude-backup gs://YOUR_BUCKET            # copy now
claude-backup gs://YOUR_BUCKET --dry-run  # list what it would copy
```

It writes to `gs://YOUR_BUCKET/<hostname>/` and never deletes anything there. To restore on a new machine with the same username:

```bash
gcloud storage rsync -r gs://YOUR_BUCKET/<old-hostname>/projects ~/.claude/projects
```

## Gotchas

- **In Claude Code's shell, `grep` skips gitignored files.** It runs ugrep with `--ignore-files`, so a recursive search skips `.venv/` and anything else `.gitignore` names. Use `command grep` when a search must see everything, such as a secret scan before a push.
- **A restart empties `/tmp`** on Cloud Workstations and Cloud Shell.
- **Cloud Shell keeps gcloud settings per tab** and drops them when the session ends. To keep them, add `export CLOUDSDK_CONFIG=$HOME/.config/gcloud` to `~/.bashrc`.
- **The Claude Code panel archives conversations idle for 14 days** (`claudeCode.archiveInactiveSessions`). They stay on disk. The setting lives in the browser's user settings, so set it once in each browser profile.
- **An extension-host restart can leave the old `claude` running** with parent PID 1, still holding its connections. Find these with `ps -eo pid,ppid,args`, and end the `claude` processes whose parent is 1.
- **Docs, Sheets and Drive calls need the Drive scope.** Application Default Credentials carry `cloud-platform` but not Drive, so those calls return `403 insufficient authentication scopes`. Log in with `gcloud auth login --enable-gdrive-access`, then send the token from `gcloud auth print-access-token`.
- **`pkill -f` and `pgrep -f` match their own shell**, because the shell's command line holds the pattern. Match on the process name with `pgrep -x`, or put the pattern in a script file.

## VS Code Claude Code extension defaults

Every `claudeCode.*` key the extension reads is **machine-scoped**, so a workspace `.vscode/settings.json` cannot set any of them. `claude-code/vscode/machine-settings.json` is the only template, and it carries one key:

| Key | Value |
|---|---|
| `claudeCode.claudeProcessWrapper` | `__HOME__/bin/claude-vscode-wrapper` |

Install it at:

- Cloud Workstation (Code OSS): `~/.codeoss-cloudworkstations/data/Machine/settings.json`
- Desktop VS Code Linux: `~/.config/Code/User/settings.json`
- Desktop VS Code macOS: `~/Library/Application Support/Code/User/settings.json`
- Desktop VS Code Windows: `%APPDATA%\Code\User\settings.json`

`./setup.sh` writes the Code OSS path and substitutes `__HOME__`. Installing by hand means replacing `__HOME__` with your home directory yourself — the wrapper path has to be absolute, and a wrong one stops the extension from launching Claude at all.

Model and env vars are not set here. Both come from `~/.claude/settings.json` (`model` and `env`), which the extension reads through the CLI. `claudeCode.selectedModel` and `claudeCode.effortLevel` no longer exist — the extension dropped them — and `claudeCode.environmentVariables` now takes `{name, value}` objects rather than `"KEY=value"` strings.

The `CLAUDE_CODE_USE_VERTEX=1` and `ANTHROPIC_VERTEX_PROJECT_ID=<...>` env vars come from your `~/.bashrc` and are inherited by the `claude` process the extension spawns.

---

## Gemini CLI

### Install

```bash
npm install -g @google/gemini-cli
```

### Configure

Gemini CLI uses your `gcloud` credentials by default. Ensure you're authenticated:

```bash
gcloud auth login
gcloud auth application-default login
```

### Install Config Files

```bash
mkdir -p ~/.gemini
cp gemini-cli/GEMINI.md ~/.gemini/GEMINI.md
```

### Register MCP Servers

Gemini CLI supports MCP via its settings file (`~/.gemini/settings.json`):

```json
{
  "mcpServers": {
    "google-cloud-logging": {
      "command": "node",
      "args": ["~/mcp/google-cloud-logging/proxy.mjs"]
    },
    "github-mcp": {
      "command": "~/mcp/github-mcp-server/github-mcp-server",
      "args": ["stdio"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "<YOUR_GITHUB_PAT>"
      }
    }
  }
}
```

### Launch

```bash
gemini
```
