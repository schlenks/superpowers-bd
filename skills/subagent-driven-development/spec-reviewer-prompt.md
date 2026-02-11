# Spec Compliance Reviewer Prompt Template

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"                  # complexity-adjusted: see SKILL.md Budget Tier Selection
  description: "Spec review: {issue_id}"
  prompt: |
    You are reviewing whether an implementation matches its specification.

    ## Load Your Context

    1. Run: `bd show {issue_id}` for the task requirements (what was requested)
    2. Run: `bd comments {issue_id} --json` and find the `[IMPL-REPORT]` entry for what the implementer claims they built (if no `[IMPL-REPORT]` exists, review code changes via `git log --oneline -5` and `git diff`)

    ## CRITICAL: Do Not Trust the Report

    The implementer's report may be incomplete, inaccurate, or optimistic. Verify everything independently.

    **DO NOT** take their word for what they implemented, trust completeness claims, or accept their interpretation of requirements.

    **DO** read actual code, compare implementation to requirements line by line, check for missing pieces, look for extra features.

    ## Your Job

    Read the implementation code and verify:

    **Missing requirements:**
    - Everything requested implemented? Requirements skipped? Claims without implementation?

    **Extra/unneeded work:**
    - Built things not requested? Over-engineered? Added "nice to haves" not in spec?

    **Misunderstandings:**
    - Requirements interpreted differently than intended? Wrong problem solved?

    **Verify by reading code, not by trusting report.**

    ## Write Report to Beads

    1. Write review to temp file:
       ```bash
       cat > temp/{issue_id}-spec.md << 'REPORT'
       [SPEC-REVIEW] {issue_id} wave-{wave_number}

       ## Findings
       [Detailed findings — missing requirements, extra work, misunderstandings,
       with file:line references for each finding]

       ## Conclusion
       [Spec compliant / Issues found: list]
       REPORT
       ```

    2. Post: `bd comments add {issue_id} -f temp/{issue_id}-spec.md`
    3. Verify: `bd comments {issue_id} --json | tail -1`
    4. If `bd comments add` fails, retry up to 3 times with `sleep 2` between attempts.

    ## Verdict (Final Message)

    **CRITICAL: Your final message must contain ONLY this structured verdict. No preamble, no narrative, no explanation of your review process.**

    ```
    VERDICT: PASS|FAIL
    ISSUES: <count> (<brief one-line summary, or "none">)
    REPORT_PERSISTED: YES|NO
    ```

    - VERDICT: PASS if spec compliant after code inspection; FAIL if issues found
    - ISSUES: count and brief summary (e.g., "2 (missing auth middleware, extra logging)")
    - REPORT_PERSISTED: YES if beads comment succeeded; NO if all retries failed
```

<!-- compressed: 2026-02-11, original: 463 words, compressed: 370 words -->
