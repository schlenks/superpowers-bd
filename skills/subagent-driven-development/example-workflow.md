# Example Workflow (Parallel, Beads-Mediated Stateless Waves)

```
You: I'm using Subagent-Driven Development to execute beads epic hub-abc.

[Load epic: bd show hub-abc]
[mkdir -p temp]  # Ensure temp dir for sub-agent reports
[Check initial state:]
  bd ready: hub-abc.1, hub-abc.2 (no deps)
  bd blocked: hub-abc.3 (by .1), hub-abc.4 (by .2, .3)

Wave 1: Tasks 1 and 2 are ready, no file conflicts
[Write .claude/file-locks.json for hub-abc.1, hub-abc.2]

[bd update hub-abc.1 --status=in_progress]
[bd update hub-abc.2 --status=in_progress]
[Dispatch implementer for hub-abc.1 - ASYNC]
  prompt includes: issue_id=hub-abc.1, epic_id=hub-abc, file_ownership_list, dependency_ids, wave_number=1
  sub-agent self-reads: bd show hub-abc.1, bd show hub-abc | head -30, bd comments hub-abc --json
[Dispatch implementer for hub-abc.2 - ASYNC]
  (same pattern — sub-agent loads its own context from beads)

... both working in parallel ...
... each writes full report to beads: bd comments add hub-abc.2 -f temp/hub-abc.2-impl.md ...

[hub-abc.2 completes — returns 5-line verdict only]
Implementer 2 verdict:
  VERDICT: PASS
  COMMIT: f3a9b1c
  FILES: 2 changed (87+/0-)
  TESTS: 8/8 pass, exit 0
  SCOPE: CLEAN
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
[Fast path: all approve, 0 Critical/Important → skip aggregation]

[Extract evidence from verdict fields]
  Commit: f3a9b1c | Files: 2 changed (87+/0-) | Tests: 8/8 pass, exit 0
[TaskCreate "Close evidence: hub-abc.2" → completed]
[bd close hub-abc.2 --reason "Commit: f3a9b1c | Files: 2 changed | Tests: 8/8 pass"]

[hub-abc.1 completes — returns verdict only]
Implementer 1 verdict:
  VERDICT: PASS
  COMMIT: a7e2d4f
  FILES: 2 changed (123+/0-)
  TESTS: 12/12 pass, exit 0
  SCOPE: CLEAN
  REPORT_PERSISTED: YES

[Reviews pass (same pattern — sub-agents self-read from beads)]
[bd close hub-abc.1 --reason "Commit: a7e2d4f | Files: 2 changed | Tests: 12/12 pass"]

[Post-wave simplification: 2 tasks in wave → dispatch code-simplifier]
[Tests pass → commit "refactor: post-wave simplification (wave 1)"]

[Post wave summary to beads with [WAVE-SUMMARY] tag]
bd comments add hub-abc "[WAVE-SUMMARY] Wave 1 complete:
- Closed: hub-abc.1, hub-abc.2
- Evidence: hub-abc.1 commit=a7e2d4f, hub-abc.2 commit=f3a9b1c
- Cost: 168,500 tokens (~$1.52) | 46 tool calls | 95s
- Conventions: uuid-v4 for IDs, camelCase for JSON fields
- Notes: JWT expiry 24h per Key Decisions"

[Cleanup temp files for this wave]

[Orchestrator retains only 2-line receipt:]
  Wave 1: 2 tasks closed (hub-abc.1, hub-abc.2), 168k tokens, ~$1.52. Conventions: uuid-v4, camelCase.

[bd ready now shows hub-abc.3]

Wave 2: Only Task 3 is ready

[bd update hub-abc.3 --status=in_progress]
[Dispatch implementer for hub-abc.3]
  sub-agent self-reads from beads, finds [WAVE-SUMMARY] → knows uuid-v4, camelCase conventions

[hub-abc.3 completes → verdict → reviews pass → bd close]
[Post [WAVE-SUMMARY] → cleanup temp → retain receipt]
  Wave 2: 1 task closed (hub-abc.3), 62k tokens, ~$0.56. No new conventions.

Wave 3: Task 4 is ready

[Same pattern → verdict → reviews → close]
  Wave 3: 1 task closed (hub-abc.4), 81k tokens, ~$0.73. No new conventions.

[All issues closed]

[Epic Completion Report]
╔══════════════════════════════════════════════╗
║  Epic hub-abc complete                       ║
╠══════════════════════════════════════════════╣
║  Waves:    3                                 ║
║  Tasks:    4 (4 impl + 4 spec + 12 code + 0 agg) ║
║  Tokens:   312,400 total                     ║
║  Cost:     ~$2.81 (blended $9/M)             ║
║  Duration: 4m 12s wall clock                 ║
╚══════════════════════════════════════════════╝
For precise cost breakdown: analyze-token-usage.py <session>.jsonl

[Cleanup: rm -f .claude/file-locks.json]

[Use superpowers:finishing-a-development-branch]

Done!
```

