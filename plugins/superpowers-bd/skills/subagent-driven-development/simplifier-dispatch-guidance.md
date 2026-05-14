# Code Simplifier Dispatch Guidance

Reference for the SDD orchestrator on invoking `code-simplifier:code-simplifier` at post-wave and pre-merge points.

## Post-Wave Simplification

**When:** After all tasks in a wave close and pass review, if wave had 2+ tasks.

**What files to pass:** All files modified across the wave's tasks. Collect from:
- Implementer evidence sections (commit diffs)
- `git diff --name-only <pre-wave-commit>..HEAD`

**Focus areas:**
- Cross-file naming consistency (did two implementers name similar things differently?)
- Duplication between tasks (shared patterns that could be unified)
- Redundant abstractions introduced by independent implementers
- Import/export consistency

**Prompt template:**
```
Focus on these files modified in wave {N}: {file_list}.
Check cross-file consistency: naming patterns, duplication between tasks,
redundant abstractions. Preserve all behavior and keep tests green.
```

**After dispatch:**
1. Run full test suite
2. If tests pass: `git commit -m "refactor: post-wave simplification (wave N)"`
3. If tests fail: `git checkout -- .` (revert all simplification changes), continue
4. Record metrics in `task_metrics[f"wave{N}.simplify"]`

## Pre-Merge Simplification

**When:** Always, during `finishing-a-development-branch` Step 1.5.

**What files to pass:** All files changed on the branch vs base (two separate commands):
```bash
git merge-base HEAD main
```
Then use the result:
```bash
git diff --name-only <merge-base-sha>..HEAD
```

**Focus areas:**
- Accumulated complexity across all waves
- Naming consistency across the full changeset
- Redundant abstractions that made sense per-task but are unnecessary in aggregate
- Unnecessary indirection layers

**Prompt template:**
```
Focus on these files from the branch: {file_list}.
This is the final simplification before merge. Check: accumulated complexity
across all changes, naming consistency, redundant abstractions, unnecessary
indirection. Preserve all behavior and keep tests green.
```

**After dispatch:**
1. Run full test suite
2. If tests pass: `git commit -m "refactor: pre-merge simplification"`
3. If tests fail: revert and proceed without simplification

## Handling Test Failures

Both post-wave and pre-merge follow the same recovery:

1. **Revert all simplification changes:** `git checkout -- .`
2. **Do not retry** — if the simplifier broke tests, the changes were too aggressive
3. **Continue the workflow** — simplification is best-effort, not blocking
4. **Note in wave summary or completion report:** "Simplification: skipped (test failure after changes)"

## Metrics Tracking

Record simplification metrics alongside other wave/epic metrics:

```python
# Post-wave
task_metrics[f"wave{N}.simplify"] = {
    "total_tokens": result.usage.total_tokens,
    "tool_uses": result.usage.tool_uses,
    "duration_ms": result.usage.duration_ms
}

# Pre-merge (not part of any wave)
task_metrics["pre_merge.simplify"] = {
    "total_tokens": result.usage.total_tokens,
    "tool_uses": result.usage.tool_uses,
    "duration_ms": result.usage.duration_ms
}
```

Include in wave cost aggregation and epic accumulator.
