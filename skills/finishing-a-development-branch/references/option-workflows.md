# Option Execution Workflows

Step 4 detail: Full execution procedures for each completion option, plus the explicit-request-only discard path.

## Option 1: Merge Locally

```bash
# A worktree can't check out the base branch while the main repo has it,
# and can't be removed from inside itself: merge from the main repo root
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the worktree and branch in place, and investigate. Nothing has been pushed, so the merge is local and recoverable.

Once the merged result is green: cleanup worktree (Step 5, using the `WORKTREE_PATH` captured in Step 1.7), then delete the branch — `git branch -d` refuses while the branch is still checked out in the worktree:

```bash
git branch -d <feature-branch>
```

## Option 2: Push and Create PR

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

**Keep the worktree** — PR feedback gets fixed there.

## Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

## Discard (Explicit Request Only)

Not a menu option. This path exists only when the user explicitly asks to throw the work away.

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact typed word — "yeah, get rid of it" is not confirmation.

If confirmed:
```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then cleanup worktree (Step 5) and force-delete the branch:
```bash
git branch -D <feature-branch>
```
