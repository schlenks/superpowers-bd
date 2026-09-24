You are implementing beads issue: inv-2

You are not alone in the codebase. Other agents may be working in parallel.
Modify only your owned files and do not overwrite changes you did not make.

## Load Your Context

1. `bd show inv-2` — full task details (requirements, files, steps)
2. `bd show inv-1` — first ~30 lines for epic goal, Key Decisions, File Structure
3. `bd comments inv-1 --json` — look for `[WAVE-SUMMARY]` entries for conventions

From `bd show inv-2`, parse:
- `## Files` → allowed file list (fallback: Files You Own below)
- `## Implementation Steps` → work plan (fallback: infer from description)

## Files You Own

You may ONLY modify: invoice/tax.py, tests/test_tax.py

If you need files outside this list, STOP and report the conflict.

## Wave File Map

| Issue | Files |
|---|---|
| inv-2 | invoice/tax.py, tests/test_tax.py |

If you need a file owned by another agent, STOP and report the conflict.

## Dependencies (Complete)

inv-1.1 (closed)

## Your Job

Verify requirements from `bd show` first, then:
1. Implement exactly what the issue specifies
2. ONLY modify your allowed files
3. Write tests (TDD if issue says to)
4. Verify implementation works
5. Commit (`feat:`, `fix:`, `refactor:`, etc.)
6. Artifacts >50 lines: apply rule-of-five variant — read the skill file for your artifact type:
   - **Code (50+ lines):** Read /Users/schlenks/Developer/personal/superpowers-bd/skills/rule-of-five-code/SKILL.md
   - **Tests (50+ lines):** Read /Users/schlenks/Developer/personal/superpowers-bd/skills/rule-of-five-tests/SKILL.md
   - **Plans/Docs (50+ lines):** Read /Users/schlenks/Developer/personal/superpowers-bd/skills/rule-of-five-plans/SKILL.md
7. Self-review, then report back

Work from: the current directory (a git repo)

## Code Organization

- Follow the plan's File Structure. One responsibility per file, well-defined interfaces.
- File growing beyond plan's intent → report DONE_WITH_CONCERNS, don't split without guidance
- Existing file large/tangled → note concern. Follow established patterns; don't restructure outside scope.

## When You're in Over Your Head

Bad work is worse than no work. **STOP and escalate when:**
- Architectural decisions with multiple valid approaches
- Can't find clarity on code beyond what was provided
- Restructuring beyond what the plan anticipated
- Reading files without making progress

Use BLOCKED or NEEDS_CONTEXT verdict. Describe what you're stuck on and what you need.

## Self-Review

- **Scope:** Only allowed files modified? No wave file map conflicts?
- **Complete:** All requirements? Edge cases?
- **Quality:** Clean code? Rule-of-five applied if >50 lines?
- **Discipline:** No overbuilding (YAGNI)? Existing patterns followed?
- **Tests:** Verify behavior (not mocks)? Comprehensive?

Fix issues before reporting.

## Write Report to Beads

**Each step = separate tool call. Never combine Bash commands.**

**If DONE or DONE_WITH_CONCERNS:**
1. Write `temp/inv-2-impl.md`:
   ```
   [IMPL-REPORT] inv-2 wave-1
   ### Evidence
   - Commit: [hash] | Files: [diff --stat] | Tests: [pass/fail, exit code]
   ### Summary
   - What implemented (1-2 sentences)
   - Files modified (must match allowed list)
   - Self-review findings, rule-of-five passes, scope violations (if any)
   ```

**If BLOCKED or NEEDS_CONTEXT:**
1. Write `temp/inv-2-impl.md`:
   ```
   [IMPL-REPORT] inv-2 wave-1
   ### Status: BLOCKED|NEEDS_CONTEXT
   ### Attempted: [what you tried, how far you got]
   ### Blocker: [what's blocking, what's needed]
   ```

2. `bd comments add inv-2 -f temp/inv-2-impl.md`
3. `bd comments inv-2 --json`
4. If step 2 fails, retry up to 3× with `sleep 2` between.

## Verdict (Final Message)

**Your final message must be ONLY this verdict. No preamble or narrative.**

**DONE or DONE_WITH_CONCERNS:**
```
VERDICT: DONE|DONE_WITH_CONCERNS
COMMIT: <hash>
FILES: <count> changed (<insertions>+/<deletions>-)
TESTS: <pass>/<total> pass, exit <code>
SCOPE: CLEAN|VIOLATION
REPORT_PERSISTED: YES|NO
CONCERNS: <1-2 sentences — DONE_WITH_CONCERNS only>
```

**BLOCKED or NEEDS_CONTEXT:**
```
VERDICT: BLOCKED|NEEDS_CONTEXT
BLOCKER: <what you're stuck on, what you tried, what help you need>
REPORT_PERSISTED: YES|NO
```

- **DONE:** Complete, tests green. **DONE_WITH_CONCERNS:** Complete but doubts.
- **BLOCKED:** Cannot complete. **NEEDS_CONTEXT:** Missing information.
- **SCOPE:** CLEAN = allowed files only; VIOLATION = others touched.

**STOP after verdict.** Do NOT ask what's next, offer options, invoke skills, or suggest actions.
