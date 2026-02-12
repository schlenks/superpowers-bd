# Batch Execution Detail

## Step 2: Execute Batch (Full Detail)

**Batch = all currently ready issues (no blockers)**

```bash
bd ready  # Shows issues that can be worked on
```

For each ready issue:
1. `bd update <id> --status=in_progress`
2. Read issue details: `bd show <id>`
3. Follow each step exactly (issue description has bite-sized steps)
4. Run verifications as specified
5. **REQUIRED BEFORE COMMIT:** Check for significant changes:
   - Run `git diff --cached --stat` (or `git diff --stat` if not yet staged)
   - For any file with >50 lines added/changed: **STOP**
   - Invoke the appropriate rule-of-five variant on each significant file:
     - Code files: `Skill(superpowers:rule-of-five-code)` (Draft, Correctness, Clarity, Edge Cases, Excellence)
     - Test files (`*test*`, `*spec*`, `tests/`): `Skill(superpowers:rule-of-five-tests)` (Draft, Coverage, Independence, Speed, Maintainability)
   - Complete all 5 passes for the chosen variant
   - Stage any improvements from the review
   - Only THEN proceed to commit
6. Commit the work
7. `bd close <id>` - **CRITICAL: This unblocks dependent issues!**

## File Conflicts

If multiple ready issues touch the same file, only work on one at a time. Serialize file-conflicting issues within the batch to avoid merge conflicts and lost work.
