---
name: subagent-driven-development
description: Use when user says "execute epic [id]" or when executing beads epics with parallel subagents in the current session
effort: high
---

# Subagent-Driven Development

Execute beads epic by dispatching parallel subagents for independent issues, with two-stage review after each completion.

**REQUIRED BACKGROUND:** You MUST understand `superpowers-bd:beads` before using this skill.
**Preconditions:** Beads epic exists with dependencies set. If not -> `plan2beads` first. If separate session -> `executing-plans` instead.
**Announce at start:** "I'm using Subagent-Driven Development to execute beads epic [epic-id]."

## Quick Start

1. Load epic: `bd show <epic-id>`, parse children and Key Decisions
2. Check for `temp/sdd-checkpoint-{epic_id}.json` -- if found, restore state (budget_tier, wave_receipts, closed_issues, metrics), print "Resuming epic {id} from wave {N+1}", jump to LOADING (skip step 3)
3. Ask budget tier (max-20x / max-5x / pro-api) -- sets model matrix for session.
4. Detect context tier: check your model ID for `[1m]` suffix. If present → extended (1M). Otherwise → standard (200k). This determines wave cap defaults and budget formula.
5. Verify `temp/` exists (do NOT run `mkdir`)
6. `bd ready`, filter to epic children
6a. If explicit wave cap in invocation (e.g., "wave-cap 7"), use it and skip 6b-6c.
6b. Query complexity distribution: `bd sql "SELECT label, COUNT(*) FROM labels WHERE issue_id LIKE '{epic_id}.%' AND label LIKE 'complexity:%' GROUP BY label"`. If query fails or returns no rows, use `min(DEFAULT_CAP, max_parallel)` and skip 6c.
6c. Calculate recommended wave cap (see Wave Cap section). Ask user via AskUserQuestion to confirm.
7. Check file conflicts, cap wave at {wave_cap}, serialize wave file map into prompts
8. Dispatch implementers (`run_in_background: true`) -- sub-agents self-read from beads
9. Each returns status: DONE/DONE_WITH_CONCERNS → review pipeline → `bd close`; NEEDS_CONTEXT/BLOCKED → re-dispatch or escalate
10. Post `[WAVE-SUMMARY]` to epic comments, cleanup `temp/<epic>*`, write checkpoint, retain 2-line receipt
11. Repeat from 6 until all closed
12. Print completion report, run `finishing-a-development-branch`

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

## Wave Cap

Controls max tasks dispatched per wave. Range: 1–10. Default: **5** (1M context) or **3** (200k context).

### Context Tier Detection

Check your model ID (from system prompt) for the `[1m]` suffix:
- **Extended (1M):** model ID contains `[1m]` (e.g., `claude-opus-4-6[1m]`). Default wave cap: **5**. Budget per wave: **15**.
- **Standard (200k):** no `[1m]` suffix (e.g., `claude-sonnet-4-6`). Default wave cap: **3**. Budget per wave: **9**.

Store `context_tier` ("extended" or "standard") in checkpoint for recovery.

### Setting Priority
1. **Explicit invocation** overrides everything: "execute epic hub-abc wave-cap 7" → wave_cap=7, skip recommendation.
2. **Smart recommendation** (default path): query complexity labels, calculate recommendation, ask user.
3. **Fallback**: if bd sql fails or user declines recommendation → use `min(DEFAULT_CAP, max_parallel)`.

### Smart Wave Cap Algorithm

After budget tier and context tier are set, query the epic's complexity distribution:

```bash
bd sql "SELECT label, COUNT(*) FROM labels WHERE issue_id LIKE '{epic_id}.%' AND label LIKE 'complexity:%' GROUP BY label"
```

Calculate recommendation:

```python
WEIGHTS = {"simple": 1, "standard": 2, "complex": 3}

# Context-tier aware budget
BUDGET_PER_WAVE = 15 if context_tier == "extended" else 9
DEFAULT_CAP = 5 if context_tier == "extended" else 3

total_tasks = sum(counts.values())
total_weight = sum(WEIGHTS[c] * n for c, n in counts.items())
avg_weight = total_weight / total_tasks if total_tasks > 0 else 2.0

max_parallel = len(ready_epic_children)  # from bd ready, already loaded

recommended = min(floor(BUDGET_PER_WAVE / avg_weight), max_parallel, 10)
recommended = max(recommended, 1)

if budget_tier == "pro/api":
    recommended = min(recommended, 3)
```

Present to user via AskUserQuestion:

```
Wave cap recommendation: {recommended} ({simple_count} simple, {standard_count} standard, {complex_count} complex — max parallel: {max_parallel}, context: {context_tier})

1. Use {recommended} (recommended)
2. Use {DEFAULT_CAP} (context-tier default)
3. Custom (enter a number 1–10)
```

Default selection is 1 for extended context (formula is well-calibrated with 1M headroom), 2 for standard context.

### Effective Wave Sizes by Context Tier

| Complexity Mix | Standard (200k) | Extended (1M) |
|----------------|-----------------|---------------|
| All simple | min(9, parallel, 10) | min(15, parallel, 10) → **10** |
| Mixed simple/standard | 6 | **10** |
| All standard | 4 | **7** |
| Mixed standard/complex | 3 | **6** |
| All complex | 3 | **5** |

### Edge Cases
- **bd sql fails**: Skip recommendation, use `min(DEFAULT_CAP, max_parallel)`. Print: "Could not query complexity labels — using wave cap {wave_cap}."
- **No complexity labels**: avg_weight defaults to 2.0 (standard). Extended: min(7, max_parallel, 10). Standard: min(4, max_parallel, 10).
- **Recommended ≤ context-tier default**: Skip the question — formula already at or below default. Use `recommended` (may be less than default if few tasks are ready).
- **max_parallel = 1**: Skip the question — wave_cap = 1 regardless. Inform user.
- **All simple tasks on extended**: recommended up to 10. Maximum parallelism.
- **All complex tasks on standard**: recommended = 3. Same as default.
- **Old checkpoint without context_tier**: Default to "standard" (200k behavior, safe fallback).

If out of range, warn and clamp. Stored in checkpoint for recovery.

## The Process

```
LOADING: bd ready -> filter to epic -> check file conflicts -> cap at {wave_cap}
DISPATCH: serialize wave file map -> bd update --status=in_progress -> dispatch async
MONITOR: await background agent completion notifications -> Read output file -> route completions
REVIEW: spec review -> code review (N if tier allows) -> gap closure (max 3 attempts)
CLOSE: extract evidence -> bd close --reason -> simplify (if 2+ tasks) -> wave summary
-> loop back to LOADING until all closed -> COMPLETE
```

## Handling Implementer Status

Implementers report one of four statuses. The controller routes each:

**DONE:** Proceed to spec review → code review pipeline (unchanged).

**DONE_WITH_CONCERNS:** Read CONCERNS field before dispatching spec reviewer. If concern is about correctness or scope, forward to spec reviewer for focused attention. If observational (e.g., "file is getting large"), note in wave summary and proceed to review.

**NEEDS_CONTEXT:** Re-dispatch same issue with additional context. Use same model. Increment `redispatch_count[issue_id]`. If redispatch_count > 2, escalate to human (see [failure-recovery.md](failure-recovery.md)).

**BLOCKED:** Assess the blocker:
1. If context problem → provide context, re-dispatch with same model
2. If reasoning capacity → re-dispatch with next model up (haiku→sonnet→opus per tier ceiling)
3. If task too large → break into sub-issues via `bd create`, add dependencies
4. If plan is wrong → escalate to human

**Never** ignore an escalation. If the implementer said it's stuck, something needs to change.

## Key Rules (GUARDS)

**Never:** dispatch blocked issues, dispatch cross-epic issues, dispatch file-conflicting issues in same wave, skip `bd update --status=in_progress`, skip `bd close` after review, skip reviews, start code review before spec passes.

**Always:** check `bd ready` before each wave, compare file lists for conflicts, `bd close` immediately after review passes, re-check `bd ready` after each close.

**Deadlock:** `bd ready` empty but issues remain open -> check `bd blocked` for circular deps or forgotten closes.

**Failure:** Crash -> restart fresh. >2 review rejections -> pause for human. >3 verification failures -> escalate. See [failure-recovery.md](failure-recovery.md).

## State Machine

```
INIT [checkpoint?] -> LOADING (resume at wave N+1)
INIT -> LOADING -> DISPATCH -> MONITOR -> STATUS_ROUTE
  STATUS_ROUTE [DONE|DONE_WITH_CONCERNS] -> REVIEW -> CLOSE [+checkpoint] -> LOADING (loop)
  STATUS_ROUTE [NEEDS_CONTEXT|BLOCKED]   -> RE_DISPATCH -> MONITOR
  RE_DISPATCH [redispatch > 2]           -> PENDING_HUMAN
                                                         LOADING -> COMPLETE [cleanup]
REVIEW -> PENDING_HUMAN (verification >3 attempts)
```

## Context Window Management

Context tier (extended/standard) is detected once at INIT and stored in checkpoint. Extended (1M) allows wider waves and more total waves before compaction. Standard (200k) uses conservative defaults.

After each wave CLOSE, write a checkpoint to `temp/sdd-checkpoint-{epic_id}.json` (see [checkpoint-recovery.md](checkpoint-recovery.md)). This enables seamless recovery after auto-compact or `/clear`.

**On seeing `<sdd-checkpoint-recovery>` in session context:** Read the checkpoint file and resume from the next wave. Do NOT re-ask budget tier or wave cap.

**At COMPLETE:** Delete `temp/sdd-checkpoint-{epic_id}.json` and `temp/metrics-{epic_id}.json`.

## Prompt Templates

- `./implementer-prompt.md` -- `{issue_id}`, `{epic_id}`, `{file_ownership_list}`, `{wave_file_map}`, `{dependency_ids}`, `{wave_number}`, `{rule_of_five_code_path}`, `{rule_of_five_tests_path}`, `{rule_of_five_plans_path}`
- `./spec-reviewer-prompt.md` -- `{issue_id}`, `{wave_number}`
- `./code-quality-reviewer-prompt.md` -- `{issue_id}`, `{base_sha}`, `{head_sha}`, `{wave_number}`, `{code_reviewer_path}`
- `skills/epic-verifier/verifier-prompt.md` -- `{epic_id}`, `{base-sha}`, `{head-sha}`, `{test-command}`
- `./simplifier-dispatch-guidance.md` -- post-wave simplification (skip on pro/api, skip single-task waves)

## Integration

- **plan2beads** -- must run first to create epic
- **superpowers-bd:finishing-a-development-branch** -- after COMPLETE state
- **superpowers-bd:test-driven-development** -- subagents use for implementation
- **superpowers-bd:rule-of-five-code** / **rule-of-five-tests** -- subagents use for artifacts >50 lines (code or test variant)
- **superpowers-bd:executing-plans** -- alternative for parallel session

## Companion Files

- [metrics-tracking.md](metrics-tracking.md): Wave/epic summary templates, cost formulas
- [background-execution.md](background-execution.md): Polling pseudocode, review pipeline parallelism
- [verification-and-evidence.md](verification-and-evidence.md): Gap closure loop, evidence extraction
- [wave-orchestration.md](wave-orchestration.md): TaskCreate/TaskUpdate tracking calls
- [example-workflow.md](example-workflow.md): Complete 3-wave worked example
- [failure-recovery.md](failure-recovery.md): Timeout, rejection loop, deadlock, bd errors
- [dispatch-and-conflict.md](dispatch-and-conflict.md): Dispatch routing, file conflict algorithm, parallel dispatch
- [checkpoint-recovery.md](checkpoint-recovery.md): Checkpoint schema, write timing, recovery logic, edge cases
- [context-loading.md](context-loading.md): Self-read pattern, report tags, orchestrator vs sub-agent responsibilities

<!-- compressed: 2026-02-11, original: 806 words, compressed: 586 words -->
