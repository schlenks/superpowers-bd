# Codex Plan to Beads Flow

Use this reference when converting a written Superpowers-BD implementation plan into beads issues from Codex. This is a native Codex entry workflow; do not require the Claude slash command document to perform the conversion.

## Prerequisites

- Load `superpowers-bd:beads` first.
- Confirm the plan path or external story source.
- Use repository-local `temp/*.md` files for multiline issue bodies and comments.
- Avoid semicolons in beads acceptance text.

## Native Flow

1. Track conversion progress with `update_plan`: load plan, create epic, create children, add dependencies, verify graph, report handoff.
2. Read the plan and identify the parent epic title, goal, architecture, key decisions, file structure, task list, dependencies, and verification requirements.
3. Create one parent beads epic for the plan.
4. Create one child issue for each implementation task, preserving the task title, purpose, dependencies, complexity, file list, steps, and verification commands.
5. Create a final verification issue that depends on all implementation tasks.
6. Add dependency edges so each child issue matches the plan's `Depends on:` section.
7. Verify the graph with `bd show <epic-id>`, `bd ready`, and `bd blocked`.
8. Report the epic ID, child issue IDs, ready set, blocked set, and exact next action.

## Issue Body Shape

Each child issue should include:

- `Depends on:` copied from the plan using task names and resolved beads IDs where useful.
- `Complexity:` copied exactly.
- `Files:` copied exactly.
- `Purpose:`, `Not In Scope:`, and `Gotchas:` when present.
- Step-by-step implementation and verification instructions.
- Any TDD RED/GREEN expectations from the plan.

## Validation

Before reporting success:

- Confirm every plan task became a beads child issue.
- Confirm every dependency from the plan exists in beads.
- Confirm the final verification issue depends on all implementation tasks.
- Confirm no task references files absent from the plan's file structure table unless the plan explicitly allowed discovery.
- Confirm `bd ready` shows only tasks with no blockers for the selected epic.

If the plan is missing required task metadata, stop and ask for clarification or update the plan before creating issues.
