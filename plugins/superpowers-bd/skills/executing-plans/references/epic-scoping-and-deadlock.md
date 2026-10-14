# Epic Scoping and Deadlock Detection

## Epic Scoping

`bd ready` is global: it shows ready issues across all epics, lists question beads unless you exclude them, and never lists `in_progress` issues. Scope it every time, in this order:

```bash
bd show <epic-id>                                    # child IDs, including the verification task
bd list --parent <epic-id> --status in_progress      # interrupted work: resume it first
bd ready --parent <epic-id> --exclude-label human    # ready work, without question beads
```

Work only on children of your epic. Leave the verification task for the Final Review; never work on a question bead (it is the human's inbox).

## Order

`bd ready` is the order. Closing an issue unblocks its dependents, so re-run it after every close:

```
start:        .1, .2 ready;  .3 blocked by .1;  .4 blocked by .2, .3
close .1      -> .3 ready
close .2, .3  -> .4 ready
close .4      -> verification task ready -> Final Review
```

## Deadlock Detection

No ready issue for your epic while children remain open:

1. `bd blocked` shows what each open child waits on.
2. Waiting on a question bead (`human` label): that is an open escalation, not a deadlock. The run ends `SDD-STATUS: PARTIAL` once nothing else is ready.
3. An `in_progress` child left from before compaction: `bd ready` hides it, so it can look like nothing is left. Resume it (SKILL.md "What next").
4. Waiting on a closed-looking issue you finished: you forgot `bd close`. Close it with its evidence.
5. A dependency cycle (A -> B -> A): post a `[RULING]` removing the edge that the epic's Key Decisions or spec do not support (`bd dep remove`), then continue. If no source supports either edge, escalate with a question bead.

## If bd Commands Fail

bd being unavailable is a hard stop (`../../subagent-driven-development/rulings-and-escalation.md`), because bd is the only durable record of progress and rulings.

1. Retry once, then check `bd doctor` and `git status`.
2. Still failing: stop. Report the exact command and error, every commit made this session, and which issues those commits implement, so the next session can reconcile bd with git.
