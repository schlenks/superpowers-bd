# Dispatch Decision & File Conflict Detection

## Filtering to Current Epic

`bd ready` returns ALL ready issues across all epics. Filter to current epic:

```bash
# Get epic's child issue IDs
bd show <epic-id>  # Lists children like hub-abc.1, hub-abc.2, etc.

# Only dispatch issues that are BOTH:
# 1. In bd ready output
# 2. Children of current epic
```

**Example:**
```
bd ready shows: hub-abc.1, hub-abc.2, hub-xyz.1
Current epic: hub-abc
Filter to: hub-abc.1, hub-abc.2 (ignore hub-xyz.1)
```

## Dispatch Decision

When a task becomes ready, determine which prompt template to use:

```python
def get_prompt_for_task(task):
    title_lower = task.title.lower()
    if "verification" in title_lower or "verify" in title_lower:
        return ("verifier", verifier_prompt_template)  # from skills/epic-verifier/verifier-prompt.md
    else:
        return ("implementer", implementer_prompt_template)
```

**Dispatch example:**
```python
# Resolve once per wave (reused across all code reviewer dispatches)
code_reviewer_path = Glob("**/requesting-code-review/code-reviewer.md")[0]

prompt_type, prompt_template = get_prompt_for_task(task)

# Sub-agents self-read from beads. Orchestrator only provides:
# - issue_id, epic_id (for bd show/bd comments)
# - file_ownership_list (safety-critical, must be in prompt)
# - dependency_ids (1-3 lines)
# - wave_number (for tagging reports)
# - code_reviewer_path (for code reviewers to self-read methodology)
Task(
    subagent_type="general-purpose",  # Always general-purpose
    model=tier_verifier if prompt_type == "verifier" else tier_impl,
    run_in_background=True,
    description=f"{'Verify' if prompt_type == 'verifier' else 'Implement'}: {task.id}",
    prompt=prompt_template.format(
        issue_id=task.id,
        epic_id=epic_id,
        file_ownership_list=task.files,
        dependency_ids=task.deps,
        wave_number=wave_n,
        code_reviewer_path=code_reviewer_path
    )
)
```

**Verification prompt:** Use template at `skills/epic-verifier/verifier-prompt.md`. Model selection follows Budget Tier Selection matrix (opus for max-20x, sonnet otherwise).

## File Conflict Detection (Task-Tracked)

**Before dispatching each wave, create a conflict check task:**

```
TaskCreate: "Check file conflicts for wave N"
  description: "Parse ## Files from each ready issue. Build file→issue map. Identify conflicts. Report parallelizable set."
  activeForm: "Checking file conflicts"
```

Before parallel dispatch, check for file overlap:

**Extract files from each issue:**
```
Issue hub-abc.1 files: [user.model.ts, models/index.ts]
Issue hub-abc.2 files: [jwt.utils.ts, utils/index.ts]
Issue hub-abc.3 files: [auth.service.ts, models/index.ts]  ← CONFLICT with .1!
```

**Parallelizable:** Issues with NO file overlap
- hub-abc.1 and hub-abc.2 → Safe to parallelize
- hub-abc.1 and hub-abc.3 → NOT safe (both touch models/index.ts)

**Algorithm:**
1. Get all ready issues from `bd ready`
2. **Filter to current epic's children only**
3. Parse `## Files` section from each issue description
4. Build file → issue mapping
5. If file appears in multiple ready issues:
   - **Dispatch lowest-numbered first** (e.g., hub-abc.1 before hub-abc.3)
   - **Defer conflicting issues to next wave** (they stay ready, dispatch after current wave completes)
6. **Cap at 3 tasks per wave.** If more than 3 are parallelizable, dispatch the lowest-numbered 3 and defer the rest. This prevents the orchestrator from exhausting its context window managing too many agents simultaneously.
7. **Mark conflict check task as `completed` with conflict report**
8. **Write `.claude/file-locks.json`** from the file → issue map (parallelizable set only):
   ```json
   {
     "epic": "<epic-id>",
     "wave": N,
     "generated_at": "<ISO-8601 timestamp>",
     "locks": {
       "<file-path>": {"owner": "<issue-id>", "action": "Create|Modify|Test"}
     }
   }
   ```
   Overwritten at each wave start. Only includes files from dispatched (non-deferred) issues.
9. Dispatch all non-conflicting issues in parallel

**If `## Files` section is missing:** Treat as conflicting with ALL other issues (cannot parallelize, must dispatch alone).

**If ALL ready tasks conflict:** Dispatch only the lowest-numbered task. This degrades to sequential execution—correct but slower. Consider whether the epic's task decomposition should be revised.

**Why defer instead of block?** Deferred issues aren't blocked by dependencies—they're just waiting to avoid merge conflicts. Once the current wave completes, re-check `bd ready` and they'll be dispatchable.

## Parallel Dispatch (Task-Tracked)

**Create wave tracking task before dispatch:**

```
TaskCreate: "Wave N: Dispatch [list issues]"
  description: "Dispatching: hub-abc.1, hub-abc.2. Files verified non-conflicting."
  activeForm: "Dispatching wave N"
  addBlockedBy: [conflict-verify-task-id]
```

**Key difference from sequential:**

```
SEQUENTIAL (old):
  for issue in ready:
    dispatch(issue)
    wait_for_completion()
    review()

PARALLEL (new):
  TaskCreate "Check file conflicts for wave N"
  parallelizable = filter_file_conflicts(ready)
  parallelizable = parallelizable[:3]  # Max 3 per wave — prevents context exhaustion
  TaskUpdate conflict-task status=completed  # with conflict report

  write_file_locks(epic_id, wave_n, parallelizable)  # .claude/file-locks.json

  TaskCreate "Wave N: Dispatch [list issues]"
  for issue in parallelizable:
    bd update <id> --status=in_progress
    dispatch_async(issue)  # Don't wait!

  while any_running:
    completed = wait_for_any()
    review(completed)
    if passes: bd close completed

  TaskUpdate wave-task status=completed  # when all in wave done
```

**ENFORCEMENT:** Wave dispatch task is blocked until file conflict check completes. This makes the step visible and non-skippable.

## Post-Wave Simplification

**After all tasks in a wave close and pass review, if the wave had 2+ tasks:**

1. Collect all files modified across the wave's tasks
2. Dispatch `code-simplifier:code-simplifier` via Task tool focusing on cross-file consistency:

```python
if wave_task_count >= 2 and budget_tier != "pro/api":
    wave_files = collect_modified_files_across_wave(wave_tasks)
    Task(
        subagent_type="code-simplifier:code-simplifier",
        description=f"Simplify: post-wave {wave_number}",
        prompt=f"Focus on these files modified in wave {wave_number}: "
               f"{wave_files}. "
               "Check cross-file consistency: naming patterns, "
               "duplication between tasks, redundant abstractions. "
               "Preserve all behavior and keep tests green."
    )
    task_metrics[f"wave{wave_number}.simplify"] = {...}
```

3. **If changes made:** Run tests, commit `refactor: post-wave simplification (wave N)`
4. **If tests fail:** Revert simplification changes, continue to wave summary
5. **Skip on pro/api tier** (save cost). Run on max-20x and max-5x only.
6. **Skip for single-task waves** (no cross-file consistency to check)

See `./simplifier-dispatch-guidance.md` for detailed invocation reference.
