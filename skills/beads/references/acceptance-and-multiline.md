# Acceptance Criteria Formatting & Multi-Line Descriptions

## Acceptance Criteria Formatting

```bash
# Commas (single line)
bd create ... --acceptance "Criterion 1, Criterion 2, Criterion 3"

# Newlines with ANSI-C quoting (displays better in bd show)
bd create ... --acceptance $'Criterion 1\nCriterion 2\nCriterion 3'

# NEVER use semicolons
bd create ... --acceptance "Criterion 1; Criterion 2"  # TRIGGERS PROMPT
```

## Multi-Line Descriptions

```bash
# Step 1: Write description to temp file
Write tool -> temp/desc.md

# Step 2: Reference with --body-file
bd create --silent --type epic "Title" --body-file temp/desc.md -p 1
```

The `temp/` directory exists at repo root. Reuse/overwrite the same temp file for multiple issues.
