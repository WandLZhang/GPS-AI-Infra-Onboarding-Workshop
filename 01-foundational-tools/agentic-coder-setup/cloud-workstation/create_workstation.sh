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

# Create a Cloud Workstation for the workshop in an Argolis project.
#
#   ./create_workstation.sh PROJECT_ID [USER_EMAIL]
#   ./create_workstation.sh PROJECT_ID [USER_EMAIL] --dry-run
#
# USER_EMAIL is the person who uses the workstation. It defaults to the account gcloud runs as.
# Run it in Cloud Shell, or anywhere gcloud runs, as an owner of the project. This is the admin
# half. Claude Code goes on afterwards from inside the workstation (see ../README.md).
#
#   1. Turns on the APIs a workstation and Claude Code on Vertex AI need.
#   2. Resets the org policies a new Argolis project inherits that stop a workstation, and allows
#      Anthropic's partner model features on Vertex AI, which Claude Code's web search needs.
#   3. Creates the default network, a cluster, a workstation config with the Vertex AI settings in
#      the workstation's environment, and the workstation.
#   4. Gives USER_EMAIL access, and makes the Developer Knowledge API key that setup.sh picks up.
#   5. On the workstation, runs box_setup.sh: installs agy and Claude Code, runs Claude Code's
#      setup.sh and the smoke test. Once the two agents are in, a failed step doesn't stop the run.
#      It goes into ~/setup-gaps.md, and the last lines print a prompt that has either agent fix it.
#
# Run --dry-run first on any project you didn't create for this. It lists each policy it would
# reset and marks the ones someone set by hand, which a reset would erase.
#
# One step stays in the console: turn on Claude Opus 5.5 for the project in Model Garden.
#
# Settings, as environment variables (also WORKSHOP_BRANCH, main, for box_setup.sh, and
# GOOGLE_DEV_KNOWLEDGE_API_KEY, passed to setup.sh when you have your own key):
#   REGION (us-east4), MACHINE (e2-standard-8), DISK_GB (200), CLUSTER (workstations),
#   NAME (from USER_EMAIL), IDLE_TIMEOUT (7200: seconds without use before the workstation stops).
#
# Safe to run again: each step checks what exists first.
set -uo pipefail
# gcloud asks "enable and retry? (y/N)" when an API is off and then waits for an answer forever.
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

PROJECT=""
EMAIL=""
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -*) echo "unknown option: $arg" >&2; exit 1 ;;
    *) if [ -z "$PROJECT" ]; then PROJECT="$arg"; else EMAIL="$arg"; fi ;;
  esac
done
if [ -z "$PROJECT" ]; then
  echo "usage: $0 PROJECT_ID [USER_EMAIL] [--dry-run]" >&2
  exit 1
fi
EMAIL="${EMAIL:-$(gcloud config get-value account 2>/dev/null)}"
[ -n "$EMAIL" ] || { echo "no USER_EMAIL given and gcloud has no account" >&2; exit 1; }

REGION="${REGION:-us-east4}"
MACHINE="${MACHINE:-e2-standard-8}"
DISK_GB="${DISK_GB:-200}"
CLUSTER="${CLUSTER:-workstations}"
IDLE_TIMEOUT="${IDLE_TIMEOUT:-7200}"
# Workstation names take lowercase letters, digits and hyphens, and start with a letter.
NAME="${NAME:-$(printf '%s' "${EMAIL%@*}" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-24)}"
case "$NAME" in [a-z]*) ;; *) NAME="ws-$NAME" ;; esac
CONFIG="$NAME-config"
WORKSTATION="$NAME"
# A service account ID takes 6 to 30 characters.
SA_NAME="$(printf 'ws-%s' "$NAME" | cut -c1-30)"
[ ${#SA_NAME} -ge 6 ] || SA_NAME="${SA_NAME}-box"
SA="$SA_NAME@$PROJECT.iam.gserviceaccount.com"
MODEL="claude-opus-5-5[1m]"

ts() { date "+%H:%M:%S"; }
say() { echo "$(ts) $*"; }
# Run a gcloud command quietly. On failure, print its ERROR lines and return non-zero.
run() {
  local out
  out="$("$@" 2>&1)" && return 0
  echo "$out" | grep -E "ERROR|error" | sed "s/^/    /" >&2
  return 1
}

# Every constraint a new Argolis project inherits that has had to be reset to build one of these
# workstations or to run what people build on them. Reset puts each back to Google's default.
CONSTRAINTS="
compute.vmExternalIpAccess
compute.requireShieldedVm
compute.skipDefaultNetworkCreation
compute.disableGuestAttributesAccess
compute.managed.disableGuestAttributesAccess
compute.disableSerialPortAccess
compute.vmCanIpForward
compute.trustedImageProjects
compute.disableNestedVirtualization
compute.restrictVpcPeering
compute.restrictLoadBalancerCreationForTypes
compute.disableGlobalLoadBalancing
compute.disableGlobalSelfManagedSslCertificate
compute.disableGlobalCloudArmorPolicy
compute.disableInternetNetworkEndpointGroup
compute.disableSshInBrowser
gcp.resourceLocations
iam.allowedPolicyMemberDomains
iam.disableServiceAccountKeyCreation
iam.disableServiceAccountKeyUpload
iam.managed.disableServiceAccountKeyCreation
iam.managed.disableServiceAccountKeyUpload
iam.automaticIamGrantsForDefaultServiceAccounts
iam.workloadIdentityPoolProviders
run.allowedIngress
run.allowedVPCEgress
run.allowedBinaryAuthorizationPolicies
cloudfunctions.allowedIngressSettings
cloudfunctions.requireVPCConnector
cloudfunctions.allowedVpcConnectorEgressSettings
storage.publicAccessPrevention
storage.uniformBucketLevelAccess
storage.secureHttpTransport
sql.restrictAuthorizedNetworks
sql.restrictPublicIp
essentialcontacts.allowedContactDomains
essentialcontacts.managed.allowedContactDomains
datastream.disablePublicConnectivity
"

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSHOP_BRANCH="${WORKSHOP_BRANCH:-main}"
RUNNER="$(gcloud config get-value account 2>/dev/null)"
T0=$(date +%s)
say "project $PROJECT, workstation $WORKSTATION for $EMAIL, region $REGION"
say "cost: the cluster bills \$0.20/hour while it exists, and an $MACHINE workstation about \$0.70/hour while it runs"

if [ "$DRY_RUN" = 1 ]; then
  say "== dry run: org policies a reset would change =="
  n=0; handset=0
  for C in $CONSTRAINTS; do
    eff=$(gcloud resource-manager org-policies describe "$C" --project="$PROJECT" --effective --format=json 2>/dev/null \
      | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    sys.exit()
lp, bp = d.get("listPolicy"), d.get("booleanPolicy")
if bp and bp.get("enforced"):
    print("enforced")
elif lp is not None and lp.get("allValues") == "DENY":
    print("deny all")
elif lp is not None and lp.get("allowedValues"):
    print("allow-list")
')
    own=$(gcloud org-policies describe "$C" --project="$PROJECT" --format=json 2>/dev/null \
      | python3 -c '
import json, sys
try:
    spec = json.load(sys.stdin).get("spec", {})
except ValueError:
    sys.exit()
if spec.get("rules") and not spec.get("reset"):
    print("set by hand: " + json.dumps(spec["rules"])[:60])
')
    if [ -n "$own" ]; then
      printf "  %-48s %s  <- a reset erases this\n" "$C" "$own"; n=$((n + 1)); handset=$((handset + 1))
    elif [ -n "$eff" ]; then
      printf "  %-48s %s\n" "$C" "$eff"; n=$((n + 1))
    fi
  done
  say "  $n would change, $handset of them set by hand. Nothing was modified."
  exit 0
fi

say "== APIs =="
gcloud services enable orgpolicy.googleapis.com --project="$PROJECT" >/dev/null 2>&1
# On a new project the Organization Policy API answers SERVICE_DISABLED for a minute or more after
# it's turned on. Wait for it, or every reset below fails.
for i in $(seq 1 30); do
  gcloud org-policies list --project="$PROJECT" >/dev/null 2>&1 && break
  [ "$i" = 30 ] && { say "  ** the Organization Policy API never answered; stopping **"; exit 1; }
  sleep 10
done
for attempt in 1 2 3 4 5; do
  if gcloud services enable compute.googleapis.com workstations.googleapis.com \
       aiplatform.googleapis.com apikeys.googleapis.com developerknowledge.googleapis.com \
       iam.googleapis.com iamcredentials.googleapis.com logging.googleapis.com \
       --project="$PROJECT" >/dev/null 2>&1; then
    say "  enabled"; break
  fi
  [ "$attempt" = 5 ] && { say "  ** couldn't enable the APIs; stopping **"; exit 1; }
  sleep 60
done

say "== org policies =="
cleared=0; failed=0
for C in $CONSTRAINTS; do
  for attempt in 1 2 3 4 5; do
    out="$(gcloud org-policies reset "$C" --project="$PROJECT" 2>&1)"
    if echo "$out" | grep -q "reset: true"; then cleared=$((cleared + 1)); break; fi
    # A constraint the org doesn't carry comes back NOT_FOUND or INVALID_ARGUMENT: nothing to reset.
    echo "$out" | grep -qE "NOT_FOUND|INVALID_ARGUMENT|not supported" && break
    if [ "$attempt" = 5 ]; then failed=$((failed + 1)); say "  ** $C: $(echo "$out" | tail -1)"; else sleep 10; fi
  done
done
say "  reset $cleared, failed $failed"
# This constraint denies everything by default, so a reset leaves it denied. Claude Code's web
# search is a partner model feature; without this allow it fails while web fetch still works.
PNUM="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
POLICY="$(mktemp)"
cat > "$POLICY" <<EOF
name: projects/$PNUM/policies/vertexai.allowedPartnerModelFeatures
spec:
  rules:
  - values:
      allowedValues:
      - publishers/anthropic
EOF
gcloud org-policies set-policy "$POLICY" --project="$PROJECT" >/dev/null 2>&1 \
  && say "  allowed partner model features for publishers/anthropic" \
  || say "  ** couldn't allow partner model features; Claude Code's web search will fail **"
rm -f "$POLICY"

T_BOOT=$(date +%s)
say "== network =="
if gcloud compute networks describe default --project="$PROJECT" >/dev/null 2>&1; then
  say "  default network exists"
else
  run gcloud compute networks create default --subnet-mode=auto --project="$PROJECT" \
    && say "  created the default network" || { say "  ** couldn't create the network; stopping **"; exit 1; }
fi

say "== service account $SA =="
if ! gcloud iam service-accounts describe "$SA" --project="$PROJECT" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" --display-name="$NAME workstation" \
    --project="$PROJECT" >/dev/null 2>&1
  # A new service account takes a few seconds to reach IAM. Grants made before then fail.
  for i in $(seq 1 12); do
    gcloud iam service-accounts describe "$SA" --project="$PROJECT" >/dev/null 2>&1 && break
    sleep 5
  done
fi
# The workstation runs as this account, and so does everything Claude runs there. Owner lets an
# agent turn on the API it needs; the narrower roles document what the box uses day to day.
for ROLE in roles/owner roles/aiplatform.user roles/logging.viewer roles/logging.logWriter \
            roles/serviceusage.serviceUsageConsumer roles/serviceusage.apiKeysViewer \
            roles/storage.objectAdmin; do
  for attempt in 1 2 3; do
    gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role="$ROLE" \
      --condition=None --quiet >/dev/null 2>&1 && break
    [ "$attempt" = 3 ] && say "  ** $ROLE failed **" || sleep 5
  done
done
say "  roles granted"

say "== Developer Knowledge API key =="
have_key=$(gcloud services api-keys list --project="$PROJECT" --format=json 2>/dev/null | python3 -c '
import json, sys
try:
    keys = json.load(sys.stdin)
except ValueError:
    keys = []
print(any(any(t.get("service") == "developerknowledge.googleapis.com"
              for t in (k.get("restrictions") or {}).get("apiTargets") or []) for k in keys))
')
if [ "$have_key" = "True" ]; then
  say "  a key restricted to the Developer Knowledge API exists"
else
  gcloud services api-keys create --project="$PROJECT" --display-name="google-dev-knowledge" \
    --api-target=service=developerknowledge.googleapis.com >/dev/null 2>&1 \
    && say "  created a key restricted to the Developer Knowledge API" \
    || say "  ** couldn't create the key; setup.sh will try again **"
fi

T_PREP=$(date +%s)
say "== cluster $CLUSTER (about 5 to 20 minutes the first time) =="
if gcloud workstations clusters describe "$CLUSTER" --region="$REGION" --project="$PROJECT" >/dev/null 2>&1; then
  say "  exists"
else
  run gcloud workstations clusters create "$CLUSTER" --region="$REGION" --project="$PROJECT" \
    --network="projects/$PROJECT/global/networks/default" \
    --subnetwork="projects/$PROJECT/regions/$REGION/subnetworks/default" \
    && say "  created" || { say "  ** couldn't create the cluster; stopping **"; exit 1; }
fi

T_CLUSTER=$(date +%s)
say "== workstation config $CONFIG =="
# Claude Code's Vertex AI settings go in the workstation's environment, so every process gets them,
# including the ones that never start an interactive shell.
ENVS="CLAUDE_CODE_USE_VERTEX=1,ANTHROPIC_VERTEX_PROJECT_ID=$PROJECT,GOOGLE_CLOUD_PROJECT=$PROJECT"
ENVS="$ENVS,CLOUD_ML_REGION=global,ANTHROPIC_SMALL_FAST_MODEL=$MODEL,CLAUDE_CODE_SUBAGENT_MODEL=$MODEL"
ENVS="$ENVS,ANTHROPIC_DEFAULT_SONNET_MODEL=$MODEL"
# agy signs in with the workstation's service account through ADC, so nobody has to sign in.
ENVS="$ENVS,AGY_ADC_AUTH=true"
if gcloud workstations configs describe "$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
     --project="$PROJECT" >/dev/null 2>&1; then
  run gcloud workstations configs update "$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT" --container-env="$ENVS" && say "  exists; environment updated"
else
  run gcloud workstations configs create "$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT" --machine-type="$MACHINE" --pd-disk-size="$DISK_GB" \
    --pd-disk-type=pd-balanced --pd-reclaim-policy=retain --service-account="$SA" \
    --service-account-scopes=https://www.googleapis.com/auth/cloud-platform \
    --container-env="$ENVS" --idle-timeout="$IDLE_TIMEOUT" --running-timeout=0 \
    && say "  created" || { say "  ** couldn't create the config; stopping **"; exit 1; }
fi

say "== workstation $WORKSTATION =="
if gcloud workstations describe "$WORKSTATION" --config="$CONFIG" --cluster="$CLUSTER" \
     --region="$REGION" --project="$PROJECT" >/dev/null 2>&1; then
  say "  exists"
else
  run gcloud workstations create "$WORKSTATION" --config="$CONFIG" --cluster="$CLUSTER" \
    --region="$REGION" --project="$PROJECT" \
    && say "  created" || { say "  ** couldn't create the workstation; stopping **"; exit 1; }
fi

say "== access for $EMAIL =="
# Project owner can create and delete a workstation but not open one: opening takes
# roles/workstations.user on the workstation itself, plus actAs on its service account.
# gcloud has no add-iam-policy-binding for workstations, so read the policy, add, and write it back.
# The person running this script gets it too: the next step reaches the box over SSH.
POLICY="$(mktemp)"
if gcloud workstations get-iam-policy "$WORKSTATION" --config="$CONFIG" --cluster="$CLUSTER" \
     --region="$REGION" --project="$PROJECT" --format=json > "$POLICY" 2>/dev/null; then
  python3 - "$POLICY" "user:$EMAIL" "user:$RUNNER" <<'EOF'
import json
import sys

path, members = sys.argv[1], sorted(set(m for m in sys.argv[2:] if m != "user:"))
with open(path) as f:
    policy = json.load(f)
for binding in policy.setdefault("bindings", []):
    if binding.get("role") == "roles/workstations.user":
        binding.setdefault("members", [])
        binding["members"] += [m for m in members if m not in binding["members"]]
        break
else:
    policy["bindings"].append({"role": "roles/workstations.user", "members": members})
with open(path, "w") as f:
    json.dump(policy, f)
EOF
  gcloud workstations set-iam-policy "$WORKSTATION" "$POLICY" --config="$CONFIG" --cluster="$CLUSTER" \
    --region="$REGION" --project="$PROJECT" --quiet >/dev/null 2>&1 \
    && say "  roles/workstations.user on the workstation" \
    || say "  ** couldn't grant roles/workstations.user; $EMAIL can't open the workstation **"
fi
rm -f "$POLICY"
gcloud iam service-accounts add-iam-policy-binding "$SA" --member="user:$EMAIL" \
  --role=roles/iam.serviceAccountUser --project="$PROJECT" --quiet >/dev/null 2>&1 \
  && say "  actAs on $SA" || say "  ** couldn't grant actAs on $SA **"

say "== starting the workstation =="
T_WS0=$(date +%s)
gcloud workstations start "$WORKSTATION" --config="$CONFIG" --cluster="$CLUSTER" \
  --region="$REGION" --project="$PROJECT" --quiet >/dev/null 2>&1
HOST="$(gcloud workstations describe "$WORKSTATION" --config="$CONFIG" --cluster="$CLUSTER" \
  --region="$REGION" --project="$PROJECT" --format='value(host)' 2>/dev/null)"
T_WS=$(date +%s)

say "== on the workstation: agents, Claude Code setup, smoke test =="
GAPS="unknown"
if [ -f "$SELF_DIR/box_setup.sh" ]; then
  B64="$(base64 -w0 "$SELF_DIR/box_setup.sh")"
  KEYVAR=""
  [ -n "${GOOGLE_DEV_KNOWLEDGE_API_KEY:-}" ] && KEYVAR="GOOGLE_DEV_KNOWLEDGE_API_KEY='$GOOGLE_DEV_KNOWLEDGE_API_KEY' "
  OUT="$(mktemp)"
  gcloud workstations ssh "$WORKSTATION" --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT" --command="echo $B64 | base64 -d > /tmp/box_setup.sh && ${KEYVAR}bash /tmp/box_setup.sh $PROJECT $WORKSHOP_BRANCH" \
    </dev/null 2>&1 | grep -vE "^(Warning: Permanently added|Picking local unused port|Listening on port)" | tee "$OUT"
  GAPS="$(sed -n 's/^GAPS=//p' "$OUT")"
  [ -n "$GAPS" ] || GAPS="unknown: the SSH step didn't finish"
  rm -f "$OUT"
else
  say "  ** box_setup.sh isn't next to this script, so nothing ran on the box **"
fi
T_END=$(date +%s)

cat <<EOF

Timing: APIs and org policies $((T_BOOT - T0))s, network and accounts $((T_PREP - T_BOOT))s, cluster $((T_CLUSTER - T_PREP))s,
config and workstation $((T_WS - T_CLUSTER))s (start $((T_WS - T_WS0))s), on the box $((T_END - T_WS))s. Total $(( (T_END - T0) / 60 )) min.

Workstation: https://$HOST/?folder=/home/user
Gaps: $GAPS (listed in ~/setup-gaps.md on the workstation)

Open the workstation, open a terminal, start agy or claude, and paste:

  Read ~/setup-gaps.md, fix each gap, then run claude-smoke-test until it passes 3 of 3.

If Claude can't reach Vertex AI (404), turn on Claude Opus 5.5 for $PROJECT in Model Garden first:
  https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-opus-5-5?project=$PROJECT

The workstation stops itself after $IDLE_TIMEOUT seconds without use. To stop it sooner:
  gcloud workstations stop $WORKSTATION --config=$CONFIG --cluster=$CLUSTER --region=$REGION --project=$PROJECT
EOF
