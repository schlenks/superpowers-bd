# Epic Scoping and Deadlock Detection

## Epic Scoping

`bd ready` shows ALL ready issues across all epics. Always filter to your current epic:

```bash
# First, get the epic's children
bd show <epic-id>  # Shows child issue IDs

# Only work on issues that are BOTH in bd ready AND children of your epic
```

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- `bd ready` shows nothing for your epic but issues remain open
- You don't understand an instruction
- Verification fails repeatedly

## Deadlock Detection

If no ready issues exist for your epic but issues remain open:
1. Run `bd blocked` to see dependency chain
2. Check for circular dependencies (A->B->A)
3. Check if you forgot to `bd close` a completed issue

## If bd Commands Fail

- Check if beads is initialized: `bd doctor`
- Check git status: `git status`
- If persistent errors, stop and ask human for help

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates issues based on your feedback
- Fundamental approach needs rethinking
- Dependencies need restructuring

**Don't force through blockers** - stop and ask.
