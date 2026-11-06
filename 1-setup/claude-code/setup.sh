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
#   GOOGLE_DEV_KNOWLEDGE_API_KEY=<key> \
#     GITHUB_PERSONAL_ACCESS_TOKEN=<token> \
#     HF_TOKEN=<token> \
#     ./setup.sh <GCP_PROJECT_ID> [REGION]
#
# Only the project ID is required. Each token you leave out skips its MCP server.
# Set NO_VSCODE=1 to skip the VS Code steps, for example on a terminal-only box.
# When it finishes, run claude-smoke-test to check the docs MCP, gcp-pricing and logging.
#
# Defaults:
#   REGION = "global"  (Vertex AI Anthropic Claude global endpoint)
#   Model  = "claude-opus-5-5[1m]" via Vertex
#   Effort = "max", via the --effort flag on both launchers. settings.json holds
#            "xhigh" because its effortLevel key rejects "max" (see README.md).

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

# On a fresh Cloud Workstation, gcloud can cache a failed GCE check in ~/.config/gcloud/gce and then
# report "no credentialed accounts" while the metadata server is up. Clear it so gcloud checks again.
[ -d /etc/workstation-startup.d ] && rm -f "$HOME_DIR/.config/gcloud/gce"

echo "============================================"
echo "  Claude Code Setup - Vertex AI + MCPs"
echo "  Project: $PROJECT_ID"
echo "  Region:  $REGION"
echo "  Model:   claude-opus-5-5[1m] (effort: max)"
echo "============================================"
echo ""

# ------------------------------------------------------------------
# 1. Install NVM + Node.js 20
# ------------------------------------------------------------------
echo "[1/9] Checking Node.js..."
if command -v node &>/dev/null && [[ "$(node --version)" == v20* ]]; then
    echo "  ✓ Node.js $(node --version) already installed"
else
    # Pin NVM_DIR first. The nvm installer follows an inherited NVM_DIR, so a shell
    # that already points at another nvm would install there instead of here.
    export NVM_DIR="$HOME_DIR/.nvm"
    if [ ! -d "$HOME_DIR/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
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
# Anthropic's native build installs under ~/.local, so it survives the restarts
# that wipe everything outside $HOME on Cloud Workstations and Cloud Shell. It
# doesn't depend on Node either. Current npm releases need Node 22, so on Node
# 20 npm falls back to a release too old to run Opus 5.5.
if curl -fsSL https://claude.ai/install.sh | bash -s stable >/dev/null; then
    export PATH="$HOME_DIR/.local/bin:$PATH"
    echo "  ✓ Claude Code installed: $(claude --version 2>/dev/null)"
else
    echo "  ⚠ Claude Code install failed. See https://code.claude.com/docs"
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
export ANTHROPIC_SMALL_FAST_MODEL="claude-opus-5-5[1m]"
export CLAUDE_CODE_SUBAGENT_MODEL="claude-opus-5-5[1m]"
export PATH="\$HOME/bin:\$PATH"
EOF
    echo "  ✓ Vertex AI env vars appended to .bashrc"
fi
grep -q '.local/bin' "$HOME_DIR/.bashrc" 2>/dev/null \
    || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME_DIR/.bashrc"
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="$PROJECT_ID"
export CLOUD_ML_REGION="$REGION"
export PATH="$HOME_DIR/bin:$PATH"

# Debian's stock .bashrc returns early in a non-interactive shell, so the exports above reach only
# an interactive terminal. ~/.claude_vertex_env holds the same settings and is sourced from the
# first line of .bashrc, before that early return, so `ssh host cmd`, cron and scripts get them too.
# The sonnet alias points at Opus 5.5: a project with only Opus 5.5 turned on in Model Garden would
# otherwise print "Sonnet 4.5 not available" at every launch.
cat > "$HOME_DIR/.claude_vertex_env" <<EOF
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID="$PROJECT_ID"
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
export CLOUD_ML_REGION="$REGION"
export ANTHROPIC_SMALL_FAST_MODEL="claude-opus-5-5[1m]"
export CLAUDE_CODE_SUBAGENT_MODEL="claude-opus-5-5[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-opus-5-5[1m]"
export PATH="\$HOME/.local/bin:\$HOME/bin:\$HOME/.npm-global/bin:\$PATH"
EOF
grep -q claude_vertex_env "$HOME_DIR/.bashrc" 2>/dev/null \
    || sed -i '1i [ -f "$HOME/.claude_vertex_env" ] && . "$HOME/.claude_vertex_env"' "$HOME_DIR/.bashrc"
echo "  ✓ ~/.claude_vertex_env written and sourced from the top of .bashrc"

# ------------------------------------------------------------------
# 4. claude-start launcher + VS Code effort wrapper
# ------------------------------------------------------------------
echo ""
echo "[4/8] Installing launchers..."
mkdir -p "$HOME_DIR/bin"
cp "$SCRIPT_DIR/bin/claude-start" "$HOME_DIR/bin/claude-start"
chmod +x "$HOME_DIR/bin/claude-start"
echo "  ✓ claude-start installed to ~/bin/claude-start"
cp "$SCRIPT_DIR/bin/claude-vscode-wrapper" "$HOME_DIR/bin/claude-vscode-wrapper"
chmod +x "$HOME_DIR/bin/claude-vscode-wrapper"
echo "  ✓ claude-vscode-wrapper installed to ~/bin/claude-vscode-wrapper"
# claude-smoke-test checks the three tools the workshop relies on. ws-login switches
# the gcloud CLI from the workstation's service account to your own account.
for b in claude-smoke-test ws-login; do
    cp "$SCRIPT_DIR/bin/$b" "$HOME_DIR/bin/$b"
    chmod +x "$HOME_DIR/bin/$b"
done
echo "  ✓ claude-smoke-test and ws-login installed to ~/bin"

# ------------------------------------------------------------------
# 5. CLI global rules + settings
# ------------------------------------------------------------------
echo ""
echo "[5/8] Installing Claude Code CLI settings..."
mkdir -p "$HOME_DIR/.claude/hooks"
cp "$SCRIPT_DIR/CLAUDE.md" "$HOME_DIR/.claude/CLAUDE.md"

# settings.json carries __HOME__ because a hook command has to be an absolute
# path, the same reason vscode/machine-settings.json does. It carries the project
# and region too: Debian's stock .bashrc returns early in a non-interactive
# shell, so the exports below never reach `claude -p` from a script, and Claude
# stops with "No projectId was given". The settings env reaches every session.
SETTINGS_JSON="$(cat "$SCRIPT_DIR/settings.json")"
SETTINGS_JSON="${SETTINGS_JSON//__HOME__/$HOME_DIR}"
SETTINGS_JSON="${SETTINGS_JSON//__PROJECT_ID__/$PROJECT_ID}"
printf '%s\n' "${SETTINGS_JSON//__REGION__/$REGION}" > "$HOME_DIR/.claude/settings.json"

# md_write_guard denies any Bash command that overwrites a .md file which
# already exists. Shell redirects and inline python rewrites skip the staleness
# check Edit/Write use, so they destroy hand edits made in the editor without
# ever warning. Creating a new .md still works.
cp "$SCRIPT_DIR/hooks/md_write_guard.py" "$HOME_DIR/.claude/hooks/md_write_guard.py"
chmod +x "$HOME_DIR/.claude/hooks/md_write_guard.py"

# accelerator_guard runs when Claude is about to end a turn. It lists the GPUs
# and TPUs still running in your project and sends the list back to Claude once,
# so Claude tells you before it hands the turn back. It never deletes anything.
cp "$SCRIPT_DIR/hooks/accelerator_guard.py" "$HOME_DIR/.claude/hooks/accelerator_guard.py"
chmod +x "$HOME_DIR/.claude/hooks/accelerator_guard.py"

echo "  ✓ ~/.claude/CLAUDE.md installed"
echo "  ✓ ~/.claude/settings.json installed"
echo "  ✓ ~/.claude/hooks/md_write_guard.py installed (PreToolUse on Bash)"
echo "  ✓ ~/.claude/hooks/accelerator_guard.py installed (Stop)"

# ------------------------------------------------------------------
# Boot hook + claude-backup
# ------------------------------------------------------------------
# The boot hook reinstalls gh and tmux after each restart, and runs your
# scripts in ~/.workstation/startup.d. claude-backup copies conversations and
# memory to a bucket you own (see README.md).
echo ""
echo "[+] Installing the boot hook and claude-backup..."
cp "$SCRIPT_DIR/bin/claude-backup" "$HOME_DIR/bin/claude-backup"
chmod +x "$HOME_DIR/bin/claude-backup"
echo "  ✓ claude-backup installed to ~/bin/claude-backup"
if [ "${CLOUD_SHELL:-}" = "true" ]; then
    BOOT_HOOK="$HOME_DIR/.customize_environment"
elif [ -d /etc/workstation-startup.d ]; then
    BOOT_HOOK="$HOME_DIR/.workstation/customize_environment"
else
    BOOT_HOOK=""
fi
if [ -n "$BOOT_HOOK" ]; then
    mkdir -p "$(dirname "$BOOT_HOOK")" "$HOME_DIR/.workstation/startup.d"
    cp "$SCRIPT_DIR/workstation/customize_environment" "$BOOT_HOOK"
    chmod +x "$BOOT_HOOK"
    echo "  ✓ boot hook installed to $BOOT_HOOK"
else
    echo "  - this isn't Cloud Shell or Cloud Workstations, so no boot hook"
fi

# ------------------------------------------------------------------
# 6. VS Code Machine settings (Code OSS / Cloud Workstation)
# ------------------------------------------------------------------
# The claudeCode.* keys in this file are machine-scoped, so this is the only
# workstation file that reaches them - a workspace .vscode/settings.json is
# ignored for them. __HOME__ is substituted here because claudeProcessWrapper
# has to be an absolute path.
#
# Application-scoped keys don't work here; VS Code ignores them in Machine
# settings. claudeCode.archiveInactiveSessions is one: it moves sessions idle
# for 14 days into the Archived list. The keep-claude-sessions step below
# sets it to Never in each browser instead.
echo ""
echo "[6/8] Installing VS Code Machine settings..."
VSCODE_MACHINE_DIR="$HOME_DIR/.codeoss-cloudworkstations/data/Machine"
MACHINE_JSON="$(cat "$SCRIPT_DIR/vscode/machine-settings.json")"
MACHINE_JSON="${MACHINE_JSON//__HOME__/$HOME_DIR}"
if [ -n "${NO_VSCODE:-}" ]; then
    echo "  - NO_VSCODE is set, so no Machine settings"
elif [ -d "$HOME_DIR/.codeoss-cloudworkstations" ]; then
    mkdir -p "$VSCODE_MACHINE_DIR"
    printf '%s\n' "$MACHINE_JSON" > "$VSCODE_MACHINE_DIR/settings.json"
    echo "  ✓ Machine settings -> $VSCODE_MACHINE_DIR/settings.json"
else
    echo "  ⚠ Cloud Workstation Code OSS dir not found; skipping Machine settings"
    echo "    Merge these keys into your desktop VS Code user settings instead:"
    while IFS= read -r line; do echo "      $line"; done <<< "$MACHINE_JSON"
    echo "    Linux:   ~/.config/Code/User/settings.json"
    echo "    macOS:   ~/Library/Application Support/Code/User/settings.json"
    echo "    Windows: %APPDATA%\\Code\\User\\settings.json"
fi

# ------------------------------------------------------------------
# keep-claude-sessions VS Code extension
# ------------------------------------------------------------------
# The Claude Code panel archives a conversation after 14 idle days unless
# claudeCode.archiveInactiveSessions is Never. Step 6's Machine settings can't
# set that key, and Code OSS keeps User settings in each browser. This
# extension runs on the workstation and sets the key to Never in the User
# settings of every browser that opens it, logging to
# ~/.cache/keep-claude-sessions.log. From a VS Code terminal the install goes
# through the running server and takes effect at once. Over SSH it takes
# effect the next time a browser opens the workstation.
echo ""
echo "[+] Installing the keep-claude-sessions VS Code extension..."
if [ -n "${VSCODE_IPC_HOOK_CLI:-}" ] && [ -x /opt/code-oss/bin/remote-cli/code-oss-cloud-workstations ]; then
    CODE_CLI=/opt/code-oss/bin/remote-cli/code-oss-cloud-workstations
else
    CODE_CLI=/opt/code-oss/bin/codeoss-cloudworkstations
fi
if [ -n "${NO_VSCODE:-}" ]; then
    echo "  - NO_VSCODE is set, so no extension"
elif [ -x "$CODE_CLI" ]; then
    KCS_DIR="$(mktemp -d)"
    cp -r "$SCRIPT_DIR/vscode/keep-claude-sessions" "$KCS_DIR/extension"
    (cd "$KCS_DIR" && python3 -m zipfile -c keep-claude-sessions.vsix extension) \
        && "$CODE_CLI" --install-extension "$KCS_DIR/keep-claude-sessions.vsix" --force >/dev/null 2>&1 \
        && echo "  ✓ keep-claude-sessions installed (Claude conversations stay out of the Archived list)" \
        || echo "  ⚠ keep-claude-sessions install failed (non-fatal)"
    rm -rf "$KCS_DIR"
    # Code OSS on a workstation doesn't ship the Claude Code panel, so install it from Open VSX.
    "$CODE_CLI" --install-extension anthropic.claude-code --force >/dev/null 2>&1 \
        && echo "  ✓ Claude Code VS Code extension installed" \
        || echo "  ⚠ Claude Code VS Code extension install failed (non-fatal)"
else
    echo "  - no Code OSS CLI here, so no extension. Set claudeCode.archiveInactiveSessions to 0 in your VS Code user settings."
fi

# ------------------------------------------------------------------
# 8. MCP proxy scripts
# ------------------------------------------------------------------
echo ""
echo "[7/8] Installing MCP proxy scripts..."
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
echo "[8/8] Registering MCP servers..."

GOOGLE_DEV_KEY="${GOOGLE_DEV_KNOWLEDGE_API_KEY:-}"
if [ -z "$GOOGLE_DEV_KEY" ] && command -v gcloud &>/dev/null; then
    # No key passed in, so take one from the project: a key restricted to the Developer Knowledge
    # API, or a new one if the project has none. On a workstation gcloud runs as the workstation's
    # service account, which needs roles/serviceusage.apiKeysViewer to read a key and
    # roles/serviceusage.apiKeysAdmin to make one.
    DK_NAME="$(gcloud services api-keys list --project="$PROJECT_ID" --format=json 2>/dev/null | python3 -c '
import json, sys
try:
    keys = json.load(sys.stdin)
except ValueError:
    keys = []
for k in keys:
    targets = (k.get("restrictions") or {}).get("apiTargets") or []
    if any(t.get("service") == "developerknowledge.googleapis.com" for t in targets):
        print(k["name"])
        break
')"
    if [ -z "$DK_NAME" ]; then
        gcloud services enable developerknowledge.googleapis.com apikeys.googleapis.com \
            --project="$PROJECT_ID" >/dev/null 2>&1 || true
        DK_NAME="$(gcloud services api-keys create --project="$PROJECT_ID" \
            --display-name="google-dev-knowledge" \
            --api-target=service=developerknowledge.googleapis.com \
            --format="value(response.name)" 2>/dev/null)"
    fi
    if [ -n "$DK_NAME" ]; then
        GOOGLE_DEV_KEY="$(gcloud services api-keys get-key-string "$DK_NAME" \
            --format="value(keyString)" 2>/dev/null)"
    fi
fi
if [ -n "$GOOGLE_DEV_KEY" ]; then
    # Remove first, so a rerun replaces the key instead of failing on "already exists".
    claude mcp remove -s user google-dev-knowledge >/dev/null 2>&1 || true
    claude mcp add -s user --transport http \
        google-dev-knowledge \
        "https://developerknowledge.googleapis.com/mcp" \
        --header "X-Goog-Api-Key:$GOOGLE_DEV_KEY" 2>/dev/null \
        && echo "  ✓ google-dev-knowledge" \
        || echo "  ⚠ google-dev-knowledge (already registered or error)"
else
    echo "  ⚠ GOOGLE_DEV_KNOWLEDGE_API_KEY not set; skipping google-dev-knowledge"
    echo "    Create a key restricted to the Developer Knowledge API:"
    echo "      gcloud services enable developerknowledge.googleapis.com --project=$PROJECT_ID"
    echo "      gcloud services api-keys create --project=$PROJECT_ID --display-name=\"DK API Key\""
    echo "      gcloud services api-keys update <name from the output> --api-target=service=developerknowledge.googleapis.com"
    echo "    Then re-run with GOOGLE_DEV_KNOWLEDGE_API_KEY=<keyString from the output>"
fi

claude mcp remove -s user google-cloud-logging >/dev/null 2>&1 || true
claude mcp add -s user \
    google-cloud-logging \
    -- node "$HOME_DIR/mcp/google-cloud-logging/proxy.mjs" 2>/dev/null \
    && echo "  ✓ google-cloud-logging" \
    || echo "  ⚠ google-cloud-logging (already registered or error)"

GITHUB_PAT="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"
if [ -n "$GITHUB_PAT" ]; then
    claude mcp remove -s user github-mcp >/dev/null 2>&1 || true
    claude mcp add -s user \
        -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_PAT" \
        github-mcp \
        -- "$HOME_DIR/mcp/github-mcp-server/github-mcp-server" stdio 2>/dev/null \
        && echo "  ✓ github-mcp" \
        || echo "  ⚠ github-mcp (already registered or error)"
else
    echo "  - GITHUB_PERSONAL_ACCESS_TOKEN not set; skipping github-mcp (optional)"
    echo "    Re-run with: GITHUB_PERSONAL_ACCESS_TOKEN=<token> ./setup.sh $PROJECT_ID"
fi

# Hugging Face over native streamable HTTP. A bridge such as `npx mcp-remote`
# runs a subprocess per session, and orphaned bridges stalled tool discovery for
# about 300 seconds per session until we switched to native HTTP.
if [ -n "${HF_TOKEN:-}" ]; then
    claude mcp remove -s user huggingface >/dev/null 2>&1 || true
    claude mcp add -s user --transport http \
        huggingface \
        "https://huggingface.co/mcp" \
        --header "Authorization:Bearer $HF_TOKEN" 2>/dev/null \
        && echo "  ✓ huggingface" \
        || echo "  ⚠ huggingface (already registered or error)"
else
    echo "  - HF_TOKEN not set; skipping huggingface (optional, for models, datasets and papers)"
fi

# ------------------------------------------------------------------
# gcp-pricing CLI (raw GCP pricing scraper)
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# Gemini rules (GEMINI.md)
# ------------------------------------------------------------------
# Antigravity (agy) and Gemini CLI read ~/.gemini/GEMINI.md, so the same rules reach them. This
# runs before the gcp-pricing installer, which adds its section to whichever rule files exist.
# A GEMINI.md this script didn't write is kept as GEMINI.md.bak-<date>.
echo ""
echo "[+] Installing Gemini rules..."
mkdir -p "$HOME_DIR/.gemini"
GEMINI_SRC="$SCRIPT_DIR/../gemini-cli/GEMINI.md"
if [ -f "$HOME_DIR/.gemini/GEMINI.md" ] \
    && [ "$(head -1 "$HOME_DIR/.gemini/GEMINI.md")" != "$(head -1 "$GEMINI_SRC")" ]; then
    cp "$HOME_DIR/.gemini/GEMINI.md" "$HOME_DIR/.gemini/GEMINI.md.bak-$(date +%Y%m%d-%H%M%S)"
fi
cp "$GEMINI_SRC" "$HOME_DIR/.gemini/GEMINI.md"
echo "  ✓ ~/.gemini/GEMINI.md installed"

echo ""
echo "[+] Installing gcp-pricing CLI (raw GCP pricing scraper)..."
curl -fsSL https://raw.githubusercontent.com/WandLZhang/gcp-pricing-scraper/main/install.sh | bash \
    && echo "  ✓ gcp-pricing installed (try: gcp-pricing tpu --filter Trillium)" \
    || echo "  ⚠ gcp-pricing install failed (non-fatal)"

# ------------------------------------------------------------------
# no-ai-slop skill (global)
# ------------------------------------------------------------------
# Lands in ~/.agents/skills/ (the universal location, so Gemini CLI and
# Antigravity pick it up too) and symlinks into ~/.claude/skills/.
#
# The skill is invocation-triggered -- it gives you /no-ai-slop for editing a
# draft. It does NOT govern ordinary prose on its own; the Writing Style block
# in CLAUDE.md is what does that. Install both or neither.
echo ""
echo "[+] Installing no-ai-slop skill..."
npx --yes skills add petergyang/no-ai-slop --skill no-ai-slop --global --yes >/dev/null 2>&1 \
    && echo "  ✓ no-ai-slop installed (try: /no-ai-slop <draft>)" \
    || echo "  ⚠ no-ai-slop install failed (non-fatal)"

# ------------------------------------------------------------------
# superpowers plugin
# ------------------------------------------------------------------
# settings.json enables it and names its marketplace; this fetches the files. It
# adds process skills such as systematic debugging, writing a plan before a big
# change, and checking the result before saying a task is done.
echo ""
echo "[+] Installing the superpowers plugin..."
claude plugin install superpowers --marketplace anthropics/claude-plugins-official >/dev/null 2>&1 \
    && echo "  ✓ superpowers installed" \
    || echo "  ⚠ superpowers install failed (non-fatal)"

# ------------------------------------------------------------------
# Check that Claude answers through Vertex AI
# ------------------------------------------------------------------
# One short request: $0.13 in a November 2026 test. When it fails, this prints the usual cause
# for that error code, so a room full of setups doesn't need one-on-one help.
# disableAllHooks keeps the Stop hook from adding a second, paid reply here.
echo ""
echo "[+] Checking that Claude answers through Vertex AI..."
if command -v claude &>/dev/null; then
    CHECK_JSON="$(timeout 180 claude -p --no-session-persistence --strict-mcp-config --tools "" \
        --settings '{"disableAllHooks":true}' --effort low --output-format json \
        "Reply with the single word ok." 2>/dev/null < /dev/null)" || true
    python3 - "$CHECK_JSON" "$PROJECT_ID" <<'PY'
import json
import sys

raw, project = sys.argv[1], sys.argv[2]
try:
    r = json.loads(raw)
except ValueError:
    print("  ⚠ Claude didn't answer. Run this to see the error:")
    print('    claude -p "Reply with the single word ok."')
    sys.exit(0)
if not r.get("is_error"):
    print(f"  ✓ Claude answered through Vertex AI (${r.get('total_cost_usd', 0):.2f})")
    sys.exit(0)
status = r.get("api_error_status")
hints = {
    404: "Turn on Claude Opus 5.5 for this project in Model Garden: "
         f"https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-opus-5-5?project={project}",
    403: f"Your account needs the Vertex AI User role (roles/aiplatform.user) on {project}, "
         "and the project needs the Vertex AI API: gcloud services enable aiplatform.googleapis.com",
    401: "Log in again: gcloud auth application-default login",
    429: "The project is out of Claude quota for now. Wait a minute, then run setup.sh again.",
}
print(f"  ⚠ Claude returned an error{f' ({status})' if status else ''}: {r.get('result', '')}")
print("    Next step: " + hints.get(status, "check the project ID, then run: gcloud auth application-default login"))
PY
else
    echo "  ⚠ claude isn't on PATH, so the check didn't run. Open a new terminal and run setup.sh again."
fi

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. source ~/.bashrc   (or open a new terminal)"
echo "  2. gcloud auth login  (if not already)"
echo "  3. claude-smoke-test  (checks the docs MCP, gcp-pricing and Cloud Logging)"
echo "  4. claude-start"
echo "  5. Before you delete this machine: claude-backup gs://YOUR_BUCKET"
