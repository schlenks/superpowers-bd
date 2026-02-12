# Aggregation Details

Full deduplication rules, severity voting nuances, strengths merging, and error handling.

## Deduplication Rules

Two findings are the same if they reference:
- Same file AND
- Lines within 5 of each other AND
- Same category of issue (e.g., both about error handling)

## Severity Voting

| Condition | Result |
|-----------|--------|
| All reviewers agree on severity | Keep that severity |
| Reviewers disagree | Use highest severity |
| **Lone finding** Critical or Important | **Keep original severity** (no downgrade) |
| **Lone finding** Minor | Downgrade to Suggestion |
| Lone finding BUT security or data-loss | **Keep original severity** (no downgrade) |

Severity levels: Critical > Important > Minor > Suggestion

Lone-finding downgrade: Only Minor -> Suggestion. Critical and Important are never downgraded -- a real bug found by one reviewer is still a real bug. Suggestion is the floor -- lone Suggestions stay at Suggestion.

## Strengths Merging

Union all strengths across reviewers. Deduplicate by meaning (same point in different words -> keep the clearer one).

## Verdict Rules

- "Ready to merge: Yes" -- only if zero Critical AND zero Important AND majority of reviewers approved
- "Ready to merge: With fixes" -- if only Minor/Suggestion issues remain after aggregation
- "Ready to merge: No" -- if any Critical or Important issues remain

## Malformed Reviewer Output

If a reviewer returns output that can't be parsed (no severity categories, no verdict), treat all its findings as Important and its verdict as "No". The aggregator should still process what it can extract.

## Reviewer Timeout/Crash Recovery

If one reviewer fails and the others succeed, aggregate with the available results (N-1). The lone-finding threshold adjusts to the actual number of successful reviews. If <2 reviewers succeed, fall back to the single successful review or retry per SDD's "Reviewer Agent Failure" recovery.
