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

# Runs on the workstation. create_workstation.sh copies it there and runs it; you can also run it
# yourself in the workstation's terminal:
#
#   bash box_setup.sh PROJECT_ID [WORKSHOP_BRANCH]
#
# Two agents go on first, because they're hard to break and they can fix anything after them:
# agy (Antigravity CLI) and Claude Code. Then the full Claude Code setup (setup.sh) and the smoke
# test run. A step that fails after the agents are in doesn't stop the run. It goes into
# ~/setup-gaps.md, and the last lines print a prompt that tells either agent to fix the gaps.
#
# GOOGLE_DEV_KNOWLEDGE_API_KEY, if set, goes to setup.sh. Without it, setup.sh uses a key from the
# project that's restricted to the Developer Knowledge API.
set -uo pipefail
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

PROJECT="${1:?usage: box_setup.sh PROJECT_ID [WORKSHOP_BRANCH]}"
BRANCH="${2:-main}"
REPO_URL="https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop.git"
REPO="$HOME/GPS-AI-Infra-Onboarding-Workshop"
SETUP="$REPO/01-foundational-tools/agentic-coder-setup/cli-agent/claude-code/setup.sh"
GAPS="$HOME/setup-gaps.md"
LOGS="$HOME/.cache/workstation-setup"
mkdir -p "$LOGS" "$HOME/Projects"

# A browser terminal inherits the workstation's environment. An SSH session doesn't, so set it here.
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export CLAUDE_CODE_USE_VERTEX=1 ANTHROPIC_VERTEX_PROJECT_ID="$PROJECT" GOOGLE_CLOUD_PROJECT="$PROJECT"
export CLOUD_ML_REGION=global AGY_ADC_AUTH=true

ts() { date "+%H:%M:%S"; }
say() { echo "$(ts) $*"; }
GAP_COUNT=0
gap() {
  GAP_COUNT=$((GAP_COUNT + 1))
  printf -- '- %s\n' "$*" >> "$GAPS"
  echo "  GAP: $*"
}
printf '# Setup gaps on %s\n\nWritten by box_setup.sh at %s for project %s. Each line is a step that failed.\n\n' \
  "$(hostname)" "$(date -u '+%Y-%m-%d %H:%M UTC')" "$PROJECT" > "$GAPS"
T0=$(date +%s)

say "== agents: agy and Claude Code =="
# The official installer puts the newest agy in ~/.local/bin. Cloud Workstations images also ship
# one at /usr/bin/agy, which is the fallback.
if curl -fsSL https://antigravity.google/cli/install.sh | bash > "$LOGS/agy-install.log" 2>&1 \
   && [ -x "$HOME/.local/bin/agy" ]; then
  say "  agy $("$HOME/.local/bin/agy" --version 2>/dev/null) in ~/.local/bin"
elif command -v agy > /dev/null; then
  say "  agy installer failed; using $(command -v agy) $(agy --version 2>/dev/null)"
  gap "The agy installer failed, so this box uses $(command -v agy). Log: $LOGS/agy-install.log"
else
  gap "agy isn't installed. Run: curl -fsSL https://antigravity.google/cli/install.sh | bash. Log: $LOGS/agy-install.log"
fi
if curl -fsSL https://claude.ai/install.sh | bash -s stable > "$LOGS/claude-install.log" 2>&1 \
   && command -v claude > /dev/null; then
  say "  Claude Code $(claude --version 2>/dev/null)"
else
  gap "Claude Code didn't install. Run: curl -fsSL https://claude.ai/install.sh | bash -s stable. Log: $LOGS/claude-install.log"
fi
T_AGENTS=$(date +%s)

say "== Claude Code setup (setup.sh, from branch $BRANCH) =="
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" fetch -q --depth 1 origin "$BRANCH" && git -C "$REPO" checkout -q -B "$BRANCH" FETCH_HEAD \
    || gap "Couldn't update $REPO to branch $BRANCH, so setup.sh ran from the copy already there."
else
  git clone -q --depth 1 -b "$BRANCH" "$REPO_URL" "$REPO" \
    || gap "Couldn't clone $REPO_URL (branch $BRANCH), so setup.sh didn't run."
fi
if [ -x "$SETUP" ]; then
  "$SETUP" "$PROJECT" global > "$LOGS/setup.log" 2>&1
  rc=$?
  # setup.sh marks each step it couldn't finish with ⚠. Each one is a gap.
  while IFS= read -r line; do
    gap "setup.sh: ${line#*⚠ }"
  done < <(grep '⚠' "$LOGS/setup.log")
  [ "$rc" = 0 ] || gap "setup.sh stopped early with exit code $rc. The last lines of $LOGS/setup.log say why."
  say "  setup.sh exit $rc. Log: $LOGS/setup.log"
fi
T_SETUP=$(date +%s)

say "== smoke test (three requests to Claude, about \$0.60) =="
if [ -x "$HOME/bin/claude-smoke-test" ]; then
  "$HOME/bin/claude-smoke-test" "$PROJECT" > "$LOGS/smoke.log" 2>&1
  rc=$?
  sed 's/^/  /' "$LOGS/smoke.log"
  [ "$rc" = 0 ] || gap "claude-smoke-test failed (exit $rc). Its output is in $LOGS/smoke.log."
else
  gap "claude-smoke-test isn't in ~/bin, so setup.sh didn't get far enough to install it."
fi
T_SMOKE=$(date +%s)

[ "$GAP_COUNT" = 0 ] && echo "No gaps. Every step finished." >> "$GAPS"
say "== timing: agents $((T_AGENTS - T0))s, setup.sh $((T_SETUP - T_AGENTS))s, smoke test $((T_SMOKE - T_SETUP))s =="
echo "GAPS=$GAP_COUNT"
