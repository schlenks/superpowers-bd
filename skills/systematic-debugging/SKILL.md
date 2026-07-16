---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
effort: high
---

# Systematic Debugging

Find the cause before changing behavior. The amount of ceremony scales with the
uncertainty and risk, but a fix still needs evidence connecting it to the
observed failure.

## Triage

Choose the smallest investigation that can establish cause:

- **Quick trace:** Use for a localized, deterministic issue with direct evidence
  such as an exact syntax error, stale path, or one-line configuration mismatch.
  Reproduce or inspect the failing boundary, state the cause, apply the narrow
  fix, and verify the original symptom.
- **Full investigation:** Use for behavioral bugs, test failures, performance
  problems, intermittent failures, unclear ownership, cross-component effects,
  or any issue where the first hypothesis is not directly proven.
- **Escalate to full:** If a quick trace fails, the first fix does not work, or
  evidence conflicts, restart with all four phases.

Risk-sensitive areas such as authentication, security, payments, migrations, and
data loss always use the full investigation.

## Full Investigation

1. **Root Cause Investigation:** Read errors, reproduce, inspect recent changes,
   trace data and control flow, and gather boundary evidence.
2. **Pattern Analysis:** Find working examples and identify meaningful
   differences.
3. **Hypothesis and Testing:** Form one specific hypothesis and test it with the
   smallest diagnostic change.
4. **Implementation:** Add a failing regression test when behavior changes,
   implement the root-cause fix, and verify regressions.

For Claude Code, create each task first and then record dependencies:

```text
TaskCreate: "Phase 1: Root Cause Investigation"
TaskCreate: "Phase 2: Pattern Analysis"
TaskUpdate: phase-2-id
  addBlockedBy: [phase-1-id]
TaskCreate: "Phase 3: Hypothesis and Testing"
TaskUpdate: phase-3-id
  addBlockedBy: [phase-2-id]
TaskCreate: "Phase 4: Implementation"
TaskUpdate: phase-4-id
  addBlockedBy: [phase-3-id]
```

TaskList exposes the intended order. Mark a phase complete only when its success
criterion is met; the task state is an audit trail, not an independent technical
barrier.

## Success Criteria

| Phase | Exit when |
|-------|-----------|
| Root cause | You can explain what failed and why with evidence |
| Pattern | Relevant differences from working behavior are identified |
| Hypothesis | The hypothesis is confirmed or replaced by a better one |
| Implementation | Original symptom and relevant regression checks pass |

If three attempted fixes fail, stop changing symptoms and reassess the
architecture or assumptions.

## Reference Files

- `references/phase-1-investigation.md`: Load for full root-cause investigation
- `references/phase-2-pattern-analysis.md`: Load when comparing working and broken paths
- `references/phase-3-hypothesis-testing.md`: Load when designing a minimal experiment
- `references/phase-4-implementation.md`: Load when turning a confirmed cause into a fix
- `references/rationalizations.md`: Load when repeated guesses are replacing evidence
- `references/git-bisect.md`: Load for regressions with a useful commit range
- `references/root-cause-tracing.md`: Load for deep call stacks or distant symptoms
- `references/defense-in-depth.md`: Load after root cause when multiple boundaries need protection
- `references/condition-based-waiting.md`: Load for timing and polling failures
- `references/condition-based-waiting-example.ts`: TypeScript condition-wait example
- `references/find-polluter.sh`: Script for test pollution searches
- `references/tests/`: Pressure-test scenarios
