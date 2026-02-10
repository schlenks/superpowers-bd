# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

Before dispatching code reviewers, resolve the path once per wave:
```
code_reviewer_path = Glob("**/requesting-code-review/code-reviewer.md")[0]
```
Pass the absolute path as `{code_reviewer_path}` to all code reviewer dispatches in the wave.

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"                  # tier-based: sonnet for max-20x, haiku for others
  description: "Code review: {issue_id}"
  prompt: |
    ## Load Review Methodology

    Read the code review methodology file using the Read tool:
    {code_reviewer_path}

    Follow every step in that file exactly.

    When following the methodology, use these values:
    - Where it says {BASE_SHA}: use {base_sha}
    - Where it says {HEAD_SHA}: use {head_sha}
    - Where it says {PLAN_OR_REQUIREMENTS}: run `bd show {issue_id}` for requirements
```

**Self-read pattern:** The sub-agent reads `code-reviewer.md` (119 lines) from disk instead of receiving it pasted into the prompt. The orchestrator resolves the path once per wave and passes it as `{code_reviewer_path}`. Placeholder values (`{BASE_SHA}`, `{HEAD_SHA}`, `{PLAN_OR_REQUIREMENTS}`) are provided in the dispatch prompt — the sub-agent reads the raw template and applies the provided values.

**See:** `skills/requesting-code-review/code-reviewer.md` for the full template with:
- 7-step procedural methodology (diff → read files → requirements → data flow → missing → tests → findings)
- Precision gate (no finding without violated requirement, concrete failing path, or missing test)
- Mandatory evidence protocol (changed files manifest, requirement mapping, uncovered paths, not checked)
- Severity levels: Critical > Important > Minor > Suggestion (Suggestion suppressed when real issues exist)
- Verdict constraint (Not Checked on core/security blocks "Yes")

**Code reviewer returns:** Changed Files Manifest, Requirement Mapping, Uncovered Paths, Not Checked, Findings (Critical/Important/Minor/Suggestion), Assessment (Ready to merge: Yes/No/With fixes)

**Write Report to Beads:** Append to the prompt:
```
## Write Report to Beads

After completing your review, persist your full report:

1. Write your full review to a temp file:
   ```bash
   cat > temp/{issue_id}-code-{reviewer_number}.md << 'REPORT'
   [CODE-REVIEW-{reviewer_number}/{n_reviews}] {issue_id} wave-{wave_number}

   [Your full structured review report — Changed Files Manifest, Requirement Mapping,
   Uncovered Paths, Not Checked, Findings, Assessment]
   REPORT
   ```

2. Post to beads:
   ```bash
   bd comments add {issue_id} -f temp/{issue_id}-code-{reviewer_number}.md
   ```

3. Verify: `bd comments {issue_id} --json | tail -1`

4. If `bd comments add` fails, retry up to 3 times with `sleep 2` between attempts.

## Verdict (Final Message)

CRITICAL: Your final message must contain ONLY this structured verdict. No preamble, no narrative, no explanation of your review process.

    VERDICT: APPROVE|REJECT|WITH_FIXES
    CRITICAL: <n> IMPORTANT: <n> MINOR: <n>
    REPORT_PERSISTED: YES|NO
```

**Multi-review mode (N>1):** For tiers with multi-review (max-20x, max-5x), each reviewer is dispatched independently with this same template plus a reviewer number suffix. Each reviewer persists their own report to beads. Reviews are aggregated afterward. See `superpowers:multi-review-aggregation` for the full algorithm.
