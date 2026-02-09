---
name: multi-review-aggregation
description: Use when dispatching code reviews for tiers with N>1 (max-20x, max-5x) in subagent-driven development, or manually for critical changes >200 lines or security-sensitive code
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

After spec review passes, dispatch N independent code reviews:

```python
on_spec_review_pass(issue_id, result):
    n_reviews = tier_n_reviews  # 3 for max-20x/max-5x, 1 for pro/api

    if n_reviews > 1:
        reviewer_tasks = []
        for i in range(n_reviews):
            task = Task(
                subagent_type="general-purpose",
                model=tier_code_model,
                run_in_background=True,
                description=f"Code review {i+1}/{n_reviews}: {issue_id}",
                prompt=code_reviewer_prompt + f"\nYou are Reviewer {i+1} of {n_reviews}. "
                    "Review independently — do not reference other reviewers."
            )
            reviewer_tasks.append(task)

        # Poll until all N complete
        results = wait_for_all(reviewer_tasks)

        # Check fast path
        if all_approve_no_issues(results):
            # Skip aggregation — unanimous clean approval
            record_metrics(results, role="code")
            proceed_to_close(issue_id)
        else:
            # Dispatch aggregator
            dispatch_aggregator(results, issue_id)
    else:
        # Single review (pro/api) — unchanged
        dispatch_single_code_review(issue_id)
```

## Aggregation Algorithm

### Fast Path

If ALL N reviewers report:
- "Ready to merge: Yes"
- Zero Critical issues
- Zero Important issues

Then skip the aggregation step. The unanimous clean result IS the review output.

### Full Aggregation (When Needed)

When any reviewer raises Critical/Important issues or disagrees on merge readiness:

**1. Deduplication**
Two findings are the same if they reference:
- Same file AND
- Lines within 5 of each other AND
- Same category of issue (e.g., both about error handling)

**2. Severity Voting**

| Condition | Result |
|-----------|--------|
| All reviewers agree on severity | Keep that severity |
| Reviewers disagree | Use highest severity |
| **Lone finding** (found by only 1 of N) | Downgrade one level |
| Lone finding BUT security or data-loss | **Keep original severity** (no downgrade) |

Severity levels: Critical > Important > Minor > Suggestion

Lone-finding downgrade: Critical → Important, Important → Minor, Minor → Suggestion. Suggestion is the floor — lone Suggestions stay at Suggestion.

**3. Strengths**
Union all strengths across reviewers. Deduplicate by meaning (same point in different words → keep the clearer one).

**4. Verdict**
- "Ready to merge: Yes" — only if zero Critical AND zero Important AND majority of reviewers approved
- "Ready to merge: With fixes" — if only Minor/Suggestion issues remain after aggregation
- "Ready to merge: No" — if any Critical or Important issues remain

### Aggregator Dispatch

```python
dispatch_aggregator(reviewer_results, task_id):
    combined_output = "\n---\n".join([
        f"## Reviewer {i+1} Output\n{result.output}"
        for i, result in enumerate(reviewer_results)
    ])

    aggregator = Task(
        subagent_type="general-purpose",
        model="haiku",  # Synthesis task, not deep analysis
        description=f"Aggregate reviews: {task_id}",
        prompt=aggregator_prompt.format(
            n_reviews=len(reviewer_results),
            reviewer_outputs=combined_output
        )
    )
```

Use the aggregator prompt template at `./aggregator-prompt.md`.

**Malformed reviewer output:** If a reviewer returns output that can't be parsed (no severity categories, no verdict), treat all its findings as Important and its verdict as "No". The aggregator should still process what it can extract.

**Reviewer timeout/crash:** If one reviewer fails and the others succeed, aggregate with the available results (N-1). The lone-finding threshold adjusts to the actual number of successful reviews. If <2 reviewers succeed, fall back to the single successful review or retry per SDD's "Reviewer Agent Failure" recovery.

## Output Format

The aggregated report follows the same structure as a single code review, with provenance annotations:

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

**Provenance rules:**
- `[Reviewers: 1, 2]` — found by multiple reviewers (no downgrade)
- `[Reviewer: 2, downgraded from Important]` — lone finding, shows original severity
- `[Reviewer: 1, security]` — lone finding, NOT downgraded (security/data-loss exemption)

## Metrics

Multi-review adds these metric keys:

```python
# Individual reviewers
task_metrics[f"{issue_id}.code.1"] = {...}  # Reviewer 1
task_metrics[f"{issue_id}.code.2"] = {...}  # Reviewer 2
task_metrics[f"{issue_id}.code.3"] = {...}  # Reviewer 3

# Aggregation step (if not fast-pathed)
task_metrics[f"{issue_id}.agg"] = {...}
```

## Cost Impact

| Component | Single (N=1) | Multi (N=3) |
|-----------|-------------|-------------|
| Spec review | 12k tok | 12k tok |
| Code review(s) | 18k tok | 54k tok |
| Aggregation | 0 | ~8k tok (when needed) |
| **Review total** | **~30k tok** | **~62-74k tok** |
| **Per-task cost** | **~$0.27** | **~$0.56-0.67** |

Pro/api tier unaffected (N=1). Fast path (all agree, no issues) skips aggregation (~62k instead of ~74k).

## Integration

**Subagent-Driven Development:** Automatically used in the REVIEW state for tiers with N>1. The SDD orchestrator dispatches N reviews, waits for all, then aggregates (or fast-paths).

**Manual use:** For critical changes outside SDD, dispatch N=3 reviews manually following the parallel dispatch pattern above. Useful for:
- Changes >200 lines
- Security-sensitive code
- Pre-merge to main
- Complex refactoring

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
