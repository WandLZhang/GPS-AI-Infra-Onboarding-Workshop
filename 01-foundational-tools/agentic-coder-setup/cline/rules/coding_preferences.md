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

# Coding Preferences (Example)

Customize these to match your team's style. Cline will follow them across all tasks.

1. NEVER run python or pip directly. Always use: `source .venv/bin/activate && python ...`
2. NEVER create markdown files telling you what to do — just execute the steps directly
3. NEVER create new scripts when you can update the existing one. No "enhanced_" or "v2_" files
4. NEVER use mock or fake data — test against real systems
5. When code sends payloads between functions, ALWAYS include log statements capturing the full payload for troubleshooting
6. NEVER truncate output or limit reading — always capture and display full command output
7. NEVER add AI attribution to anything you write. No "Co-Authored-By: Cline", no "Generated with" line, no 🤖 — not in commit messages, not in PR bodies, not in issue comments, release notes, or changelogs
8. Never run `git config user.name` or `git config user.email` — the machine's existing identity is correct
