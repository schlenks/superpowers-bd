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
    "Wave 1: 2 tasks closed (hub-abc.1, hub-abc.2), 168k known tokens, 0 metrics unavailable. Conventions: uuid-v4, camelCase.",
    "Wave 2: 1 task closed (hub-abc.3), structured metrics unavailable. No new conventions.",
    "Wave 3: 2 tasks closed (hub-abc.4, hub-abc.5), 95k known tokens, 1 metric unavailable. Conventions: error boundaries."
  ],
  "closed_issues": ["hub-abc.1", "hub-abc.2", "hub-abc.3", "hub-abc.4", "hub-abc.5"],
  "escalated_tasks": {
    "hub-abc.4": "BLOCKED: requires database migration strategy not in plan",
    "hub-abc.7": "NEEDS_CONTEXT: 3 re-dispatches exhausted, unclear auth pattern"
  },
  "fix_loop": {
    "hub-abc.6": {
      "fix_round": 1,
      "fix_base_sha": "c41d9e2",
      "implementer_agent_id": "a3f0c2e9-impl-6",
      "base_sha": "9b07a11",
      "head_sha": "c41d9e2",
      "review_phase": "code",
      "fix_stage": "fixing",
      "open_findings": ["F1 (Important): src/auth/token.ts:42 refresh skips expiry check"]
    }
  },
  "epic_tokens": 325000,
  "epic_input_tokens": 214000,
  "epic_output_tokens": 111000,
  "epic_tool_uses": 412,
  "epic_metrics_unavailable": 2,
  "timestamp": "2026-02-11T14:32:00Z"
}
```

## Write Timing

Write checkpoint at the end of CLOSE phase, **after** the wave summary is posted
and the exact report files created for that wave are cleaned.

Also write it whenever the fix loop changes state (`background-execution.md`
Fix Rounds): after each fix message or fresh/fallback/round-3 dispatch, and
before each re-review dispatch. A compacted or restarted orchestrator then keeps
the round count and resumes the live agent. `fix_loop` holds one entry per task
in the loop:

- `fix_round` (1-3) and `fix_stage` (`fixing`, `awaiting_re_review`, `re_reviewed`);
- `fix_base_sha` (the last reviewed commit, start of the fix diff), `head_sha`
  (latest commit for the task) and `base_sha` (the task's original
  implementation base);
- `review_phase` (`spec`, `code` or `verify`) and `open_findings` (F1..Fn);
- `implementer_agent_id`: the agent to resume, rewritten after every fallback or
  round-3 replacement so it never names a dead agent.

Remove a task's entry when it closes or is adjudicated.

The checkpoint path is not part of the exact per-wave report-file cleanup list.

## Recovery Logic

When the orchestrator detects a checkpoint (via INIT check or `<sdd-checkpoint-recovery>` injection):

1. Read `temp/sdd-checkpoint-{epic_id}.json`
2. Restore: `budget_tier`, `context_tier`, `platform`, `platform_agent_plan`, `wave_cap`, `wave_receipts`, `closed_issues`, and running measured metrics (`epic_tokens`, `epic_input_tokens`, `epic_output_tokens`, `epic_tool_uses`, `epic_metrics_unavailable`). For older checkpoints, default missing metric fields to 0 and ignore the retired `epic_cost` estimate. If `wave_cap` is absent, default to 3. If `context_tier` is absent, default to "standard" (200k behavior — safe fallback). If `platform` is absent, infer the current session platform and write it at the next checkpoint. If `platform_agent_plan` is absent, rebuild it from the active platform dispatch path.
3. Rebuild pending escalations from bd: open question beads are `bd list --label human --parent {epic_id} --status open`. bd is the record; the checkpoint's `escalated_tasks` is only a cache (default `{}` if absent in old checkpoints). Work items blocked by an open question bead are not in `bd ready`. Question beads are never dispatched: they are the human's inbox, and LOADING uses `bd ready --exclude-label human`. Find answered questions from bd, not the cache (the corrupted-checkpoint path has none): for each `bd list --label human --parent {epic_id} --status closed` bead, get its work item with `bd dep list <question-bead> --direction=up`; if that work item is still open, read the answer (the close reason in `bd show <question-bead>` and `bd comments <question-bead>`) and pass it into the work item's next dispatch prompt (`rulings-and-escalation.md` Escalation Format). Re-read `[RULING]` comments with `bd comments {epic_id} --json` so later dispatch prompts still carry them.
4. Restore `fix_loop` (default `{}`). An in_progress task with an entry is not reset to open; restore its pending gate without incrementing `fix_round`:
   - `fixing`: if a commit for the task exists past `fix_base_sha` and `temp/{issue_id}-impl.md` (or its `[IMPL-REPORT]` comment) has `### Fix round R`, the fix landed: set `head_sha` to that commit and go to re-review. Otherwise re-send the current round with `send_round` (resume `implementer_agent_id`: `SendMessage` in Claude Code, `followup_task`/`send_input` in Codex; fresh fallback if it can't be messaged).
   - `awaiting_re_review`: dispatch the re-review for `fix_base_sha..head_sha` with `open_findings`.
   - `re_reviewed`: read the latest `[RE-REVIEW-R.n]` comments in `bd comments <issue-id> --json` and route them (PASS, next round, or adjudication).
   Without an entry, the task is reset as in Edge Cases: Partial wave.
5. Set `wave_number = wave_completed + 1`
6. Restore Claude-only Codex advisory fields only when `platform` is `claude-code`. In Codex sessions, ignore stale `codex_enabled`/`codex_install_path`; native Codex is the orchestrator, not an external advisory reviewer.
7. Skip budget tier, platform, platform agent plan, context tier, and wave cap questions (already stored or restored).
8. Print: `"Resuming epic {epic_id} from wave {wave_number} after context recovery."`
9. Jump to LOADING phase

## Edge Cases

**Crashed session (startup with checkpoint):** SessionStart hook detects checkpoint, injects recovery notice. User can resume with "execute epic {id}". INIT phase finds checkpoint and restores state.

**Corrupted/unreadable checkpoint:** Ignore checkpoint, fall back to beads as SSOT. Use `bd show` to determine completed vs remaining tasks and rebuild escalations as in Recovery Logic step 3. Resolve the budget tier without asking (`budget-and-wave-cap.md`). Re-detect context tier. Run smart wave cap recommendation (or use context-tier default if bd sql fails). Print: `"Checkpoint corrupted — falling back to beads (budget tier: {tier})."`

**Legacy checkpoint without platform fields:** Infer `platform` from the current session and rebuild `platform_agent_plan` from the native dispatch path. Continue with restored budget/context/wave settings and persist the platform fields at the next checkpoint write.

**Stale Claude-only advisory fields in Codex:** Ignore `codex_enabled` and `codex_install_path` when the current platform is Codex. Those fields only mean Claude Code has a separate Codex advisory integration available.

**Partial wave (in_progress tasks exist):** After restoring from checkpoint, if `bd ready` shows no ready tasks but `bd show` lists in_progress tasks, those are from an interrupted wave. Reset them: `bd update --status=open <id>` for each in_progress task without a `fix_loop` entry (Recovery Logic step 4 covers the rest), then proceed to LOADING.

**Stale checkpoint (different epic):** If the user says "execute epic {Y}" but checkpoint is for epic {X}, ignore the checkpoint. Only use a checkpoint whose `epic_id` matches the requested epic.

**Multiple checkpoints:** If multiple `sdd-checkpoint-*.json` files exist, the hook injects recovery for the most recent one (by mtime). The INIT phase only loads the one matching the requested epic.
