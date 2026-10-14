---
name: executing-plans
description: Use when you have a written implementation plan or beads epic to execute yourself in a separate session, or when the execution handoff chose Native mode
effort: medium
---

# Executing Plans (Native Mode)

Implement every issue of a beads epic yourself, in this session: no implementer subagent per issue and no reviewer per issue. One fresh-context review of the whole epic at the end.

**Announce at start:** "I'm using the executing-plans skill to execute this epic natively."
**REQUIRED BACKGROUND:** Read `superpowers-bd:beads` (bd CLI usage, dependencies) and `../subagent-driven-development/rulings-and-escalation.md` (hard stops, `[RULING]` and `[HUMAN-NEEDED]` formats). This skill reuses that file's policy; it does not restate it.
**Prerequisite:** A beads epic. If you only have a markdown plan, convert it with `plan2beads` first.

**Why Native:** SDD pays for a fresh implementer and fresh reviewers on every issue. Native pays for one context (yours) plus one verifier at the end. Beads replaces what the fresh contexts bought: the issue body is the brief, `bd` is the durable ledger that survives compaction, TDD is the per-issue gate, and the epic verifier is the second pair of eyes.

**Continuous execution.** Do not stop between issues to report or ask "should I continue?". Only the hard stops in `rulings-and-escalation.md` wait for a human, and even they never pause independent work. Everything else gets a `[RULING]` and you keep going.

## When to Use

- The execution handoff chose `Execution: Native` (`../writing-plans/references/execution-handoff.md`), typically an epic of ≤5 issues or all `complexity:simple`.
- No subagent tool is available. Never fabricate a dispatch; run the epic here.

Prefer `superpowers-bd:subagent-driven-development` for long epics (later issues would run on a compacted context) or when a review gate on every issue is wanted.

## Platform Routing

- **Claude Code:** this file. Progress mirrors (`TaskCreate`/`TaskUpdate`, when enabled) are optional and never the record.
- **Codex:** also follow `references/codex-execution-checkpoints.md` (`update_plan` mirror, `spawn_agent agent=epic_verifier`).

## Setup

1. `bd show <epic-id>`: note the Key Decisions, the `Spec:` line, the child IDs and the verification task (the child titled "Epic Verification" or containing "verify"). Read the spec if one is named; it outranks the issue text (authority order in `rulings-and-escalation.md`).
2. **Resume check:** closed children are done; do not redo them. A child already `in_progress` was interrupted: read `bd comments <id>` and `git log --oneline` for its commits before continuing it. After compaction, trust bd and git over your memory.
3. **Pre-flight scan:** read every open child body. Check each child's steps against the hard stops (Dispatch-Time Guard) and scan for contradictory requirements on a shared surface, as in SDD `SKILL.md` "Pre-flight Requirement-Conflict Scan". Rule, record, continue.
4. **REQUIRED SUB-SKILL:** load `superpowers-bd:test-driven-development` now. It governs every issue below.

## The Issue Loop

Ready work for this epic = `bd ready --exclude-label human`, intersected with the epic's child IDs, minus the verification task (`references/epic-scoping-and-deadlock.md`). Take issues in that dependency order, one at a time:

1. `bd update <id> --status=in_progress`, then `bd show <id>` and `bd comments <id>` (earlier rulings live there). Read the issue every time, even if you remember it from the scan.
2. Work its steps in order under TDD: write the test, watch it fail for the expected reason, make it pass. Run every verification the issue names and read the output.
3. When a step's output disagrees with the issue:
   - **The code is wrong:** use `superpowers-bd:systematic-debugging`. Fix the cause, never the symptom.
   - **The issue is wrong** (contradicts the spec or an earlier issue's interface, or a command cannot work): rule on the smallest change that satisfies the higher authority and post the `[RULING]` on the epic and the issue before continuing.
4. Commit the work with your own paths only.
5. Close with evidence, under `superpowers-bd:verification-before-completion`:
   `bd close <id> --reason "commit <sha>; tests: <command> -> <result line>"`
   Never close an issue whose final test run you did not see pass.
6. Back to `bd ready --exclude-label human` for newly unblocked issues.

**Rule-of-five is opt-in here.** Apply a `rule-of-five-*` variant only when the issue, the epic, or the user asks for it. The final verifier already applies rule-of-five lenses to files with more than 50 changed lines.

**Escalations do not stop the run.** When a hard stop applies, file the `[HUMAN-NEEDED]` question bead exactly as `rulings-and-escalation.md` says, leave the work item open and blocked, and continue with every independent ready issue. Never work on a question bead.

## Final Review

When every implementation child is closed, the verification task becomes ready. Run the epic verifier as the single review of the whole epic; see `references/completion-protocol.md` for dispatch details.

- Dispatch it fresh and read-only on the **most capable available model**, set explicitly (Claude Code: `Agent` with `model: "opus"`; Codex: `spawn_agent agent=epic_verifier`). An omitted model inherits the session's, which may not be the most capable. Do not replace it with your own read of the diff.
- **One fix pass, no re-review.** For every FAIL finding: write the test that reproduces it, watch it fail, fix, watch it pass, then run the whole suite. A finding you decide not to fix is a `[RULING]`, except a security defect, which is never ruled "keep" and escalates instead. There is no second fix pass and no second verifier dispatch.

## Finish

- Any open epic child, including a question bead, ends the run `SDD-STATUS: PARTIAL`; do not run `finishing-a-development-branch`.
- Otherwise close the verification task with its evidence, report `SDD-STATUS: COMPLETE`, and use `superpowers-bd:finishing-a-development-branch`.
- The final report lists every ruling under "Rulings I made" (from `bd comments <epic-id>`), each with its cost if wrong, and every escalation with its question bead ID.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I remember what issue N says" | You remember a summary. `bd show` has the exact values. Read it. |
| "Let me check in before the next issue" | Native was chosen to run without check-ins. Only the hard stops stop you. |
| "The issue is wrong, I'll just do the right thing" | Do it, and post the `[RULING]`. An unrecorded deviation is a decision made in secret. |
| "I read my own diff; the verifier is redundant" | Same author, same blind spots. The verifier is the one fresh context this run buys. |
| "The fix is obvious, no failing test needed" | The failing test is the only proof the finding was real and is gone. |
| "I'll re-run the verifier after fixing" | The covering tests answer "addressed" and the suite answers "broke nothing". One pass. |

## Integration

- **plan2beads**: creates the epic.
- **writing-plans** `references/execution-handoff.md`: chooses Native vs SDD and records `[EXECUTION-MODE]`.
- **superpowers-bd:epic-verifier**: the final review.
- **superpowers-bd:finishing-a-development-branch**: after a COMPLETE run.
- **superpowers-bd:subagent-driven-development**: the alternative, with per-issue subagents and reviews.

## Reference Files

- `references/epic-scoping-and-deadlock.md`: scoping `bd ready` to the epic, deadlock detection, bd failures
- `references/completion-protocol.md`: epic verifier dispatch, the single fix pass, closing and handoff
- `references/codex-execution-checkpoints.md`: Codex-native progress tracking and verifier dispatch
