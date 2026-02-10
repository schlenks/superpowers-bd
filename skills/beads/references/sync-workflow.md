# Sync Workflow

## Key Sync Commands

| Command | Purpose |
|---------|---------|
| `bd sync` | Full sync (import + export + git) |
| `bd sync --status` | Check sync status without syncing |
| `bd sync --from-main` | Pull beads updates from main branch |
| `bd sync --flush-only` | Export to JSONL without git operations |
| `bd sync --import-only` | Import from JSONL after git pull |
| `bd sync --check` | Pre-sync integrity check |

## JSONL is Source of Truth

After `git pull`, JSONL is the source of truth - the database syncs to match, not vice versa.

## Daily Maintenance

Run these commands regularly:

| Frequency | Command | Purpose |
|-----------|---------|---------|
| Daily | `bd doctor` | Diagnose and fix issues |
| Every few days | `bd cleanup` | Keep issue count under 200 |
| Weekly | `bd upgrade` | Stay current with releases |
