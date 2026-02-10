# Dependency Analysis

When planning tasks, explicitly identify what each task needs:

| Dependency Type | Example | How to Express |
|-----------------|---------|----------------|
| Data model | Service needs User entity | `Depends on: Task 1 (User model)` |
| Import/export | Route imports service | `Depends on: Task 2 (Auth service)` |
| Config | Feature needs env vars | `Depends on: Task 0 (Config setup)` |
| Schema | Migration before model | `Depends on: Task 1 (DB migration)` |
| None | Independent task | `Depends on: None` |

## Rules

- **Always explicit:** Every task MUST have `Depends on:` line
- **Be specific:** List exact task numbers, not "previous tasks"
- **Minimize dependencies:** Only list what's truly required
- **Enable parallelism:** Tasks with `Depends on: None` can run in parallel

## Example Dependency Structure

```
Task 1: User Model           Depends on: None              <- READY
Task 2: JWT Utils            Depends on: None              <- READY (parallel with 1)
Task 3: Auth Service         Depends on: Task 1            <- Blocked by 1 only
Task 4: Login Endpoint       Depends on: Task 2, Task 3    <- Blocked by 2 AND 3
Task 5: Logout Endpoint      Depends on: Task 3            <- Blocked by 3 only
```

This enables: Tasks 1 & 2 parallel -> Task 3 -> Tasks 4 & 5 parallel
