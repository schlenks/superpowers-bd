# Gap Closure Enforcement Protocol

When verification fails, follow this protocol exactly. Gap-closure fixes have no budget of their own: they count against the single fix-round cap of 3 per task, shared with review findings (in SDD, the task's `fix_round` counter; see `subagent-driven-development/failure-recovery.md` Fix-Round Adjudication). The `TaskCreate`/`TaskUpdate` records below are native progress tracking (Codex: `update_plan`). They are optional where Task tools are unavailable (off by default on Claude Code 2.1.233+), and they are never the only record of an escalation: Step 4 escalates in bd.

## Step 1: Create Gap-Fix Task

```
TaskCreate: "Fix: [specific failure from verification]"
  description: "Failure evidence: [actual error message]. Fix the root cause."
  activeForm: "Fixing [failure]"
  metadata:
    triggered_by: "[verification task ID]"
    fix_round: [1|2|3]   # shared with review fix rounds
```

## Step 2: Create Blocked Re-Verification Task

```
TaskCreate: "Re-verify: [original claim]"
  description: "Re-run verification after fix. Evidence: [same verification command]."
  activeForm: "Re-verifying [claim]"
  metadata:
    fix_round: [1|2|3]
    max_fix_rounds: 3     # the one shared cap, not a separate gap-closure budget
    original_verification: "[original task ID]"
TaskUpdate: [re-verification task ID]
  addBlockedBy: ["[gap-fix task ID]"]
```

## Step 3: Execute Fix, Then Re-Verify

- Complete the gap-fix task
- Re-verification task unblocks automatically
- Run the verification command again
- If passes: Complete re-verification task, proceed
- If fails: Check the fix-round count (review fix rounds already spent count too)

## Step 4: Handle Persistent Failure (after round 3)

```
IF fix_round >= 3 AND still failing:   # a failing check is load-bearing, so it escalates
  # Separate question bead; never label the issue itself (bd human respond closes the bead it answers)
  bd create "[HUMAN-NEEDED] <issue-id>: [claim] failed after 3 fix rounds" --parent <epic-id> --type task \
    --description "Fix rounds: [failures and fixes tried]."      # -> <question-bead>
  bd label add <question-bead> human
  bd dep add <issue-id> <question-bead>
  Leave the issue open and continue with independent work. When the question bead closes, read its answer and resume.
  Optional mirror: TaskCreate (Codex: update_plan) "ESCALATE: [claim] failed after 3 fix rounds"
```

Outside a beads workflow (no issue id), report the failure history in your final message and do not claim the work complete.

## Why blockedBy Matters

Ensures fix completes before re-verification runs. Prevents race conditions and premature re-verification.

## Tracking Attempt History

Each re-verification task links to its predecessor via `original_verification` metadata. This creates an audit trail of gap-closure fix rounds.
