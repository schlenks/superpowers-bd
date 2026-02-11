---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch superpowers:code-reviewer subagent to catch issues before they cascade.

## When to Request Review

**Mandatory:** After each task in SDD, after completing major feature, before merge to main.

**Optional:** When stuck, before refactoring, after fixing complex bug.

## How to Request

1. Get git SHAs: `BASE_SHA=$(git rev-parse HEAD~1)` and `HEAD_SHA=$(git rev-parse HEAD)`
2. Dispatch code-reviewer subagent using template at `code-reviewer.md`
   - `{PLAN_OR_REQUIREMENTS}` -- plan file path, bd show output, or spec
   - `{BASE_SHA}` / `{HEAD_SHA}` -- commit range
3. Act on feedback: fix Critical immediately, fix Important before proceeding, note Minor for later, push back if wrong

## Multi-Review Mode

For critical changes, dispatch N=3 independent reviews and aggregate per `superpowers:multi-review-aggregation` (118% recall improvement per SWR-Bench).

**When:** Changes >200 lines, security-sensitive, pre-merge to main, complex refactoring.

**How:** 3 independent code-reviewer subagents with `run_in_background: true`, each with `"You are Reviewer {i} of 3. Review independently."` Single review is default for ad-hoc; multi-review is automatic in SDD for max-20x and max-5x tiers.

## Example

```
BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)
[Dispatch superpowers:code-reviewer with plan context + SHAs]
[Subagent returns: 4/4 requirements mapped, Important: missing progress indicators]
[Fix -> Continue to next task]
```

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:** Push back with technical reasoning, show code/tests, request clarification.

See template at: requesting-code-review/code-reviewer.md

<!-- compressed: 2026-02-11, original: 449 words, compressed: 272 words -->
