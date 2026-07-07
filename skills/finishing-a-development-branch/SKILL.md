---
name: finishing-a-development-branch
description: Use when ALL tasks in an epic or branch are closed and you are ready to integrate the entire body of work - never after individual task completions, never mid-epic
effort: medium
---

# Finishing a Development Branch

## Guard: Do NOT Use Mid-Epic

**STOP.** Before proceeding, check:

1. **Are you a subagent implementing a single task?** -> This skill does NOT apply. Report your evidence and stop.
2. **Are there still open tasks in the epic?** -> This skill does NOT apply. Only the orchestrator at COMPLETE state should invoke this.
3. **Is there an epic with a `completion:*` label?** -> Read it and execute automatically (see Step 3 Auto below). No prompting needed.

**This skill is ONLY for:** The final integration step after ALL work is done. If even one task remains open, do not invoke this skill.

## The Process

### Step 0: Check Epic Verification Tasks (If Applicable)

**Skip if** not working on a beads epic. Otherwise, run `bd list --parent <epic-id>` and check for verification tasks. Three outcomes: open verification tasks (STOP), no verification tasks/legacy (WARNING, proceed), all closed (proceed). See `references/epic-verification.md`.

### Step 1: Verify Tests (Task-Tracked)

Create a "Verify all tests pass" task. Run the project's full test suite.

**ENFORCEMENT:** Cannot mark completed unless test command was run fresh, output shows 0 failures, and exit code was 0. If tests fail, stop. See `references/test-verification.md`.

### Step 1.5: Pre-Merge Simplification (Task-Tracked, Mandatory)

Create a "Pre-merge simplification" task blocked by test verification. Get changed files: first run `git merge-base HEAD main` to get the base SHA, then `git diff --name-only <base-sha>..HEAD`. Dispatch `code-simplifier:code-simplifier` on the full changeset. If changes made, re-run tests -- revert if they fail, commit if they pass. See `references/pre-merge-simplification.md`.

### Step 1.7: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
SUPERPROJECT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
```

**Submodule guard:** If `SUPERPROJECT` is non-empty, you are inside a submodule. Treat it as a normal repo (no worktree cleanup, no detached-HEAD menu reduction). `GIT_DIR != GIT_COMMON` is also true in submodules, so always check `SUPERPROJECT` first.

This determines which menu to show in Step 3:

| State | Menu | Cleanup behavior |
|-------|------|------------------|
| `SUPERPROJECT` non-empty (submodule) | Standard 4 options | Treat as normal repo |
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (Step 5) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | Provenance-based on Discard (Option 3); harness exit tool if not superpowers-owned |

### Step 2: Determine Base Branch

```bash
git merge-base HEAD main
```
If that fails, try `git merge-base HEAD master` instead.

Or ask: "This branch split from main - is that correct?"

### Step 3 Auto: Execute Pre-Chosen Strategy

If the epic has a `completion:*` label, execute automatically:

**Before executing:** check env state from Step 1.7. If `BRANCH` is empty (detached HEAD) AND label is `completion:merge-local`, abort:
> "completion:merge-local is invalid on detached HEAD. Re-tag the epic with completion:push-pr or resolve manually."

| Label | Action |
|-------|--------|
| `completion:commit-only` | Verify clean tree. Done. |
| `completion:push` | Verify clean, push. |
| `completion:push-pr` | Push, create PR. |
| `completion:merge-local` | Merge to base locally. |

Skip to Step 5 if applicable. See `references/completion-strategies.md`.

### Step 3 Manual: Present Options

If no `completion:*` label, present options based on HEAD state from Step 1.7.

**On a named branch (normal repo or named-branch worktree) — present exactly these 4 choices:**

1. Merge back to \<base-branch\> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

**On detached HEAD (externally managed workspace) — present exactly these 3 choices:**

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Keep options concise. See `references/completion-strategies.md`.

### Step 4: Execute Chosen Option

Execute the user's chosen option. Each option has specific bash commands and confirmation requirements. Option 4 (Discard) requires typed "discard" confirmation. See `references/option-workflows.md`.

### Step 5: Cleanup Workspace

Only runs for actions that delete the branch (Merge locally, Discard). Branch on env state from Step 1.7 first, then map options to actions:

- **Named branch (4-option menu):** Options 1 (Merge) and 4 (Discard) trigger cleanup; Options 2 (PR) and 3 (Keep) preserve the worktree.
- **Detached HEAD (3-option menu):** Option 3 (Discard) triggers cleanup; Options 1 (PR) and 2 (Keep) preserve the worktree.

```bash
# Re-detecting for clarity; may already be set from Step 1.7
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**Use prefix-anchored matching against `$MAIN_ROOT` and `$HOME`** to determine ownership. Substring matching risks false-positives (e.g. `/home/user/worktrees-backup/` would incorrectly match an unanchored `worktrees/` check):

```bash
# Compute MAIN_ROOT for anchored matching
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)

if [[ "$WORKTREE_PATH" == "$MAIN_ROOT/.worktrees/"* ]] || \
   [[ "$WORKTREE_PATH" == "$MAIN_ROOT/worktrees/"* ]] || \
   [[ "$WORKTREE_PATH" == "$HOME/.config/superpowers/worktrees/"* ]]; then
  # superpowers-owned: git worktree remove
  cd "$MAIN_ROOT"
  git worktree remove "$WORKTREE_PATH"
  git worktree prune  # Self-healing: clean up any stale registrations
else
  # harness-owned: ExitWorktree or leave in place
fi
```

**Otherwise (harness-owned workspace):** Do NOT remove it. If your platform provides a workspace-exit tool (e.g., `ExitWorktree`), use it. Otherwise, leave the workspace in place.

See `references/worktree-cleanup.md` for full provenance check and removal commands.

## Quick Reference

**Named branch:**

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | Y | - | - | Y |
| 2. Create PR | - | Y | Y | - |
| 3. Keep as-is | - | - | Y | - |
| 4. Discard | - | - | - | Y (force) |

**Detached HEAD:**

| Option | Push | Keep Worktree | Cleanup Branch |
|--------|------|---------------|----------------|
| 1. Push as new branch + PR | yes | yes | - |
| 2. Keep as-is | - | yes | - |
| 3. Discard | - | - | yes (force) |

## Common Mistakes

- **Skip test verification** -> merge broken code. Always verify tests first.
- **Open-ended questions** -> present exactly 4 options (named branch) or 3 options (detached HEAD), not "what should I do?"
- **Remove harness-owned worktree** -> creates phantom state in harness registry. Check provenance (prefix-anchored to `$MAIN_ROOT/.worktrees/`, `$MAIN_ROOT/worktrees/`, or `$HOME/.config/superpowers/worktrees/`) before running `git worktree remove`.
- **Run `git worktree remove` from inside the worktree** -> fails silently. Always `cd` to main repo root first.
- **Auto-cleanup without provenance check** -> only remove worktrees we created; harness-owned workspaces need the harness exit tool.
- **No discard confirmation** -> require typed "discard" before the Discard option (Option 4 on named branch, Option 3 on detached HEAD).

See `references/red-flags.md` for detailed Never/Always lists.

## Integration

**Called by:** subagent-driven-development (Step 7), executing-plans (Step 5)
**Pairs with:** using-git-worktrees (cleans up worktree created by that skill)

## Reference Files

- `references/epic-verification.md`: checking beads epic verification tasks
- `references/test-verification.md`: task-tracked test verification protocol
- `references/pre-merge-simplification.md`: code simplifier dispatch protocol
- `references/completion-strategies.md`: auto/manual completion strategy details
- `references/option-workflows.md`: execution details for all 4 options
- `references/worktree-cleanup.md`: worktree cleanup procedures
- `references/red-flags.md`: detailed red flags and common mistakes

<!-- compressed: 2026-02-11, original: 797 words, compressed: 679 words -->
