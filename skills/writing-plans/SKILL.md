---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."
**Context:** This should be run in a dedicated worktree (created by brainstorming skill).
**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

**REQUIRED:** Before ExitPlanMode, run the Plan Verification Checklist (scope/accuracy), then apply rule-of-five (Draft->Correctness->Clarity->Edge Cases->Excellence). Verify *what* before polishing *how*.

## Mandatory Tasks (Enforcement)

**Create these 7 native tasks at plan start.** You cannot call ExitPlanMode with pending tasks:

1. **Write draft plan** -- Create initial plan structure with all tasks, dependencies, and file lists
2. **Plan Verification Checklist** -- Verify: Complete, Accurate, Commands valid, YAGNI, Minimal, Not over-engineered
3. **Rule-of-five: Draft pass** -- Shape and structure. Get the outline right
4. **Rule-of-five: Correctness pass** -- Logic, accuracy, file paths. Does everything work?
5. **Rule-of-five: Clarity pass** -- Can someone unfamiliar follow this? Simplify
6. **Rule-of-five: Edge Cases pass** -- What's missing? Error handling? Rollback?
7. **Rule-of-five: Excellence pass** -- Polish. Would you show this to a senior colleague?

Each task is blocked by the previous (addBlockedBy), enforcing the sequence. TaskList shows progress. Skipping tasks is visible -- blocked tasks cannot be marked in_progress. See `references/task-enforcement-examples.md` for full TaskCreate blocks.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** After human approval, use plan2beads to convert this plan to a beads epic, then use `superpowers:subagent-driven-development` for parallel execution.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Key Decisions:**
- **[Decision area]:** [Choice made] -- [Why this over alternatives]
- **[Decision area]:** [Choice made] -- [Why]
- **[Decision area]:** [Choice made] -- [Why]

---
```

**Key Decisions guidance:** 3-5 decisions that implementers might question. Include WHAT was decided AND WHY. Focus on decisions where alternatives existed (e.g., "JWT over sessions -- stateless scaling").

## Task Structure

**CRITICAL: Every task MUST include `Depends on:` and `Files:` sections.** These enable safe parallel execution and file conflict detection. See `references/dependency-analysis.md` and `references/file-lists.md` for detailed rules.

**RECOMMENDED context sections:** `Purpose:` (why this task exists), `Not In Scope:` (prevents overbuilding), `Gotchas:` (known quirks).

```markdown
### Task N: [Component Name]

**Depends on:** Task M, Task P | None
**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Purpose:** [One sentence explaining why this task exists and what it enables]

**Step 1: Write the failing test**
[code block with test]

**Step 2: Run test to verify it fails**
Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**
[code block with implementation]

**Step 4: Run test to verify it passes**
Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**
`git add ... && git commit -m "feat: add specific feature"`
```

## Plan Verification Checklist

**Before applying rule-of-five, verify scope and accuracy:**

| Check | Question |
|-------|----------|
| **Complete** | All requirements from brainstorming addressed? |
| **Accurate** | File paths verified? (existing files exist, new files in correct locations) |
| **Commands valid** | Test/build commands correct and runnable? |
| **YAGNI** | Every task directly serves a stated requirement? |
| **Minimal** | Could any task be removed or combined without losing functionality? |
| **Not over-engineered** | Is this the simplest approach that works? |
| **Key Decisions documented** | Are 3-5 key decisions captured with rationale? |
| **Context sections present** | Do non-obvious tasks have Purpose? Scope-boundary tasks have Not In Scope? |

**Why before rule-of-five:** This checklist verifies *what* you're building is correct. Rule-of-five then polishes *how* it's written. Scope errors caught here save wasted polish on tasks that get deleted.

## Remember

- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills by name (e.g., `superpowers:skill-name`)
- DRY, YAGNI, TDD, frequent commits
- **Every task needs `Depends on:` and `Files:`**
- **Include `Purpose:` for non-obvious tasks, `Not In Scope:` when scope boundaries are unclear, `Gotchas:` for quirks**
- **Run Plan Verification Checklist before rule-of-five**
- **Announce each verification phase** (see `references/announcements-protocol.md`)
- **Plan MUST end with Verification Record** (see `references/verification-footer.md`)
- **After approval, follow execution handoff** (see `references/execution-handoff.md`)

## Reference Files

| File | When to read |
|------|-------------|
| `references/task-enforcement-examples.md` | Full TaskCreate blocks with blocked-by relationships |
| `references/dependency-analysis.md` | Identifying and expressing task dependencies |
| `references/file-lists.md` | File list format and rules for parallel execution |
| `references/announcements-protocol.md` | Required announcement templates for verification phases |
| `references/verification-footer.md` | Plan Document Footer template (Verification Record) |
| `references/execution-handoff.md` | Post-plan workflow: plan2beads -> subagent-driven-development |
