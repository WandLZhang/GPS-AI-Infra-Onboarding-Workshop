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
- Model: `fable` → `claude-fable-5[1m]` (Claude Fable 5 with 1M context window)
- Effort: `max`
- Backend: Vertex AI, region `global` (Anthropic Claude global endpoint)
- Subagent model: also `claude-fable-5[1m]`
- VS Code Claude Code extension: same model/effort/env defaults

### Quick install (one-shot)

```bash
cd 01-foundational-tools/agentic-coder-setup/cli-agent/claude-code
GOOGLE_DEV_KNOWLEDGE_API_KEY=AIza... \
  GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx \
  ./setup.sh <YOUR_GCP_PROJECT_ID>
```

The script installs Node 20 + Claude Code CLI, writes the Vertex env vars to `~/.bashrc`, drops the `claude-start` launcher into `~/bin`, copies CLI rules + permissions to `~/.claude/`, writes the VS Code extension defaults (Code OSS Machine settings + workspace `<root>/.vscode/settings.json`), installs the Cloud Logging proxy + GitHub MCP binary, and registers all three MCP servers.

### Manual install (step-by-step)

```bash
npm install -g @anthropic-ai/claude-code
```

Add to your `~/.bashrc`:

```bash
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="<YOUR_PROJECT_ID>"
export CLOUD_ML_REGION="global"   # use a regional value (e.g. us-east5) only if your project lacks global Anthropic access
# 1M on Vertex: the [1m] suffix must live on these alias-backing vars (the /model picker strips it from the model field)
export ANTHROPIC_DEFAULT_FABLE_MODEL="claude-fable-5[1m]"
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-4-8[1m]"
export CLAUDE_CODE_SUBAGENT_MODEL="claude-fable-5[1m]"
export PATH="$HOME/bin:$PATH"
```

Then `source ~/.bashrc`.

#### Install config files

```bash
# System prompt
mkdir -p ~/.claude
cp claude-code/CLAUDE.md ~/.claude/CLAUDE.md

# Permissions + model + effort defaults
cp claude-code/settings.json ~/.claude/settings.json

# Launcher script (Fable 5, max effort)
mkdir -p ~/bin
cp claude-code/bin/claude-start ~/bin/claude-start
chmod +x ~/bin/claude-start
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

## VS Code Claude Code extension defaults

The extension reads three keys from VS Code settings:

| Key | Value |
|---|---|
| `claudeCode.selectedModel` | `fable` |
| `claudeCode.effortLevel` | `max` |
| `claudeCode.environmentVariables` | `["CLOUD_ML_REGION=global", "ANTHROPIC_DEFAULT_FABLE_MODEL=claude-fable-5[1m]", "ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-8[1m]", "CLAUDE_CODE_SUBAGENT_MODEL=claude-fable-5[1m]"]` |

Two template files are provided:

- **`claude-code/vscode/machine-settings.json`** — Machine-scope (applies IDE-wide). Install at:
  - Cloud Workstation (Code OSS): `~/.codeoss-cloudworkstations/data/Machine/settings.json`
  - Desktop VS Code Linux: `~/.config/Code/User/settings.json`
  - Desktop VS Code macOS: `~/Library/Application Support/Code/User/settings.json`
  - Desktop VS Code Windows: `%APPDATA%\Code\User\settings.json`
- **`claude-code/vscode/workspace-settings.json`** — Workspace-scope (applies when that folder is open). Install at: `<your-workspace>/.vscode/settings.json`

Workspace overrides Machine, so you can pin a project to a different model/effort. `./setup.sh` writes both: Machine to the Cloud Workstation Code OSS path, and workspace to `~/Projects/.vscode/settings.json` (if `~/Projects` exists).

The `CLAUDE_CODE_USE_VERTEX=1` and `ANTHROPIC_VERTEX_PROJECT_ID=<...>` env vars come from your `~/.bashrc` and are inherited by the `claude` process the extension spawns — they don't need to be in `claudeCode.environmentVariables`.

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
