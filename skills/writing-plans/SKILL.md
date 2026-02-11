---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

Write comprehensive implementation plans assuming zero codebase context. Document: which files to touch, code, testing, docs, how to test. Bite-sized tasks. DRY. YAGNI. TDD. Frequent commits. Assume skilled developer, minimal domain knowledge, weak test design.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."
**Context:** Run in a dedicated worktree (created by brainstorming skill).
**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`
**REQUIRED:** Before ExitPlanMode, run Plan Verification Checklist, then rule-of-five. Verify *what* before polishing *how* -- scope errors caught early save wasted polish on deleted tasks.

## Mandatory Tasks (Enforcement)

Create these 7 native tasks at plan start (each blocked by previous via addBlockedBy). Cannot call ExitPlanMode with pending tasks:

1. **Write draft plan** -- Initial structure with all tasks, dependencies, file lists
2. **Plan Verification Checklist** -- Complete/Accurate/Commands valid/YAGNI/Minimal/Not over-engineered
3. **Rule-of-five: Draft pass** -- Shape and structure
4. **Rule-of-five: Correctness pass** -- Logic, accuracy, file paths
5. **Rule-of-five: Clarity pass** -- Can someone unfamiliar follow this?
6. **Rule-of-five: Edge Cases pass** -- What's missing? Error handling? Rollback?
7. **Rule-of-five: Excellence pass** -- Polish for senior colleague

See `references/task-enforcement-examples.md` for full TaskCreate blocks.

## Bite-Sized Task Granularity

Each step is one action (2-5 min): write failing test, run it to verify failure, implement minimal code, run test to verify pass, commit.

## Plan Document Header

Every plan MUST start with:

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** After human approval, use plan2beads to convert this plan to a beads epic, then use `superpowers:subagent-driven-development` for parallel execution.

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
**Key Decisions:**
- **[Area]:** [Choice] -- [Why over alternatives]
---
```

Key Decisions: 3-5 decisions implementers might question. WHAT was decided AND WHY. Focus where alternatives existed.

## Task Structure

**CRITICAL: Every task MUST include `Depends on:`, `Complexity:`, and `Files:` sections.** These enable safe parallel execution, model selection, and file conflict detection. See `references/dependency-analysis.md` and `references/file-lists.md`.

Recommended context: `Purpose:` (why), `Not In Scope:` (prevents overbuilding), `Gotchas:` (quirks).

```markdown
### Task N: [Component Name]
**Depends on:** Task M, Task P | None
**Complexity:** simple | standard | complex
**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Purpose:** [One sentence]

**Step 1: Write the failing test**
[code block]
**Step 2: Run test to verify it fails**
Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL
**Step 3: Write minimal implementation**
[code block]
**Step 4: Run test to verify it passes**
Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS
**Step 5: Commit**
`git add ... && git commit -m "feat: add specific feature"`
```

## Plan Verification Checklist

Before rule-of-five, verify scope and accuracy:

- **Complete** -- All requirements from brainstorming addressed?
- **Accurate** -- File paths verified? (existing files exist, new files in correct locations)
- **Commands valid** -- Test/build commands correct and runnable?
- **YAGNI** -- Every task directly serves a stated requirement?
- **Minimal** -- Could any task be removed/combined without losing functionality?
- **Not over-engineered** -- Simplest approach that works?
- **Key Decisions documented** -- 3-5 decisions with rationale?
- **Context sections present** -- Purpose for non-obvious tasks? Not In Scope for boundary tasks?

## Remember

- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills by name
- **Every task needs `Depends on:`, `Complexity:`, and `Files:`**
- **Include `Purpose:`, `Not In Scope:`, `Gotchas:` where needed**
- **Run Plan Verification Checklist before rule-of-five**
- **Announce each verification phase** (see `references/announcements-protocol.md`)
- **Plan MUST end with Verification Record** (see `references/verification-footer.md`)
- **After approval, follow execution handoff** (see `references/execution-handoff.md`)

## Reference Files

- `references/task-enforcement-examples.md`: Full TaskCreate blocks with blocked-by relationships
- `references/dependency-analysis.md`: Identifying and expressing task dependencies
- `references/file-lists.md`: File list format, parallel execution rules, and complexity estimation
- `references/announcements-protocol.md`: Required announcement templates for verification phases
- `references/verification-footer.md`: Plan Document Footer template (Verification Record)
- `references/execution-handoff.md`: Post-plan workflow: plan2beads -> subagent-driven-development

<!-- compressed: 2026-02-11, original: 915 words, compressed: 599 words -->
