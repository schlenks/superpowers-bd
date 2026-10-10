# Superpowers-BD performance pilots — 2026-09-22

The original local pilots were not token-cost benchmarks. The same active Codex model ran each blinded review and plan treatment. At that point Claude CLI returned `401` (expired OAuth token), and `codex exec` could not initialize its app server (`EPERM`). Claude CLI recovered after the weekly reset, allowing the later V3.2 Sonnet cycle below. Repeated matched task-level runs remain unavailable.

## Duplicate Codex context

- A saved session transcript contains two identical 3,868-byte routing blocks in each of two turns and two identical 38-byte work-state blocks in each of five prompt turns.
- This machine's Codex config enables both project-local and installed-plugin hooks. Project-local SessionStart and UserPromptSubmit now defer when the corresponding installed-plugin hook is enabled and trusted. A local-only or untrusted-plugin configuration still emits context.
- Simulating both hook sources after the change produces one routing block instead of two: 3,868 bytes removed per startup/resume/compact injection. The five observed prompt turns would each save 38 bytes. Bytes are a proxy, not measured billed tokens.
- The installed-plugin `PostCompact` registration was removed. [Codex hook documentation](https://learn.chatgpt.com/docs/hooks) specifies `SessionStart(source: compact)` for restored developer context; `PostCompact` does not define `additionalContext`. The protected project-local `.codex/hooks.json` could not be edited in this environment, so its legacy `PostCompact` command now exits without context. The installed cached plugin will retain its old registration until refreshed.
- The project-local prompt hook's plugin-enabled median was 66.6 ms over 20 invocations; the installed-plugin prompt hook's median was 498.7 ms. Hooks for the same event run concurrently, so these figures show avoided duplicate work, not a demonstrated 432 ms wall-time saving.
- Claude Code issue [#17688](https://github.com/anthropics/claude-code/issues/17688) is now closed. The separate plugin-frontmatter workaround remains until this repository's live integration test proves native hook execution; Claude CLI authentication prevented that test here.

## Task review fanout

- Fixture: `tests/verification/fixtures/*-v3.*`, with 12 keyed defects and 16 keyed decoys. A pro-tier-shaped pair of one spec reviewer and one code reviewer was compared with one combined reviewer returning both verdicts. The max-tier three-code-reviewer fanout was not run. All were blinded to `ground-truth-v3.json`.
- Against that key, the two-reviewer union named 11/12 defects; the combined reviewer named 10/12. Both rejected the implementation and found serious defects outside the key, including unreachable bulk routes. The combined reviewer missed the request-order defect named by the spec reviewer.
- The key marks the 10 KB body limit as a safe decoy, but 100 permitted 200-character titles exceed that limit; the fixture needs recalibration before precision or false-positive rates are trusted. The key's bulk-delete performance finding also overlaps a more severe atomicity failure.
- One run has no reliable cost, wall-time, or variance estimate. Keep the current review pipeline until repeated matched runs show lower cost with preserved correctness.

### Fixture revision after the pilot

The V3 fixture is now version 3.4 with its calibration gate closed after a failed audit. V3.1 exposed unsound decoys and major unkeyed defects; V3.2 repaired them but a Sonnet pilot exposed an unkeyed body-size test gap in the depicted suite. An Opus 5 high-effort probe of V3.3 then exposed an unkeyed webhook retry defect, and the V3.4 audit found more unkeyed behavior. The [fixture audit](2026-09-22-v3-fixture-audit.md) records the evidence. V3 is retired from workflow treatment selection. The 11/12 and 10/12 results above belong to an earlier fixture and cannot be compared directly with new trials.

### V3.2 Sonnet trial, invalidated during adjudication

One paired cycle ran eight Sonnet 5 reviews on V3.2. All eight returned parsable
area JSON. The four specialists and four generalists each found all 12 planted
defects in aggregate. One generalist also flagged that the depicted test suite
had no body-size regression test. That observation was correct, even though D7
was keyed as a safe implementation. The script counted it as a false positive;
that count and its `PARTIAL` verdict are **invalid**. V3.3 adds the missing
boundary tests and has not yet received a scored model trial.

| Condition | Calls | Planted recall | Reported cost | Summed call time | Cache created | Cache read | Output tokens |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Four specialists | 4 | 12/12 | $1.9508 | 749.2 s | 261,836 | 90,225 | 78,700 |
| Four generalists | 4 | 12/12 | $1.9510 | 757.9 s | 255,319 | 95,592 | 81,213 |

Costs are the CLI's model-aware list-price estimates for successful calls,
including auxiliary model use. The saved V3.2 rows lack retry metadata, so
they cannot establish total billed cost or full wall time if a call retried.
The current harness uses one attempt per reviewer; failed calls remain visible
and cannot enter paired inference. The [usage](data/v3-2-invalid-usage.jsonl),
[reviewer scores](data/v3-2-invalid-results.csv), and
[aggregate rows](data/v3-2-invalid-aggregate.csv) are retained for audit, not
for treatment selection. The old harness deleted raw prompts and responses;
these preserved rows support the numeric table but cannot independently
reproduce the D7 wording. The harness now retains complete run artifacts and
the exact fixture snapshot. A single Sonnet generalist also found 12/12 with no
flagged decoys in this cycle, so this fixture offers little headroom for a
four-reviewer accuracy comparison on Sonnet 5. The mixed Sonnet/Opus trial was
not run on this ceiling-prone fixture. No review-fanout change follows from it.

### V3.3 Opus 5 high-effort feasibility probe

Two isolated, read-only CLI calls reviewed the same seven-file V3.3 snapshot
without the old area hints: one dual-verdict reviewer and one spec-only gate.
Both used `--model opus --effort high --safe-mode --tools ''` and returned
`claude-opus-5` in model usage. Each named all 12 planted defects and kept the
task open. The spec-only gate also found that the retry loop made only two
retries after the initial attempt, an unkeyed real defect confirmed by a
failing HTTP check (3 attempts versus 4 required). V3.3 is therefore invalid
for precision or treatment selection.

| Call | Reported cost | Duration | Cache created/read | Output tokens |
| --- | ---: | ---: | ---: | ---: |
| Dual verdict | $0.6112 | 126.1 s | 32,390 / 0 | 10,579 |
| Spec-only gate | $0.5760 | 108.0 s | 29,997 / 2,365 | 10,082 |

These are successful-call CLI list-price estimates, including auxiliary Haiku
usage. The prompt, full raw response, command, and input hashes remain in
`temp/optimization-eval/opus-high-v3-3-probe/` locally. This is one ordered
pair with tools disabled, not a full SDD run. Current SDD would stop after
the failed spec gate, so the four-reviewer code fanout was correctly not run.
The saturated fixture and newly discovered defects rule out a cost conclusion.

### Opus 5 high-effort historical task replay

Three pre-review tasks from the Codex parity epic were replayed against their
historical source snapshots with read-only `Read` access. The baseline used a
spec-first gate and, only on `PASS`, three code reviewers plus a low-cost
aggregator. The treatment used one dual-verdict reviewer. All review calls
used Opus 5 at high effort. [Full measurements and adjudication](2026-09-22-opus-high-historical-replay.md)
and [machine-readable receipts](data/opus-high-historical-replay.json) are
retained.

The sole full-fanout case cost $2.0931 baseline versus $0.6679 dual, with both
arms finding the main known documentation overclaim and keeping the task open.
On a separate hooks task, the dual reviewer missed a self-contained `/hooks`
documentation requirement that spec-only caught, though it found a different
hook-path bug and kept the task open. The correctness gate therefore fails:
do not replace current fanout with one dual reviewer. The result is one-cycle,
historical, and custom-prompt evidence, not a production savings estimate.

## Plan review

- Scratch fixture: `temp/optimization-eval/requirements.md` and `flawed-plan.md`. One reviewer repaired a copy inline; five fresh reviewers repaired another copy in Draft, Feasibility, Completeness, Risk, and Optimality order.
- Both repaired the seeded requirement, dependency, interface, command, file-list, push, and unnecessary-network gaps. The five-pass plan added an isolated test that `render()` calls `format()`; the inline plan tested only returned strings.
- Independent executions under `temp/optimization-eval/inline-run/` and `five-run/` passed 6/6 and 8/8 Node 24 tests respectively. Both plans still used `## Task` headings; the Claude plan2beads command recognizes only `### Task N:` and would create no children. The Codex flow had no explicit heading rule during the pilot. Scratch directories resolved plain `node` to v26, so execution used the installed Node 24 binary explicitly.
- Keep five-pass Claude plan review for now. A one-run same-model pilot cannot establish Sonnet cost or final implementation reliability. The H3 heading check has since been added to shared plan verification and the Codex flow; repeat matched runs with a repaired held-out fixture.

## Next measurement gate

Claude CLI is available again. The historical replay rejected the initial
dual-verdict treatment at the correctness gate, so more repetitions of that
unchanged prompt would spend tokens without qualifying it. A revised
treatment needs a frozen, held-out epic with spec and code defects, an
unresolved sibling dependency, and a clean task. Run repeated matched
current-fanout and revised dual-verdict treatments under the same models and
acceptance checks. Capture input, output, and cache tokens; elapsed time;
tool calls; defect recall and severity; false positives; and actual task
closure. Do not adopt a cheaper workflow if correctness falls.
