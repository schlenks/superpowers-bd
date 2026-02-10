# Creation Steps (Full Detail)

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

TaskCreate: "Install dependencies"
  description: "Auto-detect project type. Run appropriate install command."
  activeForm: "Installing dependencies"
  addBlockedBy: [create-task-id]

TaskCreate: "Run baseline tests"
  description: "Run project test suite. MUST capture output showing pass/fail."
  activeForm: "Running baseline tests"
  addBlockedBy: [install-task-id]

TaskCreate: "Worktree ready"
  description: "Report location and test status. Only complete if tests passed."
  activeForm: "Finalizing worktree setup"
  addBlockedBy: [baseline-tests-task-id]
```

**ENFORCEMENT:** Each step is blocked by the previous, making the setup process visible and non-skippable.

## 1. Detect Project Name

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

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

**If tests fail:** Report failures, ask whether to proceed or investigate. Leave baseline tests task incomplete.

**If tests pass:** Mark baseline tests task complete. Report ready.

## 5. Report Location

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

**Mark "Worktree ready" task as complete.**
