# Metrics and Cost Impact

Per-reviewer metric keys and cost breakdown by tier.

## Metric Keys

Multi-review adds these metric keys:

```python
# Individual reviewers
task_metrics[f"{issue_id}.code.1"] = {...}  # Reviewer 1
task_metrics[f"{issue_id}.code.2"] = {...}  # Reviewer 2
task_metrics[f"{issue_id}.code.3"] = {...}  # Reviewer 3

# Aggregation step (if not fast-pathed)
task_metrics[f"{issue_id}.agg"] = {...}
```

## Cost Impact

| Component | Single (N=1) | Multi (N=3) |
|-----------|-------------|-------------|
| Spec review | 12k tok | 12k tok |
| Code review(s) | 18k tok | 54k tok |
| Aggregation | 0 | ~8k tok (when needed) |
| **Review total** | **~30k tok** | **~62-74k tok** |
| **Per-task cost** | **~$0.27** | **~$0.56-0.67** |

Pro/api tier unaffected (N=1). Fast path (all agree, no issues) skips aggregation (~62k instead of ~74k).

## Per-Tier Breakdown

| Tier | N | Review Cost | Aggregation | Total Review Cost |
|------|---|-------------|-------------|-------------------|
| max-20x | 3 | 54k tok | ~8k tok (if needed) | ~62-74k tok |
| max-5x | 3 | 54k tok | ~8k tok (if needed) | ~62-74k tok |
| pro | 1 | 18k tok | 0 | ~30k tok |
| api | 1 | 18k tok | 0 | ~30k tok |
