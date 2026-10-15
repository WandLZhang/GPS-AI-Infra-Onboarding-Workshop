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
"""Stop hook: before Claude ends a turn, list the GPUs and TPUs still running.

A GPU VM, a TPU slice or a GPU-backed endpoint bills every hour until someone
deletes it. A session that creates one and then ends its turn leaves it running.
This hook runs when Claude is about to stop. It checks your project and sends the
list back to Claude, so Claude tells you what's still running before it hands the
turn back.

What it checks, with one access token and a few REST calls in parallel:
  Compute Engine  running VMs with a GPU or an accelerator machine type
  Cloud TPU       TPU VMs and queued TPU requests, all zones
  GKE             GPU and TPU node pools that keep nodes, or wait for capacity
  Vertex AI       endpoints that serve a model on GPUs or TPUs, in REGIONS

Projects: the active gcloud project, plus any listed one per line in
~/.claude/accelerator-guard-projects.

To keep something running on purpose, add a line to ~/.claude/accelerator-allowlist:

    <part of the resource name>  <YYYY-MM-DD>  <reason>

A line silences matching resources through that date (UTC). An undated line
silences nothing, so a silence can't outlive the reason for it.

It never deletes anything. It blocks once per turn: when Claude tries to stop again
right after a block, the turn ends. Any error, such as no gcloud login or an API
that isn't enabled, lets the turn end too.

Exit 0 lets Claude stop. Exit 2 sends stderr back to Claude and keeps it working.
"""

import concurrent.futures as cf
import configparser
import datetime
import json
import os
import subprocess
import sys
import time
import urllib.request

# Vertex AI endpoints are regional, so each region costs one call. Add yours.
REGIONS = ["us-central1", "us-east1", "us-east4", "us-east5",
           "us-west1", "us-west4", "europe-west4", "asia-northeast1"]

ALLOWLIST_FILE = os.path.expanduser("~/.claude/accelerator-allowlist")
PROJECTS_FILE = os.path.expanduser("~/.claude/accelerator-guard-projects")

# Machine types that carry accelerators: A2/A3/A4 and G2/G4 GPUs, ct* TPU VMs.
ACCEL_MACHINES = ("a2-", "a3-", "a4-", "a4x-", "g2-", "g4-", "ct5", "ct6", "ct7")
TPU_MACHINES = ("ct5", "ct6", "ct7")
LIVE_TPU_NODE = {"CREATING", "READY", "RESTARTING", "REIMAGING", "REPAIRING", "STARTING"}
QUEUED_TPU = {"CREATING", "ACCEPTED", "PROVISIONING", "WAITING_FOR_RESOURCES"}

BUDGET = 12          # seconds for the whole check; a slow API must not hold the turn
HTTP_TIMEOUT = 8
DEADLINE = time.monotonic() + BUDGET


def get(url, tok):
    """One GET of JSON. Any failure, a disabled API included, returns {}."""
    if time.monotonic() > DEADLINE:
        return {}
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}"})
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as r:
            return json.load(r)
    except Exception:
        return {}


def access_token():
    try:
        r = subprocess.run(["gcloud", "auth", "print-access-token"],
                           capture_output=True, text=True, timeout=20)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def active_project():
    """The project gcloud uses, read from its config files without starting gcloud.

    Cloud Shell keeps gcloud settings per tab and names the console's project in
    GOOGLE_CLOUD_PROJECT, so that and the Vertex AI project are the fallbacks.
    """
    if os.environ.get("CLOUDSDK_CORE_PROJECT"):
        return os.environ["CLOUDSDK_CORE_PROJECT"]
    base = os.environ.get("CLOUDSDK_CONFIG", os.path.expanduser("~/.config/gcloud"))
    try:
        with open(os.path.join(base, "active_config")) as f:
            name = f.read().strip() or "default"
    except Exception:
        name = "default"
    cfg = configparser.ConfigParser()
    try:
        cfg.read(os.path.join(base, "configurations", f"config_{name}"))
    except Exception:
        pass
    return (cfg.get("core", "project", fallback="")
            or os.environ.get("GOOGLE_CLOUD_PROJECT", "")
            or os.environ.get("ANTHROPIC_VERTEX_PROJECT_ID", ""))


def projects():
    found = [active_project()]
    try:
        with open(PROJECTS_FILE) as f:
            found += [ln.split()[0] for ln in f if ln.strip() and not ln.startswith("#")]
    except Exception:
        pass
    return [p for i, p in enumerate(found) if p and p not in found[:i]]


def allowlist():
    """Name parts silenced through today, from dated lines in ALLOWLIST_FILE."""
    today = datetime.datetime.now(datetime.timezone.utc).date()
    keep = []
    try:
        with open(ALLOWLIST_FILE) as f:
            for ln in f:
                parts = ln.split()
                if len(parts) < 2 or parts[0].startswith("#"):
                    continue
                try:
                    until = datetime.date.fromisoformat(parts[1])
                except ValueError:
                    continue
                if today <= until:
                    keep.append(parts[0])
    except Exception:
        pass
    return keep


def sweep_compute(p, tok):
    hits = []
    d = get(f"https://compute.googleapis.com/compute/v1/projects/{p}"
            f"/aggregated/instances?filter=status%3DRUNNING", tok)
    for scope, v in d.get("items", {}).items():
        for i in v.get("instances", []):
            mt = i.get("machineType", "").split("/")[-1]
            gpus = [f"{a.get('acceleratorCount', 1)} x {a['acceleratorType'].split('/')[-1]}"
                    for a in i.get("guestAccelerators", [])]
            if i.get("status") == "RUNNING" and (gpus or mt.startswith(ACCEL_MACHINES)):
                hits.append((i["name"], f"Compute VM   {p}  {scope.split('/')[-1]}  "
                                        f"{i['name']}  {mt}  {', '.join(gpus) or '-'}"))
    return hits


def sweep_tpu(p, tok):
    hits = []
    d = get(f"https://tpu.googleapis.com/v2/projects/{p}/locations/-/queuedResources", tok)
    for q in d.get("queuedResources", []):
        name, loc = q["name"].split("/")[-1], q["name"].split("/")[3]
        state = q.get("state", {}).get("state", "")
        if state in QUEUED_TPU:
            hits.append((name, f"TPU request  {p}  {loc}  {name}  {state}  "
                               f"(free while it waits; bills once granted)"))
    d = get(f"https://tpu.googleapis.com/v2/projects/{p}/locations/-/nodes", tok)
    for n in d.get("nodes", []):
        name, loc = n["name"].split("/")[-1], n["name"].split("/")[3]
        if n.get("state", "") in LIVE_TPU_NODE:
            hits.append((name, f"TPU VM       {p}  {loc}  {name}  "
                               f"{n.get('acceleratorType', '?')}  {n.get('state')}"))
    return hits


def sweep_gke(p, tok):
    hits = []
    d = get(f"https://container.googleapis.com/v1/projects/{p}/locations/-/clusters", tok)
    for c in d.get("clusters", []):
        for pool in c.get("nodePools", []):
            cfg = pool.get("config", {})
            mt = cfg.get("machineType", "")
            gpus = [a.get("acceleratorType", "") for a in cfg.get("accelerators", [])]
            if not (gpus or mt.startswith(ACCEL_MACHINES)):
                continue
            label = f"{c['name']}/{pool['name']}"
            status = pool.get("status", "")
            floor = max(pool.get("initialNodeCount", 0),
                        pool.get("autoscaling", {}).get("minNodeCount", 0))
            # A pool waiting for capacity bills nothing yet, but nodes can land at
            # any time. A running pool scaled to zero bills nothing; its nodes, when
            # it has some, show up as Compute VMs above.
            if status == "PROVISIONING":
                hits.append((label, f"GKE pool     {p}  {c.get('location', '?')}  {label}  "
                                    f"{mt}  waiting for capacity"))
            elif status == "RUNNING" and floor > 0:
                hits.append((label, f"GKE pool     {p}  {c.get('location', '?')}  {label}  "
                                    f"{mt} {', '.join(gpus)}  keeps at least {floor} node(s)"))
    return hits


def sweep_vertex(p, tok, region):
    hits = []
    d = get(f"https://{region}-aiplatform.googleapis.com/v1/projects/{p}"
            f"/locations/{region}/endpoints?pageSize=100", tok)
    for e in d.get("endpoints", []):
        for m in e.get("deployedModels", []):
            spec = m.get("dedicatedResources", {}).get("machineSpec", {})
            mt, acc = spec.get("machineType", ""), spec.get("acceleratorType", "")
            if acc or mt.startswith(ACCEL_MACHINES):
                name = e.get("displayName") or e["name"].split("/")[-1]
                hits.append((name, f"Vertex AI    {p}  {region}  endpoint {name}  {mt}  "
                                   f"{acc} x{spec.get('acceleratorCount', 0)}"))
    return hits


def main():
    try:
        event = json.load(sys.stdin)
    except Exception:
        event = {}
    if event.get("stop_hook_active"):
        sys.exit(0)

    projs = projects()
    tok = access_token() if projs else ""
    if not tok:
        sys.exit(0)

    keep = allowlist()
    hits = []
    with cf.ThreadPoolExecutor(max_workers=16) as ex:
        futs = [ex.submit(fn, p, tok) for p in projs
                for fn in (sweep_compute, sweep_tpu, sweep_gke)]
        futs += [ex.submit(sweep_vertex, p, tok, r) for p in projs for r in REGIONS]
        for f in cf.as_completed(futs):
            try:
                hits.extend(line for name, line in f.result()
                            if not any(k in name for k in keep))
            except Exception:
                pass
    if not hits:
        sys.exit(0)

    short = " The check ran out of time, so this list may be short." \
        if time.monotonic() > DEADLINE else ""
    print("\n".join([
        f"GPUs or TPUs are still running. They bill until someone deletes them.{short}",
        "",
        *("  " + h for h in sorted(set(hits))),
        "",
        "Before you end the turn, tell the user what is still running.",
        "Delete only what the user says they're done with.",
        "To keep one running on purpose, add a dated line to ~/.claude/accelerator-allowlist:",
        "  <part of the resource name>  <YYYY-MM-DD>  <reason>",
    ]), file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
