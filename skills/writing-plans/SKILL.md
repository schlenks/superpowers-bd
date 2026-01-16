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

**REQUIRED:** Before ExitPlanMode, run the Plan Verification Checklist (scope/accuracy), then apply rule-of-five (Draft→Correctness→Clarity→Edge Cases→Excellence). Verify *what* before polishing *how*.

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

---
```

## Task Structure

**CRITICAL: Every task MUST include `Depends on:` and `Files:` sections.** These enable:
- Safe parallel execution (tasks with no dependency conflicts)
- File conflict detection (tasks modifying same files can't run in parallel)

```markdown
### Task N: [Component Name]

**Depends on:** Task M, Task P | None
**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

## Identifying Dependencies

When planning tasks, explicitly identify what each task needs:

| Dependency Type | Example | How to Express |
|-----------------|---------|----------------|
| Data model | Service needs User entity | `Depends on: Task 1 (User model)` |
| Import/export | Route imports service | `Depends on: Task 2 (Auth service)` |
| Config | Feature needs env vars | `Depends on: Task 0 (Config setup)` |
| Schema | Migration before model | `Depends on: Task 1 (DB migration)` |
| None | Independent task | `Depends on: None` |

**Rules:**
- **Always explicit:** Every task MUST have `Depends on:` line
- **Be specific:** List exact task numbers, not "previous tasks"
- **Minimize dependencies:** Only list what's truly required
- **Enable parallelism:** Tasks with `Depends on: None` can run in parallel

**Example dependency structure:**
```
Task 1: User Model           Depends on: None              ← READY
Task 2: JWT Utils            Depends on: None              ← READY (parallel with 1)
Task 3: Auth Service         Depends on: Task 1            ← Blocked by 1 only
Task 4: Login Endpoint       Depends on: Task 2, Task 3    ← Blocked by 2 AND 3
Task 5: Logout Endpoint      Depends on: Task 3            ← Blocked by 3 only
```

This enables: Tasks 1 & 2 parallel → Task 3 → Tasks 4 & 5 parallel

## File List Requirements

The `Files:` section enables safe parallel execution by detecting conflicts.

**Format:**
```markdown
**Files:**
- Create: `apps/api/src/models/user.model.ts`
- Modify: `apps/api/src/models/index.ts:15-20`
- Test: `apps/api/src/__tests__/models/user.test.ts`
```

**Rules:**
- List ALL files the task will touch
- Be specific about line ranges for modifications when known
- Include test files
- If two tasks modify the same file, they CANNOT run in parallel

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

**Why before rule-of-five:** This checklist verifies *what* you're building is correct. Rule-of-five then polishes *how* it's written. Scope errors caught here save wasted polish on tasks that get deleted.

## Remember
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits
- **Every task needs `Depends on:` and `Files:`**
- **Run Plan Verification Checklist before rule-of-five**
- **Apply rule-of-five before finalizing plan**

## Execution Handoff

**The full workflow:**
```
writing-plans → Plan Verification → rule-of-five → Human Review → plan2beads → /compact → subagent-driven
                      ↓                   ↓              ↓              ↓           ↓            ↓
                 Scope check         Quality polish  Approve/Edit   bd verify   Reclaim     Parallel
                                                                               context     execution
```

After saving the plan and human approval:

**Step 1: Convert to Beads**

**REQUIRED:** Use plan2beads to convert the approved plan to a beads epic with properly linked issues:

```
/plan2beads docs/plans/YYYY-MM-DD-feature-name.md
```

This creates:
- Epic for the feature
- Child issues for each task
- Dependencies between issues (from `Depends on:` lines)
- File lists preserved in issue descriptions

**Step 2: Verify Structure**

After conversion, verify:
```bash
bd ready          # Shows tasks with no blockers
bd blocked        # Shows tasks waiting on dependencies
bd graph <epic>   # Visual dependency graph
```

**Step 3: Compact Session**

Planning consumes context. Before execution, reclaim it:

**Tell the user:**
```
Epic <epic-id> ready with N tasks.

To maximize context for execution, run:
  /compact

Then say:
  execute epic <epic-id>
```

**Why compact:** Subagents need context for implementation. Planning conversation is no longer needed - the epic preserves all task details.

**Step 4: Execute**

**REQUIRED SUB-SKILL:** Use `superpowers:subagent-driven-development`
- Reads from beads epic (not markdown)
- Parallel dispatch of non-conflicting tasks
- Dependency-aware execution
- Two-stage review (spec compliance + code quality) after each task
