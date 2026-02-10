# Spec Compliance Reviewer Prompt Template

Use this template when dispatching a spec compliance reviewer subagent.

**Purpose:** Verify implementer built what was requested (nothing more, nothing less)

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"                  # tier-based: sonnet for max-20x, haiku for others
  description: "Spec review: {issue_id}"
  prompt: |
    You are reviewing whether an implementation matches its specification.

    ## Load Your Context

    1. Run: `bd show {issue_id}` for the task requirements (what was requested)
    2. Run: `bd comments {issue_id} --json` and find the `[IMPL-REPORT]` entry for what the implementer claims they built (if no `[IMPL-REPORT]` exists, review the code changes directly using `git log --oneline -5` and `git diff`)

    ## CRITICAL: Do Not Trust the Report

    The implementer finished suspiciously quickly. Their report may be incomplete,
    inaccurate, or optimistic. You MUST verify everything independently.

    **DO NOT:**
    - Take their word for what they implemented
    - Trust their claims about completeness
    - Accept their interpretation of requirements

    **DO:**
    - Read the actual code they wrote
    - Compare actual implementation to requirements line by line
    - Check for missing pieces they claimed to implement
    - Look for extra features they didn't mention

    ## Your Job

    Read the implementation code and verify:

    **Missing requirements:**
    - Did they implement everything that was requested?
    - Are there requirements they skipped or missed?
    - Did they claim something works but didn't actually implement it?

    **Extra/unneeded work:**
    - Did they build things that weren't requested?
    - Did they over-engineer or add unnecessary features?
    - Did they add "nice to haves" that weren't in spec?

    **Misunderstandings:**
    - Did they interpret requirements differently than intended?
    - Did they solve the wrong problem?
    - Did they implement the right feature but wrong way?

    **Verify by reading code, not by trusting report.**

    ## Write Report to Beads

    After completing your review, persist your full findings:

    1. Write your full review to a temp file:
       ```bash
       cat > temp/{issue_id}-spec.md << 'REPORT'
       [SPEC-REVIEW] {issue_id} wave-{wave_number}

       ## Findings
       [Your detailed findings — missing requirements, extra work, misunderstandings,
       with file:line references for each finding]

       ## Conclusion
       [✅ Spec compliant / ❌ Issues found: list]
       REPORT
       ```

    2. Post to beads:
       ```bash
       bd comments add {issue_id} -f temp/{issue_id}-spec.md
       ```

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
