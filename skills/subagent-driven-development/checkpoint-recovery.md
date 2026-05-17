# Checkpoint & Recovery

## Checkpoint Schema

Written to `temp/sdd-checkpoint-{epic_id}.json` after each wave CLOSE phase:

```json
{
  "epic_id": "hub-abc",
  "wave_completed": 3,
  "budget_tier": "max-5x",
  "context_tier": "extended",
  "platform": "codex",
  "platform_agent_plan": {
    "implementer": "spawn_agent default worker with issue-owned files",
    "spec_review": "spawn_agent agent=spec_reviewer",
    "code_review": "spawn_agent agent=code_reviewer",
    "review_aggregation": "spawn_agent agent=review_aggregator when N > 1",
    "epic_verification": "spawn_agent agent=epic_verifier"
  },
  "codex_enabled": false,
  "wave_cap": 5,
  "wave_receipts": [
    "Wave 1: 2 tasks closed (hub-abc.1, hub-abc.2), 168k tokens, ~$1.52. Conventions: uuid-v4, camelCase.",
    "Wave 2: 1 task closed (hub-abc.3), 62k tokens, ~$0.56. No new conventions.",
    "Wave 3: 2 tasks closed (hub-abc.4, hub-abc.5), 95k tokens, ~$0.86. Conventions: error boundaries."
  ],
  "closed_issues": ["hub-abc.1", "hub-abc.2", "hub-abc.3", "hub-abc.4", "hub-abc.5"],
  "escalated_tasks": {
    "hub-abc.4": "BLOCKED: requires database migration strategy not in plan",
    "hub-abc.7": "NEEDS_CONTEXT: 3 re-dispatches exhausted, unclear auth pattern"
  },
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
2. Restore: `budget_tier`, `context_tier`, `platform`, `platform_agent_plan`, `wave_cap`, `wave_receipts`, `closed_issues`, running metrics (`epic_tokens`, `epic_tool_uses`, `epic_cost`). If `wave_cap` is absent (old checkpoint), default to 3. If `context_tier` is absent, default to "standard" (200k behavior — safe fallback). If `platform` is absent, infer the current session platform and write it at the next checkpoint. If `platform_agent_plan` is absent, rebuild it from the active platform dispatch path.
3. Restore `escalated_tasks` (default `{}` if absent in old checkpoint) — these need human resolution before dispatch. Skip them during LOADING filter (treat as not-ready even if `bd ready` lists them).
4. Set `wave_number = wave_completed + 1`
5. Restore Claude-only Codex advisory fields only when `platform` is `claude-code`. In Codex sessions, ignore stale `codex_enabled`/`codex_install_path`; native Codex is the orchestrator, not an external advisory reviewer.
6. Skip budget tier, platform, platform agent plan, context tier, and wave cap questions (already stored or restored).
7. Print: `"Resuming epic {epic_id} from wave {wave_number} after context recovery."`
8. Jump to LOADING phase

## Edge Cases

**Crashed session (startup with checkpoint):** SessionStart hook detects checkpoint, injects recovery notice. User can resume with "execute epic {id}". INIT phase finds checkpoint and restores state.

**Corrupted/unreadable checkpoint:** Ignore checkpoint, fall back to beads as SSOT. Use `bd show` to determine completed vs remaining tasks. Re-ask budget tier. Re-detect context tier. Run smart wave cap recommendation (or use context-tier default if bd sql fails). Print: `"Checkpoint corrupted — falling back to beads. Which budget tier?"`

**Legacy checkpoint without platform fields:** Infer `platform` from the current session and rebuild `platform_agent_plan` from the native dispatch path. Continue with restored budget/context/wave settings and persist the platform fields at the next checkpoint write.

**Stale Claude-only advisory fields in Codex:** Ignore `codex_enabled` and `codex_install_path` when the current platform is Codex. Those fields only mean Claude Code has a separate Codex advisory integration available.

**Partial wave (in_progress tasks exist):** After restoring from checkpoint, if `bd ready` shows no ready tasks but `bd show` lists in_progress tasks, those are from an interrupted wave. Reset them: `bd update --status=open <id>` for each in_progress task, then proceed to LOADING.

**Stale checkpoint (different epic):** If the user says "execute epic {Y}" but checkpoint is for epic {X}, ignore the checkpoint. Only use a checkpoint whose `epic_id` matches the requested epic.

**Multiple checkpoints:** If multiple `sdd-checkpoint-*.json` files exist, the hook injects recovery for the most recent one (by mtime). The INIT phase only loads the one matching the requested epic.
