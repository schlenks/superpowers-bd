# Safety Verification

## For Project-Local Directories (.worktrees or worktrees)

**MUST verify directory is ignored before creating worktree:**

```bash
# Check if directory is ignored (respects local, global, and system gitignore)
git check-ignore -q .worktrees
```
If that fails (exit code 1), try `git check-ignore -q worktrees` instead.

**If NOT ignored:**

Per Jesse's rule "Fix broken things immediately":
1. Add appropriate line to .gitignore
2. Commit the change
3. Proceed with worktree creation

**Why critical:** Prevents accidentally committing worktree contents to repository.

## For Global Directory (~/.config/superpowers/worktrees)

No .gitignore verification needed - outside project entirely.
