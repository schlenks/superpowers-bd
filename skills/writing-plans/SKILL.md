---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
effort: xhigh
---

# Writing Plans

Write comprehensive implementation plans assuming zero codebase context. Document: which files to touch, code, testing, docs, how to test. Bite-sized tasks. DRY. YAGNI. TDD. Frequent commits. Assume skilled developer, minimal domain knowledge, weak test design.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."
**Context:** Run in a dedicated worktree (created by brainstorming skill).
**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`. NEVER write to `~/.claude/plans/` -- ignore the plan mode default path.
**REQUIRED:** Run Plan Verification Checklist, then rule-of-five-plans before presenting the plan as ready. Verify *what* before polishing *how* -- scope errors caught early save wasted polish on deleted tasks.

## Platform Routing

- **Claude Code:** Use the mandatory task sequence below. Do not call ExitPlanMode until verification is complete. Claude Code command/tool wording in this file is intentional for the Claude platform.
- **Codex:** Follow `references/codex-plan-verification.md` for the native Codex planning and verification flow. Use `update_plan` for phase tracking, write the plan with normal file edits, and do not enter Claude plan mode or translate Claude-only tools.

## Mandatory Tasks (Enforcement)

Create these 7 native tasks at plan start (each blocked by previous via addBlockedBy). Cannot call ExitPlanMode with pending tasks:

1. **Write draft plan** -- Initial structure with all tasks, dependencies, file lists
   - **After saving plan — context check:** Look at your model ID in the system prompt (e.g., `claude-opus-4-6[1m]`).
     - **`[1m]` present (default):** Skip compact. Announce "Plan written to {path}. Proceeding to verification." and continue to task 2.
     - **No `[1m]` (200k):** Show copy-pasteable `/compact` command (see `references/announcements-protocol.md`) and wait for user's follow-up before proceeding to task 2.
2. **Plan Verification Checklist** -- Complete/Accurate/Commands valid/YAGNI/Minimal/Not over-engineered
3. **Rule-of-five-plans: Draft pass** -- Shape and structure
4. **Rule-of-five-plans: Feasibility pass** -- Can every step be executed? Deps available? Paths valid?
5. **Rule-of-five-plans: Completeness pass** -- Every requirement traced to a task?
6. **Rule-of-five-plans: Risk pass** -- What could go wrong? Migration, breaking changes?
7. **Rule-of-five-plans: Optimality pass** -- Simplest approach? YAGNI?

**Task 2: Inline Self-Review.** The orchestrator runs the Plan Verification Checklist directly — no sub-agent dispatch. The orchestrator just wrote the plan and has full context; a sub-agent would only re-read it from disk. Mark task 2 in_progress, run each checklist item against the plan, edit the plan to fix any issues, mark task 2 completed, then proceed to task 3.

**Tasks 3–7: Sub-Agent Dispatch.** After task 2 completes, dispatch each rule-of-five-plans pass sequentially as a **sonnet** sub-agent using the template in `references/verification-dispatch.md`. Mark each native task in_progress before dispatch, completed after collecting verdict. If any verdict is BLOCKED/FAIL, stop and report to user. After all 5 verdicts collected, assemble Verification Record (see `references/verification-footer.md`) and append to plan file.

See `references/task-enforcement-examples.md` for full TaskCreate blocks and dispatch loop.

## Bite-Sized Task Granularity

Each step is one action (2-5 min): write failing test, run it to verify failure, implement minimal code, run test to verify pass, commit.
Split tasks only where a reviewer could reject one while approving its neighbor.

## Plan Document Header

Every plan MUST start with:

```markdown
# [Feature Name] Implementation Plan

> **After approval:** convert this plan to a beads epic with plan2beads, then execute it with subagent-driven-development unless a different execution path is explicitly chosen.

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
**Key Decisions:**
- **[Area]:** [Choice] -- [Why over alternatives]
---
```

Key Decisions: 3-5 decisions implementers might question. WHAT was decided AND WHY. Focus where alternatives existed.

## Optional Metadata (Preserved Through Import)

These sections are OPTIONAL. When a plan includes them, `plan2beads` carries them into beads instead of dropping them; when a plan omits them, import is unchanged.

- `## Global Constraints` (epic-level): rules that apply to every task. When present, plan2beads threads this text into **every** child task body so each implementer carries it.
- `**Interfaces:**` (per-task, with `Consumes:` / `Produces:`): the contract a task consumes and produces. When present, plan2beads preserves the line verbatim in that task's body.

Both surfaces (`commands/plan2beads.md` and `skills/plan2beads/references/codex-plan2beads-flow.md`) parse these identically.

## Global Constraints

**OPTIONAL. Keep it short** — `plan2beads` threads this block verbatim into every child task body so each implementer carries it. Anything here multiplies by N tasks; trim ruthlessly.

Use for epic-wide rules every implementer must honor: version floors, commit/push restrictions, mirror-sync requirements, shared invariants. Rules that apply to only one or two tasks belong in those tasks' bodies, not here.

**Template:**

```markdown
## Global Constraints
- [Rule — concise and actionable, one line each]
- [Rule 2]
```

**Example (from this epic's own plan):**

```markdown
## Global Constraints
- All plan2beads edits touch BOTH parsers; mirror skills, `diff -rq` empty before commit.
- Commit local only — no push/tag/bd dolt push. No version bump.
```

`plan2beads` propagates this block into each child task body and retains it in the epic description. If absent, import is unchanged — backward-compatible.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

```markdown
| File | Responsibility | Action |
|------|---------------|--------|
| `exact/path/to/file.py` | One clear responsibility | Create |
| `exact/path/to/existing.py` | One clear responsibility | Modify |
| `tests/exact/path/to/test.py` | Tests for file.py | Create |
```

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- Prefer smaller, focused files. Files that can be held in context at once produce more reliable edits.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If a file has grown unwieldy, including a split in the plan is reasonable.

This structure informs task decomposition. Each task's `Files:` section must reference entries from this table — no task should introduce files not listed here.

## Task Structure

**CRITICAL: Every task MUST include `Depends on:`, `Complexity:`, and `Files:` sections.** These enable safe parallel execution, model selection, and file conflict detection. See `references/dependency-analysis.md` and `references/file-lists.md`.

Recommended context: `Purpose:` (why), `Not In Scope:` (prevents overbuilding), `Gotchas:` (quirks).

**Interfaces (optional):** Add when tasks share a boundary — implementers get exact sibling signatures at task start, preventing mis-integrations without re-reading sibling code. `Consumes:` names sibling outputs or call signatures this task depends on; `Produces:` names what this task exposes for other tasks. `plan2beads` preserves this block verbatim in each task's beads body.

```markdown
### Task N: [Component Name]
**Depends on:** Task M, Task P | None
**Complexity:** simple | standard | complex
**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:** (optional)
- Consumes: [sibling output or signature this task needs — e.g. `UserSchema` type from Task 2]
- Produces: [what this task exposes for siblings — e.g. `AuthToken` type, `POST /api/auth` endpoint]

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
`git add ...` then `git commit -m "feat: add specific feature"`
```

## Plan Verification Checklist

Before rule-of-five-plans, verify scope and accuracy:

- **Complete** -- All requirements from brainstorming addressed?
- **Accurate** -- File paths verified? (existing files exist, new files in correct locations)
- **Commands valid** -- Test/build commands correct and runnable?
- **YAGNI** -- Every task directly serves a stated requirement?
- **Minimal** -- Could any task be removed/combined without losing functionality?
- **Not over-engineered** -- Simplest approach that works?
- **Key Decisions documented** -- 3-5 decisions with rationale?
- **Context sections present** -- Purpose for non-obvious tasks? Not In Scope for boundary tasks?
- **File Structure complete** -- Every file in task `Files:` sections appears in File Structure table? No undeclared files?

## Remember

- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills by name
- **Every task needs `Depends on:`, `Complexity:`, and `Files:`**
- **Include `Purpose:`, `Not In Scope:`, `Gotchas:` where needed**
- **File Structure table before tasks — tasks reference it, never introduce undeclared files**
- **Run Plan Verification Checklist before rule-of-five-plans**
- **Announce each verification phase** (see `references/announcements-protocol.md`)
- **Plan MUST end with Verification Record** (see `references/verification-footer.md`)
- **After approval, follow execution handoff** (see `references/execution-handoff.md`)

## Reference Files

- `references/task-enforcement-examples.md`: Full TaskCreate blocks with blocked-by relationships
- `references/codex-plan-verification.md`: Codex-native plan drafting, verification, and rule-of-five flow
- `references/dependency-analysis.md`: Identifying and expressing task dependencies
- `references/file-lists.md`: File list format, parallel execution rules, and complexity estimation
- `references/announcements-protocol.md`: Required announcement templates for verification phases
- `references/verification-dispatch.md`: Sub-agent prompt templates and dispatch flow for verification passes
- `references/verification-footer.md`: Plan Document Footer template (Verification Record)
- `references/execution-handoff.md`: Post-plan workflow: plan2beads -> subagent-driven-development

<!-- compressed: 2026-02-11, original: 915 words, compressed: 599 words -->
