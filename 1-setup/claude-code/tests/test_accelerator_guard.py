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
"""Tests for hooks/accelerator_guard.py.

Run: python3 tests/test_accelerator_guard.py -v

The first three cases pipe a Stop payload into the hook. They run it with no
gcloud on PATH and an empty gcloud config, so they make no network calls. The
last case loads the hook as a module and feeds it TPU VM records in the shape
the TPU v2 API returns.
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hooks", "accelerator_guard.py")
PROJECT_VARS = ("CLOUDSDK_CORE_PROJECT", "GOOGLE_CLOUD_PROJECT", "ANTHROPIC_VERTEX_PROJECT_ID", "CLOUDSDK_CONFIG")


def stop(active=False):
    return {"hook_event_name": "Stop", "stop_hook_active": active}


def run_hook(payload, env):
    p = subprocess.run([sys.executable, HOOK], input=json.dumps(payload), capture_output=True, text=True, timeout=60, env=env)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def load_hook():
    sys.dont_write_bytecode = True  # keep __pycache__ out of hooks/
    spec = importlib.util.spec_from_file_location("accelerator_guard", HOOK)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def tpu_vm(name, state, health):
    return {"name": f"projects/demo-project/locations/us-east5-b/nodes/{name}",
            "state": state, "health": health, "acceleratorType": "v6e-8"}


class AcceleratorGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.home = tempfile.mkdtemp(prefix="accelerator-guard-test-")
        cls.bin = os.path.join(cls.home, "empty-bin")
        os.mkdir(cls.bin)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.home)

    def env(self, **extra):
        """No gcloud on PATH, an empty HOME, and no project variables."""
        env = {k: v for k, v in os.environ.items() if k not in PROJECT_VARS}
        env.update(HOME=self.home, PATH=self.bin, CLOUDSDK_CONFIG=os.path.join(self.home, "gcloud"))
        env.update(extra)
        return env

    def test_second_stop_ends_the_turn(self):
        self.assertEqual(run_hook(stop(active=True), self.env()), (0, "", ""))

    def test_no_project_warns(self):
        code, out, err = run_hook(stop(), self.env())
        self.assertEqual((code, err), (0, ""))
        msg = json.loads(out)["systemMessage"]
        self.assertIn("no gcloud project is set", msg)
        self.assertIn("nothing was checked", msg)

    def test_no_token_warns(self):
        code, out, err = run_hook(stop(), self.env(CLOUDSDK_CORE_PROJECT="demo-project"))
        self.assertEqual((code, err), (0, ""))
        msg = json.loads(out)["systemMessage"]
        self.assertIn("gcloud returned no access token", msg)
        self.assertIn("nothing was checked", msg)

    def test_unhealthy_tpu_needs_full_name(self):
        g = load_hook()
        healthy = g.tpu_node_hit("demo-project", tpu_vm("train-v6e", "READY", "HEALTHY"))
        unknown = g.tpu_node_hit("demo-project", tpu_vm("train-v6e-c", "READY", "HEALTH_UNSPECIFIED"))
        broken = g.tpu_node_hit("demo-project", tpu_vm("train-v6e-b", "READY", "UNHEALTHY_TENSORFLOW"))
        self.assertIsNone(g.tpu_node_hit("demo-project", tpu_vm("old-v6e", "STOPPED", "HEALTHY")))

        self.assertEqual(healthy[2], False)
        self.assertEqual(unknown[2], False)
        self.assertEqual(broken[2], True)
        self.assertIn("UNHEALTHY_TENSORFLOW", broken[1])
        self.assertNotIn("health", healthy[1])

        # A part of the name silences a healthy VM, not an unhealthy one.
        self.assertTrue(g.silenced(healthy[0], healthy[2], ["train"]))
        self.assertFalse(g.silenced(broken[0], broken[2], ["train"]))
        self.assertTrue(g.silenced(broken[0], broken[2], ["train-v6e-b"]))


if __name__ == "__main__":
    unittest.main()
