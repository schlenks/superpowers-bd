# Rulings and Escalation

Unattended runs (`claude -p`, `codex exec`, background sessions) have no one to answer a question, so the controller rules on judgment calls, records the ruling, and continues; only the hard stops below wait for a human, and even they never pause independent work.

## Hard Stops

Only these stop for a human:

- destructive or irreversible actions,
- security-sensitive actions, including any use or change of live secrets or credentials,
- push, merge or publish not pre-authorized by a `completion:*` label,
- a plan where every path forward is a guess,
- bd being unavailable.

Everything else gets a ruling.

**Security-sensitive action** means using or changing live credentials or secrets, widening access on a real system, or disabling a security control. Editing security-related code in the repo to fix something is reversible by a later commit and gets a ruling like any other change.

**Security defects are never ruled through.** A ruling may never keep or accept a defect that exposes secrets or credentials, weakens authentication or authorization, enables injection, or exposes data, even when the plan mandates it and even though a later commit could revert it. Fixing such a defect may be ruled. Keeping it escalates through a question bead (Escalation Format), and the task stays open.

## When a Ruling Is Allowed

A ruling is allowed when every option is reversible by a later commit and none falls under the security rule above. It is not allowed when the action touches remote state (push, deploy, publish, a shared cache or database, an external service) or deletes data that git cannot restore. A conflict is never resolved by choosing the option that deletes data or touches remote state: drop that option, rule among the rest, and escalate the step if no other option remains.

Authority order when requirements disagree:

1. the epic's Key Decisions and acceptance criteria;
2. the spec named on the epic's `Spec:` line, if any (`context-loading.md`);
3. the child issue's text.

A child issue's text is its argument for an approach, not the binding decision. Pick the option the higher authority supports. When none decides it, pick the option that is cheapest to reverse.

"Every path is a guess" is narrow. Use it only when you can name the options and say why no source above favors any of them. Put that list in the question bead (Escalation Format). If one option is merely less certain than another, rule.

## Dispatch-Time Guard

Before ruling on a conflict or dispatching a child, check each of its steps against the hard stops. A matching step (for example, "purge the production-shared cache", "rotate the API key", "deploy") is removed from the implementer's scope:

1. File it as a question bead (Escalation Format) titled `[HUMAN-NEEDED] <issue-id>: <the step and why it was withheld>`.
2. Required, before the original task closes: move its blocking edges to the new bead. For every dependent of the original task (`bd dep list <original-id> --direction=up`), run `bd dep add <dependent> <new-bead>`, and always run it for the epic's verification task. Otherwise closing the original makes those dependents (and epic verification) ready while the human step is unresolved.
3. Dispatch the child without the step, saying in the prompt that the step was withheld and why.

## Ruling Format

Post every ruling on both the epic and the affected child. The epic copy is the audit trail; the child copy is what the spec reviewer and any re-dispatched implementer read first:

```bash
bd comments add <epic-id> "[RULING] <issue-id>: <decision> — why: <reason> — cost if wrong: <impact>"
bd comments add <issue-id> "[RULING] <issue-id>: <decision> — why: <reason> — cost if wrong: <impact>"
```

Carry the ruling verbatim into each affected implementer's dispatch prompt. A ruling amends the requirement it addresses: the spec reviewer treats it as part of the spec (`spec-reviewer-prompt.md`).

## Escalation Format

Escalation is asynchronous, and it always uses a separate **question bead**. Never put the `human` label on the work item itself: `bd human respond <id>` adds the answer as a comment and closes the bead with reason "Responded", and `bd human dismiss <id>` closes it as "Dismissed". On a work item, either would close a still-unfinished task and release its dependents.

```bash
bd create "[HUMAN-NEEDED] <issue-id>: <question>" --parent <epic-id> --type task   # -> <question-bead>
bd label add <question-bead> human
bd dep add <work-item> <question-bead>    # work item stays open and blocked until answered
```

- **The whole task needs a human** (NEEDS_CONTEXT exhausted, scope change, gap closure exhausted, a kept security defect): the work item is the task. Set it back to `open`; `bd ready` will not list it while the question bead is open.
- **One step needs a human:** the question bead is the withheld step (Dispatch-Time Guard). The human runs or declines the step, then responds or dismisses.
- **Answered:** when a question bead closes, read the answer (close reason in `bd show <question-bead>`, plus `bd comments <question-bead>`). Responded: re-dispatch the work item with the answer in its prompt. Dismissed: record a `[RULING]` on how to proceed without it, or leave the work item open if a hard stop still applies.
- **Dependents** of the work item stay blocked through the normal dependency chain. A task held on CANNOT_VERIFY whose sibling is waiting on a question bead also gets `bd dep add <held-task> <question-bead>`.
- **Never dispatch a question bead.** It is the human's inbox, not work. List ready work with `bd ready --exclude-label human`.
- Continue with every independent ready issue. Escalation never pauses the epic.

`bd human list` is the human's inbox. Never let `TaskCreate` (Claude Code) or `update_plan` (Codex) be the only record of an escalation: Task tools are off by default on Claude Code 2.1.233+, and native progress trackers do not survive the session. They may mirror the bd record.

## Where Each Case Is Handled

- Pre-flight conflicts: SDD `SKILL.md` Pre-flight Requirement-Conflict Scan.
- Budget tier and wave cap (never asked): `budget-and-wave-cap.md`.
- NEEDS_CONTEXT, BLOCKED, review loop past its cap, reviewer failure, bd failure: `failure-recovery.md`.
- Gap closure exhausted: `verification-and-evidence.md`.
- Resume: `checkpoint-recovery.md`.

## Ending a Run

- `[WAVE-SUMMARY]` carries `Rulings:` and `Escalated:` lines (`metrics-tracking.md`).
- If any epic child is open, including question beads, the run ends `SDD-STATUS: PARTIAL`. The epic verifier runs only when all implementation tasks are closed, and `finishing-a-development-branch` never runs on a PARTIAL epic.
- Otherwise the epic verifier runs; after PASS and finishing, the run ends `SDD-STATUS: COMPLETE`.
- The completion report lists every ruling under "Rulings I made" (`metrics-tracking.md`).
