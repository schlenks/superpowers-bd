# Completion Strategies

Step 3 detail: Auto and manual completion strategy selection.

## Step 3 Auto: Execute Pre-Chosen Strategy

Check the epic for a `completion:*` label:

```bash
bd show <epic-id>
```

Look for labels like `completion:commit-only`, `completion:push`, `completion:push-pr`, `completion:merge-local`.

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

## Step 3 Manual: Present Options (Task-Tracked)

**Only if no `completion:*` label exists on the epic.**

### TaskCreate Blocks

```
TaskCreate: "Present completion options"
  description: "Present 4 structured options to user: merge, PR, keep, discard."
  activeForm: "Presenting options"
  addBlockedBy: [verify-tests-task-id, simplification-task-id]

TaskCreate: "Execute chosen option"
  description: "Execute user's chosen option from the 4 presented."
  activeForm: "Executing chosen option"
  addBlockedBy: [present-options-task-id]

TaskCreate: "Cleanup worktree (if applicable)"
  description: "Remove worktree for options 1, 2, or 4. Keep for option 3."
  activeForm: "Cleaning up worktree"
  addBlockedBy: [execute-option-task-id]
```

### Present Exactly 4 Options

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.
