# Implementer Subagent Prompt Template

Use this template when dispatching an implementer subagent for a beads issue.

```
Task tool:
  subagent_type: "general-purpose"
  model: "opus"                    # tier-based: opus for max-20x, sonnet for others
  run_in_background: true          # for parallelism
  description: "Implement Issue: [issue-id] [issue title]"
  prompt: |
    You are implementing beads issue: {issue_id}

    ## Load Your Context

    1. Run: `bd show {issue_id}` for full task details (requirements, files, steps)
    2. Run: `bd show {epic_id} | head -30` for epic goal and Key Decisions
    3. Run: `bd comments {epic_id} --json` and look for `[WAVE-SUMMARY]` entries to learn conventions from previous waves

    Parse from `bd show {issue_id}`:
    - The `## Files` section → your allowed file list (if missing, use the `Files You Own` list below)
    - The `## Implementation Steps` section → your work plan (if missing, infer steps from the issue description)
    - Dependencies listed → already completed, their outputs are available

    ## Files You Own

    You are ONLY allowed to modify these files:
    {file_ownership_list}

    **CRITICAL:** DO NOT modify any files outside this list.
    If you discover you need to modify other files, STOP and ask.
    This constraint enables safe parallel execution with other subagents.

    **Advisory lock file:** `.claude/file-locks.json` lists all file locks for this wave.
    If you discover you need a file not in your list, check `.claude/file-locks.json` to see
    if another agent owns it. If locked, STOP and report the conflicting file and its owner.
    Do NOT read this file routinely — only consult it when you encounter an unexpected file need.

    ## Dependencies (Already Complete)

    {dependency_ids}

    ## Your Job

    Verify you understand all requirements from `bd show` before starting, then:
    1. Implement exactly what the issue specifies
    2. ONLY modify files in your allowed list
    3. Write tests (following TDD if issue says to)
    4. Verify implementation works
    5. Commit your work (use conventional commit format: `feat:`, `fix:`, `refactor:`, etc.)
    6. For artifacts >50 lines: Apply rule-of-five passes (Draft, Correctness, Clarity, Edge Cases, Excellence)
    7. Self-review (see below)
    8. Report back

    Work from: {working_directory}

    **If you need files outside your allowed list:**
    STOP immediately and ask. Do not modify them. This would conflict with parallel work.

    ## Before Reporting Back: Self-Review

    Review your work with fresh eyes. Ask yourself:

    **File Scope:**
    - Did I ONLY modify files in my allowed list?
    - If I touched other files, I need to report this as an issue
    - If I needed a file owned by another agent (per `.claude/file-locks.json`), did I STOP and report it?

    **Completeness:**
    - Did I fully implement everything in the spec?
    - Did I miss any requirements?
    - Are there edge cases I didn't handle?

    **Quality:**
    - Is this my best work?
    - Are names clear and accurate (match what things do, not how they work)?
    - Is the code clean and maintainable?
    - For >50 lines: Did I apply rule-of-five passes?

    **Discipline:**
    - Did I avoid overbuilding (YAGNI)?
    - Did I only build what was requested?
    - Did I follow existing patterns in the codebase?

    **Testing:**
    - Do tests actually verify behavior (not just mock behavior)?
    - Did I follow TDD if required?
    - Are tests comprehensive?

    If you find issues during self-review, fix them now before reporting.

    ## Write Report to Beads

    After implementation and self-review, persist your full report to beads:

    1. Write your full report to a temp file:
       ```bash
       cat > temp/{issue_id}-impl.md << 'REPORT'
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
       REPORT
       ```

    2. Post to beads:
       ```bash
       bd comments add {issue_id} -f temp/{issue_id}-impl.md
       ```

    3. Verify it was persisted:
       ```bash
       bd comments {issue_id} --json | tail -1
       ```

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

## Example Dispatch

```
Task tool:
  subagent_type: "general-purpose"
  model: "opus"                    # tier-based: opus for max-20x, sonnet for others
  run_in_background: true          # for parallelism
  description: "Implement Issue: hub-abc.3 Auth Service"
  prompt: |
    You are implementing beads issue: hub-abc.3

    ## Load Your Context

    1. Run: `bd show hub-abc.3` for full task details
    2. Run: `bd show hub-abc | head -30` for epic goal and Key Decisions
    3. Run: `bd comments hub-abc --json` for [WAVE-SUMMARY] entries → conventions

    Parse from `bd show hub-abc.3`:
    - The `## Files` section → your allowed file list
    - The `## Implementation Steps` section → your work plan
    - Dependencies listed → already completed, their outputs are available

    ## Files You Own

    You are ONLY allowed to modify these files:
    - apps/api/src/services/auth.service.ts (Create)
    - apps/api/src/services/index.ts (Modify)
    - apps/api/src/__tests__/services/auth.service.test.ts (Test)

    **CRITICAL:** DO NOT modify any files outside this list.

    **Advisory lock file:** `.claude/file-locks.json` lists all file locks for this wave.

    ## Dependencies (Already Complete)

    - hub-abc.1: User Model

    ...

    **STOP after the verdict.** Do NOT:
    - Ask what to do next
    - Offer options (commit, push, merge, etc.)
    - Invoke workflow skills (finishing-a-development-branch, etc.)
    - Suggest follow-up actions
    The orchestrator manages all workflow decisions. Your only job is the verdict.
```
