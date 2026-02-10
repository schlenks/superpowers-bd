# bd edit Warning & Sandbox Incompatibility

## NEVER Use `bd edit`

`bd edit` opens an interactive editor that AI agents cannot use. Always use `bd update` with flags:

```bash
# NEVER
bd edit hub-abc

# ALWAYS
bd update hub-abc --title "New Title" --body-file temp/desc.md
bd update hub-abc --status in_progress
bd update hub-abc --acceptance $'Criterion 1\nCriterion 2'
```

## Sandbox Incompatibility

The `bd` CLI is a native macOS binary. It does **not** work in Claude Code's Linux sandbox. If you see "command not found" errors, you're likely in sandbox mode.
