# Task Enforcement Examples

Full TaskCreate blocks for the 7 mandatory tasks. Each task is blocked by the previous, enforcing the sequence.

```
TaskCreate: "Write draft plan"
  description: "Create initial plan structure with all tasks, dependencies, and file lists."
  activeForm: "Writing draft plan"

TaskCreate: "Plan Verification Checklist"
  description: "Verify: Complete, Accurate, Commands valid, YAGNI, Minimal, Not over-engineered."
  activeForm: "Running verification checklist"
  addBlockedBy: [draft-task-id]

TaskCreate: "Rule-of-five-plans: Draft pass"
  description: "Shape and structure. All sections sketched, task list complete."
  activeForm: "Draft pass"
  addBlockedBy: [checklist-task-id]

TaskCreate: "Rule-of-five-plans: Feasibility pass"
  description: "Can every step be executed? Deps available? Paths valid? Estimates realistic?"
  activeForm: "Feasibility pass"
  addBlockedBy: [draft-pass-id]

TaskCreate: "Rule-of-five-plans: Completeness pass"
  description: "Every requirement traced to a task? Gaps? Missing rollback?"
  activeForm: "Completeness pass"
  addBlockedBy: [feasibility-pass-id]

TaskCreate: "Rule-of-five-plans: Risk pass"
  description: "What could go wrong? Migration, data loss, breaking changes, parallel conflicts?"
  activeForm: "Risk pass"
  addBlockedBy: [completeness-pass-id]

TaskCreate: "Rule-of-five-plans: Optimality pass"
  description: "Simplest approach? YAGNI? Could tasks be combined? Defend every task."
  activeForm: "Optimality pass"
  addBlockedBy: [risk-pass-id]
```

## Enforcement

- Cannot call ExitPlanMode until all 7 tasks show `status: completed`
- Each task is blocked by the previous, enforcing the sequence
- TaskList shows exactly where you are in the process
- Skipping tasks is visible - blocked tasks cannot be marked in_progress

## Sub-Agent Dispatch

After compact + "continue", the main session drives this loop for tasks 2-7:

```
TaskUpdate(id, status: "in_progress")
→ Announce: "Dispatching verification sub-agent: {pass_name}..."
→ Task(subagent_type: "general-purpose", model: "sonnet",
       description: "Verify plan: {pass_name}",
       prompt: <verification template with pass definition inlined>)
→ Collect verdict
→ Announce: "{pass_name} verdict: {STATUS} — {SUMMARY}"
→ If BLOCKED/FAIL: stop, report to user
→ TaskUpdate(id, status: "completed")
→ Next task
```

See `references/verification-dispatch.md` for full prompt templates and pass definitions.
