# Completion Protocol (Native Mode)

## Resuming

The final review runs once, so a resumed session finds its stage in `bd comments <epic-id>` before doing anything:

- A verifier report is already persisted (its report marker, or a PASS/FAIL verdict): do not dispatch again. Continue at section 2 (One Fix Pass) with that report, skipping findings that already have a `Final fix:` or `[RULING]` comment.
- No report yet: start at step 1.

## 1. Final Review: the Epic Verifier

Start only when every implementation child is closed and the verification task is the one ready child left (a question bead still open means the run is PARTIAL; skip to step 4).

1. `bd update <verification-id> --status=in_progress`.
2. Collect the dispatch context the `superpowers-bd:epic-verifier` skill names: `{epic_id}`, base SHA, head SHA, the test command, and `{quality-delta}` from `bash skills/epic-verifier/scripts/quality-delta.sh <base-sha> <head-sha>` (plugin path, run from the repository root; pass `Unavailable: <reason>` if it cannot run).
   - **Base SHA** is the `[NATIVE-BASE] <sha>` comment recorded on the epic at Setup. Never derive it at the end: `git merge-base` equals HEAD on `main` or after a resume, and the review would see an empty or partial diff. If the comment is missing, use the parent of the earliest commit cited in a child's `bd close` reason (`commit <sha>`) and post a `[RULING]` naming the SHA you chose.
3. Dispatch one fresh, read-only verifier with `../../epic-verifier/verifier-prompt.md`:
   - **Claude Code:** `Agent` with `model: "opus"` (the most capable model available; never omit it).
   - **Codex:** `spawn_agent agent=epic_verifier` (`high`).
   - **No subagent tool:** perform the verifier checklist yourself as a separate pass, post `[RULING] <epic-id>: final review was a self-review (no subagent tool) — why: no fresh context available — cost if wrong: author blind spots ship`, and say so in the final report.
4. Read the verdict and its persisted report (`bd comments <epic-id>`).

**When no review happened.** `FAIL (CANNOT_VERIFY)`, unconfirmed Report Persistence, or a verifier that ended without a verdict means there is no review yet: re-dispatch once. This retry exists only for a review that never happened; a PASS or FAIL verdict is final and is never re-dispatched. If the retry also produces no review, escalate with a `[HUMAN-NEEDED]` question bead (`../../subagent-driven-development/rulings-and-escalation.md`) and end PARTIAL.

## 2. One Fix Pass

On PASS, go to the green-suite gate. On FAIL, sort the findings first; the verifier's labels are advice, the gate is yours.

- **Blocking findings** must be fixed: a missing or unmet acceptance criterion, a correctness or data-integrity defect, a failing test or build (including a failure in the verifier's own test run), and any security defect (secrets, auth, injection, data exposure). These are never ruled "keep".
- **Each fix:** write a test that reproduces the finding, watch it fail, fix, watch it pass, run the whole suite, commit. Record it on the epic: `bd comments add <epic-id> "Final fix: <finding> — <test name> RED->GREEN, suite <N>/<N>"`.
- **Rulings** may keep only non-blocking findings: style, maintainability, or a requirement change the user explicitly authorized (say so in the ruling). Post the `[RULING]` on the epic with why the code stands and the cost if wrong.
- **Warnings** (for example the non-gating Maintainability row) are listed in the final report, not fixed.
- **A blocking finding you could not fix:** escalate it with a `[HUMAN-NEEDED]` question bead, leave the verification task open, and end PARTIAL.

No re-review: the covering tests and the green suite are the evidence. There is no second fix pass and no second verifier dispatch.

**Green-suite gate.** After the fix pass (or on PASS), run the full project suite. If it is not green, revert the fix commit that broke it (`git revert <sha>`) and escalate that finding, or escalate the red suite directly, with a `[HUMAN-NEEDED]` question bead. Either way, leave the verification task open and end PARTIAL. A red suite is never ruled "keep".

## 3. Close and Hand Off

Only when the suite is green and every blocking finding is fixed:

1. Close the verification task with its evidence: `bd close <verification-id> --reason "verifier <PASS|FAIL>; fixes: <count> RED->GREEN; suite: <command> -> <result line>"`.
2. Verify with `bd show <epic-id>` that every child is closed.
3. Announce "I'm using the finishing-a-development-branch skill to complete this work." and follow `superpowers-bd:finishing-a-development-branch`. Its unattended rules apply as written.

## 4. Final Report

- First line: `SDD-STATUS: COMPLETE` when every child is closed and the full suite is green, otherwise `SDD-STATUS: PARTIAL` (never run finishing on a PARTIAL epic). On PARTIAL with the verification task never run, say that the closed issues have not been reviewed.
- **Rulings I made:** every `[RULING]` from `bd comments <epic-id>`, in order, each with its cost if wrong.
- **Escalated:** every open question bead ID and its question.
- **Final review:** verifier verdict, fixes with their tests, and warnings not acted on.
