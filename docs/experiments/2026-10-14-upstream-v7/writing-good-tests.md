# writing-good-tests research (2026-10-14)

The parent session saved this from the subagent's hand-back, because the subagent's own write was blocked. The harness, results and upstream PR text are in this directory: `harness/experiments/{s1-retry,s2-script,s3-pressure}`, `harness/results/*.jsonl`, `harness/summarize.py`, `upstream/`.

Spend: about $10.00 over 80 runs (Opus $5.27), against a $15 budget.

## Recommendation: adapt it, don't copy it

- **Replace** `references/testing-anti-patterns.md` (byte-identical to upstream v6.1.1, last touched 2026-01-30) with an adapted `writing-good-tests.md`.
- **Widen the SKILL.md pointer to "any test writing".** Today it only fires on "adding mocks or test-only production APIs", so Sonnet read the reference in 0/21 runs.
- **Update `rule-of-five-tests` and the reviewer/implementer checklists,** which would otherwise contradict the new guidance.
- **Add a lint carve-out.** Do not import "never grep a skill's text" unchanged: linting executable instructions (tool parameters, commands, links, mirrors) is a linter, not a behavior test.
- **Do not fold "Why Order Matters" into rationalization rows.** It showed no effect (8/8 vs 8/8).

The measured win is the broader trigger plus the change-detector rule. The string-presence and mutation-check additions showed no measurable falsifiability gain on a well-specified task.

## What's stale in bd

- **`testing-anti-patterns.md`:** catalogs mock anti-patterns only, behind a narrow trigger.
- **SKILL.md Test Quality:** generic bullets. Nothing on falsifiability, hand-derived expected values or change detectors.
- **`good-vs-bad-examples.md`:**
  - The Bad retry example is labeled "tests mock not code", but the Good example asserts the same call count. The real flaw is the vague name.
  - "Test passes? You're testing existing behavior" ignores broken fixtures (upstream #2092/#2196).
- **`rule-of-five-tests`:**
  - "Every public function has a test" is coverage theater.
  - "I/O mocked where possible" contradicts testing the real thing.
  - "DRY helpers" contradicts keeping expected values out of helpers.
  - "Tests don't have bugs" is wrong: a tautological test is the bug.
  - "Tests define correctness" leaves no falsifiability lens.
- **`code-reviewer.md` step 8:** nothing on mirror assertions, change detectors or grep-the-source tests.
- **Implementer self-review:** "Comprehensive?" invites padding. The 5.13.0 Test Integrity policy is orthogonal and should stay.
- **Epic-verifier 1.3:** function-coverage lens only.

## Upstream evidence (as upstream reported it)

- **PR #1935:** micro-tests at n=2–3 per change; the rewrite was parity-checked 3/3; no mutation-score data.
- **PR #1934:** deleting "Why Order Matters" dropped test-first from 8/10 to 5/10. The fold that replaced it was never re-scored. The file is unchanged from v6.2.0 through v7.0.0.
- **PR #2141 (closed):** the mental mutation check was executed 0/5 times. An executed-mutation rule reached 4/5 but was rejected.

## Experiments

Setup:
- Claude Code 2.1.299.
- The harness is a copy of `research-2026-09` with per-arm fixture overlays. Each run used a fresh repo outside the project and `--setting-sources project`, and the prompt told the agent to read `.skills/test-driven-development/SKILL.md`.
- The `haiku` alias resolved to claude-haiku-5-5, not Haiku 4.5.

Arms:
- **Arm A:** the current working-tree TDD skill plus the old reference.
- **Arm B:** Test Quality bullets replaced by a pointer ("read writing-good-tests.md when writing or changing any test") plus 4 bullets, with upstream's file verbatim.

Grader: drops tests that fail on the reference implementation, then counts planted mutants killed.

**S1: retry helper, 14 mutants**

| Model | Arm | n | Mean kills | Change-detector runs | Read the reference | Test-first | Cost |
|---|---|---|---|---|---|---|---|
| Sonnet 5 | A | 8 | 13.75 | 8/8 | 0/8 | 8/8 | $0.83 |
| Sonnet 5 | B | 8 | 13.50 | 1/8 (p=.0014) | 8/8 | 8/8 | $0.90 |
| Opus 5.5 | A | 5 | 13.8 | 4/5 | 4/5 | 4/5 | $3.24 |
| Opus 5.5 | B | 5 | 13.6 | 0/5 (p=.048) | 5/5 | 4/5 | $2.04 |
| Haiku 5.5 | A | 8 | 12.6 (min 9) | 5/8 | 8/8 | 8/8 | $0.09 |
| Haiku 5.5 | B | 8 | 12.9 (min 11) | 3/8 | 8/8 | 8/8 | $0.10 |

- Pooled change detectors (constant-equality asserts such as `assert MAX_DELAY == 2.0`): 17/21 → 4/21 (p=0.00014).
- Every run also killed the default-literal mutant, so the constant asserts were pure maintenance cost.
- Kills saturated in both arms. Arm B suites were 5–17% smaller.

**S2: `bump-version.sh` change under an "every change ships a test" rule, 8 mutants**

- All 20 runs (Sonnet and Haiku, n=5 per arm) executed the script; none asserted on its text.
- Mean kills: Sonnet A 7.4 vs B 8.0 (2 vs 6 tests); Haiku A 8.0 vs B 6.8.
- The Haiku B figure is a grader artifact: that suite's main rejection test included `""`, which the reference handles with exit 1, so the grader dropped it.
- The string-presence trap did not occur without RED pressure.

**S3: "write it, test after" pressure (Sonnet, S1 task, n=8 per arm)**

- Current bd: 8/8 test-first with RED observed.
- Inline rationalization rows: also 8/8. No headroom.

**Not separated or not tested:**
- Trigger vs content effects were not separated (though Opus and Haiku read the old reference too and still improved in B).
- Mock misuse, mirror assertions and test-only methods.
- Vague tasks.

## bd's own grep-style tests

Classification (approximate, by hand) of `tests/claude-code/test-workflow-contract-audit.sh` (33 checks) and `test-subagent-driven-development.sh`, which greps the skill by design after live-model probes proved flaky:

- **About 13 legitimate lints or invariants** — mirrors, the beads fixture, invalid-API, blocked-command and dangerous-glob checks, stale pointers, heredoc structure, no `rg`, runner fails closed. Keep.
- **About 15 required-phrase change detectors** (e.g. `Triage|triage`, `capabilit`). Stop adding these; retire them or replace them with `evals/` cases when they block a rewording.
- **3 counterfeit behavior checks** (epic-verifier persistence): named as behavior but only regex the prompt. Convert them to execute the heredoc in a temp git repo against the stub `bd`.
- **2–3 "removed content stays removed" checks.** Keep only where reintroduction is a known recurring regression.

## Change outline

1. **Adapted reference:**
   - `superpowers-bd:` naming;
   - the lint carve-out;
   - mutation check either executed-only (for input or fixture tests, with `git diff` restore proof) or dropped.
2. **Delete the old file** in `skills/` and `plugins/superpowers-bd/skills/`.
3. **SKILL.md:** use the arm-B text.
4. **`good-vs-bad-examples.md`:** fix the Bad-example label.
5. **`rule-of-five-tests`:**
   - Pass 2 becomes Coverage & Falsifiability, dropping "every public function has a test".
   - Pass 4 drops "mock I/O where possible".
   - Pass 5 allows DRY helpers for setup only, never for expected values.
   - Delete the "tests don't have bugs" row.
   - Keep the 5 passes and point to the reference.
6. **Lens edits:**
   - code-reviewer step 8;
   - implementer self-review ("Comprehensive?" → "names the break?");
   - epic-verifier check 1.3.
7. **Leave alone:** "Why Order Matters" and the Test Integrity policy.
8. **Validate:** run `run-skill-tests.sh` and re-run S1 against the edited tree.

## Risks

- About 1.3k words loaded on every test task; +8% per run on Sonnet.
- "Trivial code earns no test" could be over-applied on vague tasks.
- Without the carve-out, the guidance conflicts with bd's own audit suite.
- Merge on top of the uncommitted TDD `SKILL.md` and implementer edits (suite-level green).
- Synthetic tasks, small Opus n, and Haiku 5.5 rather than 4.5.
