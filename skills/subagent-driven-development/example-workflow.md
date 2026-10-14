# Example Workflow (Parallel, Beads-Mediated Stateless Waves)

```
You: I'm using Subagent-Driven Development to execute beads epic hub-abc.

[Load epic: bd show hub-abc]
[Check for checkpoint: temp/sdd-checkpoint-hub-abc.json — not found]
[Budget tier: max-5x (no explicit tier, SDD_BUDGET_TIER unset → default; never asked)]

[bd ready: hub-abc.1, hub-abc.2 (no deps)]
[bd blocked: hub-abc.3 (by .1), hub-abc.4 (by .2, .3)]

[Query complexity distribution:]
  bd sql "SELECT label, COUNT(*) FROM labels WHERE issue_id LIKE 'hub-abc.%' AND label LIKE 'complexity:%' GROUP BY label"
  → complexity:simple=1, complexity:standard=2, complexity:complex=1

[Smart wave cap calculation:]
  avg_weight = (1×1 + 2×2 + 3×1) / 4 = 2.0
  context_tier = "extended" (1M-native model: [1m] suffix, or Sonnet 5 / Fable 5)
  BUDGET_PER_WAVE = 15, DEFAULT_CAP = 5
  recommended = min(floor(15/2.0), max_parallel=2, 10) = 2
  Recommended (2) ≤ DEFAULT_CAP (5) → skip question, use recommended
  wave_cap = 2

Wave 1: Tasks 1 and 2 are ready, no file conflicts
[Build wave_file_map table for hub-abc.1, hub-abc.2 → serialized into each prompt]

[bd update hub-abc.1 --status=in_progress]
[bd update hub-abc.2 --status=in_progress]
[Dispatch implementer for hub-abc.1 - ASYNC]
  prompt includes: issue_id=hub-abc.1, epic_id=hub-abc, file_ownership_list, dependency_ids, wave_number=1
  sub-agent self-reads: bd show hub-abc.1, bd show hub-abc, bd comments hub-abc --json
[Dispatch implementer for hub-abc.2 - ASYNC]
  (same pattern — sub-agent loads its own context from beads)

... both working in parallel ...
... each writes full report to beads: bd comments add hub-abc.2 -f temp/hub-abc.2-impl.md ...

[hub-abc.2 completes — returns 5-line verdict only]
Implementer 2 verdict:
  VERDICT: DONE
  COMMIT: f3a9b1c
  FILES: 2 changed (87+/0-)
  TESTS: 8/8 pass, exit 0
  SCOPE: CLEAN
  INTERFACES: none
  REPORT_PERSISTED: YES

[Dispatch spec reviewer for hub-abc.2]
  sub-agent self-reads: bd show hub-abc.2 (requirements), bd comments hub-abc.2 --json ([IMPL-REPORT])
Spec reviewer verdict:
  VERDICT: PASS
  ISSUES: 0 (none)
  REPORT_PERSISTED: YES

[Dispatch code quality reviewer for hub-abc.2 (×3)]
  each reviewer self-reads methodology from disk + requirements from beads, uses base_sha/head_sha from prompt
Code reviewer verdicts:
  VERDICT: APPROVE  CRITICAL: 0 IMPORTANT: 0 MINOR: 0  REPORT_PERSISTED: YES  (×3)
[Aggregate 3 reviews (always aggregate when N>1)]

[Extract evidence from verdict fields]
  Commit: f3a9b1c | Files: 2 changed (87+/0-) | Tests: 8/8 pass, exit 0
[Optional progress mirror: TaskCreate "Close evidence: hub-abc.2" → completed (Codex: update_plan)]
[bd close hub-abc.2 --reason "Commit: f3a9b1c | Files: 2 changed | Tests: 8/8 pass"]

[hub-abc.1 completes — returns verdict only]
Implementer 1 verdict:
  VERDICT: DONE
  COMMIT: a7e2d4f
  FILES: 2 changed (123+/0-)
  TESTS: 12/12 pass, exit 0
  SCOPE: CLEAN
  INTERFACES: none
  REPORT_PERSISTED: YES

[Spec review PASS. Code review (×3) + aggregation: 1 Important consensus finding, 2 Minor]
  F1 (Important): src/auth/token.ts:42 refresh skips expiry check
  Minor findings stay out of the loop → listed in the close reason

[Fix round 1, sent at once while the implementer's cache is warm]
  fix_round=1, fix_base_sha=a7e2d4f, checkpoint fix_loop updated
  SendMessage(to=<hub-abc.1 agentId>, message="Fix round 1 for hub-abc.1: F1 ...")
  (Codex: followup_task(<agent id>, ...), or send_input on V1)
Implementer 1 verdict (resumed, round 1):
  VERDICT: DONE
  COMMIT: b81c0d3
  FILES: 2 changed (9+/2-)
  TESTS: 13/13 pass, exit 0
  SCOPE: CLEAN
  INTERFACES: none
  REPORT_PERSISTED: YES
  (temp/hub-abc.1-impl.md gained "### Fix round 1"; commit message "fix: check expiry on refresh")

[Scoped re-review R1: one haiku reviewer, re-review-prompt.md, diff a7e2d4f..b81c0d3]
  F1: ADDRESSED — src/auth/token.ts:44
  NEW: none
  REPORT_PERSISTED: YES
  VERDICT: PASS
  (no second spec review, no ×3 code review, no aggregation)

[bd close hub-abc.1 --reason "Commit: b81c0d3 | Files: 2 changed | Tests: 13/13 pass | Fix rounds: 1 | Minor: 2 noted"]

[Post-wave simplification: 2 tasks in wave → dispatch code-simplifier]
[Tests pass → commit "refactor: post-wave simplification (wave 1)"]

[Post wave summary to beads with [WAVE-SUMMARY] tag]
bd comments add hub-abc "[WAVE-SUMMARY] Wave 1 complete:
- Closed: hub-abc.1, hub-abc.2
- Evidence: hub-abc.1 commit=b81c0d3, hub-abc.2 commit=f3a9b1c
- Fix rounds: hub-abc.1: 1 (R1 resume) → PASS
- Metrics: 168,500 known tokens | 46 known tool calls | longest agent 95s | 0 unavailable
- Conventions: uuid-v4 for IDs, camelCase for JSON fields
- Notes: JWT expiry 24h per Key Decisions"

[Cleanup temp files for this wave]

[Orchestrator retains only 2-line receipt:]
  Wave 1: 2 tasks closed (hub-abc.1, hub-abc.2), 168k known tokens, 0 metrics unavailable. Conventions: uuid-v4, camelCase.

[bd ready now shows hub-abc.3]

Wave 2: Only Task 3 is ready

[bd update hub-abc.3 --status=in_progress]
[Dispatch implementer for hub-abc.3]
  sub-agent self-reads from beads, finds [WAVE-SUMMARY] → knows uuid-v4, camelCase conventions

[hub-abc.3 completes → verdict → code review: 2 Important findings]
[Fix round 1: SendMessage to hub-abc.3's agentId fails (agent was stopped)]
  Fallback: fresh implementer with issue id hub-abc.3, "read the latest [IMPL-REPORT]
  in bd comments hub-abc.3 --json", and F1-F2. It is still round 1, not round 2.
  implementer_agent_id → the fallback agent (later rounds resume it)
[Fallback fixer returns DONE_WITH_CONCERNS: "F2 contradicts requirement 3 (IDs stay uuid-v4)"]
  [RULING] hub-abc.3: keep uuid-v4, drop F2 — why: requirement 3 and Key Decisions — cost if wrong: one-line ID change
  The dispute uses no round; re-review R1 checks F1 only → PASS → bd close
  (Had the ruling dropped every finding, there would be no re-review: route as passed.)
[Post [WAVE-SUMMARY] (Fix rounds: hub-abc.3: 1 (R1 fallback) → PASS; Rulings: hub-abc.3: keep uuid-v4) → cleanup temp → retain receipt]
  Wave 2: 1 task closed (hub-abc.3), 62k known tokens, 0 metrics unavailable. No new conventions.

Wave 3: Task 4 is ready

[Same pattern → verdict → reviews → close]
  Wave 3: 1 task closed (hub-abc.4), 81k known tokens, 1 metric unavailable. No new conventions.

[All issues closed]

[Epic Completion Report]
SDD-STATUS: COMPLETE
╔══════════════════════════════════════════════╗
║  Epic hub-abc complete                       ║
╠══════════════════════════════════════════════╣
║  Waves:    3                                 ║
║  Tasks:    4 (4 impl + 4 spec + 12 code + 0 agg) ║
║  Tokens:   312,400 known minimum             ║
║  Metrics:  1 result unavailable              ║
║  Duration: 4m 12s wall clock                 ║
╚══════════════════════════════════════════════╝
For model-aware cost analysis: analyze-token-usage.py <session>.jsonl

[Use superpowers-bd:finishing-a-development-branch]

Done!
```
