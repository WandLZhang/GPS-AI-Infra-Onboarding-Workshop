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

# Global Rules for Claude Code

## Python
- NEVER run python or pip directly. Always use: `source .venv/bin/activate && python ...` OR `source venv/bin/activate && python ...`

## File Management
- NEVER create markdown or text files telling me what to do — just walk through and run the deployments
- NEVER create new scripts when you can replace/update the old script that is not working. No "enhanced_" or "v2_" files

## Data Integrity
- NEVER use mock or fake data. Test real systems. Do not simulate responses — solve the real problem and if you cannot, say so.
- When code sends payloads between functions, ALWAYS include log statements capturing the full payload for troubleshooting.

## Output
- NEVER truncate output or limit reading. Do NOT use head, tail, or pipes that reduce output. Always capture and display full command output.

## Git
- NEVER add AI attribution to anything you write. No `Co-Authored-By:` trailer naming an agent, no "Generated with" line, no 🤖 — not in commit messages, not in PR bodies, not in issue comments, release notes, or changelogs. Write the message or body and stop. (`settings.json` also disables this at the harness level via the `attribution` keys; this rule covers the cases settings cannot reach.)
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
Condensed from the `no-ai-slop` skill (https://github.com/petergyang/no-ai-slop), installed globally by setup.sh. Run `/no-ai-slop` for a full editing pass on a draft; these apply to everything you write.
- **No binary contrasts.** "It's not X, it's Y" / "The question isn't X, it's Y" / "not just X but Y". State Y directly.
- **No throat-clearing or faux-insight setups.** "Here's the thing", "Let me be clear", "What nobody tells you", "The part everyone misses". Cut the setup, make the claim.
- **No colon reveals.** Noun phrase, colon, dramatic lowercase payoff ("The best part: it learns"). Write a plain sentence. Colons are for lists, labels, and quotes.
- **No fake-profound kickers or summary-recaps.** Don't end on an aphorism, mic-drop, or "In conclusion"/"Ultimately" restatement. End on the last concrete point, takeaway, or next action.
- **No importance puffery or superficial analysis.** "marks a pivotal moment", "a testament to", and trailing `-ing` clauses that fake explanation ("highlighting the team's commitment to..."). State the fact; let the reader judge.
- **No interpretive metadiscourse.** "The key point is", "This distinction matters", "As you can see". If it's clear, delete the aside; if it isn't, add a fact.
- **No weasel attribution.** "experts agree", "studies show", "widely regarded as". Name the source or cut the claim. Never invent one.
- **No synonym cycling, negative listing, dramatic fragments, or rhetorical setups.** Repeat the right word. Say Z instead of "Not X. Not Y. A Z."
- **Banned words:** delve, foster, leverage, utilize, facilitate, empower, streamline, robust, cutting-edge, paradigm shift, game changer, tapestry, realm, beacon, multifaceted, meticulous, intricate, paramount, transformative, elevate, embark, supercharge, harness, ever-evolving. (Prose bans; a literal product or API name is fine.)
- **Usually-empty phrases:** it's worth noting, at the end of the day, when it comes to, at its core, in today's world, the reality is, in terms of, going forward, let's dive in. Cut when they delay the point.
- **Cut empty adverbs** — just, literally, simply, actually, truly, fundamentally, importantly, crucially — unless they carry real emphasis, uncertainty, or contrast.
- **Be concrete.** "cut deploy time from 40 minutes to 4" beats "improved efficiency". Portability test: if a sentence could move unchanged to another person, company, or product, it's filler.
- **Active voice, verbs doing the work.** "decided" not "made a decision"; "can" not "has the ability to".
- **Em dashes:** none in short replies; 1-2 in a long piece only when they clearly beat a comma, period, or parentheses.
- **Formatting follows content.** No emoji in headings, no bold mid-sentence, no bullet list where two sentences read better.
