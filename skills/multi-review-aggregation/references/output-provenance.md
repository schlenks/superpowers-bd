# Output Provenance Rules

Detailed provenance annotation rules and full format specification for aggregated review output.

## Provenance Annotations

Every finding in the aggregated report must include provenance showing which reviewers found it:

- `[Reviewers: 1, 2]` -- found by multiple reviewers (no downgrade)
- `[Reviewer: 2]` -- lone Critical or Important finding (never downgraded)
- `[Reviewer: 2, downgraded from Minor]` -- lone Minor finding, downgraded to Suggestion
- `[Reviewer: 1, security]` -- lone finding, NOT downgraded (security/data-loss exemption)

## Full Output Format Specification

The aggregated report follows the same structure as a single code review:

```
## Strengths
- [strength description] [Reviewers: X, Y]

## Issues

### Critical
- [issue description] [Reviewers: X, Y] -- file:line
(or "(none)" if no critical issues)

### Important
- [issue description] [Reviewers: X, Y] -- file:line
(or "(none)" if no important issues)

### Minor
- [issue description] [Reviewers: X, Y] -- file:line
(or "(none)" if no minor issues)

### Suggestion
- [issue description] [Reviewer: X, downgraded from Minor] -- file:line
(or "(none)" if no suggestions)

## Assessment
Ready to merge: [Yes/With fixes/No]
Reviewers: [X/N approved, Y requested changes]
```
