# Brainstorming v7 vs bd: recommendation and evidence (2026-10-14)

The parent session saved this from the subagent's hand-back, because the subagent's own write was blocked.

Artifacts in this directory:
- `results/results.jsonl`: 63 first-turn runs.
- `results/conversations.jsonl`: 4 multi-turn transcripts.
- `arms/v7bd/` and `arms/v7h/`: the candidate SKILL.md files. `v7h` is the recommended hybrid.
- `harness/*.py`: the scripts that produced the runs.
- `upstream/`: the full upstream PR bodies.

The agent graded runs from final messages and tool calls. Spend: $13.61 of the $15 budget.

## Recommendation: adapt v7, don't adopt it wholesale; leave the visual companion out

Keep v7's intent-first core:
- the offer to skip the questions,
- the open "real moment" question,
- playback, with guesses marked as guesses,
- sizing the work after intent is clear,
- tech-choice ownership,
- the builder check,
- the hard gate before implementation.

Change three things:
- Restore bd's "read the code first" step.
- Add a code-grounded opening for changes to existing code.
- Add a "when they're not there" rule for autonomous runs.

## The bigger finding: the skill mostly doesn't fire on changes to existing code

| Scenario | Fired | Notes |
|---|---|---|
| "Add caching", Bash available, Opus 5.5 and Sonnet 5, all 3 skill arms | 0/15 | Every run just built it; the builds were good |
| Same prompt through `claude plugin eval` (no Bash) | 5/6 | The old eval gain reproduced: 1.00 with the plugin vs 0.25 without |
| Upstream's "You MUST" description | 0/5 | No help |
| New greenfield app | 11/11 | — |
| "I'm offline, make your own calls" | 0/6 | Every run built a web app |

The plugin's measured eval value therefore depends on the no-Bash restriction. The user's CLAUDE.md is a possible confound that wasn't separated within budget.

## Measured: skill content, with the skill forced to run

**Caching scenario.**
- v7 as written:
  - asked "tell me about the last time the API felt slow" without reading code (0/6 read the code);
  - never raised staleness or invalidation (0/6).
- bd:
  - read the code 6/6;
  - raised the oversell risk 6/6, but always as an A/B/C menu.
- Hybrid:
  - read the code 5/5;
  - raised the risk 5/5, with no menu.

**Greenfield app.**
- bd opened with a platform menu recommending a web app (PWA) in 3/4.
- v7 asked an open "real moment" question 4/4.

**Simulated user (n=2 conversations per arm).**
- The hybrid surfaced the persona's hidden goal ("don't let me re-read old entries") 2/2. bd missed it 2/2 and designed a history tab.
- One bd menu steered the persona into iCloud sync against his stated wishes.
- The hybrid wrote a design doc and ran the builder check 1/2, and the check caught a real gap. bd wrote a design doc 0/2.
- Agent cost per conversation was 10–20% higher for the hybrid.

**Small edit (page size 50→25).** Both arms just did it, 3/3.

**Autonomous runs.**
- Nothing hung in any arm.
- bd wrote a design doc 3/3.
- v7 and the hybrid wrote 0, because they sized caching as a small change.

## Inferred, not tested here

Upstream reports large wins:
- 0/25 jargon openings,
- menus cut from 16–27 to 0–1 per conversation,
- 6/6 blind testers preferring it.

But its baseline was its own 2,600-word skill, not bd's 54-line one, and it ran no change-to-existing-code scenarios. Expect much smaller gains over bd.

## Change outline

1. Replace `skills/brainstorming/SKILL.md` with the hybrid, unwrapped to fit the 150-line limit (it's 197 lines hard-wrapped, about 1,750 words). Keep:
   - the "Use when…" description,
   - the `docs/plans/` location,
   - the worktrees → writing-plans handoff,
   - the Codex `request_user_input` line (`tests/codex/test-codex-workflow-semantics.sh:165` asserts it).
2. Add `builder-check-prompt.md` and mirror both files into `plugins/superpowers-bd/skills/brainstorming/`.
3. Evals:
   - add a Bash-enabled variant of `brainstorm-before-build`;
   - loosen its grader so it accepts staleness raised as the agent's own call;
   - add a greenfield platform case and a small-edit control.
4. Track triggering on existing-code changes as a separate issue.

## Risks

- The numbers are small: 2–3 runs per first-turn cell and 2 conversations per arm. The simulated user sometimes drifted from its brief.
- The rewrite only matters when the skill fires.
- The "when they're not there" rule is untested on project-sized work.
- The v7 style takes more turns to reach a design doc.

## Visual companion

Leave it out. It's a networked server with its own security history and tests, and it pays off in interactive UI sessions, which isn't where this project is heading.

## Gotcha

`claude plugin eval .` also picked up `temp/head-check-20261014/evals/`, a leftover scratch worktree, and ran it as a duplicate case for $0.70. The parent session has since removed that worktree.
