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

TaskCreate: "Rule-of-five: Draft pass"
  description: "Shape and structure. Get the outline right."
  activeForm: "Draft pass"
  addBlockedBy: [checklist-task-id]

TaskCreate: "Rule-of-five: Correctness pass"
  description: "Logic, accuracy, file paths. Does everything work?"
  activeForm: "Correctness pass"
  addBlockedBy: [draft-pass-id]

TaskCreate: "Rule-of-five: Clarity pass"
  description: "Can someone unfamiliar follow this? Simplify."
  activeForm: "Clarity pass"
  addBlockedBy: [correctness-pass-id]

TaskCreate: "Rule-of-five: Edge Cases pass"
  description: "What's missing? Error handling? Rollback?"
  activeForm: "Edge cases pass"
  addBlockedBy: [clarity-pass-id]

TaskCreate: "Rule-of-five: Excellence pass"
  description: "Polish. Would you show this to a senior colleague?"
  activeForm: "Excellence pass"
  addBlockedBy: [edge-cases-pass-id]
```

## Enforcement

- Cannot call ExitPlanMode until all 7 tasks show `status: completed`
- Each task is blocked by the previous, enforcing the sequence
- TaskList shows exactly where you are in the process
- Skipping tasks is visible - blocked tasks cannot be marked in_progress
