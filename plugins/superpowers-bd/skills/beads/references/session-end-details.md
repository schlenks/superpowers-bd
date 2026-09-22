# Session End Protocol Details

## Auto-Commit Handles Persistence

With `dolt.auto-commit: on` (the default), every write command auto-commits to Dolt. No explicit sync or commit is needed at session end — data is already persisted.

The superpowers-bd `session-end.sh` hook runs `bd dolt commit` as a safety net for non-default configs (`batch`/`off` modes). This is a no-op if auto-commit already ran.

## When to Use Manual Commands

- **`bd dolt commit`**: Only needed if `dolt.auto-commit: off` or `batch`
- **`bd dolt push`**: Only needed if remotes are configured and you want to sync upstream
- **`bd export`**: For creating JSONL backups before destructive operations

## Ephemeral Branches

Merge to main locally rather than pushing. Ephemeral data (wisps) is excluded from Dolt versioning via `dolt_ignore`.
