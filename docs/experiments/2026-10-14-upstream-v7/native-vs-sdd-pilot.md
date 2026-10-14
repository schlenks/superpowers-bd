# Native vs SDD pilot (2026-10-14)

Bead `superpowers_bd-ugg.9`. This pilot checks the Native-mode risk named in `execution-modes.md` §1: is Native cheaper than SDD on a small bd epic, and does it still catch a defect the spec implies but doesn't state?

- **Skills under test:** the tree at commit `7f0e4a1` (ugg.2, ugg.8, ugg.10 and ugg.11 landed). It was exported with `git archive` and loaded with `--plugin-dir`, so the runs used the branch's skills, agents and hooks rather than the installed plugin or files other tasks were still editing.
- **Controller:** Opus 5.5 (`--model opus`; the init event reports `claude-opus-5-5`), on Claude Code 2.1.300.
- **Spend:** $11.61 of $15. n = 3 Native and 1 SDD. At most 2 `claude` processes ran at once.

## Verdict

**GO, provisional:** a GO on cost; this fixture does not establish that Native catches defects as well as SDD. Keep the handoff recommendation as it is: Native for epics of 5 or fewer issues, or for all-`complexity:simple` epics. The pilot supports the cost case and found no stall or missed defect. It does not test compaction on longer epics, or how well Native's review catches a defect that the pre-flight scan cannot see.

- Native cost $1.69 per run on average (n=3), about a quarter of SDD's $6.54 (n=1, capped at $7, so a lower bound; Codex advisory cost not counted). Native finished in about 5 minutes; SDD took 30.
- Native shipped the planted defect fixed in 3 of 3 runs, and SDD in 1 of 1. In all four runs the controller's pre-flight scan caught the defect from the spec before any code was written. So this fixture tested the pre-flight scan, not whether Native's single final review can replace SDD's per-issue reviews (see Limits).
- In all four runs the Opus final review found extra spec violations that no issue mentions, and the fix pass fixed them. These findings are the only signal this pilot gives about the review layers.
- No run stalled, and every run ended `SDD-STATUS: COMPLETE`. No run compacted or resumed, so neither was tested.

Follow-up: `superpowers_bd-qto` (see Limits, "Next test").

## Method

The method follows `tests/research-2026-09/harness.py`, with three changes:

- **Real `bd`:** each run uses a real `bd init` (embedded Dolt) instead of the stub, because both modes rely on bd for state, dependencies and comments.
- **Plugin from the commit:** `--plugin-dir` points at the `7f0e4a1` export.
- **Budget cap:** each run gets a `--max-budget-usd` cap.

Each run copies a prebuilt template repo into its own directory under `/private/tmp/sbd-ugg-9/runs/` and runs:

```
claude -p <prompt> --model opus --output-format stream-json --verbose \
  --permission-mode bypassPermissions --setting-sources project \
  --no-session-persistence --plugin-dir <export of 7f0e4a1> --max-budget-usd <cap>
```

The scripts, fixture and transcripts are scratch files outside the repo and are not committed.

**Fixture: the `wordstat` CLI.** The fixture follows upstream's wordstat idea from PR #2318.

- `docs/spec.md` defines the words, the output block and the error contract. The error contract says: "wordstat must never end with a Python traceback. When wordstat cannot report on FILE, it prints a single line `wordstat: error: <reason>` to stderr and exits with status 2."
- The epic's Key Decisions say the spec outranks the issue text.
- The bd epic has four implementation issues and an Epic Verification task:

| Issue | Complexity | Depends on |
|---|---|---|
| Tokenizer | simple | – |
| Stats and top_n | simple | – |
| Report formatter | simple | Stats and top_n |
| CLI entry point | standard | all three above |
| Epic Verification | – | all four issues |

**Planted defect.** The CLI issue says: "If the file does not exist or cannot be opened (`OSError`), print `wordstat: error: cannot open FILE`."

- A non-UTF-8 file raises `UnicodeDecodeError`, which is a `ValueError`, not an `OSError`, so an implementation that follows the issue literally crashes with a traceback.
- The spec's no-traceback rule implies that case but does not state it.
- A reference implementation that catches only `OSError` reproduces the traceback under the grader.

**Prompts.**
- **Native:** "Execute beads epic `<id>` natively using the superpowers-bd:executing-plans skill."
- **SDD:** "Execute epic `<id>` using the superpowers-bd:subagent-driven-development skill."
- Both prompts continue: "Execution mode was already chosen: …. This is an unattended run … Do not push, merge, or open a PR …". SDD used the default `max-5x` budget tier.

**Grading** (`grade.py`, run against the final working tree):
- **Defect caught:** `python3 -m wordstat <binary file>` exits 2 with exactly one stderr line that starts `wordstat: error:` and no traceback.
- **Hidden behaviour checks:** a known sample with `--top 2` must match the expected output byte for byte; an empty file and a missing file are also checked.
- **Agent's own suite** must pass.
- **bd:** every child must be closed.
- **From the transcript:** cost (`total_cost_usd`, which includes subagent usage in `modelUsage`), wall time, `SDD-STATUS`, and the counts of `Agent` and `SendMessage` calls.

## Results

| Run | Cost | Wall | Defect caught | Stalled | SDD-STATUS | Subagent dispatches | Hidden checks | Own suite | bd children closed |
|---|---|---|---|---|---|---|---|---|---|
| native-00 | $1.73 | 5.3 min | yes | no | COMPLETE | 2 (1 Opus verifier, 1 simplifier) | pass | 22 pass | 5/5 |
| native-01 | $1.75 | 5.8 min | yes | no | COMPLETE | 2 (1 Opus verifier, 1 simplifier) | pass | 25 pass | 5/5 |
| native-02 | $1.59 | 4.7 min | yes | no | COMPLETE | 2 (1 Opus verifier, 1 simplifier) | pass | 27 pass | 5/5 |
| sdd-00 | $6.54 | 30.5 min | yes | no | COMPLETE | 30 `Agent` + 3 `SendMessage` | pass | 40 pass | 7/7 (2 gap-closure issues added) |

**Native mean:** $1.69 and 5.3 min. **SDD:** 3.9× the cost and 5.8× the wall time.

### SDD cost and dispatches

- **Cost by model:** Opus $5.01 (the controller plus 2 Opus verifier runs), Sonnet $1.44, Haiku $0.08.
- **Dispatches:**
  - 4 implementers;
  - 4 spec reviewers;
  - 6 code reviewers (N=1 for each simple issue, N=3 for the CLI issue);
  - 4 Codex cross-model advisory wrappers on Haiku (the session-start hook found the local Codex install);
  - 2 fresh fix dispatches and 3 scoped re-reviewers;
  - 1 epic verification and 2 re-verifications;
  - 2 gap-closure implementers and 2 gap-closure reviews.
- **What the dispatch counts show:** the ugg.11 complexity fan-out worked (simple issues got N=1). Micro-task batching did not trigger, as expected, because the three simple issues are not the same shape.

### Where the defect was caught

All four runs caught the defect in the same place: the controller's **pre-flight scan**, before any code was written. Each controller set the CLI issue against the spec's Errors section, posted a `[RULING]` to also catch `UnicodeDecodeError`, and the implementation then shipped with a test for that case. No per-issue reviewer and no final verifier had to find it.

### What the final review added

- In every Native run the Opus verifier returned FAIL with 2–3 further spec violations. Examples:
  - a newline in the FILE path split the error over two lines;
  - a closed or broken stdout gave a traceback, or exit 1 or 120;
  - the CLI tests only passed when run from the repo root.
- The single fix pass fixed each one test-first.
- SDD's verifier found the same class of issue and closed it through two gap-closure issues.
- So on this fixture, Native's one final review matched what SDD's per-issue reviews plus verifier delivered. That rests on SDD n=1, and that run's last re-verification was moved to Sonnet because of the budget cap.

### Things to know about the runs

1. **The SDD run reacted to its budget cap.** It reported "about $1.40 was left", then ran its last gap fixer and final re-verification on Sonnet instead of Opus. That suggests Claude Code shows `--max-budget-usd` to the model. Uncapped, SDD would have cost somewhat more, so $6.54 is a lower bound.
2. **Epic ID.** `native-00` and `sdd-00` were started with a stale epic ID (`ws-901`), because bd assigns hash IDs at each `bd init`. Both controllers found the real epic from the repo, posted a `[RULING]`, and carried on. The cost of that is a few tool calls. `native-01` and `native-02` used a fixed template with the correct ID.
3. **Codex cost is not counted.** The Codex advisory reviews ran outside Claude, so their cost is not in `total_cost_usd`. Their Haiku wrappers are counted.

## Limits

- **The fixture cannot tell the review layers apart.** The implied defect was caught at pre-flight by both modes. That is good news for the ugg.8 pre-flight scan, but this pilot does not repeat upstream's finding that only a fresh Opus review catches the defect. The spec's wording ("never end with a Python traceback") is probably explicit enough for a careful controller to connect. A defect that only shows up when the code runs would be the stronger test.
- **The sample is small.** SDD n=1 is a smoke result, not a distribution. Native n=3 is consistent: cost range $1.59–$1.75, all three caught.
- **One small epic.** The fixture has 4 issues. It says nothing about compaction risk on longer epics, which is why the ≤5-issue threshold exists; the threshold is unchanged.
- **The export predates later epic commits.** The plugin export at `7f0e4a1` predates `cfac41d`, `692597c` and `a686ed1`, which changed the TDD reference, the verifier's falsifiability lens, and the implementer and verifier prompts. Both arms use those prompts. The declared dependencies were all present, so the comparison stands, but "what ships" here means "as of `7f0e4a1`".
- **Next test (`superpowers_bd-qto`):**
  - Plant a defect the pre-flight scan cannot see from the bead text: one that only shows when the code runs, like the newline-in-path and closed-stdout cases that only the reviews found here. Or drop the "spec outranks issue text" Key Decision.
  - Run at least 3 reps per arm, with SDD uncapped or under a higher cap.
  - Include one run long enough to compact, so the ≤5-issue threshold and resume get tested.

## Spend

| Run | Cap | Cost |
|---|---|---|
| native-00 | $4 | $1.73 |
| native-01 | $4 | $1.75 |
| native-02 | $3 | $1.59 |
| sdd-00 | $7 | $6.54 |
| **Total** | | **$11.61** |

A second SDD rep (about $6.5) would have taken the total past $15, so SDD stayed at n=1 and Native got n=3, as the bead allows.
