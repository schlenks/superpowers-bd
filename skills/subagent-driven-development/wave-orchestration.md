# Wave Orchestration with Native Tasks

Create tasks to track orchestrator state:

```python
# At wave start
conflict_task = TaskCreate(
    subject="Wave 1: Conflict check",
    activeForm="Checking file conflicts"
)

# After conflict check, build wave file map for {wave_file_map} template slot
wave_file_map = build_wave_file_map(parallelizable)  # markdown table serialized into each prompt

wave_task = TaskCreate(
    subject="Wave 1: hub-abc.1, hub-abc.2",
    activeForm="Executing wave 1",
    addBlockedBy=[conflict_task.id]
)

# For each implementation — review_task is a commitment device preventing review-skipping
review_task = TaskCreate(
    subject="Review hub-abc.1",
    activeForm="Reviewing User Model"
)

# At wave end — aggregate metrics, then persist to disk (see metrics-tracking.md "Disk Persistence")
wave_metrics = [v for k, v in task_metrics.items() if k.startswith(tuple(wave_issue_ids))]
wave_tokens = sum(m["total_tokens"] for m in wave_metrics)
wave_tool_uses = sum(m["tool_uses"] for m in wave_metrics)
wave_duration_ms = max(m["duration_ms"] for m in wave_metrics)
wave_cost = wave_tokens * 9 / 1_000_000
epic_tokens += wave_tokens
epic_tool_uses += wave_tool_uses
epic_cost += wave_cost

summary_task = TaskCreate(
    subject=f"Wave 1 summary ({wave_tokens:,} tokens, ~${wave_cost:.2f})",
    activeForm="Summarizing wave 1",
    addBlockedBy=[all_review_task_ids]
)
TaskUpdate(taskId=summary_task.id, metadata={
    "total_tokens": wave_tokens,
    "tool_uses": wave_tool_uses,
    "duration_ms": wave_duration_ms,
    "estimated_cost_usd": round(wave_cost, 2)
})
```

## Wave Cleanup

After posting the wave summary, remove temp report files: `rm -f temp/<epic-prefix>*`

The `temp/` directory already exists at the repo root — do NOT run `mkdir` for it.

## Checkpoint Write

After wave cleanup, write the checkpoint for context recovery:

```python
import json, datetime

checkpoint = {
    "epic_id": epic_id,
    "wave_completed": wave_number,
    "budget_tier": budget_tier,
    "wave_receipts": wave_receipts,       # list of 2-line receipt strings
    "closed_issues": closed_issues,       # all issues closed so far
    "epic_tokens": epic_tokens,
    "epic_tool_uses": epic_tool_uses,
    "epic_cost": round(epic_cost, 2),
    "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
}

checkpoint_path = f"temp/sdd-checkpoint-{epic_id}.json"
json.dump(checkpoint, open(checkpoint_path, "w"), indent=2)
```

The `sdd-checkpoint-` prefix survives wave cleanup (`rm -f temp/<epic-prefix>*`).

## COMPLETE Cleanup

At epic completion, delete ephemeral files:

```bash
rm -f temp/sdd-checkpoint-{epic_id}.json temp/metrics-{epic_id}.json
```

