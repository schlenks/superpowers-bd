# Creation Steps (Full Detail)

**Scope:** This file describes the **Step 1b git-worktree fallback** flow. If a native worktree tool (`EnterWorktree`, etc.) is available, Step 1a applies and the harness manages directory placement, branch creation, and lifecycle — the task-tracked flow below does NOT apply.

## Task Definitions

**Create setup tasks with dependencies:**

```
TaskCreate: "Select worktree directory location"
  description: "Check existing dirs, CLAUDE.md, or ask user. Follow priority order."
  activeForm: "Selecting directory"

TaskCreate: "Verify gitignore for project-local directory"
  description: "If project-local, verify ignored with git check-ignore. Add to .gitignore if needed."
  activeForm: "Verifying gitignore"
  addBlockedBy: [select-task-id]

TaskCreate: "Create worktree"
  description: "Run git worktree add. Capture path."
  activeForm: "Creating worktree"
  addBlockedBy: [verify-gitignore-task-id]

TaskCreate: "Proceed to Step 3 (Project Setup)"
  description: "Steps 3 and 4 (project setup and baseline tests) run outside this task-tracked sequence — same work for both native and fallback paths."
  activeForm: "Transitioning to Step 3"
  addBlockedBy: [create-task-id]
```

**ENFORCEMENT:** Each step is blocked by the previous, making the setup process visible and non-skippable.

## 1. Detect Project Name

```bash
git rev-parse --show-toplevel
```
Extract the project name (last path component) from the output.

## 2. Create Worktree

```bash
# Determine full path
case $LOCATION in
  .worktrees|worktrees)
    path="$LOCATION/$BRANCH_NAME"
    ;;
  ~/.config/superpowers/worktrees/*)
    path="~/.config/superpowers/worktrees/$project/$BRANCH_NAME"
    ;;
esac

# Create worktree with new branch
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

## 3. Run Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

## 4. Verify Clean Baseline

Run tests to ensure worktree starts clean:

```bash
# Examples - use project-appropriate command
npm test
cargo test
pytest
go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

## 5. Report Location

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## 6. Leaving a Worktree

When work in the worktree is complete:

```bash
ExitWorktree tool
  action: "keep" or "remove"
  discard_changes: true or false (only with action: "remove")
```

**Parameters:**
- **action: "keep"** -- Leaves the worktree and branch intact on disk. Use if you want to return to this work later or preserve uncommitted changes.
- **action: "remove"** -- Deletes the worktree directory and its branch. Clean exit when work is done. If the worktree has uncommitted files or unmerged commits, set `discard_changes: true` to proceed.

**After exit:** Your session returns to the original working directory and repository state.
