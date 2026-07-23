#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Claude Code one-shot setup for the GPS AI Infra Onboarding Workshop.
# Installs Claude Code CLI, configures Vertex AI backend, registers MCP servers,
# and writes the VS Code Claude Code extension defaults.
#
# Usage:
#   GOOGLE_DEV_KNOWLEDGE_API_KEY=AIza... \
#     GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx \
#     ./setup.sh <GCP_PROJECT_ID> [REGION]
#
# Defaults:
#   REGION = "global"  (Vertex AI Anthropic Claude global endpoint)
#   Model  = "claude-opus-4-8[1m]" via Vertex
#   Effort = "max"

set -e

PROJECT_ID="${1:-${ANTHROPIC_VERTEX_PROJECT_ID:-}}"
REGION="${2:-global}"

if [ -z "$PROJECT_ID" ]; then
    echo "Usage: ./setup.sh <GCP_PROJECT_ID> [REGION]"
    echo "Example: ./setup.sh my-vertex-project global"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$(cd "$SCRIPT_DIR/../shared" && pwd)"
HOME_DIR="$HOME"

echo "============================================"
echo "  Claude Code Setup - Vertex AI + MCPs"
echo "  Project: $PROJECT_ID"
echo "  Region:  $REGION"
echo "  Model:   claude-opus-4-8[1m] (effort: max)"
echo "============================================"
echo ""

# ------------------------------------------------------------------
# 1. Install NVM + Node.js 20
# ------------------------------------------------------------------
echo "[1/9] Checking Node.js..."
if command -v node &>/dev/null && [[ "$(node --version)" == v20* ]]; then
    echo "  ✓ Node.js $(node --version) already installed"
else
    if [ ! -d "$HOME_DIR/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    export NVM_DIR="$HOME_DIR/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 20
    nvm use 20
    nvm alias default 20
fi
export NVM_DIR="$HOME_DIR/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# ------------------------------------------------------------------
# 2. Install Claude Code CLI
# ------------------------------------------------------------------
echo ""
echo "[2/9] Installing Claude Code CLI..."
if command -v claude &>/dev/null; then
    echo "  ✓ Claude Code already installed: $(claude --version 2>/dev/null)"
else
    npm install -g @anthropic-ai/claude-code
fi

# ------------------------------------------------------------------
# 3. Vertex AI env vars in .bashrc
# ------------------------------------------------------------------
echo ""
echo "[3/9] Configuring Vertex AI in .bashrc..."
if grep -q "CLAUDE_CODE_USE_VERTEX" "$HOME_DIR/.bashrc" 2>/dev/null; then
    echo "  ✓ Vertex AI env vars already in .bashrc"
else
    cat >> "$HOME_DIR/.bashrc" <<EOF

# Claude Code - Vertex AI Configuration
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="$PROJECT_ID"
export CLOUD_ML_REGION="$REGION"
export ANTHROPIC_SMALL_FAST_MODEL="claude-opus-4-8[1m]"
export CLAUDE_CODE_SUBAGENT_MODEL="claude-opus-4-8[1m]"
export PATH="\$HOME/bin:\$PATH"
EOF
    echo "  ✓ Vertex AI env vars appended to .bashrc"
fi
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="$PROJECT_ID"
export CLOUD_ML_REGION="$REGION"
export PATH="$HOME_DIR/bin:$PATH"

# ------------------------------------------------------------------
# 4. claude-start launcher
# ------------------------------------------------------------------
echo ""
echo "[4/9] Installing claude-start launcher..."
mkdir -p "$HOME_DIR/bin"
cp "$SCRIPT_DIR/bin/claude-start" "$HOME_DIR/bin/claude-start"
chmod +x "$HOME_DIR/bin/claude-start"
echo "  ✓ claude-start installed to ~/bin/claude-start"

# ------------------------------------------------------------------
# 5. CLI global rules + settings
# ------------------------------------------------------------------
echo ""
echo "[5/9] Installing Claude Code CLI settings..."
mkdir -p "$HOME_DIR/.claude"
cp "$SCRIPT_DIR/CLAUDE.md" "$HOME_DIR/.claude/CLAUDE.md"
cp "$SCRIPT_DIR/settings.json" "$HOME_DIR/.claude/settings.json"
echo "  ✓ ~/.claude/CLAUDE.md installed"
echo "  ✓ ~/.claude/settings.json installed"

# ------------------------------------------------------------------
# 6. VS Code Machine settings (Code OSS / Cloud Workstation)
# ------------------------------------------------------------------
echo ""
echo "[6/9] Installing VS Code Machine settings..."
VSCODE_MACHINE_DIR="$HOME_DIR/.codeoss-cloudworkstations/data/Machine"
if [ -d "$HOME_DIR/.codeoss-cloudworkstations" ]; then
    mkdir -p "$VSCODE_MACHINE_DIR"
    cp "$SCRIPT_DIR/vscode/machine-settings.json" "$VSCODE_MACHINE_DIR/settings.json"
    echo "  ✓ Machine settings -> $VSCODE_MACHINE_DIR/settings.json"
else
    echo "  ⚠ Cloud Workstation Code OSS dir not found; skipping Machine settings"
    echo "    Desktop VS Code paths:"
    echo "      Linux:   ~/.config/Code/User/settings.json"
    echo "      macOS:   ~/Library/Application Support/Code/User/settings.json"
    echo "      Windows: %APPDATA%\\Code\\User\\settings.json"
fi

# ------------------------------------------------------------------
# 7. VS Code Workspace settings (~/Projects/.vscode/settings.json)
# ------------------------------------------------------------------
echo ""
echo "[7/9] Installing VS Code Workspace settings..."
PROJECTS_DIR="$HOME_DIR/Projects"
if [ -d "$PROJECTS_DIR" ]; then
    mkdir -p "$PROJECTS_DIR/.vscode"
    cp "$SCRIPT_DIR/vscode/workspace-settings.json" "$PROJECTS_DIR/.vscode/settings.json"
    echo "  ✓ Workspace settings -> $PROJECTS_DIR/.vscode/settings.json"
else
    echo "  ⚠ ~/Projects not found; skipping workspace settings"
fi

# ------------------------------------------------------------------
# 8. MCP proxy scripts
# ------------------------------------------------------------------
echo ""
echo "[8/9] Installing MCP proxy scripts..."
mkdir -p "$HOME_DIR/mcp/google-cloud-logging"
cp "$SHARED_DIR/google-cloud-logging/proxy.mjs" "$HOME_DIR/mcp/google-cloud-logging/proxy.mjs"
echo "  ✓ Cloud Logging proxy installed"

mkdir -p "$HOME_DIR/mcp/github-mcp-server"
if [ -f "$HOME_DIR/mcp/github-mcp-server/github-mcp-server" ]; then
    echo "  ✓ GitHub MCP server binary already exists"
else
    LATEST=$(curl -s https://api.github.com/repos/github/github-mcp-server/releases/latest | grep -m1 tag_name | cut -d'"' -f4)
    echo "  Downloading GitHub MCP Server $LATEST..."
    curl -sL "https://github.com/github/github-mcp-server/releases/download/${LATEST}/github-mcp-server_Linux_x86_64.tar.gz" \
      | tar xz -C "$HOME_DIR/mcp/github-mcp-server/" github-mcp-server
    chmod +x "$HOME_DIR/mcp/github-mcp-server/github-mcp-server"
    echo "  ✓ GitHub MCP server $LATEST installed"
fi

# ------------------------------------------------------------------
# 9. Register MCP servers with Claude Code
# ------------------------------------------------------------------
echo ""
echo "[9/9] Registering MCP servers..."

GOOGLE_DEV_KEY="${GOOGLE_DEV_KNOWLEDGE_API_KEY:-}"
if [ -n "$GOOGLE_DEV_KEY" ]; then
    claude mcp add -s user --transport http \
        google-dev-knowledge \
        "https://developerknowledge.googleapis.com/mcp" \
        --header "X-Goog-Api-Key:$GOOGLE_DEV_KEY" 2>/dev/null \
        && echo "  ✓ google-dev-knowledge" \
        || echo "  ⚠ google-dev-knowledge (already registered or error)"
else
    echo "  ⚠ GOOGLE_DEV_KNOWLEDGE_API_KEY not set; skipping google-dev-knowledge"
    echo "    Get a key from https://console.cloud.google.com/apis/credentials and re-run:"
    echo "    GOOGLE_DEV_KNOWLEDGE_API_KEY=AIza... ./setup.sh $PROJECT_ID"
fi

claude mcp add -s user \
    google-cloud-logging \
    -- node "$HOME_DIR/mcp/google-cloud-logging/proxy.mjs" 2>/dev/null \
    && echo "  ✓ google-cloud-logging" \
    || echo "  ⚠ google-cloud-logging (already registered or error)"

GITHUB_PAT="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
if [ -n "$GITHUB_PAT" ]; then
    claude mcp add -s user \
        -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_PAT" \
        github-mcp \
        -- "$HOME_DIR/mcp/github-mcp-server/github-mcp-server" stdio 2>/dev/null \
        && echo "  ✓ github-mcp" \
        || echo "  ⚠ github-mcp (already registered or error)"
else
    echo "  ⚠ GITHUB_PERSONAL_ACCESS_TOKEN not set; skipping github-mcp registration"
    echo "    Re-run with: GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx ./setup.sh $PROJECT_ID"
fi

# ------------------------------------------------------------------
# gcp-pricing CLI (raw GCP pricing scraper)
# ------------------------------------------------------------------
echo ""
echo "[+] Installing gcp-pricing CLI (raw GCP pricing scraper)..."
curl -fsSL https://raw.githubusercontent.com/WandLZhang/gcp-pricing-scraper/main/install.sh | bash \
    && echo "  ✓ gcp-pricing installed (try: gcp-pricing tpu --filter Trillium)" \
    || echo "  ⚠ gcp-pricing install failed (non-fatal)"

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. source ~/.bashrc   (or open a new terminal)"
echo "  2. gcloud auth login  (if not already)"
echo "  3. claude-start"
