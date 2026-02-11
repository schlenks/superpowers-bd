---
name: subagent-driven-development
description: Use when user says "execute epic [id]" or when executing beads epics with parallel subagents in the current session
---

# Subagent-Driven Development

Execute beads epic by dispatching parallel subagents for independent issues, with two-stage review after each completion.

**REQUIRED BACKGROUND:** You MUST understand `superpowers:beads` before using this skill.
**Preconditions:** Beads epic exists with dependencies set. If not -> `plan2beads` first. If separate session -> `executing-plans` instead.
**Announce at start:** "I'm using Subagent-Driven Development to execute beads epic [epic-id]."

## Quick Start

1. Ask budget tier (max-20x / max-5x / pro-api) -- sets model matrix for session
2. Load epic: `bd show <epic-id>`, parse children and Key Decisions
3. Verify `temp/` exists (do NOT run `mkdir`)
4. `bd ready`, filter to epic children
5. Check file conflicts, cap wave at 3, serialize wave file map into prompts
6. Dispatch implementers (`run_in_background: true`) -- sub-agents self-read from beads
7. Each returns: spec review -> code review -> verification -> evidence -> `bd close`
8. Post `[WAVE-SUMMARY]` to epic comments, cleanup `temp/<epic>*`, retain 2-line receipt
9. Repeat from 4 until all closed
10. Print completion report, run `finishing-a-development-branch`

## Budget Tier Selection

Ask tier once at session start. Each task's `complexity:*` label (set during planning)
selects the model; tier ceiling caps it. Code reviewer and verifier use tier defaults.

### Implementer Models

| Tier | simple | standard | complex |
|------|--------|----------|---------|
| max-20x | haiku | sonnet | opus |
| max-5x | haiku | sonnet | opus |
| pro/api | haiku | sonnet | sonnet |

### Spec Reviewer Models

| Tier | simple | standard | complex |
|------|--------|----------|---------|
| max-20x | haiku | haiku | sonnet |
| max-5x | haiku | haiku | sonnet |
| pro/api | haiku | haiku | haiku |

### Other Roles (unchanged by complexity)

| Tier | Code Reviewer | N Reviews | Verifier | Simplify |
|------|--------------|-----------|----------|----------|
| max-20x | sonnet | 3 | opus | Yes |
| max-5x | sonnet | 3 | opus | Yes |
| pro/api | haiku | 1 | sonnet | Skip |

Default: if `complexity:*` label missing, use `standard`.
Store tier selection for session -- don't ask again per wave.

## The Process

```
LOADING: bd ready -> filter to epic -> check file conflicts -> cap at 3
DISPATCH: serialize wave file map -> bd update --status=in_progress -> dispatch async
MONITOR: poll TaskOutput(block=False, timeout=5000) -> route completions
REVIEW: spec review -> code review (N if tier allows) -> gap closure (max 3 attempts)
CLOSE: extract evidence -> bd close --reason -> simplify (if 2+ tasks) -> wave summary
-> loop back to LOADING until all closed -> COMPLETE
```

## Key Rules (GUARDS)

**Never:** dispatch blocked issues, dispatch cross-epic issues, dispatch file-conflicting issues in same wave, skip `bd update --status=in_progress`, skip `bd close` after review, skip reviews, start code review before spec passes.

**Always:** check `bd ready` before each wave, compare file lists for conflicts, `bd close` immediately after review passes, re-check `bd ready` after each close.

**Deadlock:** `bd ready` empty but issues remain open -> check `bd blocked` for circular deps or forgotten closes.

**Failure:** Crash -> restart fresh. >2 review rejections -> pause for human. >3 verification failures -> escalate. See [failure-recovery.md](failure-recovery.md).

## State Machine

```
INIT -> LOADING -> DISPATCH -> MONITOR -> REVIEW -> CLOSE -> LOADING (loop)
                                                          -> COMPLETE (all closed)
REVIEW -> PENDING_HUMAN (verification >3 attempts)
```

## Compaction Safety Net

For large epics (8+ waves), set early compaction:

```bash
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70
```

Triggers at 70% context usage instead of default 95%.

## Prompt Templates

- `./implementer-prompt.md` -- `{issue_id}`, `{epic_id}`, `{file_ownership_list}`, `{wave_file_map}`, `{dependency_ids}`, `{wave_number}`
- `./spec-reviewer-prompt.md` -- `{issue_id}`, `{wave_number}`
- `./code-quality-reviewer-prompt.md` -- `{issue_id}`, `{base_sha}`, `{head_sha}`, `{wave_number}`, `{code_reviewer_path}`
- `skills/epic-verifier/verifier-prompt.md` -- `{epic_id}`, `{base-sha}`, `{head-sha}`, `{test-command}`
- `./simplifier-dispatch-guidance.md` -- post-wave simplification (skip on pro/api, skip single-task waves)

## Integration

- **plan2beads** -- must run first to create epic
- **superpowers:finishing-a-development-branch** -- after COMPLETE state
- **superpowers:test-driven-development** -- subagents use for implementation
- **superpowers:rule-of-five** -- subagents use for artifacts >50 lines
- **superpowers:executing-plans** -- alternative for parallel session

## Companion Files

- [metrics-tracking.md](metrics-tracking.md): Wave/epic summary templates, cost formulas
- [background-execution.md](background-execution.md): Polling pseudocode, review pipeline parallelism
- [verification-and-evidence.md](verification-and-evidence.md): Gap closure loop, evidence extraction
- [wave-orchestration.md](wave-orchestration.md): TaskCreate/TaskUpdate tracking calls
- [example-workflow.md](example-workflow.md): Complete 3-wave worked example
- [failure-recovery.md](failure-recovery.md): Timeout, rejection loop, deadlock, bd errors
- [dispatch-and-conflict.md](dispatch-and-conflict.md): Dispatch routing, file conflict algorithm, parallel dispatch
- [context-loading.md](context-loading.md): Self-read pattern, report tags, orchestrator vs sub-agent responsibilities

<!-- compressed: 2026-02-11, original: 806 words, compressed: 586 words -->
