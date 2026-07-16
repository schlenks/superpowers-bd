# Wave Orchestration with Native Progress

**Load this companion before every DISPATCH phase.** It owns the active-wave flag
lifecycle used by PreCompact, verdict-audit, work-state, and notification hooks.
Do not dispatch an implementer until the flag has been created.

Create tasks to track orchestrator state:

```python
# At wave start
conflict_task = TaskCreate(
    subject="Wave 1: Conflict check",
    activeForm="Checking file conflicts"
)

# After conflict check, build wave file map for {wave_file_map} template slot
wave_file_map = build_wave_file_map(parallelizable)  # markdown table serialized into each prompt

# Mark wave in-flight so PreCompact hook blocks compaction during dispatch/monitor/review.
# Removed at the end of wave cleanup below.
open(f"temp/sdd-wave-active-{epic_id}.flag", "w").close()

wave_task = TaskCreate(
    subject="Wave 1: hub-abc.1, hub-abc.2",
    activeForm="Executing wave 1"
)
TaskUpdate(taskId=wave_task.id, addBlockedBy=[conflict_task.id])

# For each implementation — review_task is a commitment device preventing review-skipping
review_task = TaskCreate(
    subject="Review hub-abc.1",
    activeForm="Reviewing User Model"
)

# At wave end — aggregate metrics, then persist to disk (see metrics-tracking.md "Disk Persistence")
wave_metrics = [v for k, v in task_metrics.items() if k.startswith(tuple(wave_issue_ids))]
measured = [m for m in wave_metrics if m["metrics_available"]]
wave_metrics_missing = len(wave_metrics) - len(measured)
wave_tokens = sum(m["total_tokens"] for m in measured)
wave_input_tokens = sum(m["input_tokens"] for m in measured)
wave_output_tokens = sum(m["output_tokens"] for m in measured)
wave_tool_uses = sum(m["tool_uses"] for m in measured)
wave_longest_agent_ms = max((m["duration_ms"] for m in measured), default=None)
epic_tokens += wave_tokens
epic_input_tokens += wave_input_tokens
epic_output_tokens += wave_output_tokens
epic_tool_uses += wave_tool_uses
epic_metrics_missing += wave_metrics_missing

summary_task = TaskCreate(
    subject=f"Wave 1 summary ({wave_tokens:,} known tokens, {wave_metrics_missing} metrics unavailable)",
    activeForm="Summarizing wave 1"
)
TaskUpdate(taskId=summary_task.id, addBlockedBy=all_review_task_ids, metadata={
    "total_tokens": wave_tokens,
    "input_tokens": wave_input_tokens,
    "output_tokens": wave_output_tokens,
    "tool_uses": wave_tool_uses,
    "longest_agent_ms": wave_longest_agent_ms,
    "metrics_unavailable": wave_metrics_missing
})
```

## Wave Cleanup

After posting the wave summary, remove the exact report files created for the
wave. Do not use a broad prefix glob that could also delete checkpoints or flags.

Also clear the wave-active flag so PreCompact stops blocking until the next wave dispatches:

```bash
rm -f temp/sdd-wave-active-{epic_id}.flag
```

The `temp/` directory already exists at the repo root — do NOT run `mkdir` for it.

## Checkpoint Write

After wave cleanup, write the checkpoint for context recovery:

```python
import json, datetime

checkpoint = {
    "epic_id": epic_id,
    "wave_completed": wave_number,
    "budget_tier": budget_tier,
    "context_tier": context_tier,
    "platform": platform,
    "platform_agent_plan": platform_agent_plan,
    "wave_cap": wave_cap,
    "wave_receipts": wave_receipts,       # list of 2-line receipt strings
    "closed_issues": closed_issues,       # all issues closed so far
    "escalated_tasks": escalated_tasks,
    "epic_tokens": epic_tokens,
    "epic_input_tokens": epic_input_tokens,
    "epic_output_tokens": epic_output_tokens,
    "epic_tool_uses": epic_tool_uses,
    "epic_metrics_unavailable": epic_metrics_missing,
    "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
}

if platform == "claude-code":
    checkpoint["codex_enabled"] = codex_enabled
    if codex_enabled:
        checkpoint["codex_install_path"] = codex_install_path
else:
    checkpoint["codex_enabled"] = False

checkpoint_path = f"temp/sdd-checkpoint-{epic_id}.json"
json.dump(checkpoint, open(checkpoint_path, "w"), indent=2)
```

The checkpoint path is not part of the exact per-wave report-file cleanup list.

## COMPLETE Cleanup

At epic completion, delete ephemeral files:

```bash
rm -f temp/sdd-checkpoint-{epic_id}.json temp/metrics-{epic_id}.json temp/sdd-wave-active-{epic_id}.flag
```
