---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - creates isolated git worktrees with smart directory selection and safety verification
effort: medium
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously without switching.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` is also true inside git submodules. Before concluding "already in a worktree," verify you are not in a submodule:

```bash
# If this returns a path, you're in a submodule, not a worktree — treat as normal repo
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**If `GIT_DIR != GIT_COMMON` (and not a submodule):** You are already in a linked worktree. Skip to Step 3 (Project Setup) below. Do NOT create another worktree.

Report with branch state:
- On a branch: "Already in isolated workspace at `<path>` on branch `<name>`."
- Detached HEAD: "Already in isolated workspace at `<path>` (detached HEAD, externally managed). Branch creation needed at finish time."

**If `GIT_DIR == GIT_COMMON` (or in a submodule):** You are in a normal repo checkout.

Has the user already indicated their worktree preference (CLAUDE.md, brainstorming spec, prior instructions)? If yes, honor it without asking. If no, ask for consent before creating a worktree:

> "Would you like me to set up an isolated worktree? It protects your current branch from changes."

If the user declines consent, work in place and skip to Step 3 (Project Setup).

## Step 1: Create Isolated Workspace

### Step 1a: Native Worktree Tool (preferred)

The user has consented to an isolated workspace (Step 0). Do you already have a way to create one? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip directly to Step 3 (Project Setup).

Native tools manage directory placement, branch creation, and harness lifecycle hooks (`WorktreeCreate`/`WorktreeRemove`). Using `git worktree add` when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native worktree tool available.

### Step 1b: Git Worktree Fallback

**Only use this if Step 1a does not apply** — you have no native worktree tool. Create a worktree manually using git via the task-tracked flow below.

Follow this priority order to select the directory:

1. **Check existing directories** -- Use `.worktrees/` or `worktrees/` if present (`.worktrees/` wins if both exist)
2. **Check CLAUDE.md** -- Use any worktree directory preference specified there
3. **Ask user** -- Offer `.worktrees/` (project-local) or `~/.config/superpowers/worktrees/<project>/` (global)

See `references/directory-selection.md` for full bash commands and ask-user flow.

**Safety verification (project-local only):**
1. **Check gitignore** -- `git check-ignore -q .worktrees` to verify directory is ignored
2. **Add if needed** -- Add to `.gitignore` if not ignored
3. **Commit** -- Commit the `.gitignore` change before proceeding

See `references/safety-verification.md` for full verification protocol.

**Creation Steps (Task-Tracked):** Create 4 native tasks, each blocked by the previous (non-skippable sequence):

1. **Select worktree directory location** -- Check existing dirs, CLAUDE.md, or ask user
2. **Verify gitignore for project-local directory** -- Run `git check-ignore`, add to `.gitignore` if needed
3. **Create worktree** -- `git worktree add <path> -b <branch>`
4. **Proceed to Step 3 (Project Setup)** -- Steps 3 and 4 below run dependency installation and baseline tests for both native and fallback paths.

See `references/creation-steps.md` for full TaskCreate blocks, bash commands, and setup detection.

## Step 3: Project Setup

After workspace is established (whether via native tool or git fallback), auto-detect and run setup:

```bash
if [ -f package.json ]; then npm install; fi
if [ -f Cargo.toml ]; then cargo build; fi
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi
if [ -f go.mod ]; then go mod download; fi
```

## Step 4: Verify Clean Baseline

Run the project test suite. Report pass/fail. If failing, ask before proceeding.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in linked worktree (Step 0) | Skip creation, go to Step 3 |
| In a submodule | Treat as normal repo (Step 0 guard) |
| Native worktree tool available | Use it (Step 1a), skip fallback |
| No native tool | Git worktree fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check CLAUDE.md -> Ask user |
| Directory not ignored | Add to .gitignore + commit |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| Done with worktree | Use ExitWorktree tool (2.1.72+) |

## Common Mistakes

- **Skipping ignore verification** -- worktree contents pollute git status. Always `git check-ignore` first.
- **Assuming directory location** -- follow priority: existing > CLAUDE.md > ask.
- **Proceeding with failing tests** -- report failures, get permission first.
- **Hardcoding setup commands** -- auto-detect from project files instead.

## Integration

**Called by:** brainstorming (after design), any skill needing isolated workspace
**Pairs with:** finishing-a-development-branch (cleanup), executing-plans / subagent-driven-development (work happens here)
**Cleanup:** ExitWorktree tool (2.1.72+) — see Quick Reference and `references/creation-steps.md` section 6.

## Reference Files

- `references/directory-selection.md`: full priority order with bash commands and ask-user flow
- `references/safety-verification.md`: full gitignore verification protocol with commands
- `references/creation-steps.md`: full TaskCreate blocks, bash commands, and setup detection
- `references/example-workflow.md`: annotated example of complete worktree setup workflow
- `references/red-flags.md`: Never/Always lists for quick self-check

<!-- compressed: 2026-02-11, original: 541 words, compressed: 481 words -->
