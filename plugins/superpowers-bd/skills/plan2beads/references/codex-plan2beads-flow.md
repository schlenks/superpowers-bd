# Codex Plan to Beads Flow

Use this reference when converting a written Superpowers-BD implementation plan into beads issues from Codex. This is a native Codex entry workflow; do not require the Claude slash command document to perform the conversion.

## Prerequisites

- Load `superpowers-bd:beads` first.
- Confirm the plan path or Shortcut story source (`SC-1234` or numeric ID).
- Use repository-local `temp/*.md` files for multiline issue bodies and comments.
- Avoid semicolons in beads acceptance text.

## Native Flow

1. Track conversion progress with `update_plan`: load plan or story, create epic, create children, add dependencies, verify graph, report handoff, start execution.
2. For a local plan path, read the plan and identify the parent epic title, goal, architecture, key decisions, file structure, task list, dependencies, verification requirements, an optional `## Global Constraints` block, and optional per-task `**Interfaces:**` lines (`Consumes:` / `Produces:`).
3. For a Shortcut input (`SC-1234` or `1234`), normalize to the numeric ID, run `short story <numeric-id> -f=markdown`, use the first markdown heading as the title, and store `--external-ref "sc-<id>"` for the epic.
4. Ask for completion strategy before creating the epic: commit only, push, push+PR, or merge local. Apply the corresponding label: `completion:commit-only`, `completion:push`, `completion:push-pr`, or `completion:merge-local`.
5. Create one parent beads epic for the plan or story. Include `--external-ref "sc-<id>"` when the source was Shortcut.
6. Create one child issue for each implementation task, preserving the task title, purpose, dependencies, complexity, file list, steps, verification commands, and the task's `**Interfaces:**` line (`Consumes:` / `Produces:`) verbatim when present.
6a. If the plan has a `## Global Constraints` block, thread its text into every child issue body so each implementer carries the epic-wide rules; also keep it in the epic description. Both sections are optional — a plan with neither imports exactly as before (backward-compatible).
7. Create a final verification issue that depends on all implementation tasks.
8. Add dependency edges so each child issue matches the plan's `Depends on:` section.
9. Verify the graph with `bd show <epic-id>`, `bd ready`, and `bd blocked`. `bd ready is global`: filter ready and blocked results to the selected epic's child IDs, and report unrelated ready issues as ignored.
10. Report the epic ID, child issue IDs, selected-epic ready set, selected-epic blocked set, and exact next action. Proceed into `subagent-driven-development` unless the user explicitly asked for conversion-only.

## Issue Body Shape

Each child issue should include:

- `Depends on:` copied from the plan using task names and resolved beads IDs where useful.
- `Complexity:` copied exactly.
- `Files:` copied exactly.
- `Global Constraints:` (OPTIONAL) — when the plan has a `## Global Constraints` block, copy its epic-wide rules text into every child issue body so each implementer carries them. Absent leaves every body unchanged.
- `Interfaces:` (OPTIONAL) — when the task has a `**Interfaces:**` line, preserve the `Consumes:` / `Produces:` lines verbatim in that task's body. Absent leaves the body unchanged.
- `Purpose:`, `Not In Scope:`, and `Gotchas:` when present.
- Step-by-step implementation and verification instructions.
- Any TDD RED/GREEN expectations from the plan.

## Validation

Before reporting success:

- Confirm every plan task became a beads child issue.
- Confirm every dependency from the plan exists in beads.
- Confirm the final verification issue depends on all implementation tasks.
- Confirm no task references files absent from the plan's file structure table unless the plan explicitly allowed discovery.
- Confirm `bd ready` is global and that selected-epic ready/blocked reporting intersects `bd ready` and `bd blocked` with the epic child IDs.
- Confirm unrelated ready issues are reported as ignored, not as part of the new epic.
- Confirm Shortcut sources preserve `--external-ref "sc-<id>"` and completion strategy labels.
- Confirm that, when a `## Global Constraints` block is present, its text propagated into every child issue body, and that any `**Interfaces:**` line propagated verbatim into its task body. When both are absent, confirm task bodies match the pre-existing (section-less) shape.
- Confirm the next action starts `subagent-driven-development` unless the user explicitly asked for conversion-only.

If the plan is missing required task metadata, stop and ask for clarification or update the plan before creating issues.
