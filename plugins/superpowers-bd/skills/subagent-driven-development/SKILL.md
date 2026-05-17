---
name: subagent-driven-development
description: Use when user says "execute epic [id]" or when executing beads epics with parallel subagents in the current session
effort: xhigh
---

# Subagent-Driven Development

Execute a beads epic by dispatching independent implementation issues in parallel waves, then reviewing each completion before closing it.

**Required background:** Load `superpowers-bd:beads` first. If no beads epic exists, run `plan2beads` first. If the work is a plain markdown plan in a separate session, use `executing-plans` instead.

**Announce:** "I'm using Subagent-Driven Development to execute beads epic [epic-id]."

## Quick Start: Shared Workflow

1. `bd show <epic-id>`; parse children, acceptance criteria, Key Decisions, and completion strategy.
2. Detect platform: `claude-code`, `codex`, or another supported native layer. Store it as `platform` in the checkpoint.
3. If `temp/sdd-checkpoint-{epic_id}.json` exists, restore it and resume from the next wave. Do not re-ask budget tier, platform, or wave cap.
4. Choose budget tier once (`max-20x`, `max-5x`, or `pro/api`) and store it in the checkpoint.
5. Detect context tier. Claude Code: `[1m]` model suffix means extended; otherwise standard. Codex: use visible model/context info; if unknown, default to standard.
6. Build `platform_agent_plan` once per session and store it in the checkpoint. It must name the native dispatch path for implementers, spec reviewers, code reviewers, aggregators, and epic verifier.
7. Claude Code only: detect Codex cross-model advisory review by looking for `<codex-integration>`. Store `codex_enabled` and `codex_install_path` in the checkpoint. In Codex sessions, omit `codex_install_path` and set `codex_enabled: false` or leave it absent because Codex is the orchestrator.
8. Run `bd ready`, filter to this epic's children, and exclude blocked/cross-epic/file-conflicting issues.
9. Select wave cap. Use explicit invocation first; otherwise use the budget/context heuristic in `budget-and-wave-cap.md`.
10. Dispatch implementers in parallel for non-conflicting ready issues. Mark each issue `in_progress` before dispatch.
11. Route implementer status: `DONE`/`DONE_WITH_CONCERNS` -> review; `NEEDS_CONTEXT`/`BLOCKED` -> re-dispatch or escalate.
12. Run review pipeline: spec review, code review(s), platform-native aggregation when needed, and gap closure up to 3 attempts.
13. Close passing issues immediately with evidence, post `[WAVE-SUMMARY]`, update checkpoint, and loop back to `bd ready`.
14. When all implementation tasks are closed, dispatch the platform-native epic verifier; after PASS, run `finishing-a-development-branch`.

## Claude Code Dispatch Path

1. Use `Task` with `run_in_background: true` for implementers, spec reviewers, code reviewers, aggregation, simplification, and epic verification.
2. Route implementer/reviewer models with the Claude Code table in `budget-and-wave-cap.md`.
3. For 2+ code reviewers, aggregate with `multi-review-aggregation`.
4. If `codex_enabled: true`, run the Codex cross-model advisory review in parallel with Claude Code code reviewers. This is Claude-only advisory input and must not replace Claude reviewer verdicts.

## Codex Dispatch Path

1. Use `spawn_agent` for implementers and reviewers; use `wait_agent` only when the orchestrator is blocked on a result.
2. Route specialist work through Codex native agents when available: `spec_reviewer`, `code_reviewer`, `review_aggregator`, and `epic_verifier`.
3. Route Codex model strength by `model_reasoning_effort` per project policy in `budget-and-wave-cap.md`; do not describe Codex work using Claude Opus/Sonnet/Haiku tiers.
4. Assign explicit file ownership in every implementer prompt, tell workers they are not alone in the codebase, and keep write scopes disjoint within each wave.

## Checkpoint Platform Fields

The checkpoint schema includes these platform fields in addition to wave, budget, and metric fields:

```json
{
  "platform": "codex",
  "platform_agent_plan": {
    "implementer": "spawn_agent default worker with issue-owned files",
    "spec_review": "spawn_agent agent=spec_reviewer",
    "code_review": "spawn_agent agent=code_reviewer",
    "review_aggregation": "spawn_agent agent=review_aggregator when N > 1",
    "epic_verification": "spawn_agent agent=epic_verifier"
  },
  "codex_enabled": false
}
```

`codex_enabled` means "Claude Code has an external Codex advisory integration available." It is not a Codex-native review switch.

## Legacy Quick Start Mapping

If you are updating an older checkpoint or prompt, map old behavior as follows:

1. Missing `platform` -> infer from the current session and write it at the next checkpoint.
2. Missing `platform_agent_plan` -> rebuild from the active dispatch path.
3. Missing `codex_enabled` in Claude Code -> detect `<codex-integration>` and store the result.
4. Missing `codex_enabled` in Codex -> treat as false; native Codex sessions do not run a separate Codex cross-model advisory review.

## Platform Mapping

- **Claude Code:** use `Task` with `run_in_background: true` as shown in prompt templates.
- **Codex:** use `spawn_agent` for implementers/reviewers and `wait_agent` only when the controller is blocked. Use `.codex/agents/` names `spec_reviewer`, `code_reviewer`, `review_aggregator`, and `epic_verifier` for specialist stages.
- **Progress tracking:** map `TaskCreate`/`TaskUpdate` blocks to the native progress tracker. Beads remains the durable source of truth for issue state.
- **Questions:** use `AskUserQuestion` only where available; otherwise ask concise direct questions.

## Budget Summary

Budget tier selects implementer/reviewer strength and review count. Exact model routing is platform-specific:

**Claude Code policy**

| Tier | Implementer cap | Spec reviewer | Code reviews | Verifier | Simplify |
|------|-----------------|---------------|--------------|----------|----------|
| max-20x | opus | sonnet for complex | 3 | opus | yes |
| max-5x | opus | sonnet for complex | 3 | opus | yes |
| pro/api | sonnet | haiku | 1 | sonnet | no |

**Codex project policy**

| Tier | Implementer effort | Spec reviewer | Code reviews | Aggregator | Verifier | Simplify |
|------|--------------------|---------------|--------------|------------|----------|----------|
| max-20x | `gpt-5.3-codex` with `model_reasoning_effort=high` or `xhigh` for complex | `spec_reviewer` (`high`) | 3 x `code_reviewer` (`high`) | `review_aggregator` (`medium`) | `epic_verifier` (`xhigh`) | yes |
| max-5x | `gpt-5.3-codex` with `model_reasoning_effort=high` or `xhigh` for complex | `spec_reviewer` (`high`) | 3 x `code_reviewer` (`high`) | `review_aggregator` (`medium`) | `epic_verifier` (`xhigh`) | yes |
| pro/api | `gpt-5.3-codex` with `model_reasoning_effort=medium` or `high` for complex | `spec_reviewer` (`high`) | 1 x `code_reviewer` (`high`) | skip | `epic_verifier` (`xhigh`) | no |

The Codex table is this repository's project policy from the current Codex agent layer, not an external guarantee about model availability.

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

Code review count follows the budget tier. In Claude Code, 2+ Claude reviewers are aggregated with `multi-review-aggregation`. In Codex, 2+ `code_reviewer` agents are aggregated with `review_aggregator`.

Claude-only Codex cross-model advisory language applies only when Claude Code detects a separate Codex integration. In native Codex sessions, Codex is the orchestrator and uses native agents rather than reviewing itself as an advisory external model.

If reviewers find issues, loop: implementer fixes, reviewers re-check, and closure happens only after evidence passes. More than 3 failed review attempts -> pause for human.

## Guardrails

**Never:** dispatch blocked issues, cross-epic issues, or file-conflicting issues in the same wave; skip `bd update --status=in_progress`; close without review evidence; start code review before spec review passes; skip Claude-only Codex advisory review when `platform: "claude-code"` and `codex_enabled: true` in the checkpoint.

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
- `background-execution.md`: event-driven dispatch and platform-native review presentation
- `dispatch-and-conflict.md`: file conflict algorithm and dispatch routing
- `verification-and-evidence.md`: gap closure loop and evidence extraction
- `metrics-tracking.md`: summary templates and usage tracking
- `context-loading.md`: self-read pattern and orchestrator responsibilities
- `failure-recovery.md`: timeout, rejection loop, deadlock, bd errors
- `example-workflow.md`: complete worked example

<!-- compressed: 2026-05-14, original: 235 lines, compressed: 123 lines -->
