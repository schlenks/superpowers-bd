---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load beads epic, review critically, execute tasks in dependency-aware batches, report for review between batches.

**Core principle:** Dependency-aware batch execution with checkpoints for architect review.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**REQUIRED BACKGROUND:** Read `superpowers:beads` SKILL.md before using this skill. It covers bd CLI usage, permission avoidance, and dependency management.

**Prerequisites:**
- Beads epic exists (created via plan2beads)
- Dependencies are set (`bd blocked` shows expected blockers)

## The Process

### Step 1: Load and Review Epic

Load epic with `bd show <epic-id>`, check `bd ready` and `bd blocked`. Review critically -- raise concerns with your human partner before starting.

### Step 2: Execute Batch

**Batch = all currently ready issues (no blockers).** For each ready issue:
1. `bd update <id> --status=in_progress` then `bd show <id>`
2. Follow each step exactly; run verifications as specified
3. **REQUIRED BEFORE COMMIT:** Run `git diff --cached --stat` -- for any file with >50 lines changed, invoke `Skill(superpowers:rule-of-five)` and complete all 5 passes before proceeding
4. Commit the work
5. `bd close <id>` -- **this unblocks dependent issues**

**File conflicts:** If multiple ready issues touch the same file, serialize them. See `references/batch-execution-detail.md` for full procedure.

### Step 3: Report (Task-Tracked)

Create a checkpoint task after each batch. Show: what was implemented, verification output, rule-of-five passes applied, newly unblocked issues (`bd ready`). Say: "Ready for feedback." Mark task `completed`. See `references/report-and-feedback.md` for TaskCreate blocks.

### Step 4: Continue (Task-Tracked)

Create blocked feedback + execution tasks to enforce the checkpoint. Do NOT proceed until human feedback received. Apply feedback, mark tasks complete, execute next batch. Repeat until all issues closed. See `references/report-and-feedback.md` for full enforcement flow.

### Step 5: Complete Development

After all epic issues closed, verify with `bd show <epic-id>`, then hand off to `superpowers:finishing-a-development-branch`. See `references/completion-protocol.md` for full handoff.

## Dependency-Aware Batching

**Old (sequential by task number):**
```
Batch 1: Tasks 1, 2, 3
Batch 2: Tasks 4, 5, 6
```

**New (dependency-aware):**
```
Batch 1: All tasks with no blockers (bd ready)
         Close completed -> check bd ready again
Batch 2: Newly unblocked tasks
         Close completed -> check bd ready again
```

See `references/batching-example.md` for a full walkthrough with bd ready/blocked output at each stage.

## Epic Scoping

`bd ready` shows ALL epics. Always filter to your current epic: run `bd show <epic-id>` to get child IDs, then only work on issues that are both ready AND children of your epic.

## When to Stop

**STOP immediately when:** blocker mid-batch, no ready issues but open issues remain, unclear instructions, repeated verification failures. Check `bd blocked` for deadlocks (circular deps, forgotten closes). See `references/epic-scoping-and-deadlock.md` for deadlock detection, bd failures, and when to revisit earlier steps.

**Ask for clarification rather than guessing.**

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

## Reference Files

| File | When to read |
|------|-------------|
| `references/batch-execution-detail.md` | Full Step 2 procedure with file conflict handling and rule-of-five trigger |
| `references/report-and-feedback.md` | Full Step 3 + Step 4 TaskCreate blocks and feedback enforcement flow |
| `references/batching-example.md` | Dependency-aware batching walkthrough with bd ready/blocked at each stage |
| `references/epic-scoping-and-deadlock.md` | Epic scoping commands, deadlock detection, bd failures, when to revisit |
| `references/completion-protocol.md` | Step 5 full completion handoff to finishing-a-development-branch |
