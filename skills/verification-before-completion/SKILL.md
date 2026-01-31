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

When frontend code is modified and browser tools are available, visual verification
is part of the gate function - not optional.

### Automatic Triggering

Visual verification runs automatically when ALL conditions are met:
- Browser tools available (`mcp__plugin_superpowers-chrome_chrome__use_browser` OR `browser_navigate`)
- Frontend files changed (see patterns below)
- Dev server is running (check common ports: 3000, 5173, 4200, 8080)

If browser tools aren't available or no frontend files changed, skip silently.
If dev server isn't running, note: "Visual verification skipped: start dev server for browser testing"

### Frontend File Patterns

**Triggers verification:**
- Extensions: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`, `*.module.css`
- Directories: `components/`, `pages/`, `app/`, `views/`, `layouts/`, `hooks/`, `styles/`, `theme/`
- Config: `tailwind.config.*`, `postcss.config.*`

**Does not trigger:**
- Test files: `*.test.*`, `*.spec.*`, `__tests__/`
- Backend: `api/`, `server/`, `db/`

### Smoke Test Procedure

1. **Infer URL** from changed files (page routes → direct path, components → trace to page, fallback → `/`)
2. **Navigate** to dev server (check ports: 3000, 5173, 4200, 8080)
3. **Check console** for uncaught exceptions or React errors (fail if found)
4. **Verify elements** render (page not blank, no error boundaries)
5. **Capture screenshot** as evidence (browser tools auto-capture to session directory)

### Failure Handling

Visual verification failures trigger the same gap closure loop:
- Console errors → fix task → re-verify
- Missing elements → fix task → re-verify
- Max 3 attempts → escalate to human

## Gap Closure Loop

When verification fails, don't just report failure—create a fix task and re-verify:

```
IF verification fails:
  1. CREATE gap-fix task
  2. CREATE re-verification task (blocked by fix)
  3. WAIT for gap fix completion
  4. RUN re-verification
  5. IF still fails AND attempt < 3: → Increment attempt, GOTO step 1
  6. IF still fails AND attempt >= 3: → ESCALATE to human
```

**Why 3 attempts:** Balances recovery against infinite loops. Most genuine bugs fix in 1-2 tries. Persistent failure indicates deeper issues needing human judgment.

**Edge case - fix introduces new failures:** The re-verification catches any regressions.

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

**Example:**
```
TaskCreate: "Verify: tests pass"
  description: "Run: npm test. Evidence: 0 failures in output, exit code 0."
  activeForm: "Running verification tests"
  metadata:
    attempt: 1
    max_attempts: 3

// RUN the command, capture output

// IF PASSES:
//   TaskUpdate status=completed
//   "Tests pass (34/34, exit 0)"

// IF FAILS (e.g., 2 failures):
//   Create gap-fix task:
//     TaskCreate: "Fix: 2 test failures in auth module"
//       metadata: { triggered_by: "verify-1", gap_closure_attempt: 1 }
//   Create re-verification task (blocked):
//     TaskCreate: "Re-verify: tests pass"
//       blockedBy: [gap-fix-task-id]
//       metadata: { attempt: 2, max_attempts: 3 }
//   Complete fix → re-verification unblocks → run again
//   IF still fails AND attempt < 3 → repeat loop
//   IF attempt >= 3 → escalate to human
```

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

## Gap Closure Enforcement

When verification fails, follow this protocol exactly:

**Step 1: Create Gap-Fix Task**
```
TaskCreate: "Fix: [specific failure from verification]"
  description: "Failure evidence: [actual error message]. Fix the root cause."
  activeForm: "Fixing [failure]"
  metadata:
    triggered_by: "[verification task ID]"
    gap_closure_attempt: [1|2|3]
```

**Step 2: Create Blocked Re-Verification Task**
```
TaskCreate: "Re-verify: [original claim]"
  description: "Re-run verification after fix. Evidence: [same verification command]."
  activeForm: "Re-verifying [claim]"
  blockedBy: "[gap-fix task ID]"
  metadata:
    attempt: [2|3]
    max_attempts: 3
    original_verification: "[original task ID]"
```

**Step 3: Execute Fix, Then Re-Verify**
- Complete the gap-fix task
- Re-verification task unblocks automatically
- Run the verification command again
- If passes: Complete re-verification task, proceed
- If fails: Check attempt count

**Step 4: Handle Persistent Failure**
```
IF attempt >= max_attempts AND still failing:
  TaskCreate: "ESCALATE: [claim] failed after 3 attempts"
    description: "Human intervention required. Attempts: [list failures and fixes tried]."
    activeForm: "Awaiting human input"
    metadata:
      requires_human: true
      failure_history: [array of attempt summaries]
```

**Why blockedBy matters:** Ensures fix completes before re-verification runs. Prevents race conditions and premature re-verification.

**Tracking attempt history:** Each re-verification task links to its predecessor via `original_verification` metadata. This creates an audit trail of gap closure attempts.

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

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

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

**Visual (frontend):**
```
✅ [Navigate to page] [Check console: 0 errors] [Elements render] "UI verified"
❌ "Build passed" / "Tests pass" (neither proves UI renders correctly)
```

## Why This Matters

From 24 failure memories:
- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
