# Implementer Subagent Prompt Template

Use this template when dispatching an implementer subagent for a beads issue.

```
Task tool:
  subagent_type: "general-purpose"
  model: "opus"                    # tier-based: opus for max-20x, sonnet for others
  run_in_background: true          # for parallelism
  description: "Implement Issue: [issue-id] [issue title]"
  prompt: |
    You are implementing beads issue: [issue-id]

    ## Issue Details

    [FULL CONTENT from `bd show <issue-id>` - paste it here, don't make subagent run bd]

    ## Epic Context (Optional)

    [EPIC_GOAL - One sentence describing what the epic achieves]

    **Key Decisions:**
    [KEY_DECISIONS - 3-5 architectural decisions with rationale from epic description]

    **Why This Task Matters:**
    [TASK_PURPOSE - How this task contributes to the epic goal]

    ## Files You Own

    You are ONLY allowed to modify these files:
    [List from issue's ## Files section]

    **CRITICAL:** DO NOT modify any files outside this list.
    If you discover you need to modify other files, STOP and ask.
    This constraint enables safe parallel execution with other subagents.

    **Advisory lock file:** `.claude/file-locks.json` lists all file locks for this wave.
    If you discover you need a file not in your list, check `.claude/file-locks.json` to see
    if another agent owns it. If locked, STOP and report the conflicting file and its owner.
    Do NOT read this file routinely — only consult it when you encounter an unexpected file need.

    ## Dependencies (Already Complete)

    These issues have been completed. You can use their outputs:
    [List completed dependency issues, if any]

    ## Established Conventions (from previous waves)

    [WAVE_CONVENTIONS - Patterns and conventions from previous wave summaries]

    If this section is empty, you are establishing conventions. Document your choices clearly in commit messages.

    ## Additional Context

    [ADDITIONAL_CONTEXT - Any scene-setting beyond epic context and wave conventions]

    ## Before You Begin

    If you have questions about:
    - The requirements or acceptance criteria
    - The approach or implementation strategy
    - Why you're limited to certain files
    - Dependencies or assumptions
    - Anything unclear in the issue description

    **Ask them now.** Raise any concerns before starting work.

    ## Your Job

    Once you're clear on requirements:
    1. Implement exactly what the issue specifies
    2. ONLY modify files in your allowed list
    3. Write tests (following TDD if issue says to)
    4. Verify implementation works
    5. Commit your work (use conventional commit format: `feat:`, `fix:`, `refactor:`, etc.)
    6. For artifacts >50 lines: Apply rule-of-five passes (Draft, Correctness, Clarity, Edge Cases, Excellence)
    7. Self-review (see below)
    8. Report back

    Work from: [directory]

    **While you work:** If you encounter something unexpected or unclear, **ask questions**.
    It's always OK to pause and clarify. Don't guess or make assumptions.

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

    ## Report Format

    When done, report using this EXACT structure:

    ### Evidence
    - **Commit:** [hash from `git rev-parse --short HEAD`]
    - **Files changed:** [output from `git diff --stat HEAD~1`]
    - **Test command:** [exact command you ran]
    - **Test results:** [pass/fail count and exit code]

    ### Summary
    - What you implemented
    - **Files actually modified** (MUST match allowed list)
    - Self-review findings (if any)
    - Rule-of-five passes applied (if artifact >50 lines)
    - Any issues or concerns
    - **File scope violations** (if any)

    **STOP after reporting.** Do NOT:
    - Ask what to do next
    - Offer options (commit, push, merge, etc.)
    - Invoke workflow skills (finishing-a-development-branch, etc.)
    - Suggest follow-up actions
    The orchestrator manages all workflow decisions. Your only job is to report results.
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

    ## Issue Details

    Title: Auth Service
    Status: in_progress
    Priority: 2

    ## Files
    - Create: `apps/api/src/services/auth.service.ts`
    - Modify: `apps/api/src/services/index.ts`
    - Test: `apps/api/src/__tests__/services/auth.service.test.ts`

    ## Implementation Steps
    **Step 1: Write the failing test**
    ```typescript
    describe('AuthService', () => {
      it('should validate user credentials', async () => {
        // ...
      })
    })
    ```

    **Step 2: Run test to verify it fails**
    Run: `pnpm api:test -- --grep "AuthService"`
    Expected: FAIL

    ...

    ## Files You Own

    You are ONLY allowed to modify these files:
    - apps/api/src/services/auth.service.ts (Create)
    - apps/api/src/services/index.ts (Modify)
    - apps/api/src/__tests__/services/auth.service.test.ts (Test)

    **CRITICAL:** DO NOT modify any files outside this list.

    ## Dependencies (Already Complete)

    - hub-abc.1: User Model (apps/api/src/models/user.model.ts exists)

    ## Established Conventions (from previous waves)

    - Using uuid v4 for all entity IDs
    - camelCase for JSON field names
    - Async/await over raw promises

    ## Epic Context (Optional)

    Build a complete authentication system for the API.

    **Key Decisions:**
    - JWT for stateless auth with 24h expiry
    - Bcrypt for password hashing
    - Refresh tokens stored in database

    **Why This Task Matters:**
    Auth service is the core of user authentication. Login endpoint (hub-abc.4) depends on this.

    ## Additional Context

    This is part of the Auth System epic. The User model is complete.
    This service will be used by the Login endpoint (hub-abc.4).

    ...

    **STOP after reporting.** Do NOT:
    - Ask what to do next
    - Offer options (commit, push, merge, etc.)
    - Invoke workflow skills (finishing-a-development-branch, etc.)
    - Suggest follow-up actions
    The orchestrator manages all workflow decisions. Your only job is to report results.
```
