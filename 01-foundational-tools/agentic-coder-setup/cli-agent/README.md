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

### Install

```bash
npm install -g @anthropic-ai/claude-code
```

### Configure Vertex AI Backend

Add to your `~/.bashrc`:

```bash
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="<YOUR_PROJECT_ID>"
export CLOUD_ML_REGION="<YOUR_REGION>"   # e.g. us-east5
export PATH="$HOME/bin:$PATH"
```

Then `source ~/.bashrc`.

### Install Config Files

```bash
# System prompt
mkdir -p ~/.claude
cp claude-code/CLAUDE.md ~/.claude/CLAUDE.md

# Permissions
cp claude-code/settings.json ~/.claude/settings.json

# Launcher script
mkdir -p ~/bin
cp claude-code/bin/claude-start ~/bin/claude-start
chmod +x ~/bin/claude-start
```

### Register MCP Servers

```bash
# Google Cloud Logging (uses gcloud auth, no API key needed)
mkdir -p ~/mcp/google-cloud-logging
cp shared/google-cloud-logging/proxy.mjs ~/mcp/google-cloud-logging/proxy.mjs
claude mcp add -s user google-cloud-logging -- node ~/mcp/google-cloud-logging/proxy.mjs

# Google Dev Knowledge (HTTP, needs API key)
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
