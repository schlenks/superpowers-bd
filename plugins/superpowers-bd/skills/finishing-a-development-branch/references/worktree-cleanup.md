# Worktree Cleanup (Provenance-Based)

Step 5 detail: Only remove worktrees we created.

## Detect Provenance

Use the values captured in Step 1.7, from inside the workspace:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

Do not re-run these after Step 4 has changed directory to the main repo root: they would describe the main repo, `GIT_DIR == GIT_COMMON` would hold, and cleanup would silently do nothing.

## Decision Matrix

Use **prefix-anchored** matching against `$MAIN_ROOT` and `$HOME` to avoid false-positives (e.g. `/home/user/worktrees-backup/` must not match).

| Condition | Action |
|-----------|--------|
| `GIT_DIR == GIT_COMMON` | Normal repo — nothing to clean up |
| Path prefix-anchored to `$MAIN_ROOT/.worktrees/`, `$MAIN_ROOT/worktrees/`, or `$HOME/.config/superpowers/worktrees/` | We own it — `git worktree remove` (on Merge or an explicitly requested discard; preserve on PR or Keep) |
| Path not under any of those prefixes (harness-owned) | Use harness exit tool (`ExitWorktree`) if available; otherwise leave in place |

## Removal Commands

```bash
# Compute MAIN_ROOT for anchored matching
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)

if [[ "$WORKTREE_PATH" == "$MAIN_ROOT/.worktrees/"* ]] || \
   [[ "$WORKTREE_PATH" == "$MAIN_ROOT/worktrees/"* ]] || \
   [[ "$WORKTREE_PATH" == "$HOME/.config/superpowers/worktrees/"* ]]; then
  # superpowers-owned: safe to remove (never --force)
  cd "$MAIN_ROOT"
  git worktree remove "$WORKTREE_PATH"
  git worktree prune
else
  # harness-owned: ExitWorktree or leave in place
fi
```

## If Removal Is Refused

`git worktree remove` refuses when the worktree `contains modified or untracked files`. Those files exist nowhere else — uncommitted plans, notes, scratch work. Never reach for `--force`.

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

- **Interactive:** show the list and ask: commit them to the branch, move them into the main repo root, or delete them (unrecoverable). Carry out the choice, then retry the removal.
- **Unattended (`completion:*` label):** leave the worktree and branch in place and report the file list in the completion summary. Do not delete anything.

## Common Mistakes

- **Running `git worktree remove` from inside the worktree** — fails silently. Always `cd` to main repo root first.
- **Re-detecting `WORKTREE_PATH` after that `cd`** — returns the main repo; cleanup no-ops.
- **`--force` on a refused removal** — destroys files that exist only in that worktree.
- **Removing harness-owned worktrees** — creates phantom state in the harness's worktree registry. Use the harness's exit tool instead.
- **Skipping `git worktree prune`** — leaves stale registrations from squash-merged PRs.

## Which Actions Trigger Cleanup

The trigger is the action (Merge/Discard), not the option number:

| Action | Named branch (3-option menu) | Detached HEAD (2-option menu) |
|--------|------------------------------|-------------------------------|
| Merge locally | Option 1 (cleanup) | N/A (not offered) |
| Push + PR | Option 2 (preserve) | Option 1 (preserve) |
| Keep as-is | Option 3 (preserve) | Option 2 (preserve) |
| Discard (explicit request only) | cleanup | cleanup |
