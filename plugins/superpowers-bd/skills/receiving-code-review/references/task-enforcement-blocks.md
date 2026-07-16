# Task Enforcement Blocks

Full TaskCreate blocks for the Response Pattern enforcement.

## Native Task Definitions

```
TaskCreate: "READ: Complete feedback without reacting"
  description: "Read all feedback items completely before doing anything else."
  activeForm: "Reading feedback"

TaskCreate: "UNDERSTAND: Restate requirements"
  description: "For each item, restate the requirement in your own words. Ask for clarification on unclear items."
  activeForm: "Understanding feedback"
TaskUpdate: understand-task-id
  addBlockedBy: [read-task-id]

TaskCreate: "VERIFY: Check against codebase"
  description: "Check each suggestion against codebase reality. Does current code exist for a reason? Will change break anything?"
  activeForm: "Verifying against codebase"
TaskUpdate: verify-task-id
  addBlockedBy: [understand-task-id]

TaskCreate: "EVALUATE: Technical soundness"
  description: "Is each suggestion technically sound for THIS codebase? Does it violate YAGNI? Conflict with architecture?"
  activeForm: "Evaluating suggestions"
TaskUpdate: evaluate-task-id
  addBlockedBy: [verify-task-id]

TaskCreate: "IMPLEMENT: Apply changes"
  description: "Implement one item at a time. Test each change. Verify no regressions."
  activeForm: "Implementing changes"
TaskUpdate: implement-task-id
  addBlockedBy: [evaluate-task-id]
```

This records the expected order so TaskList exposes a skipped VERIFY phase.
