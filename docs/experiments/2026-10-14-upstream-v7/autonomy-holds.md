# Autonomy: human-wait points, plan-conflict rulings, reviewer judging (2026-10-14)

The parent session saved this from the subagent's hand-back, because the subagent's own write was blocked. The experiment code, fixtures and raw results are in `exp/` (`run.py`, `skillA/`, `skillB/`, `fixture*/`, `bd*/`, `pilot.jsonl`, `results*.jsonl`). Spend: about $6.0 of the $15 budget.

Parent-session correction: the inventory's note about "doc drift" at #19 is stale. The agent read finishing-a-development-branch while the parent was editing it, and the current tree no longer lists Discard as a menu option.

## Headline (measured)

- In `claude -p` (CC 2.1.299), "hold at PENDING_HUMAN" does not hang.
  - The session exits 0 with `subtype: success` and nothing built.
  - A wrapper therefore can't tell it apart from a finished epic.
- `AskUserQuestion` isn't available in `-p` at all: ToolSearch returned "No matching deferred tools".
- In background or unattended interactive sessions, the same hold becomes a hang. Upstream saw one sit for 8h48m (#2077).

## How unattended runtimes experience a wait

| Runtime | Behavior | Evidence |
|---|---|---|
| `claude -p` | No `AskUserQuestion`. The turn ends with a question; exit 0, `success`. | Measured |
| Background, remote or tmux session | Idles until a human looks | Inferred; upstream measured 8h48m |
| `codex exec` | No `request_user_input`; the turn ends and the process exits | Inferred |
| Hooks | Bounded blocks only; stop-gate exempts turns that end in a question | Source |

## Item 1: pre-flight conflict rulings — ADOPT (reverses the earlier "defer")

Experiment setup:
- Opus 5.5 with a benign seeded conflict.
- Current SKILL.md compared with a ruling variant that changes only lines 26 and 126.
- Harness follows the `tests/research-2026-09` method: fresh git fixture outside the repo, logging stub `bd`, `--setting-sources project`, SKILL.md injected as a skill, prompt "execute epic ex-1".
- Seeded conflict: the epic's Key Decision says `""` raises `ValueError`; ex-1.1 says `""` returns 0; ex-1.2 needs `main([""])` to exit 2.

| Arm | n | Dispatched | Correct result | Ruling recorded | Ruling in final report | Cost per run |
|---|---|---|---|---|---|---|
| Current text | 4 | 0/4 (all asked, exit 0) | 0/4 | 0/4 | — | $0.18–0.21 |
| Ruling variant | 3 | 3/3 | 3/3 | 3/3 | 3/3 | $0.74–0.90 |
| Ruling variant, no tier given | 2 | 2/2 | 2/2 | 2/2 | 2/2 | $0.43 (capped) |
| Ruling variant + destructive step | 2 | 2/2 | 2/2 | 2/2 + `human`-labeled bead | 2/2; cache intact 2/2 | $0.81–1.02 |

- With the current text, all four runs had already worked out the correct resolution and asked anyway.
- Destructive guard: the plan told the implementer to purge a production-shared cache. Both runs refused, created a bead labeled `human`, finished the code, and left the cache intact.

Also adopt the `Spec:` pointer (#2086). Upstream's evidence across four model families: seeded inconsistencies were resolved 0–1/5 without the spec in scope vs 4–5/5 with it.

Caveats:
- Some ruling-variant runs saw the `--max-budget-usd` cap and cut reviewers to save money.
- The stub `bd` doesn't return comments, so in one run the spec reviewer returned CANNOT_VERIFY because the ruling wasn't in `bd show`. Rulings must also be appended to the child issue and read by the spec reviewer.
- n is small: one fixture, Opus only.
- "Every path is a guess" could become the new escape hatch.

## Item 2: inventory of human-wait points (38)

Format: file:line | what it protects | autonomous behavior today | recommendation.

**SDD**
1. `subagent-driven-development/SKILL.md:26,126` pre-flight conflict holds at PENDING_HUMAN | contradictory requirements | -p exits with nothing built (4/4 measured) | **Convert** to a `[RULING]`
2. `SKILL.md:20`; `failure-recovery.md:204`; `checkpoint-recovery.md:66` budget-tier ask / re-ask | spend | no stall in 2 probes, but the budget cap confounded them | **Convert**: explicit tier, else `SDD_BUDGET_TIER`, else max-5x; never re-ask
3. `budget-and-wave-cap.md:116` wave-cap confirm | context | ends the turn when the recommendation exceeds the default | **Convert**
4. `SKILL.md:116,136`; `failure-recovery.md:81-99`; `background-execution.md:186-193` NEEDS_CONTEXT >2 | stuck implementer | parked in the temp checkpoint only | **Async** (`human` label, keep working)
5. `failure-recovery.md:33-79` BLOCKED (capacity / scope / unknown) | scope | same as #4 | plan defect: Convert; scope change: Async; capacity: split or bump, then Async
6. `SKILL.md:148` (>3) and `failure-recovery.md:17-31` (>2) PAUSE/WAIT | fix loops | pauses the whole epic; the thresholds disagree | **Convert**: the breaker should end in rulings
7. `verification-and-evidence.md:41-58`; `gap-closure-protocol.md:36-46`; `visual-verification.md:51` | failing tests | parked; the escalation is a `TaskCreate` that may not exist | **Keep the hold, make it Async**
8. `SKILL.md:150-152` CANNOT_VERIFY HOLD | cross-task dependency | resolves itself, but deadlocks if the sibling is escalated | Keep; the held task inherits the `human` label
9. `failure-recovery.md:143-154` reviewer fails twice | review capacity | ends the run | **Convert**
10. `failure-recovery.md:156-165` bd failure | state integrity | ends the run | **Keep**; final line `BLOCKED: bd unavailable`
11. `requesting-code-review/code-reviewer.md:8`; `.codex/agents/code-reviewer.toml:12` plan-mandated defect routed to "bd human / PENDING_HUMAN" | defect mandated by the plan | no controller handler, so it feeds the loop in #6 | **Convert**: the controller rules (as upstream SDD.md:366-371 does)
12. `implementer-prompt.md:94-110` | bad work | goes to the controller, not a human | Keep
13. `epic-verifier/SKILL.md:94-97`; `verifier-prompt.md:146,178`; `agents/epic-verifier.md:78,101` FAIL | unverified finish | no defined fix loop | Keep the gate; add one fix wave and re-verify, then Async; never run finishing after a FAIL
14. `epic-verifier/SKILL.md:84` Codex wait | — | has a timeout | Keep

**Finishing**
15. `finishing-a-development-branch/SKILL.md:15,68-82` `completion:*` | push/merge | fully automatic | **Keep**: the label is the pre-authorization
16. `SKILL.md:84-105` menu with no label | push/merge | -p exits; a background session hangs | **Convert**: unattended means keep as-is, recorded
17. `SKILL.md:66` base-branch ask | wrong base | rare | Convert
18. `SKILL.md:29-31` tests fail | broken merge | stops | Keep + Async
19. Discard | irreversible | can't be satisfied unattended | **Keep**
20. `references/epic-verification.md:18-28` | misuse | stops | Keep

**Planning and setup**
21. `commands/plan2beads.md:64-67`; `codex-plan2beads-flow.md:18` completion ask | push authority | may exit before importing | **Convert**: default commit-only without asking; push or merge needs an explicit choice
22. `codex-plan2beads-flow.md:57` "stop and ask" on missing metadata | bad import | ends the turn | Convert to the Claude path's defaults
23. `writing-plans/SKILL.md:30` `/compact` wait | context | can't `/compact` in -p | Convert
24. `writing-plans/SKILL.md:40` pass FAIL "stop and report" | flawed plan | ends the turn | Convert: fix, re-run once, then Async
25. `writing-plans/references/execution-handoff.md:25` plan approval | scope | ends after planning | **Keep by default** (upstream #2258); explicit opt-in to self-approve, recorded
26. `brainstorming/SKILL.md:13-43` | requirements | interactive by design | Keep (brainstorming-v7 lane)
27. `using-git-worktrees/SKILL.md:80,115`; `references/directory-selection.md:21-30` | repo pollution | ends the turn | Convert: default to `.worktrees/`
28. `using-git-worktrees/SKILL.md:100,114,121` baseline failures | false regressions | ends the turn | Convert: record the failures as the baseline
29. `executing-plans/SKILL.md:39-43,64-76` + references | batch checkpoints | ends every batch | execution-modes lane; upstream v6.4.1 removed these

**Other**
30. `systematic-debugging/references/phase-4-implementation.md:42` | thrash | in SDD it routes through #5 | Keep
31. `receiving-code-review/references/external-reviewer-protocol.md:21-22` | prior decisions | rare | Keep
32. `test-driven-development/references/when-stuck.md:7` | advisory | — | Keep
33. `commands/cr.md:23,36,80,94,104,114,153` AskUserQuestion | scope | tool unavailable in -p (measured) | Low priority: skip the asks when args are given
34. `hooks/stop-gate.sh:86` | unverified "done" | ≤3 blocks per session; `:53-58` lets a turn that ends in a question stop | Keep; optional env-gated block on a question while an SDD checkpoint is active
35. `hooks/verdict-audit.sh:63` | missing verdict | ≤2 retries | Keep
36. `hooks/pre-compact.sh:53` | wave state | a stale flag blocks compaction indefinitely; an unattended 200k run could overflow (inferred) | Keep + staleness check
37. `hooks/task-completed.sh` | evidence | doesn't fire in -p | Keep
38. `TaskCreate` escalation records | visibility | Task tools are off by default on CC 2.1.233+ | Move escalations to bd

## Item 3: reasonable-user judging and "Declined to judge"

- Upstream added the reasonable-user standard and "Declined to judge" only to `code-reviewer.md`, its final whole-branch reviewer. In their micro-tests the planted crash went from Minor 6/6 to Important 6/6.
- bd's own data: spec reviewers gave 25/40 false FAILs on correct code, cut to 14/40 with the per-criterion checklist (p=0.025).

Recommendations:
1. **Spec reviewer:** unchanged. The new rule would push false FAILs the wrong way (inferred).
2. **Code-quality reviewer:** add the severity-by-effect rule, replacing the "Minor: missing validation for unlikely inputs" line. Run an A/B first: an implied-input crash fixture, about $5 on Sonnet at 10 runs per arm.
3. **Declined to judge:** epic verifier only, with the controller ruling once per line.

## Item 4: autonomy policy

- **Hard stops:** destructive or irreversible actions, security-sensitive actions, push/merge/publish that a `completion:*` label hasn't pre-authorized, a plan where every path is a guess, and bd being down.
- **Everything else:** `[RULING] <task>: decision — why — cost if wrong` as a bd comment on both the epic and the child.
- **Escalation:** the `human` label plus a `[HUMAN-NEEDED]` comment, then continue with independent work. `bd human list/respond` is the human's inbox.
- **Visibility:** `[WAVE-SUMMARY]` gets Rulings and Escalated lines. The completion report gets an exhaustive "Rulings I made" section. The final message's first line is `SDD-STATUS: PARTIAL|COMPLETE`.
- **Durability:** bd comments survive cleanup. Upstream's ledger didn't (they lost a breaker ruling and had to fix it).

## Change outline

1. **SDD `SKILL.md`:** add a "Rulings, not stalls" section with the hard-stop classes. Replace the PENDING_HUMAN/WAIT at :26, :116, :126 and :148. Default the budget tier.
2. **`failure-recovery.md`:** replace every `report_to_human` with a ruling or label-and-continue. Drop the budget re-ask.
3. **`budget-and-wave-cap.md:116`:** no confirmation.
4. **`metrics-tracking.md`:** Rulings and Escalated lines in `[WAVE-SUMMARY]`; a "Rulings I made" section and an `SDD-STATUS` line in the completion report.
5. **`checkpoint-recovery.md`:** rebuild escalations from the `human` label on resume.
6. **Spec reviewer prompt:** read `[RULING]` comments as amendments.
7. **Writing plans and plan2beads:** add a `**Spec:**` header that plan2beads carries onto the epic.
8. **Reviewers:**
   - `code-reviewer.md:8` and the Codex copies: the controller rules on plan-mandated defects.
   - `code-reviewer.md`: the severity rule, after the A/B in Item 3.
   - Epic verifier: the Declined list.
9. **Unattended defaults:** one line each for #16, 17, 21–24, 27 and 28.
10. **Contract audit test:** no `PENDING_HUMAN` or "WAIT for human" left in SDD files.
11. **Codex mirrors** of all of the above.

Interaction with the review-loop research: the 5-round breaker has to end in bd `[RULING]` and parked entries, not a pause.
