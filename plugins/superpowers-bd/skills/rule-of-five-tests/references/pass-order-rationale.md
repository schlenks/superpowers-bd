# Pass Order Rationale — Tests Variant

## Why This Order

- **Draft before coverage** — Don't add coverage to poorly structured tests
- **Coverage before independence** — No point isolating tests that don't cover anything
- **Independence before speed** — Fix coupling before optimizing (coupling causes false speed wins)
- **Speed before maintainability** — Polish naming after structure is final

## Why Tests Need Different Passes Than Code

Code needs correctness checks and edge case handling. Tests need:
- **Coverage gaps** — missing paths that silently allow regressions
- **Independence violations** — shared state causing flaky tests
- **Speed problems** — slow suites that get skipped under pressure
- **Maintainability debt** — opaque tests that nobody updates

"Correctness" on tests is confusing — tests define correctness. "Edge Cases" on tests means coverage gaps. Test-specific passes name what matters directly.

## When Passes Find Issues from Earlier Passes

If Maintainability reveals a coverage gap (Coverage issue): add the test, then re-run Maintainability. Don't restart all passes — just fix and continue.
