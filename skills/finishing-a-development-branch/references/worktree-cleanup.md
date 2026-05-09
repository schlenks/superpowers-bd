# Worktree Cleanup (Provenance-Based)

Step 5 detail: Only remove worktrees we created.

## Detect Provenance

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

## Decision Matrix

| Condition | Action |
|-----------|--------|
| `GIT_DIR == GIT_COMMON` | Normal repo — nothing to clean up |
| Path under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/` | We own it — `git worktree remove` (on Discard or Merge; preserve on PR or Keep) |
| Path not under any of those prefixes (harness-owned) | Use harness exit tool (`ExitWorktree`) if available; otherwise leave in place |

## Removal Commands

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune
```

## Common Mistakes

- **Running `git worktree remove` from inside the worktree** — fails silently. Always `cd` to main repo root first.
- **Removing harness-owned worktrees** — creates phantom state in the harness's worktree registry. Use the harness's exit tool instead.
- **Skipping `git worktree prune`** — leaves stale registrations from squash-merged PRs.

## Which Options Trigger Cleanup

The trigger is the user's action (Merge/Discard), not the option number. Option numbers differ between menus:

| Action | Named branch (4-option menu) | Detached HEAD (3-option menu) |
|--------|------------------------------|-------------------------------|
| Merge locally | Option 1 | N/A (not offered) |
| Push + PR | Option 2 (preserve) | Option 1 (preserve) |
| Keep as-is | Option 3 (preserve) | Option 2 (preserve) |
| Discard | Option 4 | Option 3 |
