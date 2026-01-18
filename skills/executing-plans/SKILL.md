---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load beads epic, review critically, execute tasks in dependency-aware batches, report for review between batches.

**Core principle:** Dependency-aware batch execution with checkpoints for architect review.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Prerequisites:**
- Beads epic exists (created via plan2beads)
- Dependencies are set (`bd blocked` shows expected blockers)

**Key tool:** `bd` is the Beads CLI - a git-backed issue tracker. Key commands: `bd ready` (unblocked issues), `bd blocked` (waiting issues), `bd show` (details), `bd close` (mark done).

## The Process

### Step 1: Load and Review Epic

1. Load epic: `bd show <epic-id>`
2. Check dependencies: `bd ready` and `bd blocked`
3. Review critically - identify any questions or concerns
4. If concerns: Raise them with your human partner before starting
5. If no concerns: Proceed to execution

### Step 2: Execute Batch

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

**File conflicts:** If multiple ready issues touch the same file, only work on one at a time.

### Step 3: Report

When batch complete:
- Show what was implemented
- Show verification output
- Note any rule-of-five passes applied to significant artifacts
- Show newly unblocked issues: `bd ready`
- Say: "Ready for feedback."

### Step 4: Continue

Based on feedback:
- Apply changes if needed
- Execute next batch (newly unblocked issues)
- Repeat until all issues closed

### Step 5: Complete Development

After all issues in epic closed:
- Verify: `bd show <epic-id>` shows all children closed
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## Dependency-Aware Batching

**Old (sequential by task number):**
```
Batch 1: Tasks 1, 2, 3
Batch 2: Tasks 4, 5, 6
```

**New (dependency-aware):**
```
Batch 1: All tasks with no blockers (bd ready)
         After closing, check bd ready again
Batch 2: Newly unblocked tasks
         After closing, check bd ready again
...
```

**Example:**
```
Initial state:
  bd ready: hub-epic.1, hub-epic.2 (no deps)
  bd blocked: hub-epic.3 (by .1), hub-epic.4 (by .2, .3)

Batch 1: Work on hub-epic.1 and hub-epic.2
  [complete and close both]

  bd ready: hub-epic.3 (unblocked by .1 closing)
  bd blocked: hub-epic.4 (still waiting on .3)

Batch 2: Work on hub-epic.3
  [complete and close]

  bd ready: hub-epic.4 (unblocked by .3 closing)

Batch 3: Work on hub-epic.4
  [complete and close]

All done!
```

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

**Deadlock detection:**
If no ready issues exist for your epic but issues remain open:
1. Run `bd blocked` to see dependency chain
2. Check for circular dependencies (A→B→A)
3. Check if you forgot to `bd close` a completed issue

**If bd commands fail:**
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

## Remember
- Check `bd ready` before each batch
- Close issues promptly (`bd close`) to unblock dependents
- Follow issue steps exactly
- Don't skip verifications
- Reference skills when issue says to
- Between batches: report and wait for feedback
- Stop when blocked, don't guess
- **REQUIRED: Invoke `Skill(superpowers:rule-of-five)` before committing any file with >50 lines changed**

## Integration

**Required workflow:**
- **plan2beads** - Creates the epic this skill executes (must run first)
- **superpowers:finishing-a-development-branch** - Complete after all issues

**Alternative workflow:**
- **`superpowers:subagent-driven-development`** - Same session, parallel execution
