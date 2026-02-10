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
