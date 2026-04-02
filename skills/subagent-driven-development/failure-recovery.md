# Failure Recovery Playbooks

## Subagent Timeout/Crash

```
if background agent shows no completion notification after extended time:
    check git status for partial commits

    if partial_work_committed:
        read what was done
        dispatch new agent: "Continue from: [summary of completed work]"
    else:
        dispatch fresh implementer
        note in wave summary: "Task X restarted due to agent failure"
```

## Review Rejection Loop (>2 iterations)

```
if rejection_count[task_id] > 2:
    PAUSE automated flow
    Report to human:
      "Task {task_id} rejected {n} times.
       Rejection reasons: {reasons}
       Options:
       1. Continue automated retries
       2. Take over manually
       3. Split task into smaller pieces
       4. Clarify spec and retry"
    WAIT for human decision
```

## Implementer BLOCKED

When an implementer returns BLOCKED:

```
blocker = verdict.BLOCKER

# 1. Assess blocker type
if blocker indicates missing context ("need to understand", "can't find"):
    # Context problem — provide more context, same model
    redispatch_with_context(task_id, blocker, same_model=True)

elif blocker indicates capacity limit ("architectural decision", "multiple approaches", "uncertain"):
    # Reasoning capacity — upgrade model
    current_model = pending_tasks[task_id]["model"]
    next_model = upgrade(current_model)  # haiku→sonnet→opus, capped by tier
    if next_model == current_model:
        # Already at tier ceiling — escalate to human
        escalated_tasks[task_id] = blocker
        report_to_human(task_id, blocker)
    else:
        redispatch(task_id, next_model, extra_context=blocker)

elif blocker indicates scope problem ("restructuring", "too large", "beyond plan"):
    # Task decomposition needed — escalate to human
    escalated_tasks[task_id] = blocker
    report_to_human(task_id, blocker,
        options=["Break task into sub-issues", "Revise plan", "Take over manually"])

else:
    # Unknown blocker — escalate to human
    escalated_tasks[task_id] = blocker
    report_to_human(task_id, blocker)
```

## Implementer NEEDS_CONTEXT

When an implementer returns NEEDS_CONTEXT:

```
missing_context = verdict.BLOCKER
redispatch_count = pending_tasks[task_id].get("redispatch_count", 0) + 1
pending_tasks[task_id]["redispatch_count"] = redispatch_count

if redispatch_count > 2:
    # Tried 3 times — human must clarify
    escalated_tasks[task_id] = missing_context
    report_to_human(task_id, missing_context,
        note="Implementer asked for context 3 times. Human clarification needed.")
else:
    # Read the relevant files/code the implementer needs
    # Include them directly in the re-dispatch prompt
    redispatch_with_context(task_id, missing_context, same_model=True)
```

**Re-dispatch prompt addendum:**

```
The previous attempt returned NEEDS_CONTEXT:
"{blocker_description}"

Here is the additional context:
{additional_context_from_orchestrator}

All other instructions from your original dispatch still apply.
```

## Verification Gap Closure (>3 attempts)

```
if verification_attempt_count[task_id] > 3:
    # Gap closure already escalated - task in pending_human_intervention
    # Don't dispatch new work for this task
    # Human must resolve via intervention task

    Report status:
      "Task {task_id} verification failed {n} times.
       Gap closure escalated to human.
       Awaiting resolution of: [intervention task subject]"
```

## Deadlock Detection

```
# If no ready tasks exist for this epic, but open tasks remain:
if (bd_ready filtered to epic_children) is empty AND open_issues > 0:
    Run: bd blocked

    if circular_dependency_detected:
        Report: "Circular dependency: A → B → A"
        Suggest: bd dep remove <id> <blocker>

    if forgot_to_close:
        Report: "Task X completed but not closed"
        Action: bd close <task_id>
```

## Reviewer Agent Failure

```
if reviewer_task_fails:
    Read the agent's output file for error details
    dispatch fresh reviewer (same prompt, same task)

    if fails_again:
        STOP and ask human
        # May indicate model capacity issue
        # May need to split the review scope
```

## bd Command Failures

```
if bd_command_fails:
    run: bd doctor   # check beads health
    run: git status  # check git state

    if persistent:
        STOP and ask human for help
```

## Compaction or Clear Recovery

When the orchestrator sees `<sdd-checkpoint-recovery>` in session context, or finds a checkpoint file during INIT:

```
1. Read temp/sdd-checkpoint-{epic_id}.json
2. Verify epic exists: bd show {epic_id}
3. Restore state:
   - budget_tier (skip re-asking)
   - wave_receipts (list of 2-line receipt strings)
   - closed_issues (for tracking)
   - epic_tokens, epic_tool_uses, epic_cost (running metrics)
4. Check for in_progress tasks: bd show {epic_id}
   if any tasks are in_progress:
       bd update --status=open {task_id}  # reset interrupted wave
5. Resume from LOADING at wave {wave_completed + 1}
6. Print: "Resuming epic {epic_id} from wave {N} after context recovery."
```

**Corrupted checkpoint fallback:**

```
if checkpoint is unreadable or missing expected fields:
    ignore checkpoint
    use beads as SSOT: bd show {epic_id} to determine completed vs remaining
    re-ask budget tier
    print: "Checkpoint corrupted — falling back to beads. Which budget tier?"
```
