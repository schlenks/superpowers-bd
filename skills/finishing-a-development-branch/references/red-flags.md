# Red Flags and Common Mistakes

Detailed guidance on what to avoid when finishing a development branch.

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request

**Always:**
- Verify tests before offering options
- Present exactly 4 options
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only

## Common Mistakes

### Skipping test verification
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

### Open-ended questions
- **Problem:** "What should I do next?" leads to ambiguity
- **Fix:** Present exactly 4 structured options

### Automatic worktree cleanup
- **Problem:** Remove worktree when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

### No confirmation for discard
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation
