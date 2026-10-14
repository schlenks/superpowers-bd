# Upstream v7 Adoption (Items 1–9) Implementation Plan

> **After approval:** convert this plan to a beads epic with plan2beads, then execute it with subagent-driven-development unless a different execution path is explicitly chosen.

**Spec:** `docs/experiments/2026-10-14-upstream-v7/` — one research report per track (`autonomy-holds.md`, `resume-implementer.md`, `leaner-plans.md`, `writing-good-tests.md`, `brainstorming-v7.md`, `execution-modes.md`) plus reference artifacts in `artifacts/`. Each task names the report section it implements; when this plan and a report disagree, this plan wins (it records the user's 2026-10-14 scope decisions).

**Goal:** Adopt the nine upstream obra/superpowers v6.1–v7.0 changes that the 2026-10-14 research recommended, adapted to beads and to unattended (autonomous) execution.

**Architecture:** Every change is to skill prose, agent prompts, hook shell scripts, one new Python script, and tests. Skills are edited in `skills/` and byte-mirrored into `plugins/superpowers-bd/skills/`. The reviewer contract is duplicated across the Claude skill, the Codex plugin agents (`plugins/superpowers-bd/agents/*.md`) and the Codex TOML fallbacks (`.codex/agents/*.toml`). Hooks exist in `hooks/`, and the Codex hook subset is also in `plugins/superpowers-bd/hooks/`.

**Tech Stack:** Markdown skills, bash hooks, Python 3 (stdlib only), the `bd` CLI, Claude Code 2.1.299 / Codex CLI, `shellcheck`, the repo's existing test harnesses.

**Key Decisions:**
- **Rulings over stalls (Tasks 1, 2, 3, 8):** non-destructive ambiguity gets a recorded `[RULING]` bd comment and work continues. Only these stop for a human:
  - destructive or irreversible actions,
  - security-sensitive actions,
  - push, merge or publish not pre-authorized by a `completion:*` label,
  - a plan where every path forward is a guess,
  - bd being unavailable.

  Why: the current PENDING_HUMAN hold exits `claude -p` with "success" and nothing built (4/4 measured), while the ruling variant finished 5/5 and still refused a destructive step 2/2.
- **Escalation is asynchronous:** add the `human` label plus a `[HUMAN-NEEDED]` comment, then keep working on independent tasks. Never use `TaskCreate` as the only record, because Task tools are off by default on CC 2.1.233+.
- **Fix loop keeps bd's 3-round cap (Task 2):** rounds 1–2 resume the original implementer by agentId, round 3 is a fresh dispatch one model tier up, then adjudication by ruling. Why: resume measured 61–63% cheaper, and resumed fixers refused a spec-contradicting finding 8/8 where fresh fixers applied it 7/8. Never pass `name:` to an implementer dispatch (teammate-mode trap, issue #2140).
- **Plans record decisions, not code (Task 4):** port upstream v6.4.2. Why: bd's current skill made Opus 5.5 build the product while planning (4/4), and the lean port did not (0/4), at 37% lower cost, with no downstream loss measured.
- **No hard enforcement where prose suffices, except one cheap case:** add `Agent` to `disallowedTools` on the review agents (Task 10). Nested spawning is on by default in CC 2.1.299, and these agents never need it.

## Review Focus

- **Task 1:** a plan step that is destructive (e.g. purge a shared cache) inside an otherwise rule-able conflict should still stop, with a `human`-labeled bead, while the rest of the epic completes. Test: Task 1 Step 11 probe.
- **Task 2:** an implementer that can no longer be messaged (stopped, Explore/Plan type, or transcript gone) should fall back to a fresh dispatch carrying the issue id, the `[IMPL-REPORT]` and the findings, without counting as an extra round. Test: worked example in `example-workflow.md`, plus a contract-audit check (Task 13) that `background-execution.md` documents the fallback path.
- **Task 3:** finishing with no `completion:*` label in an unattended run should keep the branch and worktree, record that choice, and never merge, push or discard. Test: Task 3 Step 4 probe.
- **Task 10:** a hook launched with an unresolvable `PATH` (`/nonexistent`) or with `/bin/bash` 3.2 should still run, or fail open with a stderr note, never crash with `unbound variable`. Test: `tests/verification/test-hooks-minimal-path.sh` (created in Task 10).
- **Task 12:** a session with zero subagent transcripts, or a subagent with no `meta.json`, should still produce a report rather than a traceback. Test: `tests/claude-code/test-sdd-postmortem.sh` fixture cases.

## Global Constraints

- Mirror every `skills/` edit into `plugins/superpowers-bd/skills/`. Gate: `diff -r` on the task's own paths prints nothing before commit (other tasks' uncommitted edits make the global `diff -rq skills plugins/superpowers-bd/skills` noisy until Task 13).
- Reviewer-contract edits land in every copy: the Claude skill file, `plugins/superpowers-bd/agents/<role>.md` and `.codex/agents/<role>.toml` (TOML must parse with `tomllib`).
- Name a Claude-only tool (`Agent`, `SendMessage`, `TaskCreate`) only alongside its Codex equivalent (`spawn_agent`, `followup_task`/`send_input`, `update_plan`).
- Files already over the 150-line SKILL.md body limit (SDD `SKILL.md` 187, `writing-plans/SKILL.md` 206) must not grow: move detail into `references/`.
- Commit locally on branch `upstream-v7-adoption`, one focused commit per task. No push, tag, version bump, or `bd dolt push`.
- Experiment steps run in scratch repos outside the project with `--setting-sources project`, stay within the step's stated budget, and never edit `~/.claude` settings.

## Execution Notes (not propagated to child beads)

- Tools: `claude` (2.1.269+ for `plugin eval`), `bd`, `shellcheck`, `node`, `python3`, `/bin/bash` 3.2. Homebrew bash >=4 is optional; assertions needing it are skipped. Eval cases tagged `needs-bash` are out of scope (the eval OS sandbox refuses to start if `~/.docker` contains a symlink).
- Experiments (Tasks 1, 3, 4, 6, 7, 9; caps sum to about $31): at most 4 concurrent `claude` processes, logs only under `temp/`, spend reported in the commit message; stop and record a ruling rather than exceed a cap. Scratch repos live in a `mktemp -d` directory outside this repo with no git remote, run with `--setting-sources project`; never push, tag, run `bd dolt push`, or edit `~/.claude`.
- Archived fixtures under `tests/research-2026-09/` quote the old PENDING_HUMAN wording on purpose. Do not edit them.

## Breaking Changes and Consumers

| Change | Consumers to update (grep-verified) | Task |
|--------|-------------------------------------|------|
| `testing-anti-patterns.md` deleted | Only `skills/test-driven-development/SKILL.md` (and its mirror) reference it; `CHANGELOG.md` and `RELEASE-NOTES.md` mentions are history and stay | 6 |
| PENDING_HUMAN / report_to_human holds removed | `plugins/superpowers-bd/agents/code-reviewer.md`, `.codex/agents/code-reviewer.toml`, `skills/requesting-code-review/code-reviewer.md`, SDD `SKILL.md` (all in Task 1) | 1 |
| `codex-execution-checkpoints.md` no longer says "wait for user feedback" | `tests/codex/test-codex-workflow-semantics.sh` lines 120, 133, 188-191 assert the old wording; `tests/verification/test-plugin-config-drift.sh:309` checks the file's mirror | 8 |
| Codex hook commands gain a `bash` prefix | `tests/codex/test-codex-hooks.sh` lines 70-84 assert the exact old command strings | 10 |
| Plan template drops "Complete code in plan" | Plans written by the old template still import; plan2beads parsing is unchanged | 4 |

## File Structure

| File | Responsibility | Action | Task |
|------|---------------|--------|------|
| `skills/subagent-driven-development/SKILL.md` | SDD state machine, review rules, rulings policy | Modify | 1, 2 |
| `skills/subagent-driven-development/rulings-and-escalation.md` | Hard-stop classes, `[RULING]`/`[HUMAN-NEEDED]` formats, async escalation | Create | 1 |
| `skills/subagent-driven-development/failure-recovery.md` | Failure handling → rulings; one reconciled round cap | Modify | 1, 2 |
| `skills/subagent-driven-development/budget-and-wave-cap.md` | Default budget tier, no wave-cap confirm; N scaled by complexity | Modify | 1, 11 |
| `skills/subagent-driven-development/metrics-tracking.md` | Rulings/Escalated lines in `[WAVE-SUMMARY]`; `SDD-STATUS` completion line; fix rounds | Modify | 1, 2 |
| `skills/subagent-driven-development/checkpoint-recovery.md` | Rebuild escalations from `human` label; store fix rounds + agentIds | Modify | 1, 2 |
| `skills/subagent-driven-development/verification-and-evidence.md` | Gap-closure escalation → rulings/async; cap reconciliation | Modify | 1, 2 |
| `skills/subagent-driven-development/spec-reviewer-prompt.md` | Read `[RULING]` comments as spec amendments | Modify | 1 |
| `plugins/superpowers-bd/agents/spec-reviewer.md` | Codex copy of spec-reviewer ruling rule | Modify | 1 |
| `.codex/agents/spec-reviewer.toml` | Codex TOML copy of spec-reviewer ruling rule | Modify | 1 |
| `skills/subagent-driven-development/background-execution.md` | Resume plumbing (Claude + Codex), fix_round tracking, fallback | Modify | 2 |
| `skills/subagent-driven-development/re-review-prompt.md` | Scoped single re-reviewer prompt | Create | 2 |
| `skills/subagent-driven-development/implementer-prompt.md` | "After Review Findings" section; self-review falsifiability lens | Modify | 2, 6 |
| `skills/subagent-driven-development/example-workflow.md` | Worked fix round | Modify | 2 |
| `skills/subagent-driven-development/dispatch-and-conflict.md` | Micro-task batching; interpreter-prefixed script call | Modify | 10, 11 |
| `skills/verification-before-completion/references/gap-closure-protocol.md` | Escalation → bd label, not TaskCreate-only | Modify | 1 |
| `skills/requesting-code-review/code-reviewer.md` | Plan-mandated defect → controller rules; step 8 test lens | Modify | 1, 6 |
| `plugins/superpowers-bd/agents/code-reviewer.md` | Codex copy of reviewer contract | Modify | 1, 6 |
| `.codex/agents/code-reviewer.toml` | Codex TOML copy of reviewer contract | Modify | 1, 6 |
| `docs/README.codex.md` | Codex resume calls (`followup_task` / `send_input`); Codex-facing behavior changes of the epic | Modify | 2, 13 |
| `skills/finishing-a-development-branch/SKILL.md` | Unattended no-label default: keep as-is, recorded | Modify | 3 |
| `skills/using-git-worktrees/SKILL.md` | Unattended defaults: `.worktrees/`, baseline failures recorded | Modify | 3 |
| `skills/using-git-worktrees/references/directory-selection.md` | Same default, detail | Modify | 3 |
| `commands/cr.md` | Skip AskUserQuestion when args fully specify the review | Modify | 3 |
| `skills/writing-plans/SKILL.md` | Lean step recipe, Proportion, `**Spec:**` header, unattended `/compact` + pass-FAIL handling | Modify | 4 |
| `skills/writing-plans/references/plan-step-content.md` | "What a Step Contains" detail moved out to keep SKILL.md under limit | Create | 4 |
| `skills/writing-plans/references/verification-dispatch.md` | Feasibility hand-trace, Optimality proportion | Modify | 4 |
| `skills/writing-plans/references/codex-plan-verification.md` | Same rules for Codex | Modify | 4 |
| `skills/writing-plans/references/announcements-protocol.md` | `/compact` wait skipped when unattended | Modify | 4 |
| `skills/rule-of-five-plans/SKILL.md` | Feasibility/Optimality rows | Modify | 4 |
| `skills/rule-of-five-plans/references/pass-definitions.md` | Same wording | Modify | 4 |
| `commands/plan2beads.md` | Parse `**Spec:**` onto epic; default `completion:commit-only` without asking | Modify | 5 |
| `skills/plan2beads/SKILL.md` | Document Spec pointer + default | Modify | 5 |
| `skills/plan2beads/references/codex-plan2beads-flow.md` | Codex parser parity; no "stop and ask" on missing metadata | Modify | 5 |
| `tests/claude-code/test-plan2beads-metadata.sh` | Spec pointer + default-completion fixtures | Modify | 5 |
| `skills/test-driven-development/references/writing-good-tests.md` | Adapted positive test-quality catalog with lint carve-out | Create | 6 |
| `skills/test-driven-development/references/testing-anti-patterns.md` | Superseded | Delete | 6 |
| `skills/test-driven-development/SKILL.md` | Pointer fires on any test writing; arm-B bullets | Modify | 6 |
| `skills/test-driven-development/references/good-vs-bad-examples.md` | Fix mislabeled Bad example | Modify | 6 |
| `skills/rule-of-five-tests/SKILL.md` | Pass 2/4/5 updates | Modify | 6 |
| `skills/rule-of-five-tests/references/pass-definitions.md` | Same | Modify | 6 |
| `skills/epic-verifier/verifier-prompt.md` | Check 1.3 falsifiability lens; read `[RULING]`/`[DEFERRED]` comments | Modify | 2, 6 |
| `plugins/superpowers-bd/agents/epic-verifier.md` | Codex copy of check 1.3 and ruling reading | Modify | 2, 6 |
| `.codex/agents/epic-verifier.toml` | Codex TOML copy of check 1.3 and ruling reading | Modify | 2, 6 |
| `skills/brainstorming/SKILL.md` | Hybrid v7 skill (intent-first, code-grounded, unattended rule) | Modify | 7 |
| `skills/brainstorming/builder-check-prompt.md` | Builder-check subagent prompt | Create | 7 |
| `evals/brainstorm-before-build/graders/outcome-surfaces-invalidation.md` | Accept staleness raised as the agent's own call | Modify | 7 |
| `evals/brainstorm-greenfield-platform/` | New eval case: greenfield platform ownership | Create | 7 |
| `evals/brainstorm-small-edit-control/` | New eval case: small edit stays fast | Create | 7 |
| `skills/executing-plans/SKILL.md` | Native beads epic execution | Modify | 8 |
| `skills/executing-plans/references/*.md` | Replace batch-checkpoint references with native-mode references | Modify/Delete | 8 |
| `skills/writing-plans/references/execution-handoff.md` | Offer SDD vs Native with cost + recommendation | Modify | 8 |
| `docs/experiments/2026-10-14-upstream-v7/native-vs-sdd-pilot.md` | A/B pilot result | Create | 9 |
| `hooks/run-hook.cmd` | Builtin dirname; explicit bash ≥4 exec | Modify | 10 |
| `hooks/*.sh` (non-sourced entry scripts) | PATH backfill line | Modify | 10 |
| `hooks/link-plugin-components.sh` | Bash 3.2 empty-array fix | Modify | 10 |
| `plugins/superpowers-bd/hooks/hooks.json` | `bash` prefix on Codex hook commands | Modify | 10 |
| `plugins/superpowers-bd/hooks/codex-*.sh` | PATH backfill, matching `hooks/` twins | Modify | 10 |
| `agents/code-reviewer.md`, `agents/epic-verifier.md` | `Agent` in `disallowedTools`; `bash` prefix on hook commands | Modify | 10 |
| `skills/epic-verifier/SKILL.md` | `bash scripts/quality-delta.sh` | Modify | 10 |
| `skills/systematic-debugging/references/root-cause-tracing.md` | `bash find-polluter.sh` | Modify | 10 |
| `skills/writing-skills/references/description-and-discovery.md` | `node render-graphs.js`; one-line interpreter rationale | Modify | 10 |
| `tests/codex/test-codex-hooks.sh` | Expected Codex hook command strings gain `bash` prefix | Modify | 10 |
| `tests/codex/test-codex-workflow-semantics.sh`, `tests/verification/test-plugin-config-drift.sh` | Assertions on the old executing-plans checkpoint reference | Modify | 8 |
| `tests/verification/test-hooks-minimal-path.sh` | Broken/minimal PATH + bash 3.2 hook probe | Create | 10 |
| `scripts/sdd-postmortem.py` | Deterministic session post-mortem | Create | 12 |
| `tests/claude-code/analyze-token-usage.py` | Thin wrapper delegating to sdd-postmortem cost mode | Modify | 12 |
| `tests/claude-code/test-sdd-postmortem.sh` | Fixture tests for the script | Create | 12 |
| `tests/claude-code/fixtures/postmortem/` | Synthetic session + subagent transcripts | Create | 12 |
| `CLAUDE.md` | Token-analysis command points at sdd-postmortem; hook/bash-prefix and rulings notes | Modify | 12, 13 |
| `tests/verification/test-workflow-contract-audit.sh` | New contract checks; convert 3 counterfeit checks | Modify | 13 |
| `RELEASE-NOTES.md` | Unreleased section summarizing the epic | Modify | 13 |

## Tasks

### Task 1: SDD rulings-and-escalation policy

**Depends on:** None
**Complexity:** complex
**Files:**
- Create: `skills/subagent-driven-development/rulings-and-escalation.md`
- Modify: `skills/subagent-driven-development/SKILL.md`, `failure-recovery.md`, `budget-and-wave-cap.md`, `metrics-tracking.md`, `checkpoint-recovery.md`, `verification-and-evidence.md`, `spec-reviewer-prompt.md`
- Modify: `skills/verification-before-completion/references/gap-closure-protocol.md`
- Modify: `skills/requesting-code-review/code-reviewer.md`, `plugins/superpowers-bd/agents/code-reviewer.md`, `.codex/agents/code-reviewer.toml`
- Modify: `plugins/superpowers-bd/agents/spec-reviewer.md`, `.codex/agents/spec-reviewer.toml`
- Mirror: all `skills/` paths above under `plugins/superpowers-bd/skills/`

**Interfaces:**
- Produces:
  - Ruling comment format: `[RULING] <issue-id>: <decision> — why: <reason> — cost if wrong: <impact>`, posted on both the epic and the child.
  - Escalation: `bd label add <id> human` plus a `[HUMAN-NEEDED] <issue-id>: <question>` comment.
  - `rulings-and-escalation.md`, which owns the five hard-stop classes.
  - Completion report first line: `SDD-STATUS: COMPLETE|PARTIAL`.
- Consumes: none

**Purpose:** Remove every SDD human-wait that guards a judgment call rather than an irreversible action (autonomy-holds.md inventory #1–#11).

**Spec:** `autonomy-holds.md` §Item 1, §Item 2 (SDD rows), §Item 4 (policy + change outline items 1–6, 8 first bullet).

**Not In Scope:**
- the fix-loop round mechanics (Task 2);
- reasonable-user judging, the code-reviewer severity-by-effect rule and the epic-verifier "Declined to judge" list (all deferred; autonomy-holds.md outline item 8 bullets 2–3);
- changes to the epic-verifier gate.

**Gotchas:**
- SDD `SKILL.md` is 187 lines and must not grow. Put the policy in the new reference file and leave a 2–3 line pointer in SKILL.md.
- The stub `bd` in the research harness doesn't return comments, so the spec reviewer must read rulings from both `bd comments <child>` and the epic.

**Steps:**
1. Write `rulings-and-escalation.md`: the hard-stop classes (verbatim from Key Decisions), the ruling and escalation formats from Interfaces, and when a ruling is allowed. A ruling is allowed when every option is reversible by a later commit; it is not allowed when the action touches remote state or deletes data.
2. Replace the PENDING_HUMAN holds in SDD `SKILL.md` (pre-flight scan at :26 and :126, the `RE_DISPATCH` row at :116, the >3 pause at :148) with "rule, record, continue". The pre-flight scan records the conflicts it checked and the rulings it made in an epic comment.
3. In `budget-and-wave-cap.md`, resolve the budget tier as: explicit tier → `SDD_BUDGET_TIER` env → `max-5x`, and never re-ask. Drop the wave-cap confirmation at :116; record the chosen cap in `[WAVE-SUMMARY]`.
4. In `failure-recovery.md`, replace every `report_to_human`:
   - plan defect → ruling;
   - scope change → async escalation;
   - capacity → split or bump the model, then async escalation;
   - bd failure → stop with final line `BLOCKED: bd unavailable`.

   Remove the budget re-ask at :204.
5. Route escalations in `verification-and-evidence.md` and `gap-closure-protocol.md` to the bd label path. `TaskCreate` becomes optional, never the only record.
6. In `metrics-tracking.md`, add `Rulings:` and `Escalated:` lines to `[WAVE-SUMMARY]`, plus a "Rulings I made" section and the `SDD-STATUS` first line in the completion report.
7. In `checkpoint-recovery.md`, rebuild pending escalations from `bd list --label human --parent <epic>` on resume.
8. In `spec-reviewer-prompt.md` and its two Codex copies (`plugins/superpowers-bd/agents/spec-reviewer.md`, `.codex/agents/spec-reviewer.toml`), read `[RULING]` comments on the child and the epic as spec amendments, so a requirement amended by a ruling is not returned as CANNOT_VERIFY.
9. Reviewer contract, in all 3 copies: a plan-mandated defect is reported to the controller, which records a ruling. Remove "recommend routing to `bd human` / PENDING_HUMAN".
10. Run the mirror gate, TOML parse, `./tests/codex/run-tests.sh` (expect `Failed: 0`), `./tests/claude-code/run-skill-tests.sh`.
11. Review Focus probe: rerun the conflict and destructive-guard arms of `temp/research-2026-10/autonomy-holds/exp/` (n=2 each, ≤$5). Expect dispatch, a recorded ruling, and the destructive step refused with a `human` label.
12. Commit: `feat(sdd): rule and continue instead of holding for a human`, with the probe results in the body.

### Task 2: Resume-implementer fix loop and scoped re-review

**Depends on:** Task 1
**Complexity:** complex
**Files:**
- Create: `skills/subagent-driven-development/re-review-prompt.md`
- Modify: `skills/subagent-driven-development/SKILL.md`, `background-execution.md`, `implementer-prompt.md`, `failure-recovery.md`, `verification-and-evidence.md`, `checkpoint-recovery.md`, `example-workflow.md`, `metrics-tracking.md`
- Modify: `skills/epic-verifier/verifier-prompt.md`, `plugins/superpowers-bd/agents/epic-verifier.md`, `.codex/agents/epic-verifier.toml`
- Modify: `docs/README.codex.md`
- Mirror: all `skills/` paths above

**Interfaces:**
- Consumes: Task 1 ruling and escalation formats; `rulings-and-escalation.md`.
- Produces:
  - Fix-round states `FIX_ROUND(R) → RE_REVIEW → CLOSE | next round | ADJUDICATE`.
  - Checkpoint fields `fix_round`, `fix_base_sha`, `implementer_agent_id` per task.
  - Re-reviewer verdict lines: `F<n>: ADDRESSED|NOT_ADDRESSED — file:line` and `VERDICT: PASS|FAIL`.

**Purpose:** Make fix rounds cheaper and resistant to wrong findings (resume-implementer.md §Recommendation).

**Spec:** `resume-implementer.md` §Recommendation, §Change outline 1–10.

**Not In Scope:**
- changing the reviewer count of the first review (Task 11);
- a 1-hour cache TTL setting (deferred);
- an eval case for wrong-finding pushback (optional in the spec; skipped, the Review Focus example covers it).

**Gotchas:**
- Never pass `name:` to the implementer `Agent` call.
- Dispatch the fix as soon as consensus findings exist; the cache goes cold after about 5 minutes.
- Three caps currently disagree (>2, >3, >=3). After this task there is exactly one: 3 rounds.
- Minor findings never enter the loop.

**Steps:**
1. Rewrite the review rules in SDD `SKILL.md` (net line count ≤ current) and in `failure-recovery.md` / `verification-and-evidence.md`:
   - round 1 and round 2: resume the implementer (Claude Code: `SendMessage` to its agentId; Codex: `followup_task`, or `send_input` on V1);
   - round 3: fresh dispatch one tier up;
   - after round 3: adjudicate with a Task 1 ruling.
   - Disputes on spec grounds go to a ruling immediately and do not use up a round.
2. In `background-execution.md`:
   - add `on_review_findings → resume`;
   - fallback when the agent can't be messaged: a fresh dispatch with the issue id, `[IMPL-REPORT]` and findings, which does not use up a round;
   - Codex: don't close implementers before review completes.
3. Write `re-review-prompt.md`:
   - check each finding in the fix diff `fix_base_sha..HEAD` only;
   - post new out-of-scope issues as `[DEFERRED]` comments;
   - one reviewer: haiku, or sonnet for `complex` tasks; on Codex, `code_reviewer` with this prompt;
   - ends with the verdict lines from Interfaces;
   - read-only, no subagents (same clause as the other reviewers).
4. Add an "After Review Findings" section to `implementer-prompt.md`:
   - fix, rerun the project suite, append `### Fix round R` to `temp/{issue_id}-impl.md`, commit `fix:`, return the same VERDICT block;
   - a finding that contradicts the spec is not applied: return DONE_WITH_CONCERNS naming the requirement.
5. In `metrics-tracking.md`, record fix rounds and rulings in `[WAVE-SUMMARY]`. In the epic-verifier prompt (3 copies), read `[RULING]` and `[DEFERRED]` comments as context, not as failures. Store the Interfaces checkpoint fields in `checkpoint-recovery.md`. Add a worked round-1 resume plus a fallback example to `example-workflow.md`. Document the Codex resume calls in `docs/README.codex.md`.
6. Run the mirror gate, the Codex suite, the fast skill suite and `./scripts/lint-shell.sh`.
7. Commit: `feat(sdd): resume implementers for fix rounds, scoped re-review`.

### Task 3: Unattended defaults outside SDD

**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`, `skills/using-git-worktrees/SKILL.md`, `skills/using-git-worktrees/references/directory-selection.md`, `commands/cr.md`
- Mirror: the `skills/` paths

**Interfaces:**
- Consumes: none (wording matches Task 1's ruling format, copied here as `[RULING] <decision> — why — cost if wrong` to avoid a dependency).
- Produces: none

**Purpose:** Remove the non-SDD waits that an unattended run can't satisfy (autonomy-holds.md inventory #16, #17, #27, #28, #33).

**Spec:** `autonomy-holds.md` §Item 2 Finishing/Planning rows; §Item 4 change outline 9.

**Not In Scope:**
- plan2beads (Task 5);
- writing-plans (Task 4);
- the discard confirmation, which stays.

**Steps:**
1. Finishing with no `completion:*` label: when no human can answer, keep the branch and worktree and report "Kept as-is (unattended; no completion label)". Base-branch detection uses the merge-base, and the ask happens only interactively.
2. using-git-worktrees:
   - when unattended, default to `.worktrees/`;
   - record pre-existing baseline test failures as the baseline instead of stopping;
   - an interactive session keeps the current asks.
3. `commands/cr.md`: when arguments fully specify the target and N, skip every AskUserQuestion.
4. Review Focus probe: run `claude -p` (n=2, budget ≤$2) on a scratch repo with a finished branch and no label. Verify no merge, no push and no discard (`git log` / `git branch` unchanged), and that the kept-as-is line appears.
5. Run the mirror gate and the fast skill suite. Commit: `feat: unattended defaults for finishing, worktrees and /cr`.

### Task 4: Leaner plans in writing-plans and rule-of-five-plans

**Depends on:** None
**Complexity:** complex
**Files:**
- Create: `skills/writing-plans/references/plan-step-content.md`
- Modify: `skills/writing-plans/SKILL.md`, `skills/writing-plans/references/verification-dispatch.md`, `codex-plan-verification.md`, `announcements-protocol.md`
- Modify: `skills/rule-of-five-plans/SKILL.md`, `skills/rule-of-five-plans/references/pass-definitions.md`
- Mirror: all of the above

**Interfaces:**
- Produces:
  - Plan header line `**Spec:** <path or URL>`, placed between the After-approval note and `**Goal:**`, optional.
  - "What a Step Contains" rules in `plan-step-content.md`.
- Consumes: none

**Purpose:** Stop Opus 5.5 from implementing the project while planning, and shrink plans and beads 2.5–3.5× (leaner-plans.md §2–3).

**Spec:** `leaner-plans.md` §1, §4 items 1–4. Reference version: `artifacts/writing-plans-lean-SKILL.md` and `artifacts/writing-plans-lean.diff`.

**Not In Scope:**
- plan2beads parsing (Task 5);
- the execution handoff (Task 8);
- the deleted upstream reviewer prompt, which bd never had, and the upstream CLAUDE.md removal (leaner-plans.md §4 item 7: do not port);
- plan2beads, `implementer-prompt.md` and `file-lists.md` stay unchanged (spec item 6).

**Gotchas:**
- `writing-plans/SKILL.md` is 206 lines; the lean diff adds about 13. Move "What a Step Contains", the template example and the Optional Metadata detail into `plan-step-content.md` so SKILL.md ends at ≤206 lines (target ≤190).
- The skill's own `Remember` list currently says "Complete code in plan". Replace it with "Decisions, not transcripts".

**Steps:**
1. Port into `writing-plans/SKILL.md` + `plan-step-content.md`:
   - the capable-reader description;
   - "one action with a checkable result" step sizing;
   - "What a Step Contains" (test step, code step, verification step, cross-task reference via Interfaces);
   - a signature-line template Step 3;
   - Step scan and Proportion in the checklist;
   - the `**Spec:**` header line.
2. Unattended handling in `announcements-protocol.md` and the SKILL.md task list: skip the `/compact` wait when no human is present. On a rule-of-five FAIL, fix and re-run that pass once; if it still fails, record a ruling in the plan's Verification Record and continue.
3. `codex-plan-verification.md` also gets the step-content rule, Step scan and Proportion. `verification-dispatch.md`, `codex-plan-verification.md`, rule-of-five-plans `SKILL.md` + `pass-definitions.md`:
   - Feasibility: replace "2-5 min" with "one checkable result" and add "hand-trace; don't build or run the plan's code";
   - Optimality: add "no bodies the signature and tests already determine; plan not several times the spec's length".
4. Verification:
   - `grep -c "Complete code in plan" skills/writing-plans/SKILL.md` = 0;
   - `grep -c "What a Step Contains" skills/writing-plans/SKILL.md` and `grep -c Proportion skills/writing-plans/SKILL.md` ≥ 1 (Task 13 adds these to the audit);
   - `wc -l skills/writing-plans/SKILL.md` ≤ 206;
   - mirror gate; Codex suite; fast suite.
5. Re-run one planning arm with `temp/research-2026-10/leaner-plans/scripts/plan_run.py` against the edited tree (n=2, Opus 5.5, budget ≤$3). Expect no product code run outside the plan, and plan length ≤4× the spec.
6. Commit: `feat(writing-plans): plans record decisions, not code`.

### Task 5: plan2beads Spec pointer and default completion

**Depends on:** Task 4
**Complexity:** standard
**Files:**
- Modify: `commands/plan2beads.md`, `skills/plan2beads/SKILL.md`, `skills/plan2beads/references/codex-plan2beads-flow.md`, `tests/claude-code/test-plan2beads-metadata.sh`
- Mirror: the `skills/` paths

**Interfaces:**
- Consumes: the `**Spec:**` header line from Task 4.
- Produces: epic description line `Spec: <value>`, which SDD context loading reads at setup.

**Purpose:** Get the spec into scope for plan-conflict rulings (upstream #2086: seeded inconsistencies resolved 0–1/5 without the spec vs 4–5/5 with it), and stop the completion-strategy ask from blocking imports.

**Spec:** `autonomy-holds.md` §Item 1 (Spec pointer), inventory #21–#22.

**Steps:**
1. Both parsers copy `**Spec:**` verbatim into the epic description. Absent means unchanged.
2. Completion strategy:
   - with no explicit choice, default to `completion:commit-only` without asking, and say so in the import summary;
   - push or merge labels still require an explicit user choice;
   - the Codex flow's "stop and ask" on missing metadata switches to the Claude path's defaults.
3. Extend `test-plan2beads-metadata.sh`:
   - a fixture with `**Spec:**` must land on the epic;
   - a fixture without it imports unchanged;
   - no-completion-choice yields `commit-only`.
4. Run `./tests/claude-code/test-plan2beads-metadata.sh` (all pass), the mirror gate and the Codex suite.
5. Commit: `feat(plan2beads): carry Spec pointer, default commit-only completion`.

### Task 6: writing-good-tests adaptation

**Depends on:** Task 1, Task 2
**Complexity:** standard
**Files:**
- Create: `skills/test-driven-development/references/writing-good-tests.md`
- Delete: `skills/test-driven-development/references/testing-anti-patterns.md`
- Modify: `skills/test-driven-development/SKILL.md`, `references/good-vs-bad-examples.md`
- Modify: `skills/rule-of-five-tests/SKILL.md`, `references/pass-definitions.md`
- Modify: `skills/requesting-code-review/code-reviewer.md` (step 8), `plugins/superpowers-bd/agents/code-reviewer.md`, `.codex/agents/code-reviewer.toml`
- Modify: `skills/subagent-driven-development/implementer-prompt.md` (self-review line)
- Modify: `skills/epic-verifier/verifier-prompt.md` (check 1.3), `plugins/superpowers-bd/agents/epic-verifier.md`, `.codex/agents/epic-verifier.toml`
- Mirror: all `skills/` paths, including the deletion

**Interfaces:**
- Consumes: none (sequenced after Tasks 1–2 only because they share files)
- Produces: none

**Purpose:** Cut change-detector tests (17/21 → 4/21 measured) and make the test-quality reference load on any test writing.

**Spec:** `writing-good-tests.md` §Recommendation, §Change outline 1–7. Upstream source: `artifacts/writing-good-tests-upstream.md`.

**Not In Scope:**
- "Why Order Matters" (leave as is);
- the Test Integrity policy (leave as is);
- converting the audit's counterfeit checks (Task 13).

**Gotchas:**
- Include the lint carve-out: asserting on executable instructions (tool parameters, commands, links, mirrors) is linting and is allowed. Asserting on prose wording is a change detector.
- The mutation check is either "executed, with `git diff` restore proof" or dropped. Upstream's "mental" version was executed 0/5 times.

**Steps:**
1. Write `writing-good-tests.md` from the upstream file with:
   - `superpowers-bd:` naming;
   - the lint carve-out;
   - the change-detector rule;
   - "trivial code earns no test" scoped to code with no branching.

   Delete the old reference in both trees.
2. TDD `SKILL.md`: replace the Test Quality bullets with the arm-B pointer ("read `references/writing-good-tests.md` when writing or changing any test") plus 4 bullets. Keep the suite-defines-green wording already committed.
3. Relabel the Bad retry example's flaw as the vague name.
4. rule-of-five-tests:
   - Pass 2 becomes Coverage & Falsifiability;
   - Pass 4 drops "mock I/O where possible";
   - Pass 5 allows DRY helpers for setup only;
   - delete the "tests don't have bugs" row;
   - point to the reference.
5. Lens edits:
   - code-reviewer step 8 (3 copies): flag constant-equality asserts, mirror/tautological asserts, grep-the-source behavior tests;
   - implementer self-review: "Comprehensive?" becomes "Each test names the production change that would break it?";
   - epic-verifier 1.3 (3 copies): the same lens.
6. Verify:
   - `grep -rn testing-anti-patterns skills plugins` returns nothing;
   - mirror gate, TOML parse, fast suite, Codex suite.
7. Re-run S1 Sonnet arm B against the edited tree (n=4, budget ≤$2) with `temp/research-2026-10/writing-good-tests/harness/`. Expect change-detector runs ≤1/4.
8. Commit: `feat(tdd): writing-good-tests reference replaces mock-only anti-patterns`.

### Task 7: Brainstorming hybrid

**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/brainstorming/SKILL.md`
- Create: `skills/brainstorming/builder-check-prompt.md`
- Modify: `evals/brainstorm-before-build/graders/outcome-surfaces-invalidation.md`
- Create: `evals/brainstorm-greenfield-platform/` (`prompt.md`, `graders/`), `evals/brainstorm-small-edit-control/` (`prompt.md`, `graders/`, `scaffold.sh`)
- Mirror: the `skills/` paths

**Interfaces:**
- Consumes: none
- Produces: none

**Purpose:** Intent-first brainstorming that still reads the code first, owns platform/stack choices, and behaves sensibly unattended.

**Spec:** `brainstorming-v7.md` §Recommendation, §Change outline. Source: `artifacts/brainstorming-hybrid-SKILL.md`, `artifacts/brainstorming-builder-check-prompt.md`.

**Not In Scope:**
- the visual companion (rejected);
- fixing the trigger rate on existing-code changes (file a bead, Step 5);
- the Bash-enabled variant of `brainstorm-before-build` (spec outline item 3): it is a `needs-bash` case and out of scope per Global Constraints; the bead in Step 5 tracks it.

**Gotchas:**
- Keep the frontmatter description starting "Use when…".
- Keep the `docs/plans/` design location and the worktrees → writing-plans handoff.
- Keep the Codex `request_user_input` line; `tests/codex/test-codex-workflow-semantics.sh:165` asserts it.
- Reflow the 197 hard-wrapped lines to ≤150 body lines and ≤2000 words.

**Steps:**
1. Install the hybrid as `SKILL.md`, reflowed, with bd's handoff and Codex lines restored. Add `builder-check-prompt.md`, read-only with no subagents.
2. Loosen the invalidation grader so it accepts staleness raised as the agent's own call.
3. Add the two eval cases, following the existing case layout:
   - greenfield platform: passes when it asks about, or states and owns, the platform choice before building;
   - small-edit control: passes when it makes the edit without a design doc.
4. Run `claude plugin eval . --tag no-bash --scaffold --allow-tools Write Edit --no-publish` restricted to the brainstorm cases (budget ≤$4). Run the Codex suite and the mirror gate.
5. File the bead: `bd create "Brainstorming does not trigger on existing-code changes when Bash is available (0/15)" -t bug -p 2`, citing `brainstorming-v7.md`.
6. Commit: `feat(brainstorming): intent-first hybrid with builder check`.

### Task 8: Native executing-plans and execution handoff choice

**Depends on:** Task 1
**Complexity:** complex
**Files:**
- Modify: `skills/executing-plans/SKILL.md`, `skills/writing-plans/references/execution-handoff.md`
- Modify/Delete: `skills/executing-plans/references/batch-execution-detail.md`, `batching-example.md`, `report-and-feedback.md` (delete), `codex-execution-checkpoints.md`, `completion-protocol.md`, `epic-scoping-and-deadlock.md` (modify)
- Modify: `tests/codex/test-codex-workflow-semantics.sh` (lines 120, 133, 188-191), `tests/verification/test-plugin-config-drift.sh` (line 309)
- Mirror: all of the above

**Interfaces:**
- Consumes: Task 1 ruling and escalation formats and hard-stop classes (via `subagent-driven-development/rulings-and-escalation.md`).
- Produces: handoff choice `Execution: SDD | Native`, recorded as an epic comment `[EXECUTION-MODE] <mode> — why`.

**Purpose:** A cheaper single-session path for small epics that doesn't stop after every batch (execution-modes.md §1).

**Spec:** `execution-modes.md` §1.

**Not In Scope:**
- nested controllers (rejected);
- batching (Task 11).

**Gotchas:**
- Keep the frontmatter description "Use when…" triggering on a written plan or epic in a separate session.
- Rule-of-five becomes opt-in in Native mode.

**Steps:**
1. Rewrite `executing-plans/SKILL.md` as Native epic execution:
   - for each issue from `bd ready` in dependency order: `bd update --status=in_progress`, TDD, commit, then `bd close` with the test command and its output;
   - rulings and escalations use Task 1's formats;
   - only the hard-stop classes stop the run;
   - when all issues are closed, run the epic-verifier as the single review on the most capable model, then one red→green fix pass with no re-review.
2. Remove the per-batch human checkpoint references and fold what remains into the new flow. Update the two test files that assert the old wording and the reference-file list (the "wait for user feedback" and "does not bypass feedback checkpoints" assertions become Native-mode assertions; if `codex-execution-checkpoints.md` is deleted instead of modified, drop it from both lists). Run the Codex suite before committing.
3. `execution-handoff.md`: offer SDD vs Native with a one-line cost note and a recommendation. Recommend Native for epics of ≤5 issues or all `complexity:simple`, otherwise SDD. When unattended, take the recommendation and record `[EXECUTION-MODE]`.
4. Run the mirror gate, the Codex suite and the fast suite.
5. Commit: `feat(executing-plans): native beads epic execution, handoff choice`.

### Task 9: Native vs SDD pilot

**Depends on:** Task 2, Task 8, Task 10, Task 11
**Complexity:** standard
**Files:**
- Create: `docs/experiments/2026-10-14-upstream-v7/native-vs-sdd-pilot.md`

**Interfaces:**
- Consumes: Task 8's Native mode; the final SDD (Tasks 2, 11) and hooks (Task 10), so the pilot measures what ships and not a mid-edit tree.
- Produces: a go/no-go line for the Native recommendation threshold.

**Purpose:** Confirm Native mode is cheaper and still catches a defect the spec implies but doesn't state before recommending it (execution-modes.md §1 Risks).

**Spec:** `execution-modes.md` §1 Risks.

**Not In Scope:** changing skills. If the pilot fails, record that and change the handoff threshold in a follow-up bead instead.

**Steps:**
1. Build a 4-issue fixture epic with one planted spec-implied defect. Use the `tests/research-2026-09` harness method: fresh repo outside the project, stub `bd` where possible, `--setting-sources project`.
2. Run 3 reps per arm (Native vs SDD, Opus 5.5 controller, budget ≤$15 total). Record cost, wall time, whether the defect was caught, and whether any run stalled.
3. Write the result doc with the method, a table, spend and a go/no-go on the ≤5-issue threshold.
4. Commit: `docs(experiments): native vs SDD pilot`.

### Task 10: Hook robustness and interpreter-prefixed scripts

**Depends on:** None
**Complexity:** complex
**Files:**
- Modify: `hooks/run-hook.cmd`, `hooks/link-plugin-components.sh`, every entry script in `hooks/` (all `.sh` except the sourced `bd-in-progress-count.sh` and `codex-plugin-owns-hook.sh`)
- Modify: `plugins/superpowers-bd/hooks/hooks.json`, `plugins/superpowers-bd/hooks/codex-*.sh`
- Modify: `agents/code-reviewer.md`, `agents/epic-verifier.md`
- Modify: `skills/epic-verifier/SKILL.md`, `skills/subagent-driven-development/dispatch-and-conflict.md` (line ~146 only), `skills/systematic-debugging/references/root-cause-tracing.md`, `skills/writing-skills/references/description-and-discovery.md`
- Modify: `tests/codex/test-codex-hooks.sh` (lines 70-84 assert the exact old command strings)
- Create: `tests/verification/test-hooks-minimal-path.sh`
- Mirror: the `skills/` paths

**Interfaces:**
- Consumes: none
- Produces: `run-hook.cmd` contract: `run-hook.cmd <script> [args]` executes `<script>` with bash ≥4 when available, otherwise `/bin/bash`, without depending on the exec bit or on `PATH`.

**Purpose:** Hooks keep working under cron, launchd and the GUI app (minimal PATH) and under repackagers that strip exec bits (execution-modes.md §6–7, §4 hard enforcement).

**Spec:** `execution-modes.md` §4, §6, §7. Probe: `artifacts/path_probe.sh`.

**Not In Scope:**
- the Windows CMD branch of `run-hook.cmd`, beyond leaving it intact;
- setting `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` for autonomous launches (execution-modes.md §4 optional, untested; document only in the Task 13 notes).

**Gotchas:**
- `plugins/superpowers-bd/hooks/codex-*.sh` intentionally differ from their `hooks/` twins. Apply the same PATH line to each, don't copy files over.
- The `link-plugin-components.sh` crash (unguarded `"${copied_skills[@]}"` / `"${copied_agents[@]}"` loops at :235 and :238) reproduces only under `/bin/bash` 3.2 with `set -u`.
- Keep `pre-compact.sh` and `work-state-anchor.sh` builtin-only.
- Every Claude hook goes through `run-hook.cmd`, so a bad interpreter choice disables all of them. Fail open: if no interpreter is found or `exec` fails, print one stderr line and `exit 0`. Never block a session on launcher trouble. Rollback is a single `git revert` of this task's commit, which is why it lands as one commit.
- The PATH backfill appends system directories after the inherited `PATH`, never before it, so it cannot shadow a binary the caller already resolved.
- `disallowedTools: Agent` binds only when the role is dispatched as a named agent. SDD dispatches the epic verifier as `general-purpose` with `verifier-prompt.md`, so the "no subagent spawning" prompt clause (audited in Task 13) is the real guard there. The named review agents never dispatch anything, so removing `Agent` breaks no legitimate caller.
- The no-subagent clause in the dispatched-role templates is Task 13's job, not this task's, because those files belong to Tasks 1, 2 and 6 and run in parallel with this one.

**Steps:**
1. Write `test-hooks-minimal-path.sh`. For each `hooks.json` command, run it via `/bin/sh -c` under `PATH=/nonexistent` and under `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, plus `link-plugin-components.sh` under `/bin/bash` directly. Assert that no run exits non-zero with `unbound variable`, and that hooks under minimal PATH find `bd` when it is installed in `/opt/homebrew/bin` or `/usr/local/bin` (skip that assertion when it isn't installed). Run it and confirm it fails.
2. `run-hook.cmd`:
   - builtin dirname: `case "$0" in */*) d=${0%/*};; *) d=.;; esac`;
   - choose the interpreter: `$BASH` if its version is ≥4, else the first executable of `/opt/homebrew/bin/bash`, `/usr/local/bin/bash`, `/bin/bash`;
   - `exec "$interp" "$d/$script" "$@"`, failing open as described under Gotchas.
3. Add `PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin"` near the top of each entry script, and of each `plugins/superpowers-bd/hooks/codex-*.sh`.
4. Fix empty-array expansions in `link-plugin-components.sh` with `${arr[@]+"${arr[@]}"}`.
5. Prefix `bash` on every command in `plugins/superpowers-bd/hooks/hooks.json` (and update the expected strings in `tests/codex/test-codex-hooks.sh`), and on the hook commands in the agent frontmatter. Add `Agent` to `disallowedTools` in `agents/code-reviewer.md` and `agents/epic-verifier.md`.
6. Skill text: `bash scripts/quality-delta.sh` (`epic-verifier/SKILL.md:46`, `dispatch-and-conflict.md:146`), `bash find-polluter.sh`, `node render-graphs.js`. Add one rationale line to writing-skills.
7. Run the new test (passes), `./scripts/lint-shell.sh`, `./tests/codex/run-tests.sh`, `bash tests/verification/test-link-plugin-components.sh`, `bash tests/verification/test-plugin-config-drift.sh` and `claude plugin validate .`.
8. Commit: `fix(hooks): PATH-independent launch, bash 3.2 safety, interpreter-prefixed scripts`.

### Task 11: Micro-task batching and complexity-scaled review fan-out

**Depends on:** Task 1, Task 10
**Complexity:** standard
**Files:**
- Modify: `skills/subagent-driven-development/dispatch-and-conflict.md`, `skills/subagent-driven-development/budget-and-wave-cap.md`
- Mirror: both

**Interfaces:**
- Consumes: Task 1's budget-tier resolution in `budget-and-wave-cap.md`.
- Produces:
  - batch-dispatch rule: 3 or more ready issues that are file-disjoint, same-shape and `complexity:simple` go to one implementer;
  - review N by complexity: simple → N=1, standard → tier default, complex → tier default.

**Purpose:** Cut dispatch count on micro-task epics (about 72 dispatches for 12 one-line issues today).

**Spec:** `execution-modes.md` §3.

**Gotchas:** a batch failure is split into single-issue re-dispatches, never retried as a batch.

**Steps:**
1. Add batching to `dispatch-and-conflict.md`:
   - one implementer for the batch;
   - one spec review that checks every listed file of every issue appears in the diff (a missing file is a FAIL for that issue);
   - N=1 code review;
   - a per-issue evidence line when closing each issue;
   - the split-on-failure rule.
2. Add the complexity-scaled N table to `budget-and-wave-cap.md`.
3. Run the mirror gate and the fast suite. Commit: `feat(sdd): batch micro-tasks, scale review N by complexity`.

### Task 12: Deterministic SDD post-mortem script

**Depends on:** None
**Complexity:** standard
**Files:**
- Create: `scripts/sdd-postmortem.py`, `tests/claude-code/test-sdd-postmortem.sh`, `tests/claude-code/fixtures/postmortem/`
- Modify: `tests/claude-code/analyze-token-usage.py`, `CLAUDE.md`

**Interfaces:**
- Consumes: none
- Produces: CLI `python3 scripts/sdd-postmortem.py <session.jsonl> [--json]`. The report has these sections:
  - per-seat and per-model tokens and dollars, including cache read and write;
  - the dispatch tree from `subagents/*.meta.json`;
  - the wave timeline;
  - idle gaps over 10 minutes;
  - joined `temp/verdict-audit.log`, `temp/sdd-notifications.log` and stop-gate counter lines;
  - `path:line` evidence.

**Purpose:** Replace the analyzer that reported $1,752 for a $64 controller (it ignored subagent transcripts and priced cache reads at full input rate).

**Spec:** `execution-modes.md` §5. Starting point: `artifacts/controller_share.py`.

**Not In Scope:**
- a diagnosing skill;
- bundle or issue drafting.

**Gotchas:** pricing lives in one dict at the top of the file, with the source and date in a comment (claude-api table, 2026-10-06). Unknown models are reported as unpriced, never guessed.

**Steps:**
1. Build synthetic fixtures:
   - a session with 2 subagents (one nested via `parentAgentId`);
   - a session with zero subagents;
   - a subagent with no `meta.json`;
   - known token counts so the dollar totals can be checked by hand.
2. Write `test-sdd-postmortem.sh` asserting:
   - exact dollar totals per seat, including cache reads at the cache rate;
   - nested depth in the tree;
   - no traceback on the degenerate fixtures;
   - an idle gap is detected.

   Run it and confirm it fails.
3. Implement the script (stdlib only) and make `analyze-token-usage.py` delegate to its cost section.
4. Update the CLAUDE.md "Token Usage Analysis" command. Run the test (passes) and `./scripts/lint-shell.sh`.
5. Commit: `feat(scripts): sdd-postmortem with cache-aware per-seat cost`.

### Task 13: Contract audit and release notes

**Depends on:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, Task 11, Task 12
**Complexity:** standard
**Files:**
- Modify: `tests/verification/test-workflow-contract-audit.sh`, `RELEASE-NOTES.md`, `docs/README.codex.md`, `CLAUDE.md`
- Modify (only where the clause is missing): the dispatched-role templates `skills/subagent-driven-development/implementer-prompt.md`, `spec-reviewer-prompt.md`, `re-review-prompt.md`, `skills/requesting-code-review/code-reviewer.md`, `skills/epic-verifier/verifier-prompt.md`, plus their `plugins/superpowers-bd/agents/*.md` and `.codex/agents/*.toml` copies and `skills/` mirrors

**Interfaces:**
- Consumes: the artifacts every task produces.
- Produces: none

**Purpose:** Lint the new invariants, retire counterfeit checks, and record the change set.

**Spec:** `writing-good-tests.md` §bd's own grep-style tests; `autonomy-holds.md` change outline 10.

**Steps:**
1. Add lint checks (executable invariants only, per the Task 6 carve-out):
   - no `PENDING_HUMAN` or "WAIT for human" in `skills/subagent-driven-development/`;
   - `re-review-prompt.md` exists and is mirrored;
   - no `name:` in the implementer dispatch block;
   - "Complete code in plan" absent;
   - `testing-anti-patterns` absent;
   - `plugins/superpowers-bd/hooks/hooks.json` commands start with `bash`;
   - `Agent` in `disallowedTools` of both review agents;
   - "What a Step Contains" and "Proportion" present in `writing-plans/SKILL.md`;
   - `background-execution.md` documents the unmessageable-implementer fallback and `on_review_findings`;
   - the no-subagent-spawning clause in every dispatched-role template (implementer, spec-reviewer, code-reviewer, re-review, epic-verifier; Claude skill, plugin agent and TOML copies). Add the clause where the audit finds it missing; this task owns that edit so it cannot collide with Tasks 1, 2 and 6;
   - `spec-reviewer` Codex copies mention `[RULING]`.
2. Convert the 3 epic-verifier persistence checks into executions: run the persistence heredoc in a temp git repo against a stub `bd` and assert the report file plus `bd comments add` invocation.
3. Add a `## Unreleased` section to `RELEASE-NOTES.md` summarizing Tasks 1–12, each with its headline measurement. Add a short Codex-behavior note to `docs/README.codex.md` (rulings/async escalation, Native execution mode, resume calls, `bash`-prefixed hooks) and a line in `CLAUDE.md` for the rulings policy and hook launch contract.
4. Run the full validation:
   - `bash tests/verification/test-workflow-contract-audit.sh`;
   - `./tests/codex/run-tests.sh`;
   - `./tests/claude-code/run-skill-tests.sh`;
   - `./scripts/lint-shell.sh`;
   - `claude plugin validate .`;
   - `git diff --check`;
   - the mirror gate.
5. Commit: `test: contract audit for upstream v7 adoption; release notes`.

---

## Verification Record

### Plan Verification Checklist
| Check | Status | Notes |
|-------|--------|-------|
| Complete | PASS | All nine accepted items map to Tasks 1–12; deferred items excluded |
| Accurate | PASS | Referenced paths checked with ls; line refs re-verified by the Feasibility pass |
| Commands valid | PASS | Test runners, lint, validate and research harness scripts exist |
| YAGNI | PASS | Task 9 pilot kept: the research made it a precondition for recommending Native |
| Minimal | PASS | 1+3 sequenced as Tasks 1→2; per-task audit edits consolidated into Task 13 |
| Not over-engineered | PASS | One hard enforcement only (`disallowedTools: Agent`) |
| Key Decisions documented | PASS | 5 decisions with measured rationale |
| Review Focus covered | PASS | 5 items, each names an owning task and a test |
| Context sections present | PASS | Purpose/Spec/Not In Scope on every task |
| File Structure complete | PASS | Synced by the Completeness pass |
| Importable task headings | FIXED | `4a`/`4b` renumbered to integer Tasks 1–13 |

### Rule-of-Five-Plans Passes
| Pass | Status | Changes | Summary |
|------|--------|---------|---------|
| Draft | EDITED | 3 | Restored two shell expansions stripped by renumbering; added Task 9 to Task 13's dependencies |
| Feasibility | EDITED | 3 | `Failed: 0` expectation; link-plugin-components line refs :235/:238; external requirements noted |
| Completeness | EDITED | 16 | Codex spec-reviewer copies, epic-verifier ruling reads, explicit Not-In-Scope for deferred items, File Structure synced |
| Risk | EDITED | 9 | Moved a cross-task template edit to Task 13; tests asserting old hook/checkpoint strings added to owning tasks; breaking-changes table; run-hook rollback; experiment guardrails |
| Optimality | EDITED | 4 | Global Constraints cut to non-propagated Execution Notes where single-task; parent restored one experiment-isolation line because six tasks run experiments |

