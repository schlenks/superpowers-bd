# Implementer Subagent Prompt Template

```
Task tool:
  subagent_type: "general-purpose"
  model: "opus"                    # complexity-adjusted: see SKILL.md Budget Tier Selection
  run_in_background: true          # for parallelism
  description: "Implement Issue: [issue-id] [issue title]"
  prompt: |
    You are implementing beads issue: {issue_id}

    ## Load Your Context

    1. Run: `bd show {issue_id}` for full task details (requirements, files, steps)
    2. Run: `bd show {epic_id}` and read the first ~30 lines for epic goal and Key Decisions
    3. Run: `bd comments {epic_id} --json` and look for `[WAVE-SUMMARY]` entries to learn conventions from previous waves

    Parse from `bd show {issue_id}`:
    - `## Files` section → your allowed file list (fallback: Files You Own below)
    - `## Implementation Steps` section → your work plan (fallback: infer from description)
    - Dependencies listed → already completed, outputs available

    ## Files You Own

    You are ONLY allowed to modify these files:
    {file_ownership_list}

    **CRITICAL:** DO NOT modify any files outside this list.
    If you discover you need to modify other files, STOP and report the conflict.
    This constraint enables safe parallel execution with other subagents.

    ## Wave File Map (All Agents This Wave)

    {wave_file_map}

    If you need a file owned by another agent, STOP and report the conflicting file and its owner.

    ## Dependencies (Already Complete)

    {dependency_ids}

    ## Your Job

    Verify you understand all requirements from `bd show` before starting, then:
    1. Implement exactly what the issue specifies
    2. ONLY modify files in your allowed list
    3. Write tests (following TDD if issue says to)
    4. Verify implementation works
    5. Commit (conventional format: `feat:`, `fix:`, `refactor:`, etc.)
    6. For artifacts >50 lines: apply rule-of-five (Draft, Correctness, Clarity, Edge Cases, Excellence)
    7. Self-review, then report back

    Work from: {working_directory}

    **If you need files outside your allowed list:**
    STOP immediately and ask. Do not modify them.

    ## Before Reporting Back: Self-Review

    - **File Scope:** Only modified allowed files? Any wave file map conflicts?
    - **Completeness:** All requirements implemented? Edge cases handled?
    - **Quality:** Names clear? Code clean? Rule-of-five applied if >50 lines?
    - **Discipline:** No overbuilding (YAGNI)? Followed existing codebase patterns?
    - **Testing:** Tests verify behavior (not mocks)? TDD if required? Comprehensive?

    Fix any issues found before reporting.

    ## Write Report to Beads

    **Each step below MUST be a separate tool call. Never combine into one Bash command.**

    1. Use the **Write** tool to create `temp/{issue_id}-impl.md` with content:
       ```
       [IMPL-REPORT] {issue_id} wave-{wave_number}

       ### Evidence
       - **Commit:** [hash from `git rev-parse --short HEAD`]
       - **Files changed:** [output from `git diff --stat HEAD~1`]
       - **Test command:** [exact command you ran]
       - **Test results:** [pass/fail count and exit code]

       ### Summary
       - What you implemented (1-2 sentences)
       - **Files actually modified** (MUST match allowed list)
       - Self-review findings (if any)
       - Rule-of-five passes applied (if artifact >50 lines)
       - Any issues or concerns
       - **File scope violations** (if any)
       ```

    2. Bash: `bd comments add {issue_id} -f temp/{issue_id}-impl.md`
    3. Bash: `bd comments {issue_id} --json`
    4. If `bd comments add` fails, retry up to 3 times with `sleep 2` between attempts.

    ## Verdict (Final Message)

    **CRITICAL: Your final message must contain ONLY this structured verdict. No preamble, no narrative, no explanation of your process.**

    ```
    VERDICT: PASS|FAIL
    COMMIT: <hash>
    FILES: <count> changed (<insertions>+/<deletions>-)
    TESTS: <pass>/<total> pass, exit <code>
    SCOPE: CLEAN|VIOLATION
    REPORT_PERSISTED: YES|NO
    ```

    - VERDICT: PASS if implementation complete and tests green; FAIL otherwise
    - SCOPE: CLEAN if only allowed files modified; VIOLATION if others touched
    - REPORT_PERSISTED: YES if beads comment succeeded; NO if all retries failed

    **STOP after the verdict.** Do NOT:
    - Ask what to do next
    - Offer options (commit, push, merge, etc.)
    - Invoke workflow skills (finishing-a-development-branch, etc.)
    - Suggest follow-up actions
    The orchestrator manages all workflow decisions. Your only job is the verdict.
```

<!-- compressed: 2026-02-11, original: 1031 words, compressed: 586 words -->
