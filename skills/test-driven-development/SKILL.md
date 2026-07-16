---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
effort: medium
---

# Test-Driven Development

For production behavior changes, establish a failing test before implementation.
Watching the test fail proves that it detects the missing or broken behavior.

## Iron Law

```text
NO PRODUCTION BEHAVIOR CODE WITHOUT A FAILING TEST FIRST
```

If implementation code was written first and no bounded exception was selected
and documented before that work, discard it and restart from the test. Do not
keep it as reference or adapt it into the test-first implementation.

## Default Path

Use RED-GREEN-REFACTOR for features, bug fixes, refactoring, and other observable
behavior changes:

1. **RED:** Write one focused test and run it. Confirm it fails for the expected
   reason rather than a typo or broken fixture.
2. **GREEN:** Implement the smallest behavior that makes the test pass. Run the
   focused test and relevant surrounding suite.
3. **REFACTOR:** Improve structure without adding behavior. Keep tests green.

After REFACTOR, if more than 50 lines changed or complexity exceeds the local
threshold, use an available simplifier on the changed files. Re-run the focused
test and surrounding suite; keep simplifier changes only while evidence remains
green. Follow the current git authority—this step does not independently
authorize a commit.

For multi-step work, track these phases with native progress. In Claude Code,
create all tasks first and use `TaskUpdate(addBlockedBy=[...])` to record the
RED → GREEN → REFACTOR order. In Codex, preserve the same order with
`update_plan`.

## Bounded Exceptions

An agent may select an exception without blocking on a human only for:

- documentation-only changes,
- declarative configuration with no practical executable unit boundary,
- generated code where the generator is the maintained source,
- throwaway prototypes explicitly not intended for production.

Do not use an exception when repository instructions or the user explicitly
require test-first work, or when authentication, security, payments, migrations,
data integrity, or user-visible behavior changes.

Every exception requires a **verification receipt** in the work report:

```text
TDD_EXCEPTION: <category>
REASON: <why a failing test would not provide useful signal>
ALTERNATIVE_VERIFICATION: <exact command or inspection>
RESULT: <exit code and concise evidence>
```

If no suitable alternative verification exists, use the default TDD path or ask
the user.

## Test Quality

- Test one behavior at a time.
- Use a name that describes the expected behavior.
- Prefer real code; mock boundaries only when unavoidable.
- Cover important errors and edge cases.
- Keep output clean and run the relevant surrounding tests after GREEN and
  REFACTOR.

## Reference Files

- `references/good-vs-bad-examples.md`: Load when shaping a focused RED/GREEN example
- `references/why-order-matters.md`: Load when deciding whether test-first provides signal
- `references/rationalizations-and-red-flags.md`: Load when behavior work is being exempted without evidence
- `references/bug-fix-workflow.md`: Load for TDD combined with root-cause debugging
- `references/when-stuck.md`: Load when RED or GREEN cannot progress
- `references/testing-anti-patterns.md`: Load when adding mocks or test-only production APIs
- `references/tdd-cycle-diagram.dot`: Optional visual of the cycle
