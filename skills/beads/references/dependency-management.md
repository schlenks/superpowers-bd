# Dependency Management

## Dependency Types

| Type | Effect on `bd ready` | Use For |
|------|---------------------|---------|
| `blocks` | Blocks dependent issues | Sequential execution |
| `related` | Does not block | Informational links |
| `discovered-from` | Does not block | Audit trail |
| `replies-to` | Does not block | Discussion threading |

**Only `blocks` dependencies affect what appears in `bd ready`.** Use `--deps` for blocking dependencies.

## Common Mistake: No Dependencies

If you create "Step 1", "Step 2", "Step 3" without `--deps`, they ALL appear in `bd ready` simultaneously:

```bash
# WRONG - All three appear as ready at once
bd create "Step 1" ...
bd create "Step 2" ...
bd create "Step 3" ...

# CORRECT - Step 2 waits for Step 1, etc.
bd create --silent "Step 1" ...          # Returns: hub-abc.1
bd create --silent "Step 2" ... --deps "hub-abc.1"
bd create --silent "Step 3" ... --deps "hub-abc.2"
```

## Creating Dependencies

Tasks depend on other tasks via `--deps`. Create tasks in order so dependencies reference earlier IDs.

```bash
# Task 1: No dependencies
bd create --silent --parent hub-abc "User Model" --body-file temp/desc.md -p 2
# Returns: hub-abc.1

# Task 2: No dependencies (can parallelize with Task 1)
bd create --silent --parent hub-abc "JWT Utils" --body-file temp/desc.md -p 2
# Returns: hub-abc.2

# Task 3: Depends on Task 1
bd create --silent --parent hub-abc "Auth Service" --body-file temp/desc.md --deps "hub-abc.1" -p 2
# Returns: hub-abc.3

# Task 4: Depends on Tasks 2 and 3
bd create --silent --parent hub-abc "Login Endpoint" --body-file temp/desc.md --deps "hub-abc.2,hub-abc.3" -p 2
```

## Dependency Validation

| Issue | Action |
|-------|--------|
| Forward reference (Task 2 depends on Task 5) | Warn and skip - indicates plan ordering issue |
| Self-reference (Task 3 depends on Task 3) | Warn and skip |
| Non-existent task | Warn and skip |
| Circular dependency | Run `bd dep cycles` to detect, then `bd dep remove` to fix |

## Verification After Creation

**Always verify** dependency structure after creating issues:

```bash
bd ready              # Tasks with no deps should appear
bd blocked            # Dependent tasks should appear
bd graph <epic-id>    # Visual verification
```

## Deadlock Detection

If `bd ready` shows nothing but issues remain open:
1. Run `bd blocked` to see dependency chain
2. Run `bd dep cycles` to check for circular dependencies
3. Check if you forgot to `bd close` a completed issue
4. Run `bd graph <epic>` for visual dependency view
