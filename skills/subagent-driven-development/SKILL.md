---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development

Execute beads epic by dispatching parallel subagents for independent issues, with two-stage review after each completion.

**Core principle:** Parallel dispatch of independent tasks + dependency awareness + two-stage review = high quality, maximum throughput

**REQUIRED BACKGROUND:** You MUST understand `superpowers:beads` before using this skill. That skill covers bd CLI usage, permission avoidance, and dependency management.

## When to Use

```dot
digraph when_to_use {
    "Have beads epic?" [shape=diamond];
    "Tasks have dependencies set?" [shape=diamond];
    "Stay in this session?" [shape=diamond];
    "subagent-driven-development" [shape=box];
    "executing-plans" [shape=box];
    "Run plan2beads first" [shape=box];

    "Have beads epic?" -> "Tasks have dependencies set?" [label="yes"];
    "Have beads epic?" -> "Run plan2beads first" [label="no"];
    "Tasks have dependencies set?" -> "Stay in this session?" [label="yes"];
    "Tasks have dependencies set?" -> "Run plan2beads first" [label="no deps"];
    "Stay in this session?" -> "subagent-driven-development" [label="yes"];
    "Stay in this session?" -> "executing-plans" [label="no - parallel session"];
}
```

**Announce at start:** "I'm using Subagent-Driven Development to execute beads epic [epic-id]."

## Budget Tier Selection

Before dispatching, determine model selection strategy.

**Ask the user:**
> What's your Claude Code subscription tier?
> - **Max 20x** - Quality priority (opus for implementation)
> - **Max 5x** - Balanced (sonnet throughout)
> - **Pro/API** - Budget priority (haiku where possible)

**Model matrix by tier:**

| Tier | Implementer | Spec Reviewer | Code Reviewer | Epic Verifier |
|------|-------------|---------------|---------------|---------------|
| max-20x | opus | sonnet | sonnet | opus |
| max-5x | sonnet | haiku | sonnet | sonnet |
| pro/api | sonnet | haiku | haiku | sonnet |

Note: Epic Verifier uses sonnet minimum (opus for max-20x) because verification is comprehensive and must catch subtle issues. See `skills/epic-verifier/SKILL.md`.

**Store selection** for the session - don't ask again per wave.

**Prerequisites:**
- Beads epic exists (created via plan2beads)
- Dependencies are set (`bd blocked` shows expected blockers)
- Each issue has `## Files` section in description

## Key Terms

| Term | Meaning |
|------|---------|
| **Dispatch** | Use the `Task` tool to spawn a subagent with a specific prompt |
| **Wave** | A batch of issues dispatched together (all have no dependency conflicts) |
| **bd** | Beads CLI - git-backed issue tracker (`bd ready`, `bd show`, `bd close`, etc.) |
| **Ready** | Issue has no blockers - all its dependencies are closed |
| **Blocked** | Issue is waiting for one or more dependencies to close |

## The Process

```dot
digraph process {
    rankdir=TB;

    "Load epic: bd show <epic-id>" [shape=box];
    "Get child IDs from epic" [shape=box];
    "ready = bd ready ∩ epic children" [shape=box];
    "Any ready issues?" [shape=diamond];
    "Filter file conflicts among ready" [shape=box];
    "Dispatch implementers IN PARALLEL" [shape=box];
    "Wait for ANY completion" [shape=box];
    "Review completed (spec then quality)" [shape=box];
    "All reviews pass?" [shape=diamond];
    "bd close <id>" [shape=box];
    "Fix issues, re-review" [shape=box];
    "All issues in epic closed?" [shape=diamond];
    "superpowers:finishing-a-development-branch" [shape=box style=filled fillcolor=lightgreen];

    "Load epic: bd show <epic-id>" -> "Get child IDs from epic";
    "Get child IDs from epic" -> "ready = bd ready ∩ epic children";
    "ready = bd ready ∩ epic children" -> "Any ready issues?";
    "Any ready issues?" -> "Filter file conflicts among ready" [label="yes"];
    "Any ready issues?" -> "Wait for ANY completion" [label="no - waiting on in_progress"];
    "Filter file conflicts among ready" -> "Dispatch implementers IN PARALLEL";
    "Dispatch implementers IN PARALLEL" -> "Wait for ANY completion";
    "Wait for ANY completion" -> "Review completed (spec then quality)";
    "Review completed (spec then quality)" -> "All reviews pass?";
    "All reviews pass?" -> "bd close <id>" [label="yes"];
    "All reviews pass?" -> "Fix issues, re-review" [label="no"];
    "Fix issues, re-review" -> "Review completed (spec then quality)";
    "bd close <id>" -> "All issues in epic closed?";
    "All issues in epic closed?" -> "ready = bd ready ∩ epic children" [label="no - check newly unblocked"];
    "All issues in epic closed?" -> "superpowers:finishing-a-development-branch" [label="yes"];
}
```

## Verification Tasks

Verification tasks (like Rule-of-Five, Code Review, Plan Verification) are processed through the **same dispatch loop** as implementation tasks. They are not special—they appear in `bd ready` when their dependencies close, get dispatched to implementer subagents, and go through spec/quality review like any other task.

**Key points:**

1. **Appear in `bd ready`** - When an implementation task closes, its dependent verification task becomes ready
2. **Same dispatch flow** - Dispatched via implementer prompt, reviewed via spec then quality reviewers
3. **Specific acceptance criteria** - The spec reviewer verifies the verification was actually performed, not just claimed

**Example: Rule-of-Five verification task**

```
Task superpowers-xyz.5 (Rule-of-Five verification)
  Dependencies: [superpowers-xyz.1, superpowers-xyz.2, superpowers-xyz.3, superpowers-xyz.4]
  Files: [docs/plans/implementation-plan.md]
  Acceptance: Apply 5-pass review to all artifacts >50 lines created in tasks 1-4
```

**Dispatch flow:**
```
[Tasks 1-4 all closed]
[bd ready now shows superpowers-xyz.5]

[bd update superpowers-xyz.5 --status=in_progress]
[Dispatch implementer for superpowers-xyz.5]

Implementer:
  - Reviews artifacts from tasks 1-4
  - Applies Rule-of-Five passes
  - Documents changes made in each pass
  - Committed

[Dispatch spec reviewer]
Spec reviewer:
  - Verifies each required artifact was reviewed
  - Confirms 5 passes were applied (not just claimed)
  - Checks that improvements were substantive
  ✅ Passes

[Dispatch code quality reviewer]
Code reviewer: ✅ Approved

[bd close superpowers-xyz.5]
```

**Why no special handling?** Verification tasks have:
- Clear acceptance criteria (verifiable by spec reviewer)
- Defined file scope (what to review)
- Dependencies (run after implementation completes)

This means the existing dispatch → review → close flow works unchanged.

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

## File Conflict Detection (Task-Tracked)

**Before dispatching each wave, create a conflict verification task:**

```
TaskCreate: "Verify no file conflicts in wave N"
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
6. **Mark conflict verification task as `completed` with conflict report**
7. Dispatch all non-conflicting issues in parallel

**If `## Files` section is missing:** Treat as conflicting with ALL other issues (cannot parallelize, must dispatch alone).

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
  TaskCreate "Verify no file conflicts in wave N"
  parallelizable = filter_file_conflicts(ready)
  TaskUpdate conflict-task status=completed  # with conflict report

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

**ENFORCEMENT:** Wave dispatch task is blocked until file conflict verification completes. This makes the verification step visible and non-skippable.

### Background Execution with Polling

For true parallelism (not just concurrent dispatch), use `run_in_background: true` with TaskOutput polling.

**Dispatch Phase:**

```python
task_ids = []
for issue in parallelizable:
    bd update <issue.id> --status=in_progress
    result = Task(
        subagent_type="general-purpose",
        model=tier_model,
        run_in_background=True,
        description=f"Implement: {issue.id} {issue.title}",
        prompt=implementer_prompt
    )
    task_ids.append(result.task_id)
```

**Monitor Phase:**

```python
while task_ids:
    for task_id in list(task_ids):
        result = TaskOutput(task_id, block=False, timeout=5000)
        if result.status == "completed":
            dispatch_review(task_id, result)
            task_ids.remove(task_id)

    # Also check review completions
    for review_id in list(pending_reviews):
        result = TaskOutput(review_id, block=False)
        if result.status == "completed":
            process_review(review_id, result)
```

**Benefits of background execution:**

- **True parallelism** - Tasks execute simultaneously, not just dispatched concurrently
- **Simultaneous monitoring** - Can poll multiple tasks without blocking on any single one
- **Immediate review dispatch** - Start reviews as soon as implementations complete, even while other implementations are running
- **Better throughput** - Wave N+1 reviews can overlap with Wave N implementations completing

## Wave Summary (Cross-Wave Context)

**After each wave completes, post a summary comment to the epic:**

```bash
bd comments add <epic-id> "Wave N complete:
- Closed: hub-abc.1, hub-abc.2
- Conventions established:
  - [Pattern/convention implementers chose]
  - [Naming convention used]
  - [Library/approach selected when choice existed]
- Notes for future waves:
  - [Anything Wave N+1 should know]"
```

**Why this matters:**
- Wave 2 implementers can see what conventions Wave 1 established
- Prevents inconsistent naming, patterns, or style choices
- Creates audit trail of implementation decisions

**What to capture:**
- File naming patterns chosen
- Code style decisions (async/await vs promises, etc.)
- Interface shapes that future tasks will consume
- Any surprises or deviations from the plan

**When to skip:** If the wave established no new conventions (e.g., single-task wave, or tasks followed existing patterns without decisions), a minimal summary is fine: "Wave N complete: Closed hub-abc.1. No new conventions."

## Prompt Templates

- `./implementer-prompt.md` - Dispatch implementer subagent (updated for beads)
- `./spec-reviewer-prompt.md` - Dispatch spec compliance reviewer subagent
- `./code-quality-reviewer-prompt.md` - Dispatch code quality reviewer subagent

## Example Workflow (Parallel)

```
You: I'm using Subagent-Driven Development to execute beads epic hub-abc.

[Load epic: bd show hub-abc]
[Check initial state:]
  bd ready: hub-abc.1, hub-abc.2 (no deps)
  bd blocked: hub-abc.3 (by .1), hub-abc.4 (by .2, .3)

Wave 1: Tasks 1 and 2 are ready, no file conflicts

[bd update hub-abc.1 --status=in_progress]
[bd update hub-abc.2 --status=in_progress]
[Dispatch implementer for hub-abc.1 - ASYNC]
[Dispatch implementer for hub-abc.2 - ASYNC]

... both working in parallel ...

[hub-abc.2 completes first]
Implementer 2:
  - Implemented JWT utils
  - Tests passing
  - Committed

[Dispatch spec reviewer for hub-abc.2]
Spec reviewer: ✅ Spec compliant

[Dispatch code quality reviewer for hub-abc.2]
Code reviewer: ✅ Approved

[bd close hub-abc.2]

[Check bd ready: still nothing new - hub-abc.4 still blocked by hub-abc.3]

[hub-abc.1 completes]
Implementer 1:
  - Implemented User model
  - Tests passing
  - Committed

[Dispatch spec reviewer for hub-abc.1]
Spec reviewer: ✅ Spec compliant

[Dispatch code quality reviewer for hub-abc.1]
Code reviewer: ✅ Approved

[bd close hub-abc.1]

[Post wave summary]
bd comments add hub-abc "Wave 1 complete:
- Closed: hub-abc.1 (User model), hub-abc.2 (JWT utils)
- Conventions: Using uuid v4 for IDs, camelCase for all JSON fields
- Notes: JWT expiry set to 24h per Key Decisions"

[bd ready now shows hub-abc.3 (unblocked - was blocked by .1)]
[bd blocked: hub-abc.4 (still waiting on .3)]

Wave 2: Only Task 3 is ready

[bd update hub-abc.3 --status=in_progress]
[Dispatch implementer for hub-abc.3]

[hub-abc.3 completes]
Implementer 3:
  - Implemented Auth service
  - Tests passing
  - Committed

[Review passes]
[bd close hub-abc.3]

[bd ready now shows hub-abc.4 (unblocked - was blocked by .2, .3, both now closed)]

Wave 3: Task 4 is ready

[bd update hub-abc.4 --status=in_progress]
[Dispatch implementer for hub-abc.4]

[hub-abc.4 completes, reviews pass]
[bd close hub-abc.4]

[All issues closed]
[Use superpowers:finishing-a-development-branch]

Done!
```

## Advantages

**vs. Sequential execution:**
- Multiple tasks execute simultaneously
- Completion of one task immediately unblocks dependents
- Better utilization of parallel capability

**vs. Manual parallelism:**
- File conflict detection prevents merge conflicts
- Dependency-aware (only dispatches ready tasks)
- Automatic unblocking as tasks complete

**Quality gates (unchanged):**
- Two-stage review: spec compliance, then code quality
- Review loops ensure fixes work

## Red Flags

**Never:**
- Dispatch issue that's not in `bd ready` (blocked by dependency)
- Dispatch issue from different epic (filter to current epic!)
- Dispatch two issues that modify same file (file conflict)
- Skip `bd update --status=in_progress` before dispatch
- Skip `bd close` after successful review (blocks dependents!)
- Skip reviews (spec compliance OR code quality)
- Start code quality review before spec compliance passes

**Deadlock detection:**
If `bd ready` shows nothing for your epic BUT issues remain open, check for:
- Circular dependencies (A blocks B, B blocks A)
- Missing dependency closure (forgot to `bd close` a completed issue)
- Run `bd blocked` to see what's waiting on what

**Always:**
- Check `bd ready` before each dispatch wave
- Parse and compare file lists for conflicts
- Use `bd close` immediately after review passes (unblocks dependents)
- Re-check `bd ready` after each close (may have unblocked new tasks)

**If reviewer finds issues:**
- Implementer fixes them
- Reviewer re-reviews
- Repeat until approved
- Only then `bd close`

**If subagent fails or crashes:**
- The issue remains `in_progress`
- Dispatch a new implementer subagent for the same issue
- Provide context: "Previous attempt failed - starting fresh"
- Don't try to salvage partial work—start clean

**If bd commands fail:**
- Check if beads is initialized: `bd doctor`
- Check git status: `git status`
- If persistent errors, stop and ask human for help

## Integration

**Required workflow skills:**
- **plan2beads** - Converts plan to beads epic (must run first)
- **superpowers:requesting-code-review** - Code review template
- **superpowers:finishing-a-development-branch** - Complete after all tasks

**Subagents should use:**
- **superpowers:test-driven-development** - TDD for each task
- **superpowers:rule-of-five** - Apply 5-pass review to significant artifacts (>50 lines)

**Alternative workflow:**
- **`superpowers:executing-plans`** - For parallel session (also reads from beads)
