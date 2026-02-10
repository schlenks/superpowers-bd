# Failure Recovery Playbooks

## Subagent Timeout/Crash

```
if TaskOutput(task_id, block=False) shows no progress:
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
    check TaskOutput for error details
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
