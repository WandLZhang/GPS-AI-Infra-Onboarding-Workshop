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
"""Tests for hooks/md_write_guard.py. Each case pipes a payload into the hook and checks its answer.

Run: python3 tests/test_md_write_guard.py -v

The probe .md sits in a temp dir under $HOME, because the hook allows every path under /tmp.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hooks", "md_write_guard.py")
HOME = os.path.expanduser("~")


def claude(cmd):
    return {"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": cmd}, "cwd": HOME}


def gemini_cli(cmd):
    return {"hook_event_name": "BeforeTool", "tool_name": "run_shell_command", "tool_input": {"command": cmd}, "cwd": HOME}


def run_hook(payload):
    p = subprocess.run([sys.executable, HOOK], input=json.dumps(payload), capture_output=True, text=True, timeout=20)
    return p.returncode, p.stdout.strip()


class MdWriteGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.mkdtemp(prefix=".md-write-guard-test-", dir=HOME)
        cls.probe = os.path.join(cls.dir, "probe.md")
        with open(cls.probe, "w") as f:
            f.write("probe\n")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir)

    def sed_writes(self):
        p = self.probe
        return (
            f"sed -i 's/a/b/' {p}",
            f"sed -i '' 's/a/b/' {p}",
            f"sed -i.bak 's/a/b/' {p}",
            f"sed -e 's/a/b/' -i {p}",
            f"sed -i \\\n  's/a/b/' \\\n  {p}",
            f"sed \\\n  -i 's/a/b/' {p}",
            f"ls\nsed -i 's/a/b/' {p}",
        )

    def sed_reads(self):
        p = self.probe
        return (
            f"sed -n '1p' {p}",
            # sed on one line, grep -i on the next. The old pattern ran across the newline and denied this.
            f"sed -n '1,5p' {p}\ngrep -i probe {p}",
            f"sed -i 's/a/b/' {self.dir}/new.md",
            "sed -i 's/a/b/' /tmp/md-write-guard-test.md",
        )

    def test_sed_writes_deny(self):
        for cmd in self.sed_writes():
            with self.subTest(cmd=cmd):
                code, out = run_hook(claude(cmd))
                self.assertEqual(code, 0)
                h = json.loads(out)["hookSpecificOutput"]
                self.assertEqual(h["permissionDecision"], "deny", out)
                self.assertIn(self.probe, h["permissionDecisionReason"])

    def test_sed_reads_pass(self):
        for cmd in self.sed_reads():
            with self.subTest(cmd=cmd):
                self.assertEqual(run_hook(claude(cmd)), (0, ""))

    def test_gemini_cli(self):
        code, out = run_hook(gemini_cli(self.sed_writes()[0]))
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["decision"], "deny")
        self.assertEqual(run_hook(gemini_cli(self.sed_reads()[1])), (0, ""))

    def test_redirect_and_read(self):
        code, out = run_hook(claude(f"echo x > {self.probe}"))
        self.assertEqual(json.loads(out)["hookSpecificOutput"]["permissionDecision"], "deny", out)
        self.assertEqual(run_hook(claude(f"cat {self.probe}")), (0, ""))


if __name__ == "__main__":
    unittest.main()
