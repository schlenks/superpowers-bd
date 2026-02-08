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
    - {WHAT_WAS_IMPLEMENTED}: [from implementer's report]
    - {PLAN_OR_REQUIREMENTS}: Task N from [plan-file]
    - {DESCRIPTION}: [task summary]
    - {PLAN_REFERENCE}: [link to plan or bd show output]
    - {BASE_SHA}: [commit before task]
    - {HEAD_SHA}: [current commit]
```

**See:** `skills/requesting-code-review/code-reviewer.md` for the full template with:
- Detailed review checklist (Code Quality, Architecture, Testing, Requirements, Production Readiness)
- Output format with severity categories
- DO/DON'T rules
- Example output

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment (Ready to merge: Yes/No/With fixes)

**Multi-review mode (N>1):** For tiers with multi-review (max-20x, max-5x), each reviewer is dispatched independently with this same template plus a reviewer number suffix. Reviews are aggregated afterward. See `superpowers:multi-review-aggregation` for the full algorithm.
