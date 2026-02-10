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

> Run: `curl -fsSL https://raw.githubusercontent.com/schlenks/superpowers-bd/main/scripts/setup-beads-local.sh | bash`
> This installs beads, initializes stealth mode, and adds git worktree support. For team use (shared `.beads/`), use `bd init` without `--stealth`.

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

## Command Quick Reference

### Issue Operations

| Action | Command |
|--------|---------|
| Create epic | `bd create --silent --type epic "Title" --body-file temp/desc.md -p 1` |
| Create child task | `bd create --silent --parent <epic-id> "Title" --body-file temp/desc.md -p 2` |
| Add dependencies | `--deps "id1,id2"` (comma-separated, no spaces) |
| View issue | `bd show <id>` |
| Update issue | `bd update <id> --status=in_progress` |
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

## Session End Protocol

```bash
bd create "Remaining work" -d "..." -p 2   # 1. File remaining work
bd close <completed-ids>                    # 2. Close completed (unblocks dependents)
bd sync                                     # 3. Force sync (bypasses 30s debounce)
git status                                  # 4. Check what changed
git add <files>                             # 5. Stage code changes
git commit -m "..."                         # 6. Commit changes
```

## Integration with Skills

| Skill | Purpose |
|-------|---------|
| `superpowers:plan2beads` | Convert markdown plan to epic with child tasks |
| `superpowers:writing-plans` | Create plans with `Depends on:` and `Files:` sections |
| `superpowers:subagent-driven-development` | Parallel execution with dependency awareness |

## Reference Files

Load these on demand when the situation requires deeper guidance.

| File | Load When |
|------|-----------|
| `references/acceptance-and-multiline.md` | Writing acceptance criteria or multi-line descriptions |
| `references/bd-edit-and-sandbox.md` | Encountering bd edit usage or sandbox errors |
| `references/dependency-management.md` | Creating dependencies, fixing deadlocks, verifying dep structure |
| `references/workflow-patterns.md` | Running autonomous work loops, checking status values |
| `references/session-end-details.md` | Need details on why bd sync matters or ephemeral branch handling |
| `references/sync-workflow.md` | Using sync subcommands, daily maintenance schedule |
| `references/troubleshooting.md` | Database sync issues, worktree limitations, merge conflicts |
| `references/parallel-execution-safety.md` | Dispatching parallel subagents, epic scoping, priority values, ID format |
