# Red Flags and Common Mistakes

Detailed guidance on what to avoid when finishing a development branch.

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Offer to discard the work, or delete work without typed confirmation
- `git worktree remove --force` a worktree that refused removal
- Force-push without explicit request

**Always:**
- Verify tests before offering options
- Present exactly 3 options (2 on detached HEAD)
- Get typed "discard" confirmation for an explicitly requested discard
- Clean up the worktree only for Merge or a confirmed discard

## Common Mistakes

### Skipping test verification
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

### Open-ended questions
- **Problem:** "What should I do next?" leads to ambiguity
- **Fix:** Present exactly 3 structured options

### Advertising discard
- **Problem:** "Discard this work" next to "Merge" invites destroying finished, passing work
- **Fix:** Discard is not a menu option; it runs only on an explicit request

### Automatic worktree cleanup
- **Problem:** Remove worktree when might need it (PR, Keep)
- **Fix:** Only cleanup for Merge and a confirmed discard

### Cleanup that silently does nothing
- **Problem:** `WORKTREE_PATH` re-detected after `cd` to the main repo root points at the main repo
- **Fix:** Use the value captured in Step 1.7

### No confirmation for discard
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation
