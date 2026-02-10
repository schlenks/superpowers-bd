---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always:** New features, bug fixes, refactoring, behavior changes.

**Exceptions (ask your human partner):** Throwaway prototypes, generated code, configuration files.

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

## Red-Green-Refactor (Task-Tracked)

For each TDD cycle, create three tracking tasks:

1. **RED: Write test for [feature]** -- Write one failing test. MUST run and see it fail before proceeding.
2. **GREEN: Implement [feature]** -- Write minimal code to pass the test. No extras. MUST run and see it pass. Blocked by RED.
3. **REFACTOR: Clean up [feature]** -- Remove duplication, improve names. Keep tests green. Blocked by GREEN.

**ENFORCEMENT:**
- GREEN is blocked until RED is completed (test must fail first)
- REFACTOR is blocked until GREEN is completed (code must pass first)
- Each task requires RUNNING the test command and capturing output
- Skipping the "WATCH it fail/pass" step is now visible in TaskList

## RED - Write Failing Test

Write one minimal test showing what should happen. One behavior, clear name, real code (no mocks unless unavoidable). See `references/good-vs-bad-examples.md` for Good/Bad code examples.

## Verify RED

**MANDATORY.** Run test, confirm it fails for expected reason (feature missing, not typos). Test passes? You're testing existing behavior -- fix test.

## GREEN - Minimal Code

Write simplest code to pass the test. Don't add features, refactor other code, or "improve" beyond the test. See `references/good-vs-bad-examples.md` for Good/Bad code examples.

## Verify GREEN

**MANDATORY.** Run test, confirm it passes and all other tests still pass. Output pristine (no errors, warnings). Test fails? Fix code, not test.

## REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers
- Reduce nesting depth (flatten conditionals, use early returns)
- Eliminate redundant abstractions (inline single-use wrappers)
- Prefer explicit over compact (readability > cleverness)

Keep tests green. Don't add behavior.

**Conditional simplification dispatch:** If this TDD cycle changed >50 lines OR any function has cyclomatic complexity >10, dispatch the `code-simplifier:code-simplifier` agent via Task tool on the changed files. After simplification: re-run tests, verify green, commit separately as `refactor: simplify [area]`. If tests fail, revert simplification.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One thing. "and" in name? Split it. | `test('validates email and domain and whitespace')` |
| **Clear** | Name describes behavior | `test('test1')` |
| **Shows intent** | Demonstrates desired API | Obscures what code should do |

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason (feature missing, not typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no errors, warnings)
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases and errors covered

Can't check all boxes? You skipped TDD. Start over.

## Reference Files

| File | When to read |
|------|-------------|
| `references/tdd-cycle-diagram.dot` | Visualizing the TDD cycle |
| `references/good-vs-bad-examples.md` | RED/GREEN code examples showing good vs bad tests and implementations |
| `references/why-order-matters.md` | Rationale for test-first approach and rebuttals to common objections |
| `references/rationalizations-and-red-flags.md` | Common excuses and stop signals for TDD violations |
| `references/bug-fix-workflow.md` | Bug fix example and debugging integration |
| `references/when-stuck.md` | Solutions for common TDD obstacles |
| `references/testing-anti-patterns.md` | Pitfalls with mocks, test-only methods, dependency misunderstanding |

## Final Rule

```
Production code -> test exists and failed first
Otherwise -> not TDD
```

No exceptions without your human partner's permission.
