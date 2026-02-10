# Example Workflow (Parallel)

```
You: I'm using Subagent-Driven Development to execute beads epic hub-abc.

[Load epic: bd show hub-abc]
[Check initial state:]
  bd ready: hub-abc.1, hub-abc.2 (no deps)
  bd blocked: hub-abc.3 (by .1), hub-abc.4 (by .2, .3)

Wave 1: Tasks 1 and 2 are ready, no file conflicts
[Write .claude/file-locks.json for hub-abc.1, hub-abc.2]

[bd update hub-abc.1 --status=in_progress]
[bd update hub-abc.2 --status=in_progress]
[Dispatch implementer for hub-abc.1 - ASYNC]
[Dispatch implementer for hub-abc.2 - ASYNC]

... both working in parallel ...

[hub-abc.2 completes first]
Implementer 2:
  - Implemented JWT utils
  - Tests passing
  - Committed

[Dispatch spec reviewer for hub-abc.2]
Spec reviewer: ✅ Spec compliant

[Dispatch code quality reviewer for hub-abc.2]
Code reviewer: ✅ Approved

[Extract evidence from implementer report]
  Commit: f3a9b1c
  Files: jwt.utils.ts (+85), utils/index.ts (+2)
  Tests: 8/8 pass, exit 0
[TaskCreate "Close evidence: hub-abc.2" with evidence in description → completed]
[bd close hub-abc.2 --reason "Commit: f3a9b1c | Files: 2 changed | Tests: 8/8 pass"]

[Check bd ready: still nothing new - hub-abc.4 still blocked by hub-abc.3]

[hub-abc.1 completes]
Implementer 1:
  ### Evidence
  - Commit: a7e2d4f
  - Files changed: user.model.ts (+120), models/index.ts (+3)
  - Test command: npm test -- --grep "User"
  - Test results: 12/12 pass, exit 0

[Dispatch spec reviewer for hub-abc.1]
Spec reviewer: ✅ Spec compliant

[Dispatch code quality reviewer for hub-abc.1]
Code reviewer: ✅ Approved

[Extract evidence from implementer report]
[TaskCreate "Close evidence: hub-abc.1" with evidence in description → completed]
[bd close hub-abc.1 --reason "Commit: a7e2d4f | Files: 2 changed | Tests: 12/12 pass"]

[Post-wave simplification: 2 tasks in wave → dispatch code-simplifier]
[code-simplifier reviews user.model.ts, jwt.utils.ts, models/index.ts, utils/index.ts]
[Simplifier: aligned naming patterns across model/util files, no behavior changes]
[Tests pass → commit "refactor: post-wave simplification (wave 1)"]

[Post wave summary]
bd comments add hub-abc "Wave 1 complete:
- Closed: hub-abc.1 (User model), hub-abc.2 (JWT utils)
- Evidence:
  - hub-abc.1: commit=a7e2d4f, files=2 changed, tests=12/12 pass
  - hub-abc.2: commit=f3a9b1c, files=2 changed, tests=8/8 pass
- Simplification: applied (2 tasks) — aligned naming across model/util files
- Cost: 168,500 tokens (~$1.52) | 46 tool calls | 95s
  - hub-abc.1: impl=52,300/15/45s, spec=12,100, code=18,400×3+agg=7,800
  - hub-abc.2: impl=41,800/12/38s, spec=11,200, code=20,400×3+agg=8,100
  - simplify: 12,300/4/6s
- Running total: 168,500 tokens (~$1.52) across 1 wave
- Conventions: Using uuid v4 for IDs, camelCase for all JSON fields
- Notes: JWT expiry set to 24h per Key Decisions"

[bd ready now shows hub-abc.3 (unblocked - was blocked by .1)]
[bd blocked: hub-abc.4 (still waiting on .3)]

Wave 2: Only Task 3 is ready

[bd update hub-abc.3 --status=in_progress]
[Dispatch implementer for hub-abc.3]

[hub-abc.3 completes]
Implementer 3:
  - Implemented Auth service
  - Tests passing
  - Committed

[Review passes]
[Extract evidence + bd close hub-abc.3 --reason "Commit: c8d1e5a | Files: 1 changed | Tests: 5/5 pass"]

[bd ready now shows hub-abc.4 (unblocked - was blocked by .2, .3, both now closed)]

Wave 3: Task 4 is ready

[bd update hub-abc.4 --status=in_progress]
[Dispatch implementer for hub-abc.4]

[hub-abc.4 completes, reviews pass]
[Extract evidence + bd close hub-abc.4 --reason "Commit: 9b3f7a2 | Files: 3 changed | Tests: 15/15 pass"]

[All issues closed]

[Epic Completion Report]
╔══════════════════════════════════════════════╗
║  Epic hub-abc complete                       ║
╠══════════════════════════════════════════════╣
║  Waves:    3                                 ║
║  Tasks:    4 (4 impl + 4 spec + 12 code + 4 agg) ║
║  Tokens:   312,400 total                     ║
║  Cost:     ~$2.81 (blended $9/M)             ║
║  Duration: 4m 12s wall clock                 ║
╚══════════════════════════════════════════════╝
For precise cost breakdown: analyze-token-usage.py <session>.jsonl

[Cleanup: rm -f .claude/file-locks.json]

[Use superpowers:finishing-a-development-branch]

Done!
```

## Advantages

**vs. Sequential execution:**
- Multiple tasks execute simultaneously
- Completion of one task immediately unblocks dependents
- Better utilization of parallel capability

**vs. Manual parallelism:**
- File conflict detection prevents merge conflicts
- Dependency-aware (only dispatches ready tasks)
- Automatic unblocking as tasks complete

**Quality gates (unchanged):**
- Two-stage review: spec compliance, then code quality
- Review loops ensure fixes work
