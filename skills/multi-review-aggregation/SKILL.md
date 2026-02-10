---
name: multi-review-aggregation
description: Use when dispatching code reviews for tiers with N greater than 1 (max-20x, max-5x) in subagent-driven development, or manually for critical changes over 200 lines or security-sensitive code
---

# Multi-Review Aggregation

Dispatch N independent code reviews and aggregate findings for higher recall. Each reviewer catches different bugs — union preserves the long tail that single-shot misses.

**Research basis:** SWR-Bench (arXiv 2509.01494) — Self-Agg with N independent reviews achieves 43.67% F1 improvement and 118.83% recall improvement over single review. Diminishing returns past N=5; N=3 captures most improvement at practical cost.

**Core principle:** Independence via separate Task dispatches — same base prompt, no shared context between reviewers. Stochastic diversity from the model itself provides sufficient variation.

## N Selection by Tier

| Tier | N Reviews | Rationale |
|------|-----------|-----------|
| max-20x | 3 | Quality priority — full aggregation |
| max-5x | 3 | Balanced — same recall benefit |
| pro/api | 1 | Budget priority — unchanged single review |

When N=1, skip this skill entirely — use standard single code review dispatch.

## Parallel Dispatch Pattern

After spec review passes, dispatch N independent code reviews in parallel:

```python
if n_reviews > 1:
    # Dispatch N reviewers (run_in_background=True, each gets "Reviewer i of N")
    results = wait_for_all(reviewer_tasks)

    if all_approve_no_issues(results):   # Fast path — unanimous clean
        proceed_to_close(issue_id)
    else:
        dispatch_aggregator(results, issue_id)  # Uses haiku model
else:
    dispatch_single_code_review(issue_id)  # pro/api unchanged
```

Full dispatch code with `on_spec_review_pass` handler: see `references/dispatch-code.md`.
Aggregator prompt template: see `./aggregator-prompt.md`.

## Aggregation Algorithm

### Fast Path

If ALL N reviewers return `VERDICT: APPROVE` with `CRITICAL: 0` and `IMPORTANT: 0`, skip aggregation. The unanimous clean result IS the review output.

### Severity Voting (When Any Reviewer Raises Issues)

| Condition | Result |
|-----------|--------|
| All reviewers agree on severity | Keep that severity |
| Reviewers disagree | Use highest severity |
| **Lone finding** (found by only 1 of N) | Downgrade one level |
| Lone finding BUT security or data-loss | **Keep original severity** (no downgrade) |

Severity levels: Critical > Important > Minor > Suggestion

### Verdict

- "Ready to merge: Yes" — zero Critical AND zero Important AND majority approved
- "Ready to merge: With fixes" — only Minor/Suggestion issues after aggregation
- "Ready to merge: No" — any Critical or Important issues remain

Full deduplication rules, strengths merging, error handling: see `references/aggregation-details.md`.

## Output Format

```
## Strengths
- Clean error handling [Reviewers: 1, 2, 3]
- Well-structured tests [Reviewers: 1, 3]

## Issues

### Critical
(none)

### Important
- Missing input validation on parseConfig() [Reviewers: 2, 3] — src/config.ts:42
- Race condition in concurrent writes [Reviewer: 1, security] — src/store.ts:88

### Minor
- Magic number 30 should be named constant [Reviewer: 2, downgraded from Important] — src/retry.ts:15

### Suggestion
- Inconsistent error message format [Reviewer: 3, downgraded from Minor] — src/api.ts:67

## Assessment
Ready to merge: With fixes
Reviewers: 2/3 approved, 1 requested changes
```

Full provenance rules and format spec: see `references/output-provenance.md`.

## Integration

SDD uses this automatically in REVIEW state for tiers with N>1. For manual use on critical changes (>200 lines, security-sensitive, pre-merge to main), dispatch N=3 reviews following the parallel dispatch pattern above.

## Red Flags

**Never:**
- Share context between reviewers (defeats independence)
- Use N>1 for pro/api tier (budget constraint)
- Skip aggregation when reviewers disagree (even if 2/3 approve)
- Downgrade security findings even as lone findings

**Always:**
- Dispatch all N reviews in parallel (not sequential)
- Include reviewer number in each dispatch prompt
- Use haiku for aggregation (synthesis, not analysis)
- Record per-reviewer metrics separately

## Reference Files

| File | When to read |
|------|-------------|
| `references/dispatch-code.md` | Implementing the full dispatch flow with on_spec_review_pass handler |
| `references/aggregation-details.md` | Deduplication rules, strengths merging, malformed output, timeout recovery |
| `references/output-provenance.md` | Provenance annotation rules and full output format specification |
| `references/metrics-and-cost.md` | Per-reviewer metric keys, cost impact table, per-tier breakdown |
| `aggregator-prompt.md` | Aggregator Task dispatch prompt template (used by dispatch code) |
