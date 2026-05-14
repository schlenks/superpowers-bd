# Gap Closure Enforcement Protocol

When verification fails, follow this protocol exactly:

## Step 1: Create Gap-Fix Task

```
TaskCreate: "Fix: [specific failure from verification]"
  description: "Failure evidence: [actual error message]. Fix the root cause."
  activeForm: "Fixing [failure]"
  metadata:
    triggered_by: "[verification task ID]"
    gap_closure_attempt: [1|2|3]
```

## Step 2: Create Blocked Re-Verification Task

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

## Step 3: Execute Fix, Then Re-Verify

- Complete the gap-fix task
- Re-verification task unblocks automatically
- Run the verification command again
- If passes: Complete re-verification task, proceed
- If fails: Check attempt count

## Step 4: Handle Persistent Failure

```
IF attempt >= max_attempts AND still failing:
  TaskCreate: "ESCALATE: [claim] failed after 3 attempts"
    description: "Human intervention required. Attempts: [list failures and fixes tried]."
    activeForm: "Awaiting human input"
    metadata:
      requires_human: true
      failure_history: [array of attempt summaries]
```

## Why blockedBy Matters

Ensures fix completes before re-verification runs. Prevents race conditions and premature re-verification.

## Tracking Attempt History

Each re-verification task links to its predecessor via `original_verification` metadata. This creates an audit trail of gap closure attempts.
