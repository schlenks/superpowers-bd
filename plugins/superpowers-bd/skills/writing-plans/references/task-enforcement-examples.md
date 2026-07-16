# Task Enforcement Examples

Full TaskCreate blocks for the 7 mandatory tasks. Each task is blocked by the previous, enforcing the sequence.

```
TaskCreate: "Write draft plan"
  description: "Create initial plan structure with all tasks, dependencies, and file lists."
  activeForm: "Writing draft plan"

TaskCreate: "Plan Verification Checklist"
  description: "Verify: Complete, Accurate, Commands valid, YAGNI, Minimal, Not over-engineered."
  activeForm: "Running verification checklist"
TaskUpdate: checklist-task-id
  addBlockedBy: [draft-task-id]

TaskCreate: "Rule-of-five-plans: Draft pass"
  description: "Shape and structure. All sections sketched, task list complete."
  activeForm: "Draft pass"
TaskUpdate: draft-pass-id
  addBlockedBy: [checklist-task-id]

TaskCreate: "Rule-of-five-plans: Feasibility pass"
  description: "Can every step be executed? Deps available? Paths valid? Estimates realistic?"
  activeForm: "Feasibility pass"
TaskUpdate: feasibility-pass-id
  addBlockedBy: [draft-pass-id]

TaskCreate: "Rule-of-five-plans: Completeness pass"
  description: "Every requirement traced to a task? Gaps? Missing rollback?"
  activeForm: "Completeness pass"
TaskUpdate: completeness-pass-id
  addBlockedBy: [feasibility-pass-id]

TaskCreate: "Rule-of-five-plans: Risk pass"
  description: "What could go wrong? Migration, data loss, breaking changes, parallel conflicts?"
  activeForm: "Risk pass"
TaskUpdate: risk-pass-id
  addBlockedBy: [completeness-pass-id]

TaskCreate: "Rule-of-five-plans: Optimality pass"
  description: "Simplest approach? YAGNI? Could tasks be combined? Defend every task."
  activeForm: "Optimality pass"
TaskUpdate: optimality-pass-id
  addBlockedBy: [risk-pass-id]
```

## Enforcement

- Do not call ExitPlanMode until all 7 tasks show `status: completed`
- Record each dependency with TaskUpdate after task creation
- TaskList shows exactly where you are in the process
- Skipping tasks or advancing out of order is visible in TaskList

## Task 2: Inline Self-Review

After task 1 completes, the orchestrator runs the Plan Verification Checklist inline:

```
TaskUpdate(checklist-task-id, status: "in_progress")
→ Announce: "Running Plan Verification Checklist inline..."
→ Read the plan file
→ For each item (Complete, Accurate, Commands valid, YAGNI, Minimal, Not over-engineered, Key Decisions, Context sections, File Structure complete):
    - Evaluate against the plan
    - Use Glob/Grep to verify file paths and commands where needed
    - Edit the plan inline to fix any issues
→ Announce per-item results (see references/announcements-protocol.md)
→ If any item fails irrecoverably: stop, report to user
→ TaskUpdate(checklist-task-id, status: "completed")
```

## Sub-Agent Dispatch (Tasks 3–7)

After task 2 completes, drive this loop for tasks 3–7:

```
TaskUpdate(id, status: "in_progress")
→ Announce: "Dispatching verification sub-agent: {pass_name}..."
→ Agent(subagent_type: "general-purpose", model: "sonnet",
       description: "Verify plan: {pass_name}",
       prompt: <verification template with pass definition inlined>)
→ Collect verdict
→ Announce: "{pass_name} verdict: {STATUS} — {SUMMARY}"
→ If BLOCKED/FAIL: stop, report to user
→ TaskUpdate(id, status: "completed")
→ Next task
```

See `references/verification-dispatch.md` for full prompt templates and pass definitions.
