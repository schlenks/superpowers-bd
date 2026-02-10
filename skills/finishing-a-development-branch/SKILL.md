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

**Skip if** not working on a beads epic. Otherwise, run `bd list --parent <epic-id>` and check for verification tasks. Three outcomes: open verification tasks (STOP), no verification tasks/legacy (WARNING, proceed), all closed (proceed). See `references/epic-verification.md` for message templates.

### Step 1: Verify Tests (Task-Tracked)

Create a "Verify all tests pass" task. Run the project's full test suite.

**ENFORCEMENT:** Cannot mark completed unless test command was run fresh, output shows 0 failures, and exit code was 0. If tests fail, stop — do not proceed. See `references/test-verification.md` for TaskCreate block and failure/pass branches.

### Step 1.5: Pre-Merge Simplification (Task-Tracked, Mandatory)

Create a "Pre-merge simplification" task blocked by test verification. Get changed files via `git diff --name-only $(git merge-base HEAD main)..HEAD`. Dispatch `code-simplifier:code-simplifier` on the full changeset. If changes made, re-run tests — revert if they fail, commit if they pass. See `references/pre-merge-simplification.md` for Task dispatch code.

### Step 2: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3 Auto: Execute Pre-Chosen Strategy

If the epic has a `completion:*` label, execute automatically — no prompting:

| Label | Action |
|-------|--------|
| `completion:commit-only` | Verify clean tree. Done. |
| `completion:push` | Verify clean, push. |
| `completion:push-pr` | Push, create PR. |
| `completion:merge-local` | Merge to base locally. |

Skip to Step 5 if applicable. See `references/completion-strategies.md` for full details.

### Step 3 Manual: Present Options

If no `completion:*` label, create task-tracked options and present exactly 4 choices:

1. Merge back to \<base-branch\> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

**Don't add explanation** - keep options concise. See `references/completion-strategies.md` for TaskCreate blocks.

### Step 4: Execute Chosen Option

Execute the user's chosen option. Each option has specific bash commands and confirmation requirements. Option 4 (Discard) requires typed "discard" confirmation. See `references/option-workflows.md` for full procedures.

### Step 5: Cleanup Worktree

**Options 1, 2, 4:** Check if in worktree (`git worktree list`), remove if yes.
**Option 3:** Keep worktree. See `references/worktree-cleanup.md`.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | Y | - | - | Y |
| 2. Create PR | - | Y | Y | - |
| 3. Keep as-is | - | - | Y | - |
| 4. Discard | - | - | - | Y (force) |

## Common Mistakes

- **Skip test verification** → merge broken code. Always verify tests first.
- **Open-ended questions** → present exactly 4 options, not "what should I do?"
- **Auto-cleanup worktree** → only for Options 1 & 4, not 2 & 3.
- **No discard confirmation** → require typed "discard" before Option 4.

See `references/red-flags.md` for detailed Never/Always lists.

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **executing-plans** (Step 5) - After all batches complete

**Pairs with:**
- **using-git-worktrees** - Cleans up worktree created by that skill

## Reference Files

| File | When to read |
|------|-------------|
| `references/epic-verification.md` | Step 0: Checking beads epic verification tasks |
| `references/test-verification.md` | Step 1: Task-tracked test verification protocol |
| `references/pre-merge-simplification.md` | Step 1.5: Code simplifier dispatch protocol |
| `references/completion-strategies.md` | Step 3: Auto/manual completion strategy details |
| `references/option-workflows.md` | Step 4: Execution details for all 4 options |
| `references/worktree-cleanup.md` | Step 5: Worktree cleanup procedures |
| `references/red-flags.md` | Detailed red flags and common mistakes |
