---
name: rule-of-five-plans
description: Use when writing 50+ lines of plans, design docs, skill documents, or process documentation - apply 5 focused passes (Draft, Feasibility, Completeness, Risk, Optimality) to catch issues single-shot generation misses
effort: high
---

# Rule of Five — Plans

Each pass has ONE job. Re-read the entire artifact through that lens. See `references/pass-order-rationale.md` for order rationale.

## Quick Start

**Create native tasks for 5 passes with sequential dependencies:**

```
TaskCreate: "Pass 1: Draft"
  description: "Shape and structure. All sections sketched. Task list complete. Breadth over depth."
  activeForm: "Drafting"

TaskCreate: "Pass 2: Feasibility"
  description: "Can every step be executed? Dependencies available? Paths valid? Estimates realistic?"
  activeForm: "Checking feasibility"
  addBlockedBy: [draft-task-id]

TaskCreate: "Pass 3: Completeness"
  description: "Every requirement traced to a task? Gaps? Missing rollback? Missing error handling?"
  activeForm: "Checking completeness"
  addBlockedBy: [feasibility-task-id]

TaskCreate: "Pass 4: Risk"
  description: "What could go wrong? Migration risks? Data loss? Breaking changes? Parallel conflicts?"
  activeForm: "Assessing risk"
  addBlockedBy: [completeness-task-id]

TaskCreate: "Pass 5: Optimality"
  description: "Simplest approach? YAGNI? Could tasks be combined? Would you defend every task to a senior colleague?"
  activeForm: "Optimizing"
  addBlockedBy: [risk-task-id]
```

**ENFORCEMENT:**
- Each pass is blocked until the previous completes
- Cannot commit until all 5 tasks show `status: completed`
- TaskList shows your progress through the passes
- Skipping passes is visible - blocked tasks can't be marked in_progress

## Cross-Model Review (Codex)

**Check availability** (use `printenv` to avoid shell expansion permission prompts):

```bash
printenv CODEX_REVIEW_AVAILABLE
```

If empty or fails, **skip this section entirely.** If `1`, resolve the path:

```bash
printenv CODEX_INSTALL_PATH
```

Capture the output as `{RESOLVED_CODEX_PATH}`. Then dispatch:

~~~
Agent:
  run_in_background: true
  description: "Codex cross-model audit (plan)"
  prompt: |
    Run a Codex adversarial review of the current changes.

    ```bash
    node "{RESOLVED_CODEX_PATH}/scripts/codex-companion.mjs" adversarial-review --wait
    ```

    Persist the full output to a temp file (background agent messages may be truncated):
    ```bash
    mkdir -p temp
    tee temp/codex-audit-plan.md <<'CODEX_AUDIT_EOF'
    [full codex review output]
    CODEX_AUDIT_EOF
    ```

    Output the full review as your final message.
~~~

This runs concurrently with all 5 passes — zero blocking. Codex uses auto-detect scope: reviews uncommitted changes if working tree is dirty, or branch diff against default branch if clean (e.g., after SDD implementer commits).

**After pass 5 completes, wait for the Codex background agent to finish before presenting results.** Do NOT present pass 5 results until the Codex review has either completed or timed out. This is a synchronous gate — the rule-of-five skill does not have a monitor loop or late-delivery mechanism, so all output must be collected before the skill finishes.

- If Codex completed successfully: Read `temp/codex-audit-plan.md` (primary) or fall back to agent output. Present as "Cross-Model Audit (Codex)" section after pass 5 results.
- If Codex failed or timed out: append `_Codex cross-model audit was unavailable for this run._` after pass 5 results

```markdown
## Cross-Model Audit (Codex)

[Full Codex adversarial review output — verdict, findings, recommendations]
```

For each pass: re-read the full artifact, evaluate through that lens only, make changes, then mark task complete.

## Detection Triggers

Invoke when: >50 lines of plan/design doc/skill document written, implementation plans, architecture decisions, process documentation, or skill SKILL.md files.

For code, use `rule-of-five-code`. For tests, use `rule-of-five-tests`.

Skip for: Minor doc edits, trivial changes under 20 lines, README updates.

Announce: "Applying rule-of-five-plans to [artifact]. Starting 5-pass review."

## The 5 Passes

| Pass | Focus | Exit when... |
|------|-------|--------------|
| **Draft** | Shape and structure. All sections sketched, task list complete. | All major sections exist; task list complete |
| **Feasibility** | Can every step be executed? Deps available? Paths valid? Estimates realistic? | No infeasible steps; all references verified |
| **Completeness** | Every requirement traced to a task? Gaps? Missing rollback? | Every requirement maps to task(s) |
| **Risk** | What could go wrong? Migration, data loss, breaking changes, parallel conflicts? | Risks identified and mitigated |
| **Optimality** | Simplest approach? YAGNI? Could tasks be combined? | You'd defend every task to a senior colleague |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Multiple lenses in one pass | ONE lens per pass. Feasibility pass ignores optimality. |
| Checking for code bugs in plans | Plans don't have bugs — check feasibility and completeness instead. |
| Skipping Risk pass on "simple" plans | All 5 or none. Simple plans still have risks (wrong assumptions, missing deps). |
| Rushing through passes | Each pass: genuinely re-read the full artifact |
| Optimizing before checking completeness | Completeness before Optimality — don't simplify away requirements. |
| Not verifying file paths and commands | Feasibility pass: Glob for paths, verify commands exist. |

## Reference Files

- `references/pass-definitions.md`: Detailed pass definitions with checklists
- `references/pass-order-rationale.md`: Why this order for plans

<!-- compressed: 2026-02-11, original: 520 words, compressed: 520 words -->
