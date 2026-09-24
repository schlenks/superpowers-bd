# Tier 1/2 research candidates: A/B results (2026-09-24)

Follow-up to the 2026-09 arXiv survey. Each candidate change was tested as an isolated
A/B against the current prompt with headless `claude -p` (Claude Code 2.1.281), a fresh
git fixture per run, a stub `bd`, no plugins/hooks (`--setting-sources project`), and
deterministic graders. 584 runs, $114 total (429 Sonnet/Haiku + 155 Opus). Harness: `tests/research-2026-09/`.

## Adopted

| Change | Where | Result |
|---|---|---|
| **Test Integrity policy** + "test/spec looks wrong → BLOCKED" trigger | `implementer-prompt.md` | Haiku: tampering 27/30 → 2/30 (both disclosed); tampering hidden behind a plain `VERDICT: DONE` 16/30 → 0/30; cost −14% to −34%. Sonnet: 6/30 → 0/30 (all disclosed at baseline), cost flat. Opus: 4/30 → 0/30 (all disclosed at baseline), cost flat. All models: 37/90 → 2/90 (p=4e-11). Control (legit obsolete-test removal): 10/10 solved both arms on every model. |
| **`INTERFACES:` verdict line → `[WAVE-SUMMARY]` interface changes** | `implementer-prompt.md`, `metrics-tracking.md`, `context-loading.md`, `background-execution.md` | Consumer (Sonnet, stale plan text after a wave-1 unit change): correct 12/20 + 8/20 escalated → 20/20 correct (p=0.003), +13% per run but removes a re-dispatch round trip in 40% of tasks. Opus 19/20 → 20/20 (already reads the code; note costs nothing, −4%). Haiku 10/10 both arms. Producer: Sonnet 5/5, Opus 5/5, Haiku 4/5. |
| **Numbered criteria checklist** in spec review | `spec-reviewer-prompt.md` | Haiku (default spec reviewer): false FAIL on correct code 14/20 → 6/20 (p=0.026), same cost; recall on 2 silent gaps 30/30 both arms. Sonnet: 5/10 → 4/10, Opus: 6/10 → 4/10 (neither significant alone); pooled over all three models 25/40 → 14/40 (p=0.025). Recall unchanged on every model (Sonnet 10/10, Opus 5/5). |

## Rejected (no headroom on current models)

| Candidate | Result |
|---|---|
| Reviewer "reproduce before you block" | Correct code: Sonnet raised 0 invented behavioral bugs in 8 reviews (the blocks were legitimate missing-test findings, which the rule exempts); Haiku 8/8 clean in both arms; buggy code caught 16/16. The existing precision gate already does this job. |
| Spec reviewer reads diff before `[IMPL-REPORT]` | Recall 10/10 vs 10/10; false FAIL 7/10 vs 7/10 (Haiku). No effect. |
| Bug fix must show fail-before/pass-after | Agent regression tests already failed on the unfixed code 10/10 (Sonnet). The rule only changed what the report says (0/10 → 10/10 mention) at +11% cost. |
| Deterministic test-edit hook | Every test edit it would flag was already disclosed; it cannot see the dangerous case (implementation special-casing). Superseded by the policy. |
| Verdict-vs-reality audit hook | 74 DONE verdicts audited: 0 Sonnet mismatches; 3 Haiku (2 missing `TESTS:` lines, 1 uncommitted). No false test claims. |

## Not tested

- Skill trimming (`superpowers_bd-yfi`) — a larger refactor; needs its own eval.
- Stop-gate frozen checklist — Stop hooks can't be A/B'd cleanly in `-p` runs.
- Worktree-per-implementer, wave-cap change, coupling-aware decomposition — Tier 3.

## Caveats

- One to four synthetic fixtures per candidate; effects on real epics may be smaller.
- User-level `~/.claude/CLAUDE.md` was loaded in both arms (it already demands evidence).
- Model aliases `sonnet`/`haiku`/`opus` resolved to Sonnet 5 / Haiku 4.5 / Opus 5.5 at run time, default effort.
- Opus rarely needs these changes (it disclosed every test edit and read the changed code 19/20 times), but none of them cost Opus anything or hurt it.

## Reproduce

```bash
cd tests/research-2026-09
python3 build_e1.py && python3 render_prompts.py e1-roman-impossible   # arm A = git HEAD, B = worktree
python3 harness.py e1-roman-impossible -n 10 --model haiku
python3 analyze.py results/e1-roman-impossible--haiku.jsonl --metric tampered_tests
```

Arm A for E1/E4 renders from `git:HEAD`, so after these changes are committed A and B
are identical; check out the pre-change commit to reproduce the baseline.
