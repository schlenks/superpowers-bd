# Troubleshooting

## Database Out of Sync

```bash
bd import --force    # Force refresh even when DB appears synced
```

## Git Worktree Limitations

Daemon mode does not work correctly with git worktrees because multiple worktrees share the same `.beads` database. Solutions:

```bash
# Option 1: Disable daemon
export BEADS_NO_DAEMON=1
# Or use --no-daemon flag on commands

# Option 2: Configure sync branch
bd config set sync.branch beads-sync
```

## Daemon Issues

```bash
bd daemons killall   # Restart daemon to match CLI version
```

## Version Mismatch Warning

`bd doctor` may flag version mismatches between CLI, daemon, and plugin. These don't break basic operations but should be synchronized.

## Merge Conflicts in JSONL

Each line is independent. Keep both sides unless same ID appears - then retain newest by `updated_at`.

```bash
git checkout --theirs .beads/issues.jsonl
bd import
```

## Protected Branches

For repositories where you can't push directly to main:

```bash
bd init --branch beads-sync    # Initialize with separate sync branch
```

This commits beads changes to `beads-sync` branch instead of main.
