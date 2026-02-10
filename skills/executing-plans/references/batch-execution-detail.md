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
   - Invoke `Skill(superpowers:rule-of-five)` on each significant file
   - Complete all 5 passes (Draft, Correctness, Clarity, Edge Cases, Excellence)
   - Stage any improvements from the review
   - Only THEN proceed to commit
6. Commit the work
7. `bd close <id>` - **CRITICAL: This unblocks dependent issues!**

## File Conflicts

If multiple ready issues touch the same file, only work on one at a time. Serialize file-conflicting issues within the batch to avoid merge conflicts and lost work.
