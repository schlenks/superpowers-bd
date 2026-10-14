# Failure Recovery Playbooks

None of these playbooks waits for a human. Each ends in a ruling, an asynchronous escalation, or (for bd failures only) a stop. Formats and the hard-stop classes: `rulings-and-escalation.md`. `rule(...)` below means "post a `[RULING]` on the epic and the child"; `escalate(...)` means "`bd label add <id> human` plus a `[HUMAN-NEEDED]` comment, then continue with independent work".

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

## Review Rejection Loop (past the cap)

```
if rejection_count[task_id] exceeds the review-loop cap (SKILL.md Review Rules):
    # Do not pause the epic. Adjudicate the remaining findings.
    for finding in open_findings:
        if fixing it needs a hard-stop action:
            escalate(finding_step_or_task, question=finding)
        else:
            rule(task_id, decision="fix" | "accept as-is", why=evidence, cost_if_wrong=impact)
    apply "fix" rulings once more, or close with the accepted findings listed in the close reason
    continue with other ready issues
```

## Implementer BLOCKED

When an implementer returns BLOCKED:

```
blocker = verdict.BLOCKER

# 1. Assess blocker type
if blocker indicates missing context ("need to understand", "can't find"):
    # Context problem — provide more context, same model
    redispatch_with_context(task_id, blocker, same_model=True)

elif blocker indicates capacity limit ("architectural decision", "multiple approaches", "uncertain", "too large"):
    # Reasoning capacity — upgrade native strength, capped by tier
    if checkpoint.platform == "codex":
        current_effort = pending_tasks[task_id]["model_reasoning_effort"]
        next_effort = upgrade_effort(current_effort)  # medium->high, capped by Codex tier table
        if next_effort == current_effort:
            split_or_escalate(task_id, blocker)
        else:
            redispatch(
                task_id,
                model_reasoning_effort=next_effort,
                extra_context=blocker,
                preserve_file_ownership=True
            )
    else:
        current_model = pending_tasks[task_id]["model"]
        next_model = upgrade(current_model)  # haiku->sonnet->opus, capped by tier
        if next_model == current_model:
            split_or_escalate(task_id, blocker)
        else:
            redispatch(task_id, next_model, extra_context=blocker)

elif blocker indicates a plan defect ("plan says X but", "contradicts", "requirement is wrong"):
    # Judgment call on the plan — rule, then re-dispatch with the ruling
    if the only resolutions need a hard-stop action:
        escalated_tasks[task_id] = blocker
        escalate(task_id, question=blocker)
    else:
        rule(task_id, decision, why, cost_if_wrong)
        redispatch(task_id, extra_context=ruling)

elif blocker indicates scope change ("restructuring", "beyond plan", "new requirement"):
    # The plan's intent is in question — async escalation, keep the epic moving
    escalated_tasks[task_id] = blocker
    escalate(task_id, question=blocker)

else:
    # Unknown blocker — re-dispatch once with the blocker as context, then escalate
    if not pending_tasks[task_id].get("unknown_blocker_retried"):
        pending_tasks[task_id]["unknown_blocker_retried"] = True
        redispatch_with_context(task_id, blocker, same_model=True)
    else:
        escalated_tasks[task_id] = blocker
        escalate(task_id, question=blocker)

def split_or_escalate(task_id, blocker):
    # Capacity exhausted at the tier cap: split if the task has separable parts
    if task splits cleanly by file or behavior:
        bd create sub-issues under the epic, carrying the original acceptance criteria
        rule(task_id, decision="split into <ids>", why=blocker, cost_if_wrong=...)
    else:
        escalated_tasks[task_id] = blocker
        escalate(task_id, question=blocker)
```

## Implementer NEEDS_CONTEXT

When an implementer returns NEEDS_CONTEXT:

```
missing_context = verdict.BLOCKER
redispatch_count = pending_tasks[task_id].get("redispatch_count", 0) + 1
pending_tasks[task_id]["redispatch_count"] = redispatch_count

if redispatch_count > 2:
    # Tried 3 times — park this task, keep the epic moving
    escalated_tasks[task_id] = missing_context
    escalate(task_id, question=f"Implementer asked for context 3 times: {missing_context}")
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
    # Gap closure already escalated via the bd human label (verification-and-evidence.md)
    # Don't dispatch new work for this task; continue with independent issues
    record in [WAVE-SUMMARY] Escalated: "{task_id}: verification failed {n} times"
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
        # Capacity or scope: narrow the review (split files across reviewers)
        # or move the reviewer one model tier up (Codex: one effort step up), once
        dispatch narrowed_or_stronger_reviewer

        if fails_a_third_time:
            escalated_tasks[task_id] = "reviewer failed 3 times"
            escalate(task_id, question="review could not complete; see reviewer output")
            # the task stays open; never close it without review evidence
```

## bd Command Failures

```
if bd_command_fails:
    run: bd doctor   # check beads health
    run: git status  # check git state

    if persistent:
        # No ruling or escalation can be recorded without bd: this is a hard stop
        write checkpoint, then end the run with final line:
        BLOCKED: bd unavailable
```

## Compaction or Clear Recovery

When the orchestrator sees `<sdd-checkpoint-recovery>` in session context, or finds a checkpoint file during INIT:

```
1. Read temp/sdd-checkpoint-{epic_id}.json
2. Verify epic exists: bd show {epic_id}
3. Restore state:
   - budget_tier (skip re-asking)
   - context_tier (default to "standard" if absent)
   - platform (infer current session platform if absent)
   - platform_agent_plan (rebuild from active dispatch path if absent)
   - wave_cap (default to 3 if absent)
   - wave_receipts (list of 2-line receipt strings)
   - closed_issues (for tracking)
   - escalated_tasks: rebuild from `bd list --label human --parent {epic_id}`
     (bd is the record; the checkpoint copy is a cache). Skip them during LOADING.
   - epic_tokens, epic_input_tokens, epic_output_tokens, epic_tool_uses,
     epic_metrics_unavailable (running measured metrics)
4. Restore Claude-only Codex advisory fields only when platform is "claude-code".
   If current platform is Codex, ignore stale codex_enabled/codex_install_path fields.
5. Check for in_progress tasks: bd show {epic_id}
   if any tasks are in_progress:
       bd update --status=open {task_id}  # reset interrupted wave
6. Resume from LOADING at wave {wave_completed + 1}
7. Print: "Resuming epic {epic_id} from wave {N} after context recovery."
```

**Corrupted checkpoint fallback:**

```
if checkpoint is unreadable or missing expected fields:
    ignore checkpoint
    use beads as SSOT: bd show {epic_id} to determine completed vs remaining
    rebuild escalations from bd list --label human --parent {epic_id}
    resolve budget tier: explicit tier, else SDD_BUDGET_TIER, else max-5x (never ask)
    re-detect platform and context tier
    rebuild platform_agent_plan from the active dispatch path
    run smart wave cap recommendation or use the context-tier default
    print: "Checkpoint corrupted — falling back to beads (budget tier: {tier})."
```
