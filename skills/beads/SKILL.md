---
name: beads
description: Use when working with the beads (bd) CLI for issue tracking, managing epics and tasks, handling dependencies, or starting/ending coding sessions with persistent work tracking
---

# Beads (bd) Usage Rules

## Overview

Reference for AI agents using the beads issue tracker CLI with Claude Code.

**Core principle:** Beads tracks work across sessions with dependency-aware execution. Use `bd ready` to find unblocked work, `bd close` to complete it, and `bd sync` to persist changes.

**When to use this skill:**
- Using `bd` commands for issue tracking
- Managing epics, tasks, and dependencies
- Starting or ending coding sessions with persistent work

## First-Time Setup

**If `bd` command is not found**, tell the user:

> Beads isn't installed yet. Run this to set it up for local-only use (won't affect the repo):
> ```bash
> curl -fsSL https://raw.githubusercontent.com/schlenks/superpowers/main/scripts/setup-beads-local.sh | bash
> ```
>
> This script installs beads, initializes stealth mode, and adds git worktree support to your shell.

For team use where `.beads/` should be committed and shared, use `bd init` without `--stealth`.

## TL;DR

```bash
bd ready                    # What can I work on?
bd update <id> --claim      # I'm starting this
bd close <id>               # I'm done with this
bd sync                     # Save my changes
```

**Critical rules:**
- Never use semicolons in `--acceptance` (triggers permission prompts)
- Never use `bd edit` (opens interactive editor)
- Always run `bd sync` before ending a session

## Permission Avoidance (Critical)

These rules prevent Claude Code permission prompts caused by deny patterns in settings.json.

| Rule | Why | Do This Instead |
|------|-----|-----------------|
| **Never use semicolons in `--acceptance`** | ` ; ` pattern triggers prompts | Use commas or `$'...\n...'` |
| **Use `--body-file` for multi-line content** | Newlines break pattern matching | Write to temp file first |
| **Never delete temp files with `rm`** | `rm` triggers permission prompts | Leave for human cleanup |

### Acceptance Criteria Formatting

```bash
# ✅ Commas (single line)
bd create ... --acceptance "Criterion 1, Criterion 2, Criterion 3"

# ✅ Newlines with ANSI-C quoting (displays better in bd show)
bd create ... --acceptance $'Criterion 1\nCriterion 2\nCriterion 3'

# ❌ NEVER use semicolons
bd create ... --acceptance "Criterion 1; Criterion 2"  # TRIGGERS PROMPT
```

### Multi-Line Descriptions

```bash
# Step 1: Write description to temp file
Write tool → temp/desc.md

# Step 2: Reference with --body-file
bd create --silent --type epic "Title" --body-file temp/desc.md -p 1
```

The `temp/` directory exists at repo root. Reuse/overwrite the same temp file for multiple issues.

## Critical Warnings

### NEVER Use `bd edit`

`bd edit` opens an interactive editor that AI agents cannot use. Always use `bd update` with flags:

```bash
# ❌ NEVER
bd edit hub-abc

# ✅ ALWAYS
bd update hub-abc --title "New Title" --body-file temp/desc.md
bd update hub-abc --status in_progress
bd update hub-abc --acceptance $'Criterion 1\nCriterion 2'
```

### Sandbox Incompatibility

The `bd` CLI is a native macOS binary. It does **not** work in Claude Code's Linux sandbox. If you see "command not found" errors, you're likely in sandbox mode.

## Command Quick Reference

### Issue Operations

| Action | Command |
|--------|---------|
| Create epic | `bd create --silent --type epic "Title" --body-file temp/desc.md -p 1` |
| Create child task | `bd create --silent --parent <epic-id> "Title" --body-file temp/desc.md -p 2` |
| Add dependencies | `--deps "id1,id2"` (comma-separated, no spaces) |
| View issue | `bd show <id>` |
| Update issue | `bd update <id> --status in_progress` |
| Claim issue | `bd update <id> --claim` (sets assignee + in_progress atomically) |
| Close issue | `bd close <id>` |
| Close multiple | `bd close <id1> <id2> <id3>` |
| Close with reason | `bd close <id> --reason "explanation"` |
| Add comment | `bd comments add <id> "comment text"` |
| Add comment from file | `bd comments add <id> -f temp/comment.md` |

### Query Commands

| Action | Command |
|--------|---------|
| Ready work (no blockers) | `bd ready` |
| Blocked work | `bd blocked` |
| Search issues | `bd search --query "text" --status open` |
| List with filters | `bd list --status open --type task --priority-max 2` |
| View dependency graph | `bd graph <id>` |
| Check stale issues | `bd stale --days 14` |
| Lint issues | `bd lint --status open` |

### Maintenance Commands

| Action | Command |
|--------|---------|
| Health check | `bd doctor` |
| Auto-fix issues | `bd doctor --fix` |
| Cleanup old issues | `bd cleanup` |
| Prime AI context | `bd prime` |
| Database info | `bd info` |

### Key Flags

| Flag | Purpose |
|------|---------|
| `--silent` | Output only ID (for scripting) |
| `--json` | Output in JSON format (machine-readable) |
| `--quiet` | Suppress non-essential output |
| `--type` | bug, feature, task, epic, chore, merge-request, molecule, gate |
| `--parent <id>` | Create as child of epic |
| `-d "text"` | Single-line description (prefer `--body-file` for multi-line) |
| `--body-file <path>` | Read description from file (use for multi-line content) |
| `-p N` | Priority 0-4 (0=critical, 4=backlog) |
| `--deps "id1,id2"` | Dependencies (blocked by these) |
| `--acceptance "..."` | Acceptance criteria (no semicolons!) |
| `--external-ref "ref"` | External link (e.g., "sc-1234") |
| `-l "label1,label2"` | Labels (comma-separated) |

## Dependency Management

### Dependency Types

| Type | Effect on `bd ready` | Use For |
|------|---------------------|---------|
| `blocks` | ✓ Blocks dependent issues | Sequential execution |
| `related` | ✗ Does not block | Informational links |
| `discovered-from` | ✗ Does not block | Audit trail |
| `replies-to` | ✗ Does not block | Discussion threading |

**Only `blocks` dependencies affect what appears in `bd ready`.** Use `--deps` for blocking dependencies.

### Common Mistake: No Dependencies

If you create "Step 1", "Step 2", "Step 3" without `--deps`, they ALL appear in `bd ready` simultaneously:

```bash
# ❌ WRONG - All three appear as ready at once
bd create "Step 1" ...
bd create "Step 2" ...
bd create "Step 3" ...

# ✅ CORRECT - Step 2 waits for Step 1, etc.
bd create --silent "Step 1" ...          # Returns: hub-abc.1
bd create --silent "Step 2" ... --deps "hub-abc.1"
bd create --silent "Step 3" ... --deps "hub-abc.2"
```

### Creating Dependencies

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

### Dependency Validation

| Issue | Action |
|-------|--------|
| Forward reference (Task 2 depends on Task 5) | Warn and skip - indicates plan ordering issue |
| Self-reference (Task 3 depends on Task 3) | Warn and skip |
| Non-existent task | Warn and skip |
| Circular dependency | Run `bd dep cycles` to detect, then `bd dep remove` to fix |

### Verification After Creation

**Always verify** dependency structure after creating issues:

```bash
bd ready              # Tasks with no deps should appear
bd blocked            # Dependent tasks should appear
bd graph <epic-id>    # Visual verification
```

### Deadlock Detection

If `bd ready` shows nothing but issues remain open:
1. Run `bd blocked` to see dependency chain
2. Run `bd dep cycles` to check for circular dependencies
3. Check if you forgot to `bd close` a completed issue
4. Run `bd graph <epic>` for visual dependency view

## Workflow Patterns

### Autonomous Work Loop

Repeat this cycle until `bd ready` returns nothing:

```bash
bd ready                              # 1. Find available work
bd show <id>                          # 2. Review issue details
bd update <id> --claim                # 3. Claim it (sets assignee + in_progress)
# ... do the work ...
bd close <id> --reason "summary"      # 4. Close when done
bd ready                              # 5. Check what's unblocked, repeat
```

### Completing Work

```bash
bd close <id1> <id2> ...              # Close completed issues (unblocks dependents)
bd sync                               # Export changes
git add . && git commit -m "..."      # Commit code changes
```

### Status Values

| Status | Meaning |
|--------|---------|
| `open` | Not started |
| `in_progress` | Currently working |
| `blocked` | Waiting on dependencies (auto-set by beads) |
| `deferred` | Postponed (hidden from `bd ready` until defer date) |
| `closed` | Complete |

## Session End Protocol ("Land the Plane")

**CRITICAL:** A session is NOT complete until all steps finish. Never say "ready to push when you are" - that is a failure.

```bash
# 1. File remaining work as beads issues
bd create "Remaining work" -d "..." -p 2

# 2. Close completed work (unblocks dependents)
bd close <completed-ids>

# 3. Force sync (bypasses 30-second debounce)
bd sync                       # Exports to JSONL and commits

# 4. Git operations
git status                    # Check what changed
git add <files>               # Stage code changes
git commit -m "..."           # Commit changes
```

**Why `bd sync` at session end?** Beads batches changes for 30 seconds before syncing. Running `bd sync` explicitly forces immediate export rather than waiting for the debounce timer.

**Ephemeral branches:** Merge to main locally rather than pushing. Run `bd sync --from-main` first to pull beads updates.

## Sync Workflow

### Key Sync Commands

| Command | Purpose |
|---------|---------|
| `bd sync` | Full sync (import + export + git) |
| `bd sync --status` | Check sync status without syncing |
| `bd sync --from-main` | Pull beads updates from main branch |
| `bd sync --flush-only` | Export to JSONL without git operations |
| `bd sync --import-only` | Import from JSONL after git pull |
| `bd sync --check` | Pre-sync integrity check |

### JSONL is Source of Truth

After `git pull`, JSONL is the source of truth - the database syncs to match, not vice versa.

## Daily Maintenance

Run these commands regularly:

| Frequency | Command | Purpose |
|-----------|---------|---------|
| Daily | `bd doctor` | Diagnose and fix issues |
| Every few days | `bd cleanup` | Keep issue count under 200 |
| Weekly | `bd upgrade` | Stay current with releases |

## Troubleshooting

### Database Out of Sync

```bash
bd import --force    # Force refresh even when DB appears synced
```

### Git Worktree Limitations

Daemon mode does not work correctly with git worktrees because multiple worktrees share the same `.beads` database. Solutions:

```bash
# Option 1: Disable daemon
export BEADS_NO_DAEMON=1
# Or use --no-daemon flag on commands

# Option 2: Configure sync branch
bd config set sync.branch beads-sync
```

### Daemon Issues

```bash
bd daemons killall   # Restart daemon to match CLI version
```

### Version Mismatch Warning

`bd doctor` may flag version mismatches between CLI, daemon, and plugin. These don't break basic operations but should be synchronized.

### Merge Conflicts in JSONL

Each line is independent. Keep both sides unless same ID appears - then retain newest by `updated_at`.

```bash
git checkout --theirs .beads/issues.jsonl
bd import
```

### Protected Branches

For repositories where you can't push directly to main:

```bash
bd init --branch beads-sync    # Initialize with separate sync branch
```

This commits beads changes to `beads-sync` branch instead of main.

## Parallel Execution Safety

### File Conflict Detection

When dispatching multiple subagents, check for file overlap in `## Files` sections:

```
Issue hub-abc.1 files: [user.model.ts, models/index.ts]
Issue hub-abc.2 files: [jwt.utils.ts, utils/index.ts]
Issue hub-abc.3 files: [auth.service.ts, models/index.ts] <- CONFLICT with .1
```

**Rules:**
- Issues with NO file overlap can run in parallel
- If file appears in multiple ready issues, dispatch lowest-numbered first
- Defer conflicting issues to next wave
- If `## Files` section missing, treat as conflicting with ALL others

### Epic Scoping

`bd ready` shows ALL ready issues across ALL epics. To focus on one epic:

```bash
bd show <epic-id> --json       # Get child issue IDs
bd ready                       # Cross-reference: only work on children of your epic
```

**Why this matters:** If you have multiple epics, `bd ready` mixes them. Check that the issue you pick is a child of the epic you're working on.

## Priority Values

Priority is 0-4, NOT high/medium/low:

| Value | Level | Use For |
|-------|-------|---------|
| `0` or `P0` | Critical | Production blockers |
| `1` or `P1` | High | Sprint commitments |
| `2` or `P2` | Medium | Standard work (default) |
| `3` or `P3` | Low | Nice-to-have |
| `4` or `P4` | Backlog | Future consideration |

## ID Format

Issue IDs use format `<prefix>-<hash>` (e.g., `hub-abc`). Child issues append `.N` (e.g., `hub-abc.1`, `hub-abc.2`).

## Integration with Skills

| Skill | Purpose |
|-------|---------|
| `superpowers:plan2beads` | Convert markdown plan to epic with child tasks |
| `superpowers:writing-plans` | Create plans with `Depends on:` and `Files:` sections |
| `superpowers:subagent-driven-development` | Parallel execution with dependency awareness |

## Commit Conventions

Include issue IDs in commit messages for traceability:

```bash
git commit -m "Fix validation bug (hub-abc)"
```

This enables `bd doctor` to detect orphaned issues (work committed but issues not closed).
