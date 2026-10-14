# Gap Closure Enforcement Protocol

When verification fails, follow this protocol exactly. The `TaskCreate`/`TaskUpdate` records below are native progress tracking (Codex: `update_plan`). They are optional where Task tools are unavailable (off by default on Claude Code 2.1.233+), and they are never the only record of an escalation: Step 4 escalates in bd.

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
  metadata:
    attempt: [2|3]
    max_attempts: 3
    original_verification: "[original task ID]"
TaskUpdate: [re-verification task ID]
  addBlockedBy: ["[gap-fix task ID]"]
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
  # Separate question bead; never label the issue itself (bd human respond closes the bead it answers)
  bd create "[HUMAN-NEEDED] <issue-id>: [claim] failed after 3 attempts" --parent <epic-id> --type task \
    --description "Attempts: [failures and fixes tried]."      # -> <question-bead>
  bd label add <question-bead> human
  bd dep add <issue-id> <question-bead>
  Leave the issue open and continue with independent work. When the question bead closes, read its answer and resume.
  Optional mirror: TaskCreate (Codex: update_plan) "ESCALATE: [claim] failed after 3 attempts"
```

Outside a beads workflow (no issue id), report the failure history in your final message and do not claim the work complete.

## Why blockedBy Matters

Ensures fix completes before re-verification runs. Prevents race conditions and premature re-verification.

## Tracking Attempt History

Each re-verification task links to its predecessor via `original_verification` metadata. This creates an audit trail of gap closure attempts.
