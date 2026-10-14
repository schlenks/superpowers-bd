# Execution modes and infrastructure: upstream re-examination (2026-10-14)

Saved by the parent session from the research subagent's hand-back (the subagent's own write was blocked).

Scope: seven upstream obra/superpowers changes first recommended for skipping, re-checked against superpowers-bd 5.13.1 on Claude Code 2.1.299. Upstream source: `temp/upstream-src/superpowers` at v7.0.0. PR dumps are in `prs/`; probes and raw output are in `probes/` and `probes/out/`.

Evidence labels: **MEASURED** = run here. **UPSTREAM** = upstream's own numbers (usually n=3 on one fixture). **INFERRED** = reasoning only.

Spend: about $0.21 of $15.

## Summary

| # | Item | Call |
|---|------|------|
| 1 | Native executing-plans + handoff choice | **Adapt** (highest value) |
| 2 | Nested controller on a mid-tier model | **Reject** for Opus 5.5 |
| 3 | Micro-task batching | **Adapt** (small change) |
| 4 | No subagent spawning by implementers/reviewers | **Keep the line**; it matters now |
| 5 | diagnosing-superpowers | **Adapt as a deterministic script** |
| 6 | PATH-independent hooks | **Adapt**, low urgency, plus one real bug |
| 7 | Invoke bundled scripts via their interpreter | **Adapt** (cheap) |

## Pricing facts that drive items 1 and 2

Prices from the claude-api skill table (cached 2026-10-06), $/MTok:

| Model | Input | Output | Cache read |
|---|---|---|---|
| Opus 5.5 | 4 | 20 | 0.20 |
| Sonnet 5.5 | 2 | 10 | 0.20 |
| Haiku 5.5 | 0.10 | 0.50 | — |
| Opus 5 (upstream's test model) | 5 | 25 | higher |

MEASURED with `probes/controller_share.py` on a real bd SDD session (`work-acr` 04010deb, 105 subagents):

- The Opus 5.5 controller used 261M cache-read, 0.92M cache-write and 0.36M output tokens, about $64 ($52 + $5 + $7), roughly 40% of the session.
- A Sonnet controller would save about $6: about 9% of the controller's cost and about 4% of the session, because cache reads cost the same on both models.
- Caveat: subagent output tokens look under-counted in the transcripts.

## 1. Native executing-plans plus the handoff choice — ADAPT

**Upstream (#2318, #2258).**
- The session implements every task itself, using SDD's workspace, ledger and stop rules.
- It decides ambiguities itself and records a ruling in the ledger instead of stopping.
- It stops for only four things: destructive actions, security-sensitive actions, external side effects, or a hopeless plan.
- `task-start` / `task-done` helper scripts.
- At the end, one fresh whole-branch review on the most capable model, then one red→green fix pass with no re-review.
- The handoff offers Subagent-driven vs Native with costs and a recommendation.

**Upstream results.**

| Fixture (n=3, Opus 5) | Old stub | Native | SDD |
|---|---|---|---|
| wordstat: cost | $0.47 | $1.83 | $4.53 |
| wordstat: planted crash | shipped 3/3 | caught 3/3 | caught 3/3 |

- Per-task reviewers found nothing the final review didn't.
- Sonnet as final reviewer caught the planted crash 0/3; Opus caught it 3/3.
- ledgerlite: plain execution plus one Opus review ($3.15) matched Native ($5.65). Native's edge is only on defects the spec implies but doesn't state.

**bd today.**
- `executing-plans/SKILL.md` Steps 3–4 say "Do NOT proceed until human feedback received" after every batch. Unattended, that is a hang.
- `writing-plans/references/execution-handoff.md` only ever offers SDD.

**Fit with beads.** Beads already provides what upstream built:
- the ledger is `bd ready` / `bd close` with evidence,
- rulings can go in `bd comments add`,
- resume after compaction is durable,
- epic-verifier is already the fresh, read-only Opus final reviewer.

**Change outline.**
1. Rewrite executing-plans as Native epic execution:
   - work through `bd ready` children in dependency order;
   - for each issue: `bd update --status=in_progress`, TDD, commit, then `bd close` with the test command and its output;
   - record rulings as `bd comments add <id> "Ruling: … — cost if wrong: …"`;
   - use upstream's four stops and drop the per-batch human checkpoint;
   - when all issues are closed, run epic-verifier plus one fix pass.
2. Handoff:
   - offer SDD vs Native with a cost line and a recommendation based on task count, complexity labels and file overlap;
   - unattended, take the recommendation automatically.
3. Make rule-of-five opt-in in Native mode.

**Risks.**
- Long epics can outgrow the context and compact. Recommend Native only for epics of 5 or fewer issues, or all-simple ones.
- There is no bd fixture yet. Run a 3-rep A/B in `tests/research-2026-09` first, with a planted defect the spec implies but doesn't state (about $10–15).

## 2. Nested controller on a mid-tier model — REJECT for Opus 5.5

MEASURED on Claude Code 2.1.299:

- **Nesting works.**
  - The default depth cap is 3. `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` sets it, and GrowthBook can override it.
  - A depth-2 agent completed a foreground Write (`nest-fg-1`).
  - `subagents/*.meta.json` records `spawnDepth`, `parentAgentId` and `requestShape`.
  - SubagentStart and SubagentStop fire for nested agents.
- **Leaving out `run_in_background` now launches agents asynchronously** (`nest-par-1`, `nest-bg2-1`).
- **Background children break the depth-1 orchestrator** (bd's SDD uses `run_in_background: true`). In 2/2 runs:
  - the orchestrator ended its turn early;
  - the children's completion notifications went to the root session;
  - in `nest-bg2-1`, a Sonnet orchestrator looped "still waiting on Child A" while the root already held A's result.
  - Unattended, that means a hang or a dropped task.
- **Explicit foreground parallel calls work**: `run_in_background: false` ran concurrently (`nest-par2-1`, 1/1). A nested mode would need a separate foreground-per-wave dispatch path.

**Economics.**
- Upstream: $3.09 vs $5.64 on Opus 5.
- On Opus 5.5 the saving is about 4% of the session.
- Costs against that: a second dispatch path to maintain, the notification-routing problems above, and possible verdict-audit blocking of a mid-wave orchestrator stop (INFERRED).
- Revisit only for a Fable controller.

## 3. Micro-task batching (#2078) — ADAPT

**Upstream.** Small, independent, same-shape edits go to one implementer and one review. The batch review reconciles the diff against the brief's file list: a listed file absent from the diff is a Missing finding.

**Upstream results.**
- 12-micro-task plan: −73% cost, −87% dispatches.
- Must-not-batch plan: 0 false batches in 3/3.
- Nobody has independently measured how reliably batching triggers when it should.

**bd today.**
- Every issue gets an implementer, a spec reviewer, and N=3 code reviewers plus an aggregator on max tiers, whatever its complexity (`budget-and-wave-cap.md`).
- Twelve one-line issues cost about 72 dispatches. Waves save wall-clock time, not money.

**Change (`dispatch-and-conflict.md`).**
- When 3 or more ready issues are file-disjoint, same-shape and `complexity:simple`, use:
  - one implementer,
  - one spec review that checks every issue's listed files appear in the diff,
  - N=1 code review,
  - a per-issue evidence line when closing each issue.
- Separately, scale N by complexity, with simple issues at N=1. This is the bigger lever.

**Risk.** One bad edit fails the whole batch. Split the batch when re-dispatching.

## 4. Implementers and reviewers may not spawn subagents (#2059)

**Upstream.**
- Across 4 Codex corpora, all 9 depth-2 spawns were workers or reviewers starting duplicate reviews. The worst tree reached 129 sessions at depth 12.
- After the fix: 0 in 118 spawns across 16 reps.
- Round 1 of the fix failed because the line was only in the implementer template; a final reviewer spawned sub-reviewers. The line must be in every dispatched-role template.

**Claude Code.** Upstream called this a "no-op on Claude Code". That is now false: nesting is the default on 2.1.299 (MEASURED), so the line matters.

**Optional hard enforcement (INFERRED, untested).**
- Add `Agent` to `disallowedTools` in `agents/code-reviewer.md` and `agents/epic-verifier.md`.
- Set `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` for autonomous launches.

## 5. diagnosing-superpowers (#2236, #2287) — ADAPT as a script

**Upstream.** A prose-only skill:
- user intake,
- 7 analyst subagents (about 460k tokens per scrub-audit pass),
- `path:line` evidence,
- scrubbed bundles and issue drafts.

Upstream admits the same input gives different conclusions from run to run.

**bd's analyzer is broken (MEASURED).** `tests/claude-code/analyze-token-usage.py`:
- ignores `<session>/subagents/*.jsonl`,
- prices cache reads at the full $3/M rate,
- reported $1,751.96 for a controller that cost about $64.

**Change.** A deterministic `scripts/sdd-postmortem.py`, starting from `probes/controller_share.py`, covering:
- per-seat and per-model tokens and dollars, including cache;
- the dispatch tree from `meta.json`;
- the wave timeline;
- joins with `temp/verdict-audit.log`, `temp/sdd-notifications.log` and the stop-gate counters;
- idle-gap (hang) detection;
- `path:line` evidence for each finding.

Skip the bundle and issue-drafting flow.

## 6. PATH-independent hooks (#2310, #2349; CC #43127) — ADAPT, low urgency, one real bug

MEASURED with `probes/path_probe.sh` and `path_probe2.sh`, invoking every `hooks.json` command via `/bin/sh -c`.

**Broken PATH (`/nonexistent`).**
- All 10 hooks exit 127 at `run-hook.cmd:16` (`dirname`).
- They fail open, so nothing hangs, but every gate silently disappears.
- Only `pre-compact.sh` and `work-state-anchor.sh` survive, because they use only builtins.
- `#!/usr/bin/env bash` also needs PATH.

**Minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`)** — the cron, launchd and GUI-app case:
- hooks run;
- `jq` is found at `/usr/bin/jq` here, but older macOS doesn't ship it;
- `bd` isn't found, so session-start loses its context and session-end silently skips `bd dolt commit`;
- `shellcheck` isn't found, so the linter is silent.

**Real bug.**
- Under minimal PATH, `env bash` resolves to `/bin/bash` 3.2.
- `link-plugin-components.sh:231` then fails with `copied_skills[@]: unbound variable` and exits 1 with no output.
- Reproduced by calling `/bin/bash` directly.

**Change.**
1. In `run-hook.cmd`:
   - get the directory with a builtin: `case "$0" in */*) d=${0%/*};; *) d=.;; esac`;
   - exec an explicit bash ≥4: `$BASH` if 4+, otherwise `/opt/homebrew/bin/bash`, `/usr/local/bin/bash`, then `/bin/bash`. This also removes the exec-bit dependency.
2. Add a PATH backfill line to each hook: `PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin"`.
3. Fix empty-array expansions with `${arr[@]+"${arr[@]}"}`.
4. Turn the probe into a test.

## 7. Invoke bundled scripts via their interpreter (#2301, #2134) — ADAPT

**Where bd runs bundled scripts directly:**
- `run-hook.cmd` executes its target script directly.
- `plugins/superpowers-bd/hooks/hooks.json` runs `"${PLUGIN_ROOT}/hooks/codex-*.sh"` directly (upstream #2040). The project-local `.codex/hooks.json` already uses `bash`.
- Skill text:
  - `epic-verifier/SKILL.md:46` and `dispatch-and-conflict.md:146` (`scripts/quality-delta.sh`)
  - `root-cause-tracing.md:105` (`./find-polluter.sh`)
  - writing-skills (`./render-graphs.js`)
- `agents/code-reviewer.md` frontmatter calls `$CLAUDE_PLUGIN_ROOT/hooks/*.sh`.
- The 0644 files `bd-in-progress-count.sh` and `codex-plugin-owns-hook.sh` are only sourced, so they are fine.

MEASURED: local Codex marketplace staging kept 0755, so the risk depends on the packager.

**Change.**
- Prefix `bash ` / `node ` in the skill text above.
- Change the Codex wrapper hook commands to `bash "${PLUGIN_ROOT}/hooks/…"`.
- Item 6 covers `run-hook.cmd`.
- Add a one-line rationale to writing-skills.
