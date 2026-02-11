# Worktree Cleanup

Step 5 detail: Remove worktree after branch completion.

## For Options 1, 2, 4

Check if in worktree:
```bash
git worktree list
```
Look for the current branch name in the output.

If yes:
```bash
git worktree remove <worktree-path>
```

## For Option 3

Keep worktree. Do not clean up.
