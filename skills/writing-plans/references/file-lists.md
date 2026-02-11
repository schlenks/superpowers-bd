# File List Requirements

The `Files:` section enables safe parallel execution by detecting conflicts.

## Format

```markdown
**Files:**
- Create: `apps/api/src/models/user.model.ts`
- Modify: `apps/api/src/models/index.ts:15-20`
- Test: `apps/api/src/__tests__/models/user.test.ts`
```

## Rules

- List ALL files the task will touch
- Be specific about line ranges for modifications when known
- Include test files
- If two tasks modify the same file, they CANNOT run in parallel

## Complexity Estimation

Estimate task complexity based on the Files section and implementation steps. This drives model selection during execution (see `subagent-driven-development`).

| Level | Label | Heuristic |
|-------|-------|-----------|
| **simple** | `complexity:simple` | ≤1 non-test file + ≤1 implementation step. Wording/config changes, adding exports, single-file modify. |
| **standard** | `complexity:standard` | 2-3 non-test files + clear requirements. Routine coding, most tasks. |
| **complex** | `complexity:complex` | 4+ non-test files OR new architectural patterns OR security-sensitive OR integration work. |

Default if unsure: `standard`
