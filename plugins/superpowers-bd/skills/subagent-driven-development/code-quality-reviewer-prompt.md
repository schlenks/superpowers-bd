# Code Quality Reviewer Prompt Template

Only dispatch after spec compliance review passes.

Before dispatching, resolve paths once per wave:
```
code_reviewer_path          = Glob("**/requesting-code-review/code-reviewer.md")[0]
rule_of_five_code_path      = Glob("**/rule-of-five-code/SKILL.md")[0]
rule_of_five_tests_path     = Glob("**/rule-of-five-tests/SKILL.md")[0]
```
Pass absolute paths as `{code_reviewer_path}`, `{rule_of_five_code_path}`, `{rule_of_five_tests_path}` to all dispatches in the wave.

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

The sub-agent reads `code-reviewer.md` from disk (self-read pattern) instead of receiving it inline. The orchestrator resolves the path once per wave. Placeholder values (`{BASE_SHA}`, `{HEAD_SHA}`, `{PLAN_OR_REQUIREMENTS}`) are provided in the dispatch prompt.

**See:** `skills/requesting-code-review/code-reviewer.md` for the full methodology (7-step procedure, precision gate, evidence protocol, severity levels, verdict constraint).

**Append to the prompt:**
```
## Write Report to Beads

After completing your review, persist your full report.

**Each step below MUST be a separate tool call. Never combine into one Bash command.**

1. Use the **Write** tool to create `temp/{issue_id}-code-{reviewer_number}.md` with content:
   ```
   [CODE-REVIEW-{reviewer_number}/{n_reviews}] {issue_id} wave-{wave_number}

   [Full structured report — Changed Files Manifest, Requirement Mapping,
   Uncovered Paths, Not Checked, Findings, Assessment]
   ```

2. Bash: `bd comments add {issue_id} -f temp/{issue_id}-code-{reviewer_number}.md`
3. Bash: `bd comments {issue_id} --json`
4. If `bd comments add` fails, retry up to 3 times with `sleep 2` between attempts.

## Verdict (Final Message)

CRITICAL: Your final message must contain ONLY this structured verdict. No preamble, no narrative, no explanation of your review process.

    VERDICT: APPROVE|REJECT|WITH_FIXES
    CRITICAL: <n> IMPORTANT: <n> MINOR: <n>
    REPORT_PERSISTED: YES|NO
```

**Architecture checks (append to reviewer prompt alongside the beads report block):**
```
In addition to standard code quality concerns, verify:
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this change create new files that are already large, or significantly grow existing files?
  (Don't flag pre-existing file sizes — focus on what this change contributed.)
```

**Rule-of-five skill application (append to reviewer prompt):**
```
For files with >50 lines changed in this diff:
- If the changes are to application code (not tests): Read {rule_of_five_code_path} and apply the 5-pass code quality review.
- If the changes are to test files: Read {rule_of_five_tests_path} and apply the 5-pass test quality review.

Apply the skill's review criteria to your findings. Elevated standards for large changes ensure quality at scale.
```

**Multi-review mode (N>1):** Each reviewer dispatched independently with reviewer number suffix. Each persists own report. Reviews aggregated afterward via `superpowers-bd:multi-review-aggregation`.

<!-- compressed: 2026-02-11, original: 460 words, compressed: 327 words -->
