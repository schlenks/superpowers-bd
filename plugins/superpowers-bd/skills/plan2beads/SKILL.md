---
name: plan2beads
description: Use when converting a Superpowers-BD implementation plan or Shortcut story into a beads epic with dependency-aware child tasks
effort: medium
---

# Plan to Beads

Convert a written plan into beads work: one parent epic, dependency-aware implementation tasks, and one final verification task.

## Required Background

Load `superpowers-bd:beads` first. You need the bd CLI workflow, dependency semantics, and multiline body-file conventions before creating issues.

## Quick Start

Read the plan file, read `../../commands/plan2beads.md`, create the epic and child issues with `bd create`, verify dependencies with `bd ready`/`bd blocked`, then execute the new epic.

## Canonical Method

The full procedure lives at `../../commands/plan2beads.md`. Read it and follow it exactly, with these platform mappings:

- Claude Code: `/superpowers-bd:plan2beads <plan-path | SC-1234 | 1234>` loads the command directly.
- Codex: invoke this skill as `$plan2beads`, then read `../../commands/plan2beads.md`.
- `TaskCreate` / `TaskUpdate` blocks map to your native progress tracker. Preserve the sequence and do not mark a later phase complete before earlier evidence exists.
- `AskUserQuestion` maps to a concise direct user question when no structured question tool is available.
- File edits for multiline issue bodies should use `temp/*.md` body files as described in the command.

## Output Contract

End with the epic ID, created child task IDs, ready/blocked summary, and the exact next execution action. The command requires proceeding into `subagent-driven-development` after successful conversion unless the user explicitly asks to stop.
