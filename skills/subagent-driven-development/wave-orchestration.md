# Wave Orchestration with Native Tasks

Create tasks to track orchestrator state:

```python
# At wave start
conflict_task = TaskCreate(
    subject="Wave 1: Conflict check",
    activeForm="Checking file conflicts"
)

# After conflict check, write advisory lock file
write_file_locks(epic_id, wave_n, parallelizable)  # .claude/file-locks.json

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

