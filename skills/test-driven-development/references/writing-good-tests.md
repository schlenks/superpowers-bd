# Writing Good Tests

**Load this reference when:** writing or changing tests, adding mocks, or
adding cleanup/helper methods for tests.

## Overview

A test exists to catch a specific break. Two principles govern everything
here:

```
1. Every test names the break it catches
2. Every test exercises the real thing
```

Strict TDD produces both naturally: a test written first and watched
failing against real code has already proven it can fail, and only earns
a mock when the real dependency proves slow or external.

## Principle 1: Name the Break

Before writing the test body, answer: **what production change should
make this test fail, and is that change a bug or a decision?** A test
earns its place by catching a wrong branch, missing side effect, wrong
argument, boundary case, or broken contract.

**Derive expectations independently.** Use literals and hand-checked
fixtures; table-driven tests with literal `want` values are the preferred
shape. An expectation computed by the code under test, or its helpers,
passes no matter what that code does:

```typescript
// ❌ Mirror assertion: the same builder computes both sides, always true
const expected = buildSearchQuery({ tag: 'urgent' });
expect(buildSearchQuery({ tag: 'urgent' })).toBe(expected);

// ✅ Hand-derived literal
expect(buildSearchQuery({ tag: 'urgent' })).toBe('tag:"urgent"');
```

**No change detectors.** If only intentional decisions can fail a test
(a constant's value, exact message wording, private structure) it fires
on redesign and sleeps through bugs. Test the behavior that depends on
the decision: not `expect(MAX_RETRIES).toBe(5)` but "a failing call is
retried 5 times and the 6th attempt never happens."

**Behavior, not text.** Asserting that prose contains an exact line proves
only that the source is the source. Run scripts against controlled inputs and
assert outputs, side effects, or exit codes. Documents that instruct agents
are tested by the consuming agent's behavior (superpowers-bd:writing-skills);
prose for humans earns no test at all.

**Lint carve-out.** Checking the executable parts of an instruction file is a
linter, not a behavior test, and is allowed: tool parameters and names,
commands that must parse or run, links and file paths that must resolve,
mirrored copies that must stay identical, frontmatter and schema validity.
If a rewording that keeps the instruction working would fail the assertion,
it is a change detector; if only a broken command, dead link, or drifted
mirror fails it, it is a lint. Test suites that pin invariants of instruction
files (for example `tests/verification/test-workflow-contract-audit.sh`:
required and forbidden instructions, retired files staying retired, mirrors)
are lints. Do not delete or rewrite them as "change detector" cleanup; prefer
adding behavior evals over removing them.

**Your code, not the framework.** Test the contract your code makes at
its boundaries: the route you register, the query you emit, the payload
you produce. Upstream mechanics are their maintainers' tests to write
(asserting your router invokes a registered handler is the framework's
test, not yours). When upstream behavior genuinely surprised you, write one
narrow characterization test naming the assumption. Constructors, getters,
constants, and trivial forwarding earn tests only when they validate,
normalize, default, derive, enforce, or cause side effects; otherwise assert
the first consumer-visible result that depends on them.

### Gate Function

```
BEFORE writing the test body:
  Name the production change that would make this test fail.

  Cannot name one            → redesign around an observable behavior
  "The source text changed"  → run the artifact and assert its effects
                               (linting commands/links/mirrors is fine)
  Only intentional decisions → change detector; test the behavior
                               that depends on the decision

  Expected value reuses the code's logic or helpers?
    Replace it with a literal or hand-checked fixture
```

## Principle 2: Exercise the Real Thing

**The mock earns no assertions.** A mock assertion passes when the mock
is present and fails when it is absent; it says nothing about the
component. Assert the real component's behavior. If the mock is what you
are checking, unmock it or delete the assertion.

```typescript
// ✅ Real behavior
expect(screen.getByRole('navigation')).toBeInTheDocument();

// ❌ Mock existence
expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
```

**Mock at the right level.** Learn every side effect of the real method
before replacing it; mock the slow or external operation and keep what
the test depends on real. When unsure, run the test against the real
implementation first and observe what actually needs to happen.

```typescript
// ❌ The mock swallows the config write that duplicate detection reads
vi.mock('ToolCatalog', () => ({
  discoverAndCacheTools: vi.fn().mockResolvedValue(undefined)
}));

// ✅ Mock only the slow server startup; the config write stays real
vi.mock('MCPServerManager');
```

**Make doubles specific.** When arguments, call counts, or ordering are
part of the contract, assert them; a fake that accepts anything verifies
nothing. Give each branch (success, error, malformed) its own fixture or
spy, so the wrong branch cannot satisfy the expectation.

**Mirror real data completely.** Mock the complete structure as it exists
in reality, all documented fields, not just the ones your test reads.
Partial mocks fail silently when downstream code reads an omitted field.

**Production classes carry production methods only.** Cleanup that only
tests need lives in test utilities, never as a `destroy()` on the
production class. If a method is called only from tests, or the class does
not own the resource's lifecycle, move it to a test utility.

**Prefer real components over complex mocks.** When mock setup outgrows
the test logic, mocks miss methods the real components have, or tests
break when the mock changes, switch to an integration test with real
components.

## Tests Ship With the Implementation

The TDD cycle (failing test, minimal implementation, refactor) is what
"complete" means. Ship the tests the behavior needs and only those: trivial
code (no branching, validation, or side effect) and human prose earn none,
and a test written to satisfy process costs maintenance forever. When
unsure, test it.

## Warning Signs

- Setup and assertion share the same object, guaranteeing equality
- The test can fail only through a panic, crash, or missing selector
- The test fails on every intentional change, never on accidental breakage
- Expected values are hidden behind loops, builders, or helpers
- The test greps prose wording, or asserts a removed symbol stays removed
  (unless a known recurring regression justifies it)
- The test would still matter if only the framework remained
- The test exists for coverage, checking no side effect or outcome
- An assertion checks a `*-mock` test ID, or fails if you remove the mock
- A method is called only from test files
- Mock setup is more than half the test, or you can't explain why the mock is needed
