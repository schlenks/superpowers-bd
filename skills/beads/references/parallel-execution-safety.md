# Parallel Execution Safety

## File Conflict Detection

When dispatching multiple subagents, check for file overlap in `## Files` sections:

```
Issue hub-abc.1 files: [user.model.ts, models/index.ts]
Issue hub-abc.2 files: [jwt.utils.ts, utils/index.ts]
Issue hub-abc.3 files: [auth.service.ts, models/index.ts] <- CONFLICT with .1
```

**Rules:**
- Issues with NO file overlap can run in parallel
- If file appears in multiple ready issues, dispatch lowest-numbered first
- Defer conflicting issues to next wave
- If `## Files` section missing, treat as conflicting with ALL others

## Epic Scoping

`bd ready` shows ALL ready issues across ALL epics. To focus on one epic:

```bash
bd show <epic-id> --json       # Get child issue IDs
bd ready                       # Cross-reference: only work on children of your epic
```

**Why this matters:** If you have multiple epics, `bd ready` mixes them. Check that the issue you pick is a child of the epic you're working on.

## Priority Values

Priority is 0-4, NOT high/medium/low:

| Value | Level | Use For |
|-------|-------|---------|
| `0` or `P0` | Critical | Production blockers |
| `1` or `P1` | High | Sprint commitments |
| `2` or `P2` | Medium | Standard work (default) |
| `3` or `P3` | Low | Nice-to-have |
| `4` or `P4` | Backlog | Future consideration |

## ID Format

Issue IDs use format `<prefix>-<hash>` (e.g., `hub-abc`). Child issues append `.N` (e.g., `hub-abc.1`, `hub-abc.2`).

## Commit Conventions

Include issue IDs in commit messages for traceability:

```bash
git commit -m "Fix validation bug (hub-abc)"
```

This enables `bd doctor` to detect orphaned issues (work committed but issues not closed).
