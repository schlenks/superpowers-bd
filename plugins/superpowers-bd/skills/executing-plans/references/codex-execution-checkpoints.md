# Codex Execution Checkpoints

Use this reference when `executing-plans` is invoked from Codex. Beads tracks durable project state; Codex progress tracking records the current execution phases and checkpoint gates.

## Native Flow

1. Load the beads context with `superpowers-bd:beads`, then inspect the target epic with `bd show <epic-id>`.
2. Use `bd ready` and `bd blocked` to identify the next dependency-ready child issues for that epic.
3. Track the active batch with `update_plan`: load epic, review scope, execute current batch, verify batch, report checkpoint, wait for feedback, continue or finish.
4. Claim or mark each issue in progress before editing it.
5. Follow the issue steps exactly, including RED/GREEN verification when the issue requires TDD.
6. Run the verification commands named by the issue before closing it.
7. Commit completed issue work, then close the beads issue to unblock dependents.
8. After each batch, report what changed, what was verified, what newly unblocked, and what feedback is needed.

## Batch Rules

- Work only on child issues of the selected epic.
- Serialize issues that touch the same file.
- Stop and ask when instructions conflict, files are outside the owned scope, or verification repeatedly fails.
- Do not close an issue until its verification evidence is captured.
- If a changed file exceeds the rule-of-five threshold, apply the appropriate variant before committing.
- Leave unrelated local edits intact and avoid rewriting files outside the active issue scope.

## Checkpoint Report

Every checkpoint should include:

- Completed issue IDs and commit SHAs.
- Verification commands and pass/fail results.
- Rule-of-five variants applied, or a clear statement that none were triggered.
- Newly ready issues from `bd ready`.
- Blockers, risks, and any user decision needed before continuing.

Do not proceed past a requested feedback checkpoint until the user responds. If the user asks for autonomous execution, continue batch by batch while still reporting verification evidence.

## Completion

When all child issues are closed, verify the epic with `bd show <epic-id>`. Then hand off to `superpowers-bd:finishing-a-development-branch` unless the user explicitly asks for a different stopping point.
