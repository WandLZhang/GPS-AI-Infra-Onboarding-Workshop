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

# Gemini CLI

Gemini CLI reads the same rules as agy and Antigravity, from `~/.gemini/GEMINI.md`. setup.sh installs that file on a workstation. On another machine, set it up by hand.

## Install

```bash
npm install -g @google/gemini-cli
```

## Configure

Gemini CLI uses your `gcloud` credentials by default. Ensure you're authenticated:

```bash
gcloud auth login
gcloud auth application-default login
```

## Install Config Files

Run this from the `1-harness-setup` folder.

```bash
mkdir -p ~/.gemini
cp gemini-cli/GEMINI.md ~/.gemini/GEMINI.md
```

## Register MCP Servers

Gemini CLI supports MCP via its settings file (`~/.gemini/settings.json`):

```json
{
  "mcpServers": {
    "google-dev-knowledge": {
      "httpUrl": "https://developerknowledge.googleapis.com/mcp",
      "headers": {
        "X-Goog-Api-Key": "<YOUR_API_KEY>"
      }
    },
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

## Launch

```bash
gemini --model gemini-4-argon
```

`gemini-4-argon` is the GA Gemini model as of November 2026. Check Model Garden for the current one before you pin it.
