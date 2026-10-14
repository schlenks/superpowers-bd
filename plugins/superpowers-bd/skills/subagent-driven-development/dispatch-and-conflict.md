# Dispatch Decision & File Conflict Detection

## Filtering to Current Epic

`bd ready --exclude-label human` returns ALL ready non-question issues across all epics (question beads labeled `human` are never dispatched; see `rulings-and-escalation.md`). Filter to current epic:

```bash
# Get epic's child issue IDs
bd show <epic-id>  # Lists children like hub-abc.1, hub-abc.2, etc.

# Only dispatch issues that are BOTH:
# 1. In bd ready --exclude-label human output
# 2. Children of current epic
```

**Example:**
```
bd ready --exclude-label human shows: hub-abc.1, hub-abc.2, hub-xyz.1
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

## Platform Dispatch Examples

Resolve once per wave and store the result in `platform_agent_plan`:

```python
platform_agent_plan = {
    "platform": platform,
    "implementer": "Agent background worker" if platform == "claude-code" else "spawn_agent default worker",
    "spec_review": "Agent general-purpose" if platform == "claude-code" else "spawn_agent agent=spec_reviewer",
    "code_review": "Agent general-purpose" if platform == "claude-code" else "spawn_agent agent=code_reviewer",
    "review_aggregation": "multi-review-aggregation" if platform == "claude-code" else "spawn_agent agent=review_aggregator",
    "epic_verification": "Agent epic verifier" if platform == "claude-code" else "spawn_agent agent=epic_verifier",
}
```

### Claude Code Dispatch Example

```python
# Resolve once per wave (reused across all code reviewer dispatches)
code_reviewer_path = Glob("**/requesting-code-review/code-reviewer.md")[0]

prompt_type, prompt_template = get_prompt_for_task(task)

# Read complexity from beads label (set at plan time)
task_labels = parse_labels(bd_show_output)  # already loaded for conflict detection
task_complexity = extract_label(task_labels, "complexity") or "standard"

# Resolve implementer model: complexity selects, tier caps
COMPLEXITY_TO_IMPL = {"simple": "haiku", "standard": "sonnet", "complex": "opus"}
TIER_CEILING = {"max-20x": "opus", "max-5x": "opus", "pro/api": "sonnet"}
MODEL_RANK = {"haiku": 0, "sonnet": 1, "opus": 2}

def min_model(selected, ceiling):
    return selected if MODEL_RANK[selected] <= MODEL_RANK[ceiling] else ceiling

impl_model = min_model(COMPLEXITY_TO_IMPL[task_complexity], TIER_CEILING[budget_tier])

# Spec reviewer: sonnet only for complex tasks on non-pro tiers; haiku otherwise
# (used in background-execution.md on_implementer_complete, not in this Agent() call)
spec_model = "sonnet" if task_complexity == "complex" and budget_tier != "pro/api" else "haiku"

# Sub-agents self-read from beads. Orchestrator only provides:
# - issue_id, epic_id (for bd show/bd comments)
# - file_ownership_list (safety-critical, must be in prompt)
# - dependency_ids (1-3 lines)
# - wave_number (for tagging reports)
# - code_reviewer_path (for code reviewers to self-read methodology)
Agent(
    subagent_type="general-purpose",  # Always general-purpose
    model=tier_verifier if prompt_type == "verifier" else impl_model,
    run_in_background=True,
    description=f"{'Verify' if prompt_type == 'verifier' else 'Implement'}: {task.id}",
    prompt=prompt_template.format(
        issue_id=task.id,
        epic_id=epic_id,
        file_ownership_list=task.files,
        wave_file_map=wave_file_map,
        dependency_ids=task.deps,
        wave_number=wave_n,
        code_reviewer_path=code_reviewer_path
    )
)
```

### Codex Dispatch Example

```python
# Resolve once per wave (reused across all code reviewer dispatches)
code_reviewer_path = "skills/requesting-code-review/code-reviewer.md"

prompt_type, prompt_template = get_prompt_for_task(task)

# Read complexity from beads label (set at plan time)
task_labels = parse_labels(bd_show_output)
task_complexity = extract_label(task_labels, "complexity") or "standard"

CODEX_IMPL_EFFORT = {
    "max-20x": {"simple": "medium", "standard": "high", "complex": "high"},
    "max-5x": {"simple": "medium", "standard": "high", "complex": "high"},
    "pro/api": {"simple": "medium", "standard": "medium", "complex": "high"},
}

impl_effort = CODEX_IMPL_EFFORT[budget_tier][task_complexity]

if prompt_type == "verifier":
    spawn_agent(
        agent="epic_verifier",
        description=f"Verify epic task: {task.id}",
        prompt=verifier_prompt_template.format(
            issue_id=task.id,
            epic_id=epic_id,
            wave_number=wave_n
        )
    )
else:
    spawn_agent(
        model_reasoning_effort=impl_effort,
        description=f"Implement: {task.id}",
        prompt=prompt_template.format(
            issue_id=task.id,
            epic_id=epic_id,
            file_ownership_list=task.files,
            wave_file_map=wave_file_map,
            dependency_ids=task.deps,
            wave_number=wave_n,
            code_reviewer_path=code_reviewer_path
        )
    )
```

**Verification prompt:** Use template at `skills/epic-verifier/verifier-prompt.md`. Before dispatch, run `bash skills/epic-verifier/scripts/quality-delta.sh <base-sha> <head-sha>` (plugin path, from the repository root) and pass its output as `{quality-delta}`; see the epic-verifier skill's Dispatch section. Claude Code model selection follows the Claude verifier row in `budget-and-wave-cap.md`; Codex uses `spawn_agent(agent="epic_verifier")`.

## File Conflict Detection (Native-Progress-Tracked)

**Before dispatching each wave, create a conflict check progress item:**

```
Progress item: "Check file conflicts for wave N"
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
1. Get all ready issues from `bd ready --exclude-label human`
2. **Filter to current epic's children only**
3. Parse `## Files` section from each issue description
4. Build file → issue mapping
5. If file appears in multiple ready issues:
   - **Dispatch lowest-numbered first** (e.g., hub-abc.1 before hub-abc.3)
   - **Defer conflicting issues to next wave** (they stay ready, dispatch after current wave completes)
6. **Cap at {wave_cap} tasks per wave (default 5 for 1M context, 3 for 200k — up to 10, set via smart recommendation or explicit invocation).** If more than {wave_cap} are parallelizable, dispatch the lowest-numbered {wave_cap} and defer the rest. This prevents the orchestrator from exhausting its context window managing too many agents simultaneously.
7. **Mark conflict check task as `completed` with conflict report**
8. **Serialize wave file map** into each implementer's `{wave_file_map}` template slot:
   ```
   | File | Owner | Action |
   |------|-------|--------|
   | src/models/user.ts | hub-abc.1 | Create |
   | src/models/index.ts | hub-abc.1 | Modify |
   | src/utils/jwt.ts | hub-abc.2 | Create |
   ```
   Include files from ALL dispatched (non-deferred) issues so each agent sees who owns what.
9. Dispatch all non-conflicting issues in parallel

**Keep dispatch flat.** Since Claude Code 2.1.172 a subagent can spawn its own subagents (up to 5 levels deep). Do **not** rely on this in SDD: the wave cap is a context-budget constraint that assumes a single dispatch level, and nested fan-out multiplies token cost outside that accounting. Implementers stay flat — they must not spawn further parallel workers. The only sanctioned exception is an implementer invoking a read-only helper skill (e.g. `systematic-debugging`) for its own task; that helper must not itself fan out.

**If `## Files` section is missing:** Treat as conflicting with ALL other issues (cannot parallelize, must dispatch alone).

**If ALL ready tasks conflict:** Dispatch only the lowest-numbered task. This degrades to sequential execution—correct but slower. Consider whether the epic's task decomposition should be revised.

**Why defer instead of block?** Deferred issues aren't blocked by dependencies—they're just waiting to avoid merge conflicts. Once the current wave completes, re-check `bd ready --exclude-label human` and they'll be dispatchable.

## Micro-Task Batching

After the conflict check, collapse a group of ready issues into one dispatch when ALL hold:

- 3 or more ready issues, all `complexity:simple`;
- file-disjoint: no shared file, and every `## Files` entry is a literal path (no globs or directories); a missing `## Files` section disqualifies;
- independent: no member Consumes what another member Produces (check each `**Interfaces:**` section);
- same shape: identical step text apart from the file path or identifier, OR a plan-time `batch:<group>` label on every member. Otherwise do not batch. A rename qualifies only when it is file-local.

Standard and complex issues are never batched. A batch counts as one slot against `{wave_cap}`; the wave-cap formula is unchanged and its members still count toward the complexity weighting. Record `[BATCH] <issue-ids>` as a comment on each member at dispatch so a crash-resume can reconstruct the batch.

| Seat | Batch behavior |
|------|----------------|
| Implementer | One implementer gets every issue id and the union of their file lists. It reports one `[IMPL-REPORT]` with a per-issue section. |
| Spec review | One review. For every issue, each listed file must appear in the diff; a listed file absent from the diff is a Missing finding and a FAIL for that issue. |
| Code review | N=1, whatever the tier default (see `budget-and-wave-cap.md`). No aggregator. |
| Close | Close issues individually; each `bd close` reason carries a per-issue evidence line (`<issue-id>: <files changed>, <verification command> exit 0`). |

**Failure attribution and split.** The batch's code reviewer must tag every finding with its issue id; an untagged Critical or Important finding fails every issue in the batch. A member closes only after it has its own spec PASS, a code-review result with no untagged and no tagged Critical/Important findings, and verification evidence; its close reason carries that per-issue gate evidence. When a member fails spec review, the spec-passing members continue through code review and verification as the batch minus the failed member, and none closes before those gates pass. Failing issues are never retried as a batch: re-dispatch each singly, fixing forward from the batch HEAD (not redoing from BASE), with its own retry counter starting at the batch's count, and review it at the N from Review Fan-Out in `budget-and-wave-cap.md`. If an implementer reports BLOCKED or NEEDS_CONTEXT for part of a batch, those issues leave the batch and follow the single-issue route; the rest proceed.

## Parallel Dispatch (Native-Progress-Tracked)

**Create wave tracking progress item before dispatch:**

```
Progress item: "Wave N: Dispatch [list issues]"
  description: "Dispatching: hub-abc.1, hub-abc.2. Files verified non-conflicting."
  activeForm: "Dispatching wave N"
TaskUpdate:
  taskId: [wave-progress-id]
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
  create native progress item "Check file conflicts for wave N"
  parallelizable = filter_file_conflicts(ready)
  parallelizable = parallelizable[:wave_cap]  # Smart recommendation or context-tier default (5 for 1M, 3 for 200k), max 10
  mark conflict progress item completed  # with conflict report
  wave_file_map = build_wave_file_map(parallelizable)  # markdown table for {wave_file_map} slot

  # Capture pre-implementation SHA BEFORE any implementer starts
  wave_base_sha = run("git rev-parse HEAD")  # snapshot for all tasks in this wave

  create native progress item "Wave N: Dispatch [list issues]"
  for issue in parallelizable:
    bd update <id> --status=in_progress
    pending_tasks[issue.id]["base_sha"] = wave_base_sha  # store per-task for review dispatch
    dispatch_async(issue)  # Don't wait!

  while any_running:
    completed = wait_for_any()
    review(completed)
    if passes: bd close completed

  mark wave progress item completed  # when all in wave done
```

**Progress contract:** Record the wave item as blocked by the conflict check. The
task list then exposes ordering mistakes or skipped checks; the orchestrator still
has to honor that state explicitly.

## Post-Wave Simplification

**After all tasks in a wave close and pass review, if the wave had 2+ tasks:**

1. Collect all files modified across the wave's tasks
2. Dispatch the platform-native simplifier focusing on cross-file consistency:

**Claude Code:**

```python
if wave_task_count >= 2 and budget_tier != "pro/api":
    wave_files = collect_modified_files_across_wave(wave_tasks)
    Agent(
        subagent_type="superpowers-bd:code-simplifier",
        description=f"Simplify: post-wave {wave_number}",
        prompt=f"Focus on these files modified in wave {wave_number}: "
               f"{wave_files}. "
               "Check cross-file consistency: naming patterns, "
               "duplication between tasks, redundant abstractions. "
               "Preserve all behavior and keep tests green."
    )
    task_metrics[f"wave{wave_number}.simplify"] = {...}
```

**Codex:**

```python
if wave_task_count >= 2 and budget_tier != "pro/api":
    wave_files = collect_modified_files_across_wave(wave_tasks)
    spawn_agent(
        model_reasoning_effort="high",
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
