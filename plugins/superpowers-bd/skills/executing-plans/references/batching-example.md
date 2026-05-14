# Dependency-Aware Batching Example

## Full Walkthrough

```
Initial state:
  bd ready: hub-epic.1, hub-epic.2 (no deps)
  bd blocked: hub-epic.3 (by .1), hub-epic.4 (by .2, .3)

Batch 1: Work on hub-epic.1 and hub-epic.2
  [complete and close both]

  bd ready: hub-epic.3 (unblocked by .1 closing)
  bd blocked: hub-epic.4 (still waiting on .3)

Batch 2: Work on hub-epic.3
  [complete and close]

  bd ready: hub-epic.4 (unblocked by .3 closing)

Batch 3: Work on hub-epic.4
  [complete and close]

All done!
```

## Key Points

- `bd ready` dynamically shows what is unblocked after each close
- `bd blocked` shows what is still waiting and why
- Always check both after completing a batch to understand the new state
- Issues may become ready mid-batch if their only blocker was closed earlier in the same batch
