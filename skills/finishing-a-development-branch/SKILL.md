---
name: finishing-a-development-branch
description: Use ONLY when ALL tasks in an epic or branch are closed and you are ready to integrate the entire body of work - never after individual task completions, never mid-epic
---

# Finishing a Development Branch

## Guard: Do NOT Use Mid-Epic

**STOP.** Before proceeding, check:

1. **Are you a subagent implementing a single task?** → This skill does NOT apply. Report your evidence and stop.
2. **Are there still open tasks in the epic?** → This skill does NOT apply. Only the orchestrator at COMPLETE state should invoke this.
3. **Is there an epic with a `completion:*` label?** → Read it and execute automatically (see Step 3 Auto below). No prompting needed.

**This skill is ONLY for:** The final integration step after ALL work is done. If even one task remains open, do not invoke this skill.

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Check completion strategy → Execute (auto or prompted) → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 0: Check Epic Verification Tasks (If Applicable)

**Skip this step if:** Not working on a beads epic (standalone work without `bd` tracking).

**If working on a beads epic**, check for verification tasks:

```bash
# List children of current epic
bd list --parent <epic-id>
```

Look for tasks with "verification" or "verify" in the title (e.g., "Verification: All changes tested").

**Three outcomes:**

1. **Verification tasks exist but NOT closed** → STOP
   ```
   BLOCKED: Epic has open verification tasks:
   - <task-id>: <task-title> (status: <status>)

   These must be completed before finishing the branch.
   Run: bd show <task-id> for details.
   ```
   Do not proceed to Step 1.

2. **Verification tasks don't exist (legacy epic)** → WARNING, proceed with caution
   ```
   WARNING: Legacy epic detected (no verification tasks).

   This epic predates verification task enforcement. Proceeding without
   formal verification checkpoints. Consider manually verifying:
   - All acceptance criteria met
   - Tests written and passing
   - Code reviewed (if applicable)

   Continuing to Step 1...
   ```
   Proceed to Step 1 with extra caution.

3. **All verification tasks closed** → Proceed to Step 1
   ```
   ✓ All verification tasks complete. Proceeding to Step 1.
   ```

### Step 1: Verify Tests (Task-Tracked)

**Create a verification task before presenting options:**

```
TaskCreate: "Verify all tests pass"
  description: "Run full test suite. Must capture actual output showing pass/fail. Cannot proceed with failing tests."
  activeForm: "Running test verification"
```

**Run project's test suite:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**ENFORCEMENT:** This task CANNOT be marked `completed` unless:
- Test command was run (fresh, in this message)
- Output shows 0 failures
- Exit code was 0

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2. Leave verification task incomplete.

**If tests pass:**
- Mark verification task `completed`
- Continue to Step 2

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3: Check Completion Strategy

**Check the epic for a `completion:*` label:**

```bash
bd show <epic-id>
```

Look for labels like `completion:commit-only`, `completion:push`, `completion:push-pr`, `completion:merge-local`.

**If a completion label exists → Step 3 Auto (skip prompting)**
**If no completion label → Step 3 Manual (present options)**

### Step 3 Auto: Execute Pre-Chosen Strategy

The completion strategy was chosen during planning. Execute it automatically:

| Label | Action |
|-------|--------|
| `completion:commit-only` | Run `git status` to verify clean working tree. Report summary. Done — skip Steps 4 and 5. |
| `completion:push` | Verify clean working tree, then `git push`. Report summary. |
| `completion:push-pr` | Verify clean, push, create PR (Option 2 below). |
| `completion:merge-local` | Merge to base branch locally (Option 1 below). |

**No prompting needed.** The user already decided during planning.

**Note:** For `completion:commit-only`, skip Step 2 (Determine Base Branch) — it's not needed when staying on the current branch.

After executing, skip to Step 5 (Cleanup Worktree) if applicable.

### Step 3 Manual: Present Options (Task-Tracked)

**Only if no `completion:*` label exists on the epic.**

**Create tasks for the remaining steps (blocked by test verification):**

```
TaskCreate: "Present completion options"
  description: "Present 4 structured options to user: merge, PR, keep, discard."
  activeForm: "Presenting options"
  addBlockedBy: [verify-tests-task-id]

TaskCreate: "Execute chosen option"
  description: "Execute user's chosen option from the 4 presented."
  activeForm: "Executing chosen option"
  addBlockedBy: [present-options-task-id]

TaskCreate: "Cleanup worktree (if applicable)"
  description: "Remove worktree for options 1, 2, or 4. Keep for option 3."
  activeForm: "Cleaning up worktree"
  addBlockedBy: [execute-option-task-id]
```

Present exactly these 4 options:

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 4: Execute Choice

#### Option 1: Merge Locally

```bash
# Switch to base branch
git checkout <base-branch>

# Pull latest
git pull

# Merge feature branch
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass
git branch -d <feature-branch>
```

Then: Cleanup worktree (Step 5)

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>

# Create PR
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Cleanup worktree (Step 5)

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 5)

### Step 5: Cleanup Worktree

**For Options 1, 2, 4:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | ✓ | - | - | ✓ |
| 2. Create PR | - | ✓ | ✓ | - |
| 3. Keep as-is | - | - | ✓ | - |
| 4. Discard | - | - | - | ✓ (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" → ambiguous
- **Fix:** Present exactly 4 structured options

**Automatic worktree cleanup**
- **Problem:** Remove worktree when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request

**Always:**
- Verify tests before offering options
- Present exactly 4 options
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **executing-plans** (Step 5) - After all batches complete

**Pairs with:**
- **using-git-worktrees** - Cleans up worktree created by that skill
