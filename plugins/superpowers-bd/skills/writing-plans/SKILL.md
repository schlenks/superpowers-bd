---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
effort: medium
---

# Writing Plans

Write implementation plans for an engineer who has not seen this codebase or this spec. Assume they write idiomatic code in the project's language once they know the exact interface and the exact test, and that they will make a reasonable choice wherever the plan leaves one open. What they cannot know is what you decided: which files, which names and signatures, which values from the spec, which tests prove each task. Document those. Bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."
**Context:** Run in a dedicated worktree (created by brainstorming skill).
**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`. NEVER write to `~/.claude/plans/` -- ignore the plan mode default path.
**REQUIRED:** Run Plan Verification Checklist, then rule-of-five-plans before presenting the plan as ready. Verify *what* before polishing *how* -- scope errors caught early save wasted polish on deleted tasks.

## Platform Routing

- **Claude Code:** Use the mandatory task sequence below. Do not call ExitPlanMode until verification is complete. Claude Code command/tool wording in this file is intentional for the Claude platform.
- **Codex:** Follow `references/codex-plan-verification.md` for the native Codex planning and verification flow. Use `update_plan` for phase tracking, write the plan with normal file edits, and do not enter Claude plan mode or translate Claude-only tools.

## Mandatory Tasks (Enforcement)

Create these 7 native tasks at plan start. After each task is created, use
`TaskUpdate(addBlockedBy=[previous-task-id])` to record the dependency. Complete
the sequence before leaving plan mode; TaskList makes unfinished passes visible:

1. **Write draft plan** -- Initial structure with all tasks, dependencies, file lists. Read `references/plan-step-content.md` before drafting tasks.
   - **After saving plan — context check:** Look at your model ID in the system prompt (e.g., `claude-opus-5-5[1m]`).
     - **Extended context:** The model ID contains `[1m]`, or belongs to a 1M-native family (`sonnet-5`, `fable-5`). Skip compact. Announce "Plan written to {path}. Proceeding to verification." and continue to task 2.
     - **Standard context (~200k):** Show the copy-pasteable `/compact` command (see `references/announcements-protocol.md`) and wait for the user's follow-up before proceeding to task 2.
     - **No human present** (headless or unattended run): skip the `/compact` wait and continue to task 2.
2. **Plan Verification Checklist** -- Complete/Accurate/Commands valid/YAGNI/Minimal/Not over-engineered
3. **Rule-of-five-plans: Draft pass** -- Shape and structure
4. **Rule-of-five-plans: Feasibility pass** -- Can every step be executed? Deps available? Paths valid?
5. **Rule-of-five-plans: Completeness pass** -- Every requirement traced to a task?
6. **Rule-of-five-plans: Risk pass** -- What could go wrong? Migration, breaking changes?
7. **Rule-of-five-plans: Optimality pass** -- Simplest approach? YAGNI?

**Task 2: Inline Self-Review.** The orchestrator runs the Plan Verification Checklist directly — no sub-agent dispatch. The orchestrator just wrote the plan and has full context; a sub-agent would only re-read it from disk. Mark task 2 in_progress, run each checklist item against the plan, edit the plan to fix any issues, mark task 2 completed, then proceed to task 3.

**Tasks 3–7: Sub-Agent Dispatch.** After task 2 completes, dispatch each rule-of-five-plans pass sequentially as a **sonnet** sub-agent using the template in `references/verification-dispatch.md`. Mark each native task in_progress before dispatch, completed after collecting verdict. On a BLOCKED/FAIL verdict, fix the plan and re-run that pass once; if it still fails, record a ruling in the plan's Verification Record and continue. After all 5 verdicts collected, assemble Verification Record (see `references/verification-footer.md`) and append to plan file.

See `references/task-enforcement-examples.md` for full TaskCreate blocks and dispatch loop.

## Step Granularity

Each step is one action with a checkable result: write failing test, run it to verify failure, implement, run test to verify pass, commit.
Split tasks only where a reviewer could reject one while approving its neighbor.

## What a Step Contains

A step is done when the implementer can write exactly one reasonable thing from it: unambiguous, not complete.

- **Test step:** the test's name and its assertions, as code, with the spec's exact values in them.
- **Code step:** the exact signature (name, parameters, return type), the file, and the specific values the spec pins (messages, constants, ordering rules). The implementer writes the body. Include a body only for an algorithm the signature and tests do not determine, or for exact copy the spec fixes.
- **Verification step:** the command and the output that means it passed.
- **Reference to another task:** that task's `**Interfaces:**` block says what to use; do not repeat its code.

A plan is the set of decisions the implementer cannot make alone. A plan longer than the code it describes has written the code instead. Lines that decide nothing ("TBD", "handle edge cases", "add validation", a type no task defines) are the opposite failure. Do not build or run the product's code while planning. Detail and the task template: `references/plan-step-content.md`.

## Plan Document Header

Every plan MUST start with:

```markdown
# [Feature Name] Implementation Plan

> **After approval:** convert this plan to a beads epic with plan2beads, then choose SDD or Native per references/execution-handoff.md.

**Spec:** [path or URL of the approved spec, optional]
**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
**Key Decisions:**
- **[Area]:** [Choice] -- [Why over alternatives]

## Review Focus

- **Task N:** [Input or condition implied by the spec but absent from its explicit examples] should [behavior a reasonable user expects]. Test: [test name or exact command added to Task N].
---
```

Key Decisions: 3-5 decisions implementers might question. WHAT was decided AND WHY. Focus where alternatives existed.

Optional metadata (`**Spec:**`, `## Global Constraints`, `**Interfaces:**`) survives plan2beads import; see `references/plan-step-content.md`.

## Review Focus

For new plans, include `## Review Focus`. Before calling the plan ready, reread the spec or agreed requirements for inputs and failure modes they imply but do not name as task tests. Record up to five that would matter most to a user. Each item names the owning task, expected behavior, and the test added to that task's steps. The section is a prompt to find missing coverage, not a substitute for the test. If inspection finds none, write `- None identified after checking implied inputs.` instead of inventing cases. plan2beads keeps the full list on the epic and copies each item into its owning child task. Legacy plans without the section still import unchanged.

## Global Constraints

**OPTIONAL. Keep it short** — `plan2beads` threads this block verbatim into every child task body so each implementer carries it. Anything here multiplies by N tasks; trim ruthlessly.

Use for epic-wide rules every implementer must honor: version floors, commit/push restrictions, mirror-sync requirements, shared invariants. Rules that apply to only one or two tasks belong in those tasks' bodies. Template and example: `references/plan-step-content.md`. If absent, import is unchanged.

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

Use the task template in `references/plan-step-content.md`. Step 3 is a signature line, `Implement fn(args) -> R in path`, plus one line on the approach only where the signature and tests leave a choice.

## Plan Verification Checklist

Before rule-of-five-plans, verify scope and accuracy:

- **Complete** -- All requirements from brainstorming addressed?
- **Accurate** -- File paths verified? (existing files exist, new files in correct locations)
- **Commands valid** -- Test/build commands correct and runnable?
- **YAGNI** -- Every task directly serves a stated requirement?
- **Minimal** -- Could any task be removed/combined without losing functionality?
- **Not over-engineered** -- Simplest approach that works?
- **Key Decisions documented** -- 3-5 decisions with rationale?
- **Review Focus covered** -- Each nonempty focus item names an owning task and a test step that exercises the implied input or failure mode?
- **Context sections present** -- Purpose for non-obvious tasks? Not In Scope for boundary tasks?
- **File Structure complete** -- Every file in task `Files:` sections appears in File Structure table? No undeclared files?
- **Step scan** -- Every step lets the implementer write exactly one reasonable thing: no line that decides nothing, no function body the signature and tests already determine?
- **Proportion** -- Compare plan length to the spec's. Several times longer, or mostly code blocks = transcript; replace bodies with signatures, test names and assertions.
- **Importable task headings** -- Every implementation task starts with `### Task N:` (H3), so plan2beads can create its child issue?

## Remember

- Exact file paths always
- Decisions, not transcripts: exact signatures, test assertions, and the spec's values (not "add validation", and not full bodies)
- Exact commands with expected output
- Reference relevant skills by name
- **Every task needs `Depends on:`, `Complexity:`, and `Files:`**
- **Include `Purpose:`, `Not In Scope:`, `Gotchas:` where needed**
- **File Structure table before tasks — tasks reference it, never introduce undeclared files**
- **Review Focus names task-owned tests for implied inputs, or records that none were found**
- **Run Plan Verification Checklist before rule-of-five-plans**
- **Announce each verification phase** (see `references/announcements-protocol.md`)
- **Plan MUST end with Verification Record** (see `references/verification-footer.md`)
- **After approval, follow execution handoff** (see `references/execution-handoff.md`)

## Reference Files

- `references/plan-step-content.md`: What a Step Contains, the task template, optional metadata
- `references/task-enforcement-examples.md`: Full TaskCreate blocks with blocked-by relationships
- `references/codex-plan-verification.md`: Codex-native plan drafting, verification, and rule-of-five flow
- `references/dependency-analysis.md`: Identifying and expressing task dependencies
- `references/file-lists.md`: File list format, parallel execution rules, and complexity estimation
- `references/announcements-protocol.md`: Required announcement templates for verification phases
- `references/verification-dispatch.md`: Sub-agent prompt templates and dispatch flow for verification passes
- `references/verification-footer.md`: Plan Document Footer template (Verification Record)
- `references/execution-handoff.md`: Post-plan workflow: plan2beads -> choose SDD or Native (executing-plans)

<!-- compressed: 2026-02-11, original: 915 words, compressed: 599 words -->
