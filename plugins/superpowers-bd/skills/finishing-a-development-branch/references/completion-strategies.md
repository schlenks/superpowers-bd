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
  description: "Present 3 structured options to user: merge, PR, keep."
  activeForm: "Presenting options"
TaskUpdate: present-options-task-id
  addBlockedBy: [verify-tests-task-id, simplification-task-id]

TaskCreate: "Execute chosen option"
  description: "Execute user's chosen option from the 3 presented."
  activeForm: "Executing chosen option"
TaskUpdate: execute-option-task-id
  addBlockedBy: [present-options-task-id]

TaskCreate: "Cleanup worktree (if applicable)"
  description: "Remove worktree for option 1 (merge) or an explicitly requested discard. Keep for options 2 and 3."
  activeForm: "Cleaning up worktree"
TaskUpdate: cleanup-task-id
  addBlockedBy: [execute-option-task-id]
```

### Present Exactly 3 Options

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?
```

**Don't add explanation** - keep options concise. Do not add a discard option: discarding finished, passing work happens only when the user explicitly asks (see `option-workflows.md`).
