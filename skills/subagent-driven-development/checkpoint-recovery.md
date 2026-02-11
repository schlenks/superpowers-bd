# Checkpoint & Recovery

## Checkpoint Schema

Written to `temp/sdd-checkpoint-{epic_id}.json` after each wave CLOSE phase:

```json
{
  "epic_id": "hub-abc",
  "wave_completed": 3,
  "budget_tier": "max-5x",
  "wave_receipts": [
    "Wave 1: 2 tasks closed (hub-abc.1, hub-abc.2), 168k tokens, ~$1.52. Conventions: uuid-v4, camelCase.",
    "Wave 2: 1 task closed (hub-abc.3), 62k tokens, ~$0.56. No new conventions.",
    "Wave 3: 2 tasks closed (hub-abc.4, hub-abc.5), 95k tokens, ~$0.86. Conventions: error boundaries."
  ],
  "closed_issues": ["hub-abc.1", "hub-abc.2", "hub-abc.3", "hub-abc.4", "hub-abc.5"],
  "epic_tokens": 325000,
  "epic_tool_uses": 412,
  "epic_cost": 2.94,
  "timestamp": "2026-02-11T14:32:00Z"
}
```

## Write Timing

Write checkpoint at the end of CLOSE phase, **after** wave summary is posted and temp report files cleaned (`rm -f temp/<epic-prefix>*`).

The `sdd-checkpoint-` prefix ensures the checkpoint file survives wave cleanup, which only removes `temp/<epic-prefix>*` files.

## Recovery Logic

When the orchestrator detects a checkpoint (via INIT check or `<sdd-checkpoint-recovery>` injection):

1. Read `temp/sdd-checkpoint-{epic_id}.json`
2. Restore: `budget_tier`, `wave_receipts`, `closed_issues`, running metrics (`epic_tokens`, `epic_tool_uses`, `epic_cost`)
3. Set `wave_number = wave_completed + 1`
4. Skip budget tier question (already stored)
5. Print: `"Resuming epic {epic_id} from wave {wave_number} after context recovery."`
6. Jump to LOADING phase

## Edge Cases

**Crashed session (startup with checkpoint):** SessionStart hook detects checkpoint, injects recovery notice. User can resume with "execute epic {id}". INIT phase finds checkpoint and restores state.

**Corrupted/unreadable checkpoint:** Ignore checkpoint, fall back to beads as SSOT. Use `bd show` to determine completed vs remaining tasks. Re-ask budget tier. Print: `"Checkpoint corrupted — falling back to beads. Which budget tier?"`

**Partial wave (in_progress tasks exist):** After restoring from checkpoint, if `bd ready` shows no ready tasks but `bd show` lists in_progress tasks, those are from an interrupted wave. Reset them: `bd update --status=open <id>` for each in_progress task, then proceed to LOADING.

**Stale checkpoint (different epic):** If the user says "execute epic {Y}" but checkpoint is for epic {X}, ignore the checkpoint. Only use a checkpoint whose `epic_id` matches the requested epic.

**Multiple checkpoints:** If multiple `sdd-checkpoint-*.json` files exist, the hook injects recovery for the most recent one (by mtime). The INIT phase only loads the one matching the requested epic.
