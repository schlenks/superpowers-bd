---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## Phase Task Enforcement

**When this skill is invoked, create native tasks for each phase:**

1. **"Phase 1: Root Cause Investigation"** — Read errors, reproduce, check changes, gather evidence. MUST understand WHAT and WHY before proceeding.
2. **"Phase 2: Pattern Analysis"** — Find working examples, compare, identify differences. `addBlockedBy: [phase-1-id]`
3. **"Phase 3: Hypothesis & Testing"** — Form single hypothesis, test minimally, verify. `addBlockedBy: [phase-2-id]`
4. **"Phase 4: Implementation"** — Create failing test, implement single fix, verify. `addBlockedBy: [phase-3-id]`

**ENFORCEMENT:**
- TaskList shows blocked phases — you CANNOT propose fixes until Phase 1-3 show `status: completed`
- Blocked tasks cannot be marked in_progress — no skipping ahead
- Task state is visible proof of process — rationalizing around this is visible
- Mark each phase complete only when its success criteria are met

## When to Use

**Use for ANY technical issue:** test failures, bugs, unexpected behavior, performance problems, build failures, integration issues.

**Use ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes or previous fix didn't work

**Don't skip when:**
- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- Manager wants it fixed NOW (systematic is faster than thrashing)

## The Four Phases

You MUST complete each phase before proceeding to the next.

**Phase 1: Root Cause Investigation** — Read errors carefully, reproduce consistently, check recent changes, gather evidence at component boundaries, trace data flow. **Success:** Understand WHAT and WHY. See `references/phase-1-investigation.md`

**Phase 2: Pattern Analysis** — Find working examples, compare against references completely, identify all differences, understand dependencies. **Success:** Differences between working and broken identified. See `references/phase-2-pattern-analysis.md`

**Phase 3: Hypothesis and Testing** — Form single specific hypothesis, test with smallest possible change, verify before continuing. **Success:** Hypothesis confirmed or replaced with new one. See `references/phase-3-hypothesis-testing.md`

**Phase 4: Implementation** — Create failing test case, implement single fix addressing root cause, verify fix and no regressions. If 3+ fixes failed, question the architecture. **Success:** Bug resolved, tests pass. See `references/phase-4-implementation.md`

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare | Identify differences |
| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass |

## When Process Reveals "No Root Cause"

If systematic investigation reveals issue is truly environmental, timing-dependent, or external:

1. You've completed the process
2. Document what you investigated
3. Implement appropriate handling (retry, timeout, error message)
4. Add monitoring/logging for future investigation

**But:** 95% of "no root cause" cases are incomplete investigation.

## Red Flags — STOP and Follow Process

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Here are the main problems: [lists fixes without investigation]"
- **"One more fix attempt" (when already tried 2+)**
- **Each fix reveals new problem in different place**

**ALL of these mean: STOP. Return to Phase 1.**

**If 3+ fixes failed:** Question the architecture (see Phase 4). See also `references/rationalizations.md` for common excuses and user signals.

## Supporting Techniques

These techniques are part of systematic debugging:

- **`references/root-cause-tracing.md`** — Trace bugs backward through call stack to find original trigger
- **`references/defense-in-depth.md`** — Add validation at multiple layers after finding root cause
- **`references/condition-based-waiting.md`** — Replace arbitrary timeouts with condition polling

**Related skills:**
- **superpowers:test-driven-development** — For creating failing test case (Phase 4, Step 1)
- **superpowers:verification-before-completion** — Verify fix worked before claiming success

## Reference Files

| File | When to read |
|------|-------------|
| `references/phase-1-investigation.md` | Detailed Phase 1 steps: errors, reproduction, evidence gathering |
| `references/phase-2-pattern-analysis.md` | Detailed Phase 2 steps: working examples, comparison |
| `references/phase-3-hypothesis-testing.md` | Detailed Phase 3 steps: hypothesis formation, minimal testing |
| `references/phase-4-implementation.md` | Detailed Phase 4 steps: test creation, fix, architecture questioning |
| `references/rationalizations.md` | Common excuses and user signals indicating wrong approach |
| `references/real-world-impact.md` | Statistics on systematic vs random debugging |
| `references/root-cause-tracing.md` | Backward tracing technique for deep call stacks |
| `references/defense-in-depth.md` | Multi-layer validation after finding root cause |
| `references/condition-based-waiting.md` | Condition polling to replace arbitrary timeouts |
| `references/condition-based-waiting-example.ts` | TypeScript example of condition-based waiting |
| `references/find-polluter.sh` | Script to find test pollution sources |
| `references/CREATION-LOG.md` | Skill creation history |
| `references/tests/` | Pressure test scenarios |
