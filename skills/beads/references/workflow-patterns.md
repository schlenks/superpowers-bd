# Workflow Patterns

## Autonomous Work Loop

Repeat this cycle until `bd ready` returns nothing:

```bash
bd ready                              # 1. Find available work
bd show <id>                          # 2. Review issue details
bd update <id> --claim                # 3. Claim it (sets assignee + in_progress)
# ... do the work ...
bd close <id> --reason "summary"      # 4. Close when done
bd ready                              # 5. Check what's unblocked, repeat
```

## Completing Work

```bash
bd close <id1> <id2> ...              # Close completed issues (unblocks dependents)
bd sync                               # Export changes
git add . && git commit -m "..."      # Commit code changes
```

## Status Values

| Status | Meaning |
|--------|---------|
| `open` | Not started |
| `in_progress` | Currently working |
| `blocked` | Waiting on dependencies (auto-set by beads) |
| `deferred` | Postponed (hidden from `bd ready` until defer date) |
| `closed` | Complete |
