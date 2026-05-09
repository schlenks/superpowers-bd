# Red Flags

## Never

- Create a worktree when Step 0 detects existing isolation
- Use `git worktree add` when you have a native worktree tool (`EnterWorktree`, `WorktreeCreate`, `/worktree`, `--worktree`). #1 mistake — if it exists, use it.
- Skip Step 1a by jumping straight to Step 1b's git commands
- Create worktree without verifying it's ignored (project-local fallback only)
- Skip baseline test verification
- Proceed with failing tests without asking
- Assume directory location when ambiguous
- Skip CLAUDE.md check

## Always

- Run Step 0 detection first
- Prefer native tools over git fallback (Step 1a beats Step 1b)
- Honor existing declared preference (CLAUDE.md, prior instructions) without re-asking
- Follow directory priority: existing > CLAUDE.md > ask
- Verify directory is ignored for project-local fallback
- Auto-detect and run project setup
- Verify clean test baseline
