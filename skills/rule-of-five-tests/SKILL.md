---
name: rule-of-five-tests
description: Use when writing 50+ lines of test code, adding test suites, or before claiming test work complete - apply 5 focused passes (Draft, Coverage, Independence, Speed, Maintainability) to catch issues single-shot generation misses
effort: high
---

# Rule of Five — Tests

Each pass has ONE job. Re-read the entire artifact through that lens. See `references/pass-order-rationale.md` for order rationale.

## Quick Start

**Create native tasks for 5 passes with sequential dependencies:**

```
TaskCreate: "Pass 1: Draft"
  description: "Shape and structure. Test organization mirrors source. All test cases exist."
  activeForm: "Drafting"

TaskCreate: "Pass 2: Coverage"
  description: "Significant code paths tested? Happy, error, boundary? Every public function covered?"
  activeForm: "Checking coverage"
  addBlockedBy: [draft-task-id]

TaskCreate: "Pass 3: Independence"
  description: "Each test runs alone? Shared state? Order dependence? Test coupling?"
  activeForm: "Checking independence"
  addBlockedBy: [coverage-task-id]

TaskCreate: "Pass 4: Speed"
  description: "Unnecessary waits? Heavy fixtures? Could mock I/O? Any test >1s unjustified?"
  activeForm: "Checking speed"
  addBlockedBy: [independence-task-id]

TaskCreate: "Pass 5: Maintainability"
  description: "Descriptive names? Clear intent? DRY helpers? A newcomer could add tests by following patterns?"
  activeForm: "Improving maintainability"
  addBlockedBy: [speed-task-id]
```

**ENFORCEMENT:**
- Each pass is blocked until the previous completes
- Cannot commit until all 5 tasks show `status: completed`
- TaskList shows your progress through the passes
- Skipping passes is visible - blocked tasks can't be marked in_progress

## Cross-Model Review (Codex)

**Skip if `CODEX_REVIEW_AVAILABLE` is not `1`.**

When creating pass 1 (Draft) task, also dispatch a background Codex adversarial review:

~~~
Agent:
  run_in_background: true
  description: "Codex cross-model audit (tests)"
  prompt: |
    Run a Codex adversarial review of the current changes.

    Check that `CODEX_REVIEW_AVAILABLE` environment variable equals "1".
    If not, output "Codex not available" and stop.

    Run the Codex adversarial review by calling the companion script directly via Bash:
    ```bash
    node "$CODEX_INSTALL_PATH/scripts/codex-companion.mjs" adversarial-review --wait
    ```

    Note: Slash commands (e.g. `/codex:adversarial-review`) are not available inside
    subagent prompts. Use the companion script directly with `$CODEX_INSTALL_PATH`.

    Persist the full output to a temp file (background agent messages may be truncated):
    ```bash
    mkdir -p temp
    tee temp/codex-audit-tests.md <<'CODEX_AUDIT_EOF'
    [full codex review output]
    CODEX_AUDIT_EOF
    ```

    Output the full review as your final message.
~~~

This runs concurrently with all 5 passes — zero blocking. Codex uses auto-detect scope: reviews uncommitted changes if working tree is dirty, or branch diff against default branch if clean (e.g., after SDD implementer commits).

**After pass 5 completes, wait for the Codex background agent to finish before presenting results.** Do NOT present pass 5 results until the Codex review has either completed or timed out. This is a synchronous gate — the rule-of-five skill does not have a monitor loop or late-delivery mechanism, so all output must be collected before the skill finishes.

- If Codex completed successfully: Read `temp/codex-audit-tests.md` (primary) or fall back to agent output. Present as "Cross-Model Audit (Codex)" section after pass 5 results.
- If Codex failed or timed out: append `_Codex cross-model audit was unavailable for this run._` after pass 5 results

```markdown
## Cross-Model Audit (Codex)

[Full Codex adversarial review output — verdict, findings, recommendations]
```

For each pass: re-read the full artifact, evaluate through that lens only, make changes, then mark task complete.

## Detection Triggers

Invoke when: >50 lines of test code written/modified, new test suites, comprehensive test refactoring, or about to claim test work "done".

For code, use `rule-of-five-code`. For plans/design docs, use `rule-of-five-plans`.

Skip for: Single test additions, trivial test fixes, changes under 20 lines.

Announce: "Applying rule-of-five-tests to [artifact]. Starting 5-pass review."

## The 5 Passes

| Pass | Focus | Exit when... |
|------|-------|--------------|
| **Draft** | Shape and structure. Test organization mirrors source. All test cases exist. | All test cases exist; structure follows source |
| **Coverage** | Significant code paths tested? Happy, error, boundary? | Every public function tested; error paths covered |
| **Independence** | Each test runs alone? Shared state? Order dependence? | Each test passes individually; no coupling |
| **Speed** | Unnecessary waits? Heavy fixtures? Could mock I/O? | No test >1s unjustified; no unnecessary I/O |
| **Maintainability** | Descriptive names? Clear intent? DRY helpers? | A newcomer could add tests by following patterns |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Multiple lenses in one pass | ONE lens per pass. Coverage pass ignores naming. |
| Checking for code bugs in tests | Tests don't have "bugs" in the traditional sense — check coverage and independence instead. |
| Skipping Independence pass | Shared state is the #1 cause of flaky tests. Always check. |
| Testing implementation details | Test behavior, not internal state. Mock at boundaries, not everywhere. |
| Speed pass removes useful tests | Speed pass optimizes execution, not coverage. Never remove tests to go faster. |
| Not running tests after each pass | Run the test suite after each pass to catch regressions in test code itself. |

## Reference Files

- `references/pass-definitions.md`: Detailed pass definitions with checklists
- `references/pass-order-rationale.md`: Why this order for tests

<!-- compressed: 2026-02-11, original: 510 words, compressed: 510 words -->
