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

# System Instructions for Gemini CLI

## Python
- NEVER run python or pip directly. Always use: `source .venv/bin/activate && python ...` OR `source venv/bin/activate && python ...`

## File Management
- NEVER create markdown or text files telling me what to do — just walk through and run the deployments
- NEVER create new scripts when you can replace/update the old script that is not working. No "enhanced_" or "v2_" files

## Data Integrity
- NEVER use mock or fake data. Test real systems. Do not simulate responses — solve the real problem and if you cannot, say so.
- When code sends payloads between functions, ALWAYS include log statements capturing the full payload for troubleshooting.

## Output
- NEVER truncate output or limit reading. Always capture and display full command output.

## Git
- NEVER add AI attribution to anything you write. No `Co-Authored-By:` trailer naming an agent, no "Generated with" line, no 🤖 — not in commit messages, not in PR/MR bodies, not in issue comments, release notes, or changelogs. Write the message or body and stop.
- Never run `git config user.name` or `git config user.email` — the machine's existing identity is correct.
- Never commit secrets (AIza*, gho_*/ghp_*, hf_*, sk-*, AKIA*). Reference environment variables instead.

## Writing Style

**Voice, in precedence order.** Where these conflict, the lower number wins.
1. **Always contract.** can't, don't, doesn't, isn't, aren't, didn't, won't, it's. Never "cannot", "does not", "is not". This overrides the ASD-STE100 full-form preference below. Exception: quoted source code and error strings.
2. **ASD-STE100 Simplified Technical English.** One idea per sentence. Active voice. Present tense. One word, one meaning. No metaphor.
3. The no-slop rules below.

### Write like a person
- **No negative setup then consequence.** Don't build a sentence from what a thing lacks and then state the result. Say what happens. Not "a config that does not set X therefore gets Y" — instead "a config without X carries Y".
- **Never "guard" or "guarded".** Say what the code does. Not "guarded on `cfg.x > 0`" — instead "builds it only when `cfg.x > 0`".
- **No noun piles.** A subject built from stacked nouns is unreadable. Not "a parameter-count assertion for a dense configuration would be the natural one" — instead "the obvious test checks the parameter count of a dense config".
- **Simple words, short sentences.** Prefer a plain question to a hedged statement.

### No AI slop
- **No binary contrasts.** "It's not X, it's Y" / "The question isn't X, it's Y". State Y directly.
- **No throat-clearing or faux-insight setups.** "Here's the thing", "Let me be clear", "What nobody tells you". Cut the setup, make the claim.
- **No colon reveals.** Noun phrase, colon, dramatic lowercase payoff ("The best part: it learns"). Write a plain sentence.
- **No fake-profound kickers or summary-recaps.** Don't end on an aphorism or an "In conclusion" restatement. End on the last concrete point or next action.
- **No importance puffery.** "marks a pivotal moment", "a testament to", and trailing `-ing` clauses that fake explanation. State the fact; let the reader judge.
- **No weasel attribution.** "experts agree", "studies show". Name the source or cut the claim.
- **Be concrete.** "cut deploy time from 40 minutes to 4" beats "improved efficiency". Names, numbers, dates, mechanisms.
- **Banned words:** delve, foster, leverage, utilize, facilitate, empower, streamline, robust, cutting-edge, paradigm shift, game changer, tapestry, realm, beacon, multifaceted, meticulous, intricate, paramount, transformative, elevate, embark, supercharge, ever-evolving.

<!-- BEGIN gcp-pricing (generated) -->
# gcp-pricing

Captures a Google Cloud pricing page **whole** and writes it to a file you can grep. No auth.
No interpretation. Nothing dropped.

```
gcp-pricing <product|url> [--filter TEXT ...] [--catalog] [--json] [--limit N]
```

Every run writes the complete capture to `/tmp/gcp-pricing/<page>.txt` and prints the path.
`--filter` only controls what is echoed to stdout — **the file always has everything.**

The capture holds, in order:
1. the whole page as readable markdown — headings, prose, lists, and **every** table
   (including tables with no `$` in them: minimum durations, free tiers, eligibility lists);
2. every row from the page's inline JSON blob, tab-separated, one per line — the only source
   of non-default regions.

## Work the file, not the tool

The general-purpose page captures to ~6.7 MB / 9,364 region rows. Don't ask the tool to
find things for you — grep the capture:

```bash
gcp-pricing general-purpose --filter "zzz"          # capture, echo nothing
F=/tmp/gcp-pricing/cloud.google.com_products_compute_pricing_general-purpose*.txt
grep -P '^Northern Virginia' $F | grep -oP '\S+-8\t8\t16 GiB\t\$[\d.]+' | sort -t'$' -k2 -g
```

That returns every 8 vCPU / 16 GiB shape in us-east4, cheapest first. Which is the query
that matters.

## The one rule: never strip context off a number

Every wrong number traced back to something that removed a value's coordinates:

| What stripped it | What was lost |
|---|---|
| a `$`-gate in the extractor | 5 tables, incl. minimum storage durations |
| a block-picker choosing "the" table | 13 of 14 machine families |
| WebFetch | whole tables |
| filtering by a SKU name chosen in advance | the cheaper candidate |
| `grep -oP` | the region prefix — a DCU rate was read from an arbitrary region |
| `head -2` | the 40 other matching regions, which would have shown the query was ambiguous |

So:

- **Grep whole lines. Never `-o`.** Every captured line already carries its region, item,
  unit and value. A fragment does not, and a fragment that looks like an answer is how a
  wrong number ships silently.
- **Never `head` a result you are about to quote.** Count first (`| wc -l`). If a query for
  one number returns many rows, the query is under-specified — that is the signal, and
  truncating destroys it.
- **More than one distinct value for what should be one number = stop.** Pin the missing
  coordinate (usually region) and re-run.
- **When a number matters, read its raw line.** Not a summary, not a rendered table — the
  line in the capture file.

Pages also print every rate twice, hourly and monthly at exactly x730. If a value needs
confirming, grep both lines and look at them. Do not build a reconciler; that is more
processing, and processing is what caused all of this.

## Operating rules

These exist because each one was violated in a real analysis and cost a wrong number.

- **Query by requirement, never by name.** List every candidate meeting the spec and sort by
  price *before* choosing. If a SKU name appears in your query before the spec does, stop —
  that is how `n4a-highcpu-8` ($0.25984) got missed in favour of `c4a-highcpu-8` ($0.30304).
- **A page omission is not a product limit.** Pages and the Billing Catalog API each omit
  what the other has. Before writing "not available", check `--catalog` and
  `gcloud compute accelerator-types list --filter="zone~REGION"`. The Agent Platform page's
  us-east4 table lists no T4; the catalog prices it at $0.444/hr.
- **Do not inherit a third party's service mapping.** Verify the engine matches before
  pricing their named target. AWS Glue runs Spark; Dataflow runs Beam — that mapping was a
  rewrite, not a migration, and priced the wrong service.
- **Sweep every dimension per line item**: region · machine family or storage class ·
  commitment (on-demand / Flex CUD / Resource CUD) · tier · batch / Spot. Storage class alone
  was worth −$512/mo; the model ladder −$490/mo.
- **Never state a rate from memory** when a page exists. Support tiers were written from
  recall and came out as the wrong product's structure.
- **When the tool falls short, ask for the page immediately.** One turn: "paste me X." Do not
  burn turns on WebFetch (it summarizes and drops tables) or assert and hope.
- **Re-grep your own artifact for superseded strings** after every correction round.

## Second source

```
gcp-pricing notebooks --catalog --filter "gpu" --filter "t4 in us-east4"
```

Queries the Cloud Billing Catalog API via `gcloud auth print-access-token`. Known service
IDs are in `registry.py` (Notebooks `D73B-5EEA-8215`, Compute Engine `6F81-5844-456A`);
anything else is found by scanning `displayName`. Substring filters are literal — `t4` also
matches `us-east4`, so filter on `t4 in us-east4`.

## Product names

`vms · general-purpose · accelerator · gpu · tpu · storage · lustre · parallelstore ·
bigquery · cloud-run · gke · spanner · cloud-sql · vertex-ai · generative-ai ·
managed-spark · dataflow · support · sud` (plus aliases: `dataproc`→`managed-spark`,
`agent-platform`/`workbench`→`vertex-ai`, `gemini`/`claude`→`generative-ai`, …).

Anything else: pass the URL. `docs.cloud.google.com` pages work too — that is where
eligibility rules live (e.g. `sud` → sustained use discounts).

## Develop

```bash
python tests/capture_fixtures.py     # real page captures, gitignored
PYTHONPATH=. python3 -m pytest -q
```
<!-- END gcp-pricing -->

