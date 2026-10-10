# Opus 5 high-effort historical review replay

## Decision

Keep the current staged spec and code review pipeline. One dual-verdict
reviewer missed a self-contained `/hooks` documentation requirement that the
spec-only gate found on task `superpowers_bd-3rz.5`. A matching `KEEP_OPEN`
decision did not preserve the complete fix list. The dual approach saved cost
in the one task that reached full fanout, but this correctness miss triggers
the pilot stop rule. No fanout change follows from these trials.

## Method

Review calls used `claude -p - --model opus --effort high --safe-mode --tools Read --output-format stream-json --verbose --max-budget-usd 4` with a prompt
on standard input and a complete historical source snapshot. A dual
reviewer returned separate spec and quality verdicts. The baseline ran a
spec-only reviewer first and stopped on `FAIL`; only after `PASS` did it run
three independent code reviewers in parallel and a low-cost Haiku aggregator
with no tools. The implementer report was supplied as untrusted context. Historical review
comments and later gap-fix commits were excluded from the model snapshot.
Each case used a randomly selected arm order. Prompts, streams, snapshot
copies, diffs, and SHA-256 hashes are retained locally in
`temp/optimization-eval/opus-high-{hook,parity,docs}-replay/`. The
[machine-readable receipt](data/opus-high-historical-replay.json) summarizes
the raw CLI usage and artifact hashes.

On 2026-10-10, all 11 receipt response hashes, recorded costs and durations,
and the three reviewed diff hashes were checked against the retained local
artifacts. The model calls were not repeated. The hooks receipt preserves an
initial tool-disabled manifest; its scored `*-response-full.jsonl` calls use
the later full-snapshot prompts with `Read` access.

| Task and pre-review head | Arm | Spec / quality | Cost | CLI duration | Read calls | Cache create / read | Output tokens |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Hooks `.5`, `c932e1d` | Spec-only baseline | FAIL / not run | $0.2820 | 26.5 s | 5 | 20,863 / 32,321 | 1,993 |
| Hooks `.5`, `c932e1d` | Dual | PASS / WITH_FIXES | $0.3452 | 47.0 s | 4 | 20,882 / 34,746 | 4,464 |
| Parity tests `.6`, `22e8b37` | Spec-only baseline | FAIL / not run | $0.6140 | 44.8 s | 17 | 41,928 / 112,990 | 5,173 |
| Parity tests `.6`, `22e8b37` | Dual | FAIL / WITH_FIXES | $0.7145 | 69.1 s | 16 | 45,066 / 154,190 | 7,110 |
| Documentation `.7`, `ccdb1e6` | Spec-only baseline | PASS | $0.4319 | 20.9 s | 11 | 32,056 / 91,959 | 2,329 |
| Documentation `.7`, `ccdb1e6` | Three code reviewers | WITH_FIXES each | $1.6259 total | 41.9 s parallel stage | 42 total | 111,521 / 345,516 | 12,666 |
| Documentation `.7`, `ccdb1e6` | Haiku aggregator | KEEP_OPEN | $0.0353 | 34.7 s | 0 | 7,238 / 0 | 3,367 |
| Documentation `.7`, `ccdb1e6` | Dual | FAIL / WITH_FIXES | $0.6679 | 37.7 s | 15 | 49,145 / 117,207 | 4,428 |

Costs are CLI list-price estimates including auxiliary Haiku use. The
documentation baseline totals **$2.0931** (spec, three reviewers, aggregator)
versus **$0.6679** for dual, a **68.1%** reduction in this one case. Its
sequential stage latency is about **97.5 s** (spec + slowest parallel reviewer
+ aggregator) versus **37.7 s** dual, a **61.3%** reduction. The baseline used
53 `Read` calls before aggregation versus 15 dual. These are descriptive
single samples with unequal cache state and local parallel execution. They
are not projected savings for the production workflow.

## Finding adjudication

- **Hooks task `.5`:** The task explicitly required `/hooks` review and trust
  instructions. The pre-review doc only said to use a generic hook review or
  trust flow. Spec-only returned `FAIL` on this gap. Dual returned spec `PASS`
  while finding the known relative hook-command path bug under quality. Both
  kept the task open, but the dual fix list omitted a requirement. The
  historical three-code-reviewer pass found the path bug; later commit
  `484bf4e` fixed it.
- **Parity task `.6`:** Both arms returned spec `FAIL` because the test suite
  allowed existing mapping framing in the SDD skill. The historical spec gate
  had passed this implementation. The dual reviewer missed the three
  important test-assertion gaps documented in the historical code aggregate;
  one separately run, dedicated Opus code reviewer missed them too. That
  diagnostic cost $0.5881 and is not part of the staged baseline. This case
  does not isolate a dual-review recall loss.
- **Documentation task `.7`:** Baseline spec returned `PASS`, matching its
  historical spec review. All three code reviewers and the dual reviewer
  caught the known overclaim that `tests/codex/run-tests.sh` covered live
  native plugin install and `$skill` loading. All also flagged an incomplete
  Claude hook-event list. Dual categorized the overclaim as a spec `FAIL`,
  while baseline classified it under code quality. Both kept the task open.
  Neither arm found every minor historical review item.

## Limits and next gate

These were historical replays with custom CLI prompts, not actual SDD agent
dispatch. The three tasks are related and not an independent held-out epic.
Two baseline spec gates failed, so those tasks did not exercise code fanout.
There is one full-fanout matched case, no repeated measurements, no clean task,
and no unresolved sibling-dependency case. Cases were chosen with historical
review outcomes visible to the experimenter, so selection bias is possible.
Raw prompts and streams are ignored local artifacts; the tracked receipt and
hashes do not by themselves reproduce the calls on another machine. The cost
result therefore cannot qualify a workflow change. A revised dual prompt
would need a fresh frozen key and the four-case repeated gate in the
[design](2026-09-22-opus-high-review-design.md).
