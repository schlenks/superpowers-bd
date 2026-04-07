---
name: epic-verifier
description: Use when all implementation tasks in an epic are closed, before calling finishing-a-development-branch
effort: high
---

# Epic Verifier

Dedicated verification agent for epic completion. Runs after all implementation tasks close, before finishing-a-development-branch. Builders build, verifiers verify -- separation prevents self-certification.

**REQUIRED BACKGROUND:** Read `superpowers-bd:verification-before-completion`, `superpowers-bd:rule-of-five-code`, and `superpowers-bd:rule-of-five-tests` SKILL.md files.

**Trigger:** All implementation tasks in epic show `status: closed`

**Do NOT use:** mid-epic (tasks still open), for single-task (use verification-before-completion), as substitute for per-task code review.

## Quick Reference

| Check | Question | Evidence Required |
|-------|----------|-------------------|
| **YAGNI** | Built only what requested? | List code not in plan |
| **Drift** | Matches spec? | Deviations with file:line |
| **Test Coverage** | Paths tested? | Untested functions |
| **Regressions** | All tests pass? | Test suite output |
| **Documentation** | Docs updated? | Outdated locations |
| **Security** | No vulnerabilities? | Concerns or "none" |
| **Rule-of-Five** | >50 line files reviewed? | Per-file 5-pass results |

## Dispatch

Use template at `./verifier-prompt.md`:

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"  # or "opus" for max-20x
  description: "Epic verification: {epic_id}"
  prompt: [use template]
```

Required context: `{epic_id}` (verifier self-reads from beads), base SHA, head SHA, test command.

## Model Selection

| Tier | Model | Rationale |
|------|-------|-----------|
| max-20x | opus | Catches subtle issues |
| max-5x | sonnet | Good quality/cost balance |
| pro/api | sonnet | Verification quality matters |

## Cross-Model Review (Codex)

**Check availability:** Look for `<codex-integration>` in the session context (injected by session-start hook). If absent, **skip this section entirely.**

If present, extract the install path from the tag. Dispatch Codex adversarial review of the full epic diff **in parallel with the verification agent** — include both in the same dispatch message:

~~~
Agent:
  run_in_background: true
  description: "Codex cross-model audit (epic)"
  prompt: |
    Run a Codex adversarial review of the full epic changes.

    ```bash
    node "{RESOLVED_CODEX_PATH}/scripts/codex-companion.mjs" adversarial-review --wait --base {base_sha}
    ```

    Persist the full output:
    ```bash
    mkdir -p temp
    AUDIT_TS=$(date +%Y%m%d-%H%M%S)
    tee temp/codex-audit-epic-${AUDIT_TS}.md <<'CODEX_AUDIT_EOF'
    [full codex review output]
    CODEX_AUDIT_EOF
    ```

    Output the full review as your final message.
~~~

**After the verification agent completes, wait for Codex before presenting results.** This is a synchronous gate — do not present the verification report until Codex has either completed or timed out.

- If Codex completed: Read persisted temp file (primary) or fall back to agent output. Present as "Cross-Model Audit (Codex)" section after the verification report.
- If Codex failed or timed out: append `_Codex cross-model audit was unavailable for this run._`

Codex is advisory-only — the verification PASS/FAIL verdict is determined solely by the engineering checklist.

## Integration

Mandatory gate: all impl tasks closed -> dispatch epic-verifier -> PASS -> finishing-a-development-branch / FAIL -> fix and re-verify.

## Red Flags - Verification Theater

| Claim Without Evidence | Reject Because |
|------------------------|----------------|
| "YAGNI passed" | Must list what was compared |
| "Tests pass" | Must show test output |
| "No security issues" | Must list what was checked |
| "Rule-of-five done" | Must show per-file findings |

**Evidence missing = reject verification.**

## Reference Files

- `references/edge-cases.md`: Unusual epic shapes (no artifacts, no tests, review-only)
- `references/common-failures.md`: Verification being skipped or rubber-stamped
- `references/example-output.md`: Output format reference for verification report
- `references/why-separation-matters.md`: Pushback on why dedicated verifier is needed

<!-- compressed: 2026-02-11, original: 519 words, compressed: 327 words -->
