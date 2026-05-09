# Verification Dispatch

The Plan Verification Checklist (task 2) is run inline by the orchestrator, not dispatched. This file describes only the 5 rule-of-five passes (tasks 3–7).

Dispatch each rule-of-five pass (tasks 3–7) as a sequential foreground sub-agent. Each sub-agent gets a fresh context window, reads the plan from disk, applies its single lens, edits the plan, and returns a structured verdict.

## Dispatch Flow

After task 2 (inline checklist) completes, the main session drives this loop for tasks 3–7. On `[1m]` (default) dispatch begins immediately after task 2; on 200k, wait for compact + "continue" before task 2, then proceed to task 3 after.

```
for each pass in [draft, feasibility, completeness, risk, optimality]:
  1. TaskUpdate(task_id, status: "in_progress")
  2. Announce: "Dispatching verification sub-agent: {pass_name}..."
  3. Task(subagent_type: "general-purpose", model: "sonnet",
         description: "Verify plan: {pass_name}",
         prompt: <built from template below>)
  4. Collect verdict from sub-agent response
  5. Announce: "{pass_name} verdict: {STATUS} — {SUMMARY}"
  6. If verdict STATUS == "BLOCKED" or "FAIL": stop, report to user, do NOT continue
  7. TaskUpdate(task_id, status: "completed")

After all 5 passes:
  8. Read plan file one final time
  9. Assemble Verification Record from accumulated verdicts
  10. Append Verification Record to plan file (see references/verification-footer.md)
  11. Display the populated Verification Record to the user (see references/announcements-protocol.md)
  12. ExitPlanMode
```

## Prompt Template — Rule-of-Five Passes (Draft, Feasibility, Completeness, Risk, Optimality)

Build each sub-agent prompt by substituting the placeholders from the pass definitions below:

```
You are verifying an implementation plan. You have ONE job: the {pass_name} pass.

## Your Pass
**Focus:** {pass_focus}
**Checklist:**
{checklist_items}
**Exit when:** {exit_criteria}

## Instructions
1. Read the plan file: {plan_path}
2. Re-read the FULL plan through the {pass_name} lens ONLY. Do not evaluate other lenses.
3. Evaluate every task against the checklist above.
4. Edit the plan file to fix any issues found.
5. Return your verdict in the EXACT format below — nothing after the verdict block.

## Verdict Format
PASS: {pass_name}
STATUS: CLEAN | EDITED | BLOCKED
CHANGES: <number of edits made>
SUMMARY: <1-3 sentences — what you found and changed>
```

## Pass Definitions

### Pass: Draft
**Focus:** Shape and structure. Get the outline right. Breadth over depth.
**Checklist:**
- All major sections exist (goal, architecture, tasks, verification)
- Task list is complete — every deliverable has a task
- Dependencies sketched (even if rough)
- Key Decisions section present with rationale
- Header template followed (Goal, Architecture, Tech Stack, Key Decisions)

**Exit when:** All major sections exist; task list complete.

### Pass: Feasibility
**Focus:** Can every step actually be executed?
**Checklist:**
- File paths verified via Glob (existing files exist, new files in correct locations)
- Commands tested or known to work (`pytest`, `npm test`, etc.)
- Dependencies available (libraries installed, APIs accessible)
- Estimates realistic (2-5 min per bite-sized step)
- No circular dependencies in task graph
- External service requirements documented

**Exit when:** No infeasible steps; all references verified.

### Pass: Completeness
**Focus:** Every requirement traced to a task?
**Checklist:**
- Every requirement from brainstorming/spec has a corresponding task
- Error handling tasks present where needed
- Rollback/cleanup tasks for destructive operations
- Documentation updates included
- Test tasks present for every feature task
- `Depends on:`, `Complexity:`, and `Files:` sections on every task
- File Structure table present with all files mapped to responsibilities
- Every task `Files:` entry traceable to File Structure table

**Exit when:** Every requirement maps to task(s).

### Pass: Risk
**Focus:** What could go wrong?
**Checklist:**
- Migration risks identified (data loss, schema changes)
- Breaking changes documented (API changes, removed features)
- Parallel execution conflicts (file conflicts between tasks)
- External dependency failures (what if API is down?)
- Rollback plan exists for risky steps
- Security implications considered

**Exit when:** Risks identified and mitigated.

### Pass: Optimality
**Focus:** Simplest approach? YAGNI?
**Checklist:**
- Every task directly serves a stated requirement
- No over-engineering (abstractions for one use case, unnecessary configurability)
- Tasks that could be combined without losing clarity are combined
- Simplest approach chosen (not most elegant)
- No speculative tasks for "future" requirements
- You'd defend every task to a senior colleague

**Exit when:** You'd defend every task to a senior colleague.

## Error Handling

- **BLOCKED verdict:** Stop the dispatch loop immediately. Report the SUMMARY to the user and do NOT continue to the next pass. The user must resolve the issue before verification can proceed.
- **Malformed verdict:** If a sub-agent returns output that doesn't match the verdict format, treat it as BLOCKED with SUMMARY: "Sub-agent returned malformed verdict. Re-run this pass."
