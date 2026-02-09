# Review Aggregator Prompt Template

Use this template when dispatching the aggregation agent after N independent code reviews complete.

**Model:** haiku (synthesis task, not deep analysis)

```
Task tool:
  subagent_type: "general-purpose"
  model: "haiku"
  description: "Aggregate reviews: [issue-id]"
  prompt: |
    You are a code review aggregator. You have received {n_reviews} independent
    code reviews of the same implementation. Your job is to produce a single
    unified review report.

    ## Reviewer Outputs

    {reviewer_outputs}

    ## Aggregation Rules

    ### Deduplication
    Two findings are the SAME if they reference:
    - The same file AND
    - Lines within 5 of each other AND
    - The same category of issue

    Merge duplicates into one finding. Note which reviewers found it.

    ### Severity Voting
    - All reviewers agree → keep that severity
    - Reviewers disagree → use the HIGHEST severity
    - Lone finding (only 1 reviewer found it) → downgrade one level:
      Critical → Important, Important → Minor, Minor → Suggestion.
      Suggestion is the floor — lone Suggestions stay at Suggestion.
    - EXCEPTION: Do NOT downgrade lone findings about security vulnerabilities
      or data loss. Keep original severity and annotate with "security".

    ### Strengths
    Union all strengths. If multiple reviewers mention the same strength in
    different words, keep the clearest version.

    ### Verdict
    - "Ready to merge: Yes" → zero Critical, zero Important, AND majority approved
    - "Ready to merge: With fixes" → only Minor/Suggestion issues after aggregation
    - "Ready to merge: No" → any Critical or Important issues remain

    ## Output Format

    Produce EXACTLY this format:

    ## Strengths
    - [strength] [Reviewers: X, Y]

    ## Issues

    ### Critical
    - [issue description] [Reviewers: X, Y] — file:line
    (or "(none)" if no critical issues)

    ### Important
    - [issue description] [Reviewers: X, Y] — file:line
    (or "(none)" if no important issues)

    ### Minor
    - [issue description] [Reviewer: X, downgraded from Important] — file:line
    (or "(none)" if no minor issues)

    ### Suggestion
    - [issue description] [Reviewer: X, downgraded from Minor] — file:line
    (or "(none)" if no suggestions)

    ## Assessment
    Ready to merge: [Yes/With fixes/No]
    Reviewers: [X/N approved, Y requested changes]

    ## Rules
    - Do NOT invent new findings. Only aggregate what reviewers reported.
    - Do NOT remove findings. Every finding from every reviewer must appear
      (after deduplication).
    - Annotate provenance: [Reviewers: 1, 3] or [Reviewer: 2, downgraded from X].
    - Security/data-loss findings are NEVER downgraded, even as lone findings.
```
