# Report and Feedback Flow

## Step 3: Report (Task-Tracked)

**Create a checkpoint task after each batch:**

```
TaskCreate: "Batch N complete - report for feedback"
  description: "Report: what implemented, verification output, rule-of-five passes applied. Then wait for human feedback."
  activeForm: "Reporting batch completion"
```

When batch complete:
- Show what was implemented
- Show verification output
- Note any rule-of-five passes applied to significant artifacts
- Show newly unblocked issues: `bd ready`
- Say: "Ready for feedback."
- **Mark checkpoint task as `completed`**

## Step 4: Continue (Task-Tracked)

**Create a feedback task before proceeding:**

```
TaskCreate: "Await human feedback on batch N"
  description: "BLOCKED: Cannot proceed until human provides feedback on batch report. Mark complete when feedback received."
  activeForm: "Awaiting feedback"
  addBlockedBy: [report-task-id]

TaskCreate: "Execute batch N+1"
  description: "Execute next batch of newly unblocked issues."
  activeForm: "Executing batch"
  addBlockedBy: [feedback-task-id]
```

**ENFORCEMENT:** The "Execute batch N+1" task is blocked until:
- The report task is completed
- The feedback task is completed (human feedback received)

Based on feedback:
- Apply changes if needed
- Mark feedback task as `completed`
- Execute next batch (newly unblocked issues)
- Repeat until all issues closed
