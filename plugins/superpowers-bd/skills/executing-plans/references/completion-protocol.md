# Completion Protocol (Native Mode)

## 1. Final Review: the Epic Verifier

Start only when every implementation child is closed and the verification task is the one ready child left (a question bead still open means the run is PARTIAL; skip to step 4).

1. `bd update <verification-id> --status=in_progress`.
2. Collect the dispatch context the `superpowers-bd:epic-verifier` skill names: `{epic_id}`, base SHA (`git merge-base <base-branch> HEAD`, where base-branch is the epic's stated branch, else `main`), head SHA, the test command, and `{quality-delta}` from `bash skills/epic-verifier/scripts/quality-delta.sh <base-sha> <head-sha>` (plugin path, run from the repository root; pass `Unavailable: <reason>` if it cannot run).
3. Dispatch one fresh, read-only verifier with `../../epic-verifier/verifier-prompt.md`:
   - **Claude Code:** `Agent` with `model: "opus"` (the most capable model available; never omit it).
   - **Codex:** `spawn_agent agent=epic_verifier` (`high`).
   - **No subagent tool:** perform the verifier checklist yourself as a separate pass, post `[RULING] <epic-id>: final review was a self-review (no subagent tool) — why: no fresh context available — cost if wrong: author blind spots ship`, and say so in the final report.
4. Read the verdict and its persisted report (`bd comments <epic-id>`).

`FAIL (CANNOT_VERIFY)` or unconfirmed Report Persistence means no review happened: re-dispatch once. If it fails again, escalate with a `[HUMAN-NEEDED]` question bead (`../../subagent-driven-development/rulings-and-escalation.md`) and end PARTIAL.

## 2. One Fix Pass

On PASS, skip to step 3. On FAIL, sort the findings first; the verifier's labels are advice, the gate is yours.

- **Each finding you fix:** write a test that reproduces it, watch it fail, fix, watch it pass, run the whole suite, commit. Record it on the epic: `bd comments add <epic-id> "Final fix: <finding> — <test name> RED->GREEN, suite <N>/<N>"`.
- **Each finding you keep:** post a `[RULING]` on the epic saying why the code stands and the cost if wrong.
- **Security defects** (secrets, auth, injection, data exposure) are never ruled "keep". If you cannot fix one, escalate it with a question bead and end PARTIAL.
- **Warnings** (for example the non-gating Maintainability row) are listed in the final report, not fixed.

No re-review: the covering tests and the green suite are the evidence. There is no second fix pass and no second verifier dispatch.

## 3. Close and Hand Off

1. Close the verification task with its evidence: `bd close <verification-id> --reason "verifier <PASS|FAIL>; fixes: <count> RED->GREEN; suite: <command> -> <result line>"`.
2. Verify with `bd show <epic-id>` that every child is closed.
3. Announce "I'm using the finishing-a-development-branch skill to complete this work." and follow `superpowers-bd:finishing-a-development-branch`. Its unattended rules apply as written.

## 4. Final Report

- First line: `SDD-STATUS: COMPLETE` when every child closed, otherwise `SDD-STATUS: PARTIAL` (never run finishing on a PARTIAL epic).
- **Rulings I made:** every `[RULING]` from `bd comments <epic-id>`, in order, each with its cost if wrong.
- **Escalated:** every open question bead ID and its question.
- **Final review:** verifier verdict, fixes with their tests, and warnings not acted on.
