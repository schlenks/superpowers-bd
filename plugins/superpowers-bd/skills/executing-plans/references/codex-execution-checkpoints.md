# Codex Native Execution

Use this reference when `executing-plans` runs in Codex. The flow is the one in `SKILL.md`; this file covers only what Codex does differently. Beads is the durable record of progress, rulings and escalations; `update_plan` is a live mirror that does not survive the session.

## Flow

1. Load the beads context with `superpowers-bd:beads`, then inspect the target epic with `bd show <epic-id>` and extract the epic child IDs. Record `[NATIVE-BASE] <sha>` on the epic if it is not there yet (SKILL.md Setup).
2. `bd ready is global`, and `bd blocked` is global too. Resume any `in_progress` child of the epic first (`bd list --parent <epic-id> --status in_progress`; `bd ready` never lists it), then run `bd ready --parent <epic-id> --exclude-label human`, which scopes ready work to the epic's child IDs; report unrelated ready issues as ignored.
3. Mirror progress with `update_plan`: one step per child issue, plus final review and finish.
4. Implement each ready child yourself, one at a time: mark it in progress, follow its steps under test-driven development, run the verification commands it names, commit, then `bd close` it with the test command and its result.
5. Record judgment calls as `[RULING]` bd comments and hard stops as `[HUMAN-NEEDED]` question beads, using the formats in `../../subagent-driven-development/rulings-and-escalation.md`. An escalation never pauses independent issues.
6. When every implementation child is closed, dispatch `spawn_agent agent=epic_verifier` as the single final review, then make one test-first fix pass with no re-review (`completion-protocol.md`). On resume, check the epic comments for an existing verifier report first; never dispatch a second one.

## Rules

- Work only on child issues of the selected epic, and never on a question bead.
- Do not stop between issues for a checkpoint report or a confirmation. Only the hard stops wait for a human.
- Do not ask the user with `request_user_input` for a judgment call a ruling can settle.
- Do not close an issue until its verification evidence is captured.
- Rule-of-five is opt-in in Native mode: apply a variant only when the issue, the epic or the user asks.
- Leave unrelated local edits intact and avoid rewriting files outside the active issue's scope.

## Completion

The final report's first line is `SDD-STATUS: COMPLETE` or `SDD-STATUS: PARTIAL`, followed by the rulings made and the open question beads. On COMPLETE, hand off to `superpowers-bd:finishing-a-development-branch` unless the user explicitly asks for a different stopping point.
