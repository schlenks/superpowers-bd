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

Read the plan file, create the epic and child issues with `bd create`, verify dependencies with `bd ready`/`bd blocked`, then report the new epic and next execution action.

## Platform Routing

- **Claude Code:** `/superpowers-bd:plan2beads <plan-path | SC-1234 | 1234>` loads the Claude command implementation at `../../commands/plan2beads.md`.
- **Codex:** Follow `references/codex-plan2beads-flow.md`. Treat this skill and that reference as the native workflow; do not route Codex through the Claude slash command.

## Shared Rules

- Use `temp/*.md` body files for multiline issue descriptions and comments.
- Keep each child issue dependency-aware with clear `Depends on:`, `Complexity:`, and `Files:` sections from the source plan.
- Verify the dependency shape with `bd ready`, `bd blocked`, and `bd show <epic-id>` before handing off.
- If the plan is incomplete or ambiguous, ask a concise question before creating issues.

## Output Contract

End with the epic ID, created child task IDs, ready/blocked summary, and the exact next execution action. The default next action is `subagent-driven-development` after successful conversion unless the user explicitly asks to stop.

## Reference Files

- `references/codex-plan2beads-flow.md`: Codex-native plan-to-beads conversion flow
