---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Visual Verification (Frontend)

When frontend code is modified and browser tools are available, visual verification is part of the gate function — not optional. Triggers automatically when browser tools exist, frontend files changed (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`), and dev server is running. If browser tools unavailable or no frontend files changed, skip silently.

See `references/visual-verification.md` for full protocol including file patterns and smoke test procedure.

## Gap Closure Loop

When verification fails, don't just report failure — create a fix task and re-verify:

```
IF verification fails:
  1. CREATE gap-fix task
  2. CREATE re-verification task (blocked by fix)
  3. WAIT for gap fix completion
  4. RUN re-verification
  5. IF still fails AND attempt < 3: → Increment attempt, GOTO step 1
  6. IF still fails AND attempt >= 3: → ESCALATE to human
```

**Why 3 attempts:** Most genuine bugs fix in 1-2 tries. Persistent failure indicates deeper issues needing human judgment.

See `references/gap-closure-protocol.md` for detailed TaskCreate blocks, blockedBy enforcement, and attempt tracking.

## Verification Task Enforcement

**Before making ANY completion claim, create a verification task:**

```
TaskCreate: "Verify: [specific claim]"
  description: "Evidence required: [verification command]. Must capture command output and exit code."
  activeForm: "Verifying [claim]"
```

**ENFORCEMENT:**
- Task description MUST specify the verification command
- Task CANNOT be marked `completed` without evidence in the conversation
- Evidence = actual command output showing pass/fail
- Subsequent completion claims blocked until verification task completed

**Why this matters:** TaskList exposes unverified completion claims. If you claim "done" without a completed verification task, the lack of evidence is visible.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |
| UI renders correctly | Visual smoke test: page loads, no console errors | "Code looks right", build passes |

## Red Flags — STOP

Using "should", "probably", "seems to". Expressing satisfaction before verification ("Great!", "Perfect!", "Done!"). About to commit/push/PR without verification. Trusting agent success reports. Relying on partial verification. Thinking "just this once". **ANY wording implying success without having run verification.**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.

## Reference Files

| File | When to read |
|------|-------------|
| `references/visual-verification.md` | Full visual/frontend verification protocol with triggers and smoke test |
| `references/gap-closure-protocol.md` | Detailed gap-fix -> re-verify -> escalate enforcement |
| `references/key-patterns-examples.md` | Verification patterns with examples for tests, builds, agents, UI |
| `references/why-this-matters.md` | Context from failure memories — why verification matters |
| `references/when-to-apply.md` | Full enumeration of when verification is required |
| `references/SKILL.test.md` | Pressure test scenarios for this skill |
