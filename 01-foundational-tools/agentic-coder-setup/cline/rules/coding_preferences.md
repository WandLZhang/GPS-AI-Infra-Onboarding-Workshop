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

1. Run `python3` directly for one-off scripts that use only the standard library (parsing, quick checks). Anything that needs `pip install` goes in a venv (`python3 -m venv .venv && source .venv/bin/activate`), NEVER into the system Python.
2. NEVER create markdown files telling you what to do — just execute the steps directly
3. NEVER create new scripts when you can update the existing one. No "enhanced_" or "v2_" files
4. NEVER use mock or fake data — test against real systems
5. When code sends payloads between functions, ALWAYS include log statements capturing the full payload for troubleshooting
6. NEVER truncate output or limit reading — always capture and display full command output
7. NEVER add AI attribution to anything you write. No "Co-Authored-By: Cline", no "Generated with" line, no 🤖 — not in commit messages, not in PR bodies, not in issue comments, release notes, or changelogs
8. Never run `git config user.name` or `git config user.email` — the machine's existing identity is correct
9. NEVER overwrite an existing `.md` file with a shell command. No `>` redirect, no `sed -i`, no inline python that opens it for writing. A shell write skips the staleness check, so it destroys hand edits made in the editor and nobody finds out. Use the edit tool. Creating a NEW `.md` that way is fine, and /tmp is always fine
10. A Cloud Billing budget sends alerts. It doesn't stop spending. Before you create a GPU, a TPU or anything else billed by the hour, say what it costs per hour and per day, and delete what you created as soon as its step is done
11. A Spot or DWS Flex-Start request for several nodes can grant all of them at once. Watch the request, and delete the nodes you don't need. Never delete something you didn't create; list it and ask
12. Spell bit and byte units correctly. Capital `B` is a byte and lowercase `b` is a bit (Gbps vs. GBps). `TB` and `GB` are decimal; `TiB` and `GiB` are binary. Copy the unit from the source and don't convert
13. Before you say a task is done, check the result: run the test, load the page, or read back what you deployed
14. Before a long or costly run, run one item first. Run anything that takes more than a few minutes inside `tmux`
15. When a tool behaves in a way you don't expect, read its source before you guess. Look up a term before you explain it, and never invent a reason, a number or a source
16. Test the user's premise against the evidence. If the evidence disagrees, say so
17. NEVER run heavy compute on your workstation or cloudtop: JAX/XLA compilation, large PyTorch model loads or multi-process test suites. Run them on a GCE VM or a TPU VM
18. Before you hardcode a model ID, look up the current one in Model Garden or the release notes. Default to the current GA Gemini model on the `global` endpoint (`gemini-4-argon` as of November 2026)
19. NEVER parse natural language with regex. Have an LLM parse it
20. Put the answer in your final message. Text between tool calls is easy to miss
21. A short "OK" covers only the items it names. A deletion is an instruction, so don't bring back text the user deleted. Before you change the wording of someone else's document, show the before and after and wait for an OK
22. Before you say you can't reach a tool or service, check what's installed and running
23. One paragraph is one line in anything that leaves the terminal: Google Docs, email, chat messages, and PR and issue bodies
24. Never put a token in a git remote URL. Show a draft and wait for an OK before you post anything other people read on GitHub. Delete the branches you create once they're merged
25. In a script, set `CLOUDSDK_CORE_DISABLE_PROMPTS=1`, so gcloud fails instead of waiting at a "y/N" question
