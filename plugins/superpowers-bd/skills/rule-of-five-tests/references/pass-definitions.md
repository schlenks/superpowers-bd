# Pass Definitions — Tests Variant

## Pass 1: Draft

**Focus:** Shape and structure. Test organization mirrors source.

**Checklist:**
- Test file structure mirrors source file structure
- All test cases exist (one per behavior, not per function)
- Describe blocks organized by feature/component
- Setup/teardown properly scoped
- Test names describe expected behavior, not implementation

**Exit when:** All test cases exist; structure follows source.

## Pass 2: Coverage & Falsifiability

**Focus:** Significant behaviors tested, and can each test fail for a named reason? See `../../test-driven-development/references/writing-good-tests.md`.

**Checklist:**
- Each test names the production change (a bug, not a decision) that would make it fail
- Expected values are hand-derived literals, not computed by the code under test or its helpers
- No change detectors (constant-equality, exact message wording), mirror assertions, or assertions on the mock itself
- Trivial code (no branching, validation, or side effect) has no test written only for coverage
- Happy path tested for each feature
- Error paths tested (invalid input, missing data, network failures)
- Boundary conditions tested (empty, one, many, max)
- Edge cases from implementation covered
- Integration points tested (API calls, database queries)

**Exit when:** Error paths covered; every test can fail for a named, intentional-bug reason.

## Pass 3: Independence

**Focus:** Each test runs alone?

**Checklist:**
- No shared mutable state between tests
- No order dependence (tests pass when run individually or shuffled)
- Each test has its own setup/teardown
- Database/filesystem state cleaned up after each test
- No test reads output from another test
- Parallel-safe (could run with `--parallel` flag)

**Exit when:** Each test passes individually; no coupling.

## Pass 4: Speed

**Focus:** Are tests fast enough?

**Checklist:**
- No test >1s without justification (integration tests excepted)
- No unnecessary `sleep`/`wait` calls
- Heavy fixtures shared where safe (read-only)
- Slow or external I/O (network) doubled at the lowest level; filesystem and in-process dependencies stay real unless slow
- Database transactions rolled back instead of drop/recreate
- No redundant setup (creating same data multiple times)

**Exit when:** No test >1s unjustified; no unnecessary I/O.

## Pass 5: Maintainability

**Focus:** Can a newcomer add tests by following patterns?

**Checklist:**
- Test names are descriptive ("should return 404 when user not found" not "test1")
- Intent is clear from reading the test (no hidden setup)
- DRY helpers for setup only (factory functions, fixtures); expected values stay literal in the test, never behind helpers
- No magic numbers without explanation
- Assertions use descriptive matchers (not just `toBe(true)`)
- Error messages help diagnose failures

**Exit when:** A newcomer could add tests by following patterns.
