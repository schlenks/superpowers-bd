# Pre-Merge Simplification Protocol

Step 1.5 detail: Dispatch code-simplifier on all changed files before merge.

## TaskCreate Block

```
TaskCreate: "Pre-merge simplification"
  description: "Dispatch code-simplifier on all files changed vs base branch. Focus: accumulated complexity, naming consistency, redundant abstractions. Revert if tests fail."
  activeForm: "Running pre-merge simplification"
  addBlockedBy: [verify-tests-task-id]
```

## Process

### 1. Get all changed files vs base branch

```bash
git diff --name-only $(git merge-base HEAD main)..HEAD
```

### 2. Dispatch code-simplifier on the full changeset

```python
Task(
    subagent_type="code-simplifier:code-simplifier",
    description="Simplify: pre-merge",
    prompt=f"Focus on these files from the branch: {changed_files}. "
           "This is the final simplification before merge. Check: "
           "accumulated complexity across all changes, naming consistency, "
           "redundant abstractions, unnecessary indirection. "
           "Preserve all behavior and keep tests green."
)
```

### 3. If changes made

Re-run tests (re-verify Step 1). If tests fail, revert simplification and proceed without it. If tests pass, commit: `refactor: pre-merge simplification`

### 4. If no changes

Mark task completed, proceed.

**Mark simplification task `completed` before continuing.**
