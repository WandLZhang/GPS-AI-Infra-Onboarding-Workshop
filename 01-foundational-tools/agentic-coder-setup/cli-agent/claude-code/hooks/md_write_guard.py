#!/usr/bin/env python3
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
"""Block a shell command from clobbering an existing tracked .md file.

Claude Code and Gemini CLI both track staleness for their edit tools, so they
warn when a file changed on disk since it was last read. A shell redirect or an
inline python slice-and-rewrite bypasses that tracking, so hand edits made in
the IDE get silently overwritten. This denies those and points back at the edit
tool.

Creating a NEW .md is allowed. Anything under /tmp is allowed. Reads are allowed.

Runs on two harnesses, which disagree on the wire format:

  Claude Code   PreToolUse / tool_name "Bash"
                -> {"hookSpecificOutput": {"permissionDecision": "deny", ...}}
  Gemini CLI    BeforeTool / tool_name "run_shell_command"
                -> {"decision": "deny", "reason": ...}

Pure stdlib, so it runs on whatever python3 the image ships.
"""
import json
import os
import re
import sys

WRITE_HINTS = ("open(", ".write(", "writelines", "truncate", "shutil.copy", "shutil.move")

REDIRECT = re.compile(r">>?\s*([^\s;|&<>()]+)")
SED_I = re.compile(r"\bsed\b[^;|&]*?\s-i\b[^;|&]*")
TEE = re.compile(r"\btee\b(?:\s+-a)?\s+([^\s;|&<>()]+)")
MD_TOKEN = re.compile(r"[\w./~@+-]+\.md\b")
CD = re.compile(r"\bcd\s+([^\s;|&<>()]+)")

SHELL_TOOLS = ("bash", "run_shell_command", "shell", "execute_command")

REASON_TAIL = (
    "Shell writes bypass the staleness check, so hand edits made in the editor "
    "get destroyed without warning. Use the edit tool, which fails loudly if the "
    "file moved under you. For a genuine full-file rewrite, read it first, then write."
)


def candidates(cmd: str):
    """Paths this command looks like it will write to."""
    out = set()
    for m in REDIRECT.finditer(cmd):
        out.add(m.group(1))
    for m in TEE.finditer(cmd):
        out.add(m.group(1))
    for seg in SED_I.finditer(cmd):
        out.update(MD_TOKEN.findall(seg.group(0)))
    # Inline python/perl/ruby rewriting a file it names.
    if any(h in cmd for h in WRITE_HINTS):
        out.update(MD_TOKEN.findall(cmd))
    return out


def bases(cmd: str, cwd: str):
    """Directories a relative path could resolve against.

    A command often starts `cd somewhere && ...`, so the shell cwd the hook is
    handed is not the cwd the write runs under. Try every `cd` target too.
    """
    out = [cwd]
    for m in CD.finditer(cmd):
        d = os.path.expanduser(m.group(1).strip("'\""))
        out.append(d if os.path.isabs(d) else os.path.normpath(os.path.join(cwd, d)))
    return out


def offending(cmd: str, cwd: str):
    hits = []
    for raw in candidates(cmd):
        p = raw.strip("'\"")
        if not p.endswith(".md"):
            continue
        p = os.path.expanduser(p)
        roots = [""] if os.path.isabs(p) else bases(cmd, cwd)
        for root in roots:
            full = os.path.normpath(os.path.join(root, p))
            if full.startswith("/tmp/") or full.startswith("/dev/"):
                continue
            if os.path.exists(full):
                hits.append(full)
    return sorted(set(hits))


def extract_command(tool_input):
    """The shell string, wherever this harness put it."""
    if not isinstance(tool_input, dict):
        return ""
    for key in ("command", "cmd", "script"):
        v = tool_input.get(key)
        if isinstance(v, str):
            return v
        if isinstance(v, list):
            return " ".join(str(x) for x in v)
    return ""


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0

    tool = (data.get("tool_name") or "").lower()
    if tool not in SHELL_TOOLS:
        return 0

    cmd = extract_command(data.get("tool_input"))
    if not cmd:
        return 0
    cwd = data.get("cwd") or os.getcwd()

    hits = offending(cmd, cwd)
    if not hits:
        return 0

    listed = "\n".join("  - " + h for h in hits)
    reason = (
        "Blocked: this command overwrites markdown that already exists:\n"
        + listed
        + "\n\n"
        + REASON_TAIL
    )

    if data.get("hook_event_name") == "BeforeTool" or tool == "run_shell_command":
        # Gemini CLI / Antigravity
        print(json.dumps({"decision": "deny", "reason": reason}))
    else:
        # Claude Code
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
