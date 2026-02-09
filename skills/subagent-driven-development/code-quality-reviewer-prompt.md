# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"                  # tier-based: sonnet for max-20x, haiku for others
  description: "Code review: [issue-id]"
  prompt: |
    [Paste contents of skills/requesting-code-review/code-reviewer.md]

    Fill in placeholders:
    - {PLAN_OR_REQUIREMENTS}: Task N from [plan-file] or bd show output
    - {BASE_SHA}: [commit before task]
    - {HEAD_SHA}: [current commit]
```

**See:** `skills/requesting-code-review/code-reviewer.md` for the full template with:
- 7-step procedural methodology (diff → read files → requirements → data flow → missing → tests → findings)
- Precision gate (no finding without violated requirement, concrete failing path, or missing test)
- Mandatory evidence protocol (changed files manifest, requirement mapping, uncovered paths, not checked)
- Severity levels: Critical > Important > Minor > Suggestion (Suggestion suppressed when real issues exist)
- Verdict constraint (Not Checked on core/security blocks "Yes")

**Code reviewer returns:** Changed Files Manifest, Requirement Mapping, Uncovered Paths, Not Checked, Findings (Critical/Important/Minor/Suggestion), Assessment (Ready to merge: Yes/No/With fixes)

**Multi-review mode (N>1):** For tiers with multi-review (max-20x, max-5x), each reviewer is dispatched independently with this same template plus a reviewer number suffix. Reviews are aggregated afterward. See `superpowers:multi-review-aggregation` for the full algorithm.
