# Sync Workflow

## Dolt Persistence Commands

| Command | Purpose |
|---------|---------|
| `bd dolt commit` | Create Dolt version snapshot (manual, when auto-commit is off) |
| `bd dolt push` | Push to configured remotes |
| `bd dolt pull` | Pull and merge from remotes |
| `bd dolt start` | Start Dolt SQL server |
| `bd dolt stop` | Stop Dolt SQL server |
| `bd dolt remote add` | Register a remote (https, s3, file://) |

## Auto-Commit (Default: On)

With `dolt.auto-commit: on` (the default), every write command (`bd create`, `bd update`, `bd close`, etc.) automatically calls `DOLT_COMMIT` after execution. No manual commit needed.

| Setting | Behavior |
|---------|----------|
| `dolt.auto-commit: on` | Immediate commit after each write (default) |
| `dolt.auto-commit: off` | Manual `bd dolt commit` required |
| `dolt.auto-commit: batch` | Accumulate in working set until explicit commit |

## Backup & Export

| Command | Purpose |
|---------|---------|
| `bd export` | Generate JSONL snapshot (disaster recovery) |
| `bd export --all` | Include closed issues |
| `bd backup sync` | Create timestamped snapshot in `.beads/backup/` |

## Daily Maintenance

| Frequency | Command | Purpose |
|-----------|---------|---------|
| Daily | `bd doctor` | Diagnose and fix issues |
| Every few days | `bd cleanup` | Keep issue count manageable |

## Deprecated

`bd sync` is deprecated (removed in v0.58.0). Use `bd dolt push`/`bd dolt pull` for remote sync, or rely on auto-commit for local persistence.
