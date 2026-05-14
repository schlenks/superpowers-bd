---
name: subagent-driven-development
description: Use when user says "execute epic [id]" or when executing beads epics with parallel subagents in the current session
effort: xhigh
---

# Subagent-Driven Development

Execute a beads epic by dispatching independent implementation issues in parallel waves, then reviewing each completion before closing it.

**Required background:** Load `superpowers-bd:beads` first. If no beads epic exists, run `plan2beads` first. If the work is a plain markdown plan in a separate session, use `executing-plans` instead.

**Announce:** "I'm using Subagent-Driven Development to execute beads epic [epic-id]."

## Quick Start

1. `bd show <epic-id>`; parse children, acceptance criteria, Key Decisions, and completion strategy.
2. If `temp/sdd-checkpoint-{epic_id}.json` exists, restore it and resume from the next wave. Do not re-ask budget tier or wave cap.
3. Choose budget tier once (`max-20x`, `max-5x`, or `pro/api`) and store it in the checkpoint.
4. Detect context tier. Claude: `[1m]` model suffix means extended; otherwise standard. Codex: use visible model/context info; if unknown, default to standard.
5. Detect Codex cross-model review only in Claude sessions by looking for `<codex-integration>`. Store `codex_enabled` and install path in the checkpoint.
6. Run `bd ready`, filter to this epic's children, and exclude blocked/cross-epic/file-conflicting issues.
7. Select wave cap. Use explicit invocation first; otherwise use the budget/context heuristic in `budget-and-wave-cap.md`.
8. Dispatch implementers in parallel for non-conflicting ready issues. Mark each issue `in_progress` before dispatch.
9. Route implementer status: `DONE`/`DONE_WITH_CONCERNS` -> review; `NEEDS_CONTEXT`/`BLOCKED` -> re-dispatch or escalate.
10. Run review pipeline: spec review, code review(s), Codex advisory review when enabled, and gap closure up to 3 attempts.
11. Close passing issues immediately with evidence, post `[WAVE-SUMMARY]`, update checkpoint, and loop back to `bd ready`.
12. When all implementation tasks are closed, dispatch `epic-verifier`; after PASS, run `finishing-a-development-branch`.

## Platform Mapping

- **Claude Code:** use `Task` with `run_in_background: true` as shown in prompt templates.
- **Codex:** use `spawn_agent` for implementers/reviewers and `wait_agent` only when the controller is blocked. Assign explicit file ownership, tell workers they are not alone in the codebase, and keep write scopes disjoint within each wave.
- **Progress tracking:** map `TaskCreate`/`TaskUpdate` blocks to the native progress tracker. Beads remains the durable source of truth for issue state.
- **Questions:** use `AskUserQuestion` only where available; otherwise ask concise direct questions.

## Budget Summary

Budget tier selects implementer/reviewer model strength and review count:

| Tier | Implementer cap | Spec reviewer | Code reviews | Verifier | Simplify |
|------|-----------------|---------------|--------------|----------|----------|
| max-20x | opus | sonnet for complex | 3 | opus | yes |
| max-5x | opus | sonnet for complex | 3 | opus | yes |
| pro/api | sonnet | haiku | 1 | sonnet | no |

Default issue complexity is `standard`. Use `complexity:simple|standard|complex` labels when present. Full formulas and edge cases: `budget-and-wave-cap.md`.

## State Machine

```
INIT -> LOADING -> DISPATCH -> MONITOR -> STATUS_ROUTE
STATUS_ROUTE [DONE|DONE_WITH_CONCERNS] -> REVIEW -> CLOSE -> LOADING
STATUS_ROUTE [NEEDS_CONTEXT|BLOCKED] -> RE_DISPATCH -> MONITOR
RE_DISPATCH [>2 attempts] -> PENDING_HUMAN
LOADING [no open implementation tasks] -> EPIC_VERIFIER -> COMPLETE
```

## Implementer Status Routing

**DONE:** Start spec review, then code review pipeline.

**DONE_WITH_CONCERNS:** Forward correctness/scope concerns to the spec reviewer. Note observational concerns in the wave summary.

**NEEDS_CONTEXT:** Re-dispatch same issue with missing context. If this happens more than twice, escalate.

**BLOCKED:** Decide whether the fix is more context, stronger model, task split, or human plan correction. Never ignore a blocker.

## Review Rules

Spec review happens before code quality review. The spec reviewer is skeptical: they must verify against code and requirements, not trust the implementer's report.

Code review count follows the budget tier. For 2+ Claude reviewers, aggregate with `multi-review-aggregation`. Codex review is advisory only and must not replace Claude reviewer verdicts.

If reviewers find issues, loop: implementer fixes, reviewers re-check, and closure happens only after evidence passes. More than 3 failed review attempts -> pause for human.

## Guardrails

**Never:** dispatch blocked issues, cross-epic issues, or file-conflicting issues in the same wave; skip `bd update --status=in_progress`; close without review evidence; start code review before spec review passes; skip Codex review when `codex_enabled: true` in the checkpoint.

**Always:** check `bd ready` before each wave; compare file lists for conflicts; close passing issues immediately; re-check `bd ready` after each close; write checkpoint after each wave; post `[WAVE-SUMMARY]`.

**Deadlock:** `bd ready` empty but open issues remain -> inspect `bd blocked` for circular dependencies or forgotten closes.

**Crash/compact recovery:** read `temp/sdd-checkpoint-{epic_id}.json`, restore wave state, and resume at LOADING. At COMPLETE, delete checkpoint and metrics files.

## Prompt Templates

- `implementer-prompt.md`: implementation worker contract, self-read pattern, report format
- `spec-reviewer-prompt.md`: skeptical requirements compliance review
- `code-quality-reviewer-prompt.md`: code quality review
- `skills/epic-verifier/verifier-prompt.md`: final epic verification
- `simplifier-dispatch-guidance.md`: post-wave simplification when enabled

## Companion Files

- `budget-and-wave-cap.md`: model matrix, context-tier wave cap formulas, edge cases
- `checkpoint-recovery.md`: checkpoint schema, recovery logic
- `background-execution.md`: event-driven dispatch and Codex review presentation
- `dispatch-and-conflict.md`: file conflict algorithm and dispatch routing
- `verification-and-evidence.md`: gap closure loop and evidence extraction
- `metrics-tracking.md`: summary templates and usage tracking
- `context-loading.md`: self-read pattern and orchestrator responsibilities
- `failure-recovery.md`: timeout, rejection loop, deadlock, bd errors
- `example-workflow.md`: complete worked example

<!-- compressed: 2026-05-14, original: 235 lines, compressed: 123 lines -->
