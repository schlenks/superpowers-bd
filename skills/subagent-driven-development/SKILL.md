---
name: subagent-driven-development
description: Use when user says "execute epic [id]" or when executing beads epics with parallel subagents in the current session
---

# Subagent-Driven Development

Execute beads epic by dispatching parallel subagents for independent issues, with two-stage review after each completion.

**Core principle:** Parallel dispatch of independent tasks + dependency awareness + two-stage review = high quality, maximum throughput

**REQUIRED BACKGROUND:** You MUST understand `superpowers:beads` before using this skill.

**Preconditions:** Beads epic exists with dependencies set. If not → run `plan2beads` first. If executing in a separate session → use `executing-plans` instead.

**Announce at start:** "I'm using Subagent-Driven Development to execute beads epic [epic-id]."

## Quick Start

1. Ask budget tier (max-20x / max-5x / pro-api) — sets model matrix for session
2. Load epic: `bd show <epic-id>`, parse children and Key Decisions
3. Get ready tasks: `bd ready`, filter to epic children only
4. Check file conflicts, cap wave at 3 tasks, write `.claude/file-locks.json`
5. Dispatch implementers in parallel (`run_in_background: true`)
6. As each completes: spec review → code review → verification → evidence → `bd close`
7. Post wave summary to epic comments (cost + conventions)
8. Repeat from step 3 until all children closed
9. Print epic completion report, cleanup file-locks.json, run `finishing-a-development-branch`

## Budget Tier Selection

| Tier | Implementer | Spec | Code | N Reviews | Verifier | Simplify |
|------|-------------|------|------|-----------|----------|----------|
| max-20x | opus | sonnet | sonnet | 3 | opus | Yes |
| max-5x | sonnet | haiku | sonnet | 3 | sonnet | Yes |
| pro/api | sonnet | haiku | haiku | 1 | sonnet | Skip |

Store selection for the session — don't ask again per wave.

## The Process

Read companion files as needed during execution. Core loop:

```
LOADING: bd ready → filter to epic → check file conflicts → cap at 3
DISPATCH: write file-locks.json → bd update --status=in_progress → dispatch async
MONITOR: poll TaskOutput(block=False, timeout=5000) → route completions
REVIEW: spec review → code review (N reviews if tier allows) → gap closure (max 3 attempts)
CLOSE: extract evidence → bd close --reason → simplify (if 2+ tasks) → wave summary
→ loop back to LOADING until all closed → COMPLETE
```

## Key Rules (GUARDS)

**Never:** dispatch blocked issues, dispatch cross-epic issues, dispatch file-conflicting issues in same wave, skip `bd update --status=in_progress`, skip `bd close` after review, skip reviews, start code review before spec passes.

**Always:** check `bd ready` before each wave, compare file lists for conflicts, `bd close` immediately after review passes, re-check `bd ready` after each close.

**Deadlock:** If `bd ready` empty but issues remain open → check `bd blocked` for circular deps or forgotten closes.

**Failure:** On crash restart fresh, on >2 review rejections pause for human, on >3 verification failures escalate. See [failure-recovery.md](failure-recovery.md).

## Companion Files

Read these on-demand during execution:

| File | When to read |
|------|-------------|
| [metrics-tracking.md](metrics-tracking.md) | Wave end (summary template), epic end (report template), cost formulas |
| [background-execution.md](background-execution.md) | Dispatching 2+ tasks (polling pseudocode, review pipeline parallelism) |
| [verification-and-evidence.md](verification-and-evidence.md) | After reviews pass (gap closure loop, evidence extraction) |
| [wave-orchestration.md](wave-orchestration.md) | Creating TaskCreate/TaskUpdate tracking calls |
| [example-workflow.md](example-workflow.md) | First time using this skill (complete 3-wave worked example) |
| [failure-recovery.md](failure-recovery.md) | On any failure (timeout, rejection loop, deadlock, bd errors) |
| [dispatch-and-conflict.md](dispatch-and-conflict.md) | Dispatch decision routing, file conflict algorithm, parallel dispatch pseudocode |
| [context-loading.md](context-loading.md) | Before first wave (epic context, wave conventions, template slots) |

## Prompt Templates

- `./implementer-prompt.md` — includes `[EPIC_GOAL]`, `[KEY_DECISIONS]`, `[TASK_PURPOSE]`, `[WAVE_CONVENTIONS]` slots
- `./spec-reviewer-prompt.md` — spec compliance
- `./code-quality-reviewer-prompt.md` — code quality
- `./simplifier-dispatch-guidance.md` — post-wave simplification (skip on pro/api, skip single-task waves)

## State Machine

```
INIT → LOADING → DISPATCH → MONITOR → REVIEW → CLOSE → LOADING (loop)
                                                      → COMPLETE (all closed)
REVIEW → PENDING_HUMAN (verification >3 attempts)
```

## Integration

- **plan2beads** — must run first to create epic
- **superpowers:finishing-a-development-branch** — after COMPLETE state
- **superpowers:test-driven-development** — subagents use for implementation
- **superpowers:rule-of-five** — subagents use for artifacts >50 lines
- **superpowers:executing-plans** — alternative for parallel session
