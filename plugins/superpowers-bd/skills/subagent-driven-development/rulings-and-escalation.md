# Rulings and Escalation

SDD runs unattended more often than not. In `claude -p` and `codex exec` there is no one to answer a question: a turn that ends in a question exits with "success" and nothing built. In a background session the same question idles until someone looks. So the controller does not stop to ask about judgment calls. It rules, records the ruling, and continues. It stops only for the five hard-stop classes below, and even then it keeps working on everything that does not depend on the stopped item.

## Hard Stops

Only these stop for a human:

- destructive or irreversible actions,
- security-sensitive actions,
- push, merge or publish not pre-authorized by a `completion:*` label,
- a plan where every path forward is a guess,
- bd being unavailable.

Everything else gets a ruling.

## When a Ruling Is Allowed

A ruling is allowed when every option is reversible by a later commit. It is not allowed when the action touches remote state (push, deploy, publish, a shared cache or database, an external service) or deletes data that git cannot restore. Those fall under the hard stops.

Authority order when requirements disagree:

1. the epic's Key Decisions and acceptance criteria;
2. the spec named on the epic's `Spec:` line, if any (`context-loading.md`);
3. the child issue's text.

A child issue's text is its argument for an approach, not the binding decision. Pick the option the higher authority supports. When none decides it, pick the option that is cheapest to reverse.

"Every path is a guess" is narrow. Use it only when you can name the options and say why no source above favors any of them. Put that list in the `[HUMAN-NEEDED]` comment. If one option is merely less certain than another, rule.

## Ruling Format

Post every ruling on both the epic and the affected child. The epic copy is the audit trail; the child copy is what the spec reviewer and any re-dispatched implementer read first:

```bash
bd comments add <epic-id> "[RULING] <issue-id>: <decision> — why: <reason> — cost if wrong: <impact>"
bd comments add <issue-id> "[RULING] <issue-id>: <decision> — why: <reason> — cost if wrong: <impact>"
```

Carry the ruling verbatim into each affected implementer's dispatch prompt. A ruling amends the requirement it addresses: the spec reviewer treats it as part of the spec (see `spec-reviewer-prompt.md`).

## Escalation Format

Escalation is asynchronous. Label the bead that needs a human, explain why, and keep going:

```bash
bd label add <id> human
bd comments add <id> "[HUMAN-NEEDED] <issue-id>: <question>"
```

- **One step of a task needs a human** (for example, the plan says to purge a production-shared cache): do not run that step. File it as its own bead under the epic, label that bead `human`, and let the implementer finish and close the rest of the task. `bd human respond <id>` closes the bead it answers, so the label belongs on the step, not on the whole task.
- **The whole task needs a human** (NEEDS_CONTEXT exhausted, scope change): label the task itself. Leave it open, and skip it in later LOADING passes.
- **Dependents** of an escalated bead stay blocked. A task held on CANNOT_VERIFY whose sibling is escalated inherits the `human` label instead of waiting.
- Continue with every independent ready issue. Escalation never pauses the epic.

`bd human list` is the human's inbox. Never let `TaskCreate` (Claude Code) or `update_plan` (Codex) be the only record of an escalation: Task tools are off by default on Claude Code 2.1.233+, and native progress trackers do not survive the session. They may mirror the bd record.

## Where Rulings Replace Holds

| Situation | Action |
|---|---|
| Pre-flight requirement conflict | Ruling, then dispatch wave 1. Record what the scan checked in an epic comment. |
| Budget tier not given | Explicit tier, else `SDD_BUDGET_TIER`, else `max-5x` (`budget-and-wave-cap.md`). Never ask. |
| Wave cap above the context default | Use the recommendation; record it in `[WAVE-SUMMARY]`. |
| NEEDS_CONTEXT more than twice | Escalate the task; continue. |
| BLOCKED: plan defect | Ruling, then re-dispatch with the ruling. |
| BLOCKED: capacity | Split the task or move it one model tier up; if neither is left, escalate. |
| BLOCKED: scope change | Escalate; continue. |
| Plan-mandated defect reported by a reviewer | Ruling: fix it or keep the plan's approach, recorded. |
| Review loop past its cap | Ruling on the remaining findings: fix, accept with reason, or escalate if a hard stop applies. |
| Reviewer fails twice | Re-dispatch at a narrower scope or one model tier up; if that fails, escalate the task. |
| Verification still failing after 3 gap-closure attempts | Escalate the task; continue. |
| Destructive, irreversible, security-sensitive or remote step | Hard stop: escalate that step; finish the rest. |
| bd unavailable | Stop. The final line is `BLOCKED: bd unavailable`. |

## Visibility

- `[WAVE-SUMMARY]` carries `Rulings:` and `Escalated:` lines (`metrics-tracking.md`).
- The completion report's first line is `SDD-STATUS: COMPLETE` or `SDD-STATUS: PARTIAL`. Use `PARTIAL` whenever any epic child is open, including `human`-labeled beads. It lists every ruling under "Rulings I made".
- bd comments survive checkpoint cleanup and compaction. On resume, rebuild pending escalations from bd (`checkpoint-recovery.md`), not from memory.
