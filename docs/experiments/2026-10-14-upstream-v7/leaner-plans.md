# Leaner plans (upstream v6.4.2, #2333): should superpowers-bd adopt it? (2026-10-14)

The parent session saved this from the subagent's hand-back, because the subagent's own write was blocked. Spend: $9.02 of $15 at list price (35 `claude -p` processes, at most 4 at once).

## Recommendation: adopt, adapted

Port upstream's changes:
- the step recipe ("What a Step Contains"),
- the proportion check,
- the capable-reader text,
- step sizing as "one action with a checkable result".

Also fix the three bd-only places that still assume the old plan shape:
- the "2-5 min" line in the rule-of-five Feasibility pass,
- the Codex verification reference,
- the `Remember` bullet "Complete code in plan".

Leave plan2beads and the implementer prompt unchanged. bd never shipped `plan-document-reviewer-prompt.md`, so there is nothing to delete.

## 1. What changed upstream

From `git diff v6.4.1 v6.4.2 -- skills/writing-plans`:

- **Reader.** "Zero context, questionable taste" becomes a capable engineer. The plan documents what was decided: files, names and signatures, the spec's values, and the tests.
- **Step sizing.** "2-5 minutes" becomes "one action with a checkable result".
- **Template Step 3.** A code block becomes `Implement fn(args) -> R in path`, plus one line on the approach.
- **"No Placeholders" is replaced by "What a Step Contains":**
  - Test step: the test's name and its assertions, using the spec's values.
  - Code step: the signature, the file and the pinned values. Include a body only for an algorithm the signature doesn't determine, or for exact copy.
  - Verification step: the command and its passing output.
  - Cross-task references go through the other task's Interfaces block.
  - Rule of thumb: "unambiguous, not complete".
- **Self-review.** Item 2 becomes a step scan that catches both gaps and transcribed bodies. New item 5 is **Proportion**.
- **Deleted** the unreferenced `plan-document-reviewer-prompt.md`.

Upstream's evidence, from the PR (not re-measured here):

| Upstream test | Old skill | New skill |
|---|---|---|
| Field replay, Opus 5.5, 5 runs per arm: scratch build | 5/5 | 0/5 |
| Plan size | 10-12k lines | 0.9-1.4k lines |
| Planning time | 47-67 min | 12-16 min |
| Tokens | 445-607K | ~175K |

- On a synthetic Go spec, scratch builds happened 2/2 even with no skill at all. This is model behaviour that full-code plans give a reason to act on.
- Terse plans executed 9/9 planted-defect probes on Sonnet 5, and 54/54 across the SDD arms.
- Upstream's own caveats: single planning runs, the author's CLAUDE.md was present, and Opus execution was untested.

**Where bd starts from.** bd never had "No Placeholders", but it carries the same pressure through:
- "Complete code in plan" in `Remember`,
- the template's `[code block]`,
- the "zero context / weak test design" reader,
- "2-5 min" steps, which also appear in the rule-of-five Feasibility checklist.

## 2. Does bd's skill over-build on Opus 5.5? Yes (measured, n=4 per arm)

Setup:
- One 110-line Python spec.
- Opus 5.5 (`claude-opus-5-5`) at medium effort.
- Skill installed at `.claude/skills`; runs outside the repo with `--setting-sources project`; tasks 1-2 only.
- **Arm A** is the HEAD skill. **Arm B** is A with upstream's changes ported (`arms/B-vs-A.diff`).

| | A (current) | B (lean) |
|---|---|---|
| Ran the product's code outside the plan | **4/4** | **0/4** (one 2-line regex probe) |
| Plan lines | 817-862 (7.4-7.8× the spec) | 228-378 (2.1-3.4×) |
| Lines in code fences | 532-572 (~66%) | 59-152 (26-43%, mostly test assertions) |
| Wall time, median | 233 s | 133 s (−43%) |
| Output tokens, median | 27.3K | 15.0K (−45%) |
| Input tokens, median | 390K | 259K (−34%) |
| Cost, median | $1.01 | $0.64 (−37%) |

- In arm A, one run built every module in `proto/` and then generated the plan from a template, which is upstream's `plangen` pattern. The other three extracted the plan's code into a scratch repo and ran pytest.
- Both arms produced 5 tasks with Interfaces, Review Focus and Global Constraints.
- The lean plans kept every spec string and corner case, for example argparse exiting 2 where the spec wants 64.
- What A had that B lacks: A's plan code was checked by actually running it. B's test snippets were never run, and one was missing imports that a later pass added.

## 3. Does a lean plan survive bd's downstream steps?

**plan2beads** (offline split using its rules):
- All 8 plans parsed.
- Depends on, Complexity, Files and Interfaces were present on every task.
- Bead bodies per epic: A 751-819 lines, B 216-362 lines.
- No plan2beads rule depends on code blocks, so no change is needed.

**rule-of-five-plans** (HEAD dispatch template; 5 Sonnet passes each on B-01, B-03 and A-01; 15 passes, $1.67):
- Lean plans: 0/10 BLOCKED, and no pass changed the amount of fenced code.
- The edits the passes made were real fixes: a README step, missing test imports, and an int-size guard.
- On the full-code plan, the **Feasibility pass extracted and ran every code block**. Sonnet shows the same build-it instinct during verification.

**SDD implementers** (HEAD shared implementer prompt; `haiku` resolved to Haiku 5.5; stub bd; sequential chains of 5 tasks; scored with 34 hidden probes validated against a reference implementation):

| Condition | Chains | Hidden probes |
|---|---|---|
| Spec present in the repo | A ×2, B ×2 | 34/34 in all |
| Spec deleted (bead is the only source) | A ×4, B ×4 | 34/34 in all |

- Verdicts: no BLOCKED or NEEDS_CONTEXT. One NO_VERDICT, in an A chain.
- Cost: about $0.01 per task.
- This is a ceiling effect. It shows no loss on this task, but cannot rule out degradation on harder or more ambiguous tasks.
- Not tested: Haiku 4.5, parallel waves, Sonnet chains.

## 4. Change outline

Mirror every `skills/` edit into `plugins/superpowers-bd/skills/` and keep `diff -rq` empty.

1. **`writing-plans/SKILL.md`** (reference version: `arms/B/writing-plans/SKILL.md`):
   - replace the reader text;
   - change step granularity;
   - add "What a Step Contains";
   - make template Step 3 a signature line;
   - add Step scan and Proportion to the checklist;
   - replace "Complete code in plan" in `Remember`.
   - This nets +13 lines on a file that is already over the length limit (`superpowers_bd-yfi`), so trim elsewhere.
2. **`writing-plans/references/verification-dispatch.md`:**
   - Feasibility: replace the "2-5 min" item with "one checkable result", and add "hand-trace; don't build or run the plan's code".
   - Optimality: add "no bodies the signature and tests already determine; plan not several times the spec's length".
3. **`rule-of-five-plans/references/pass-definitions.md` and the Feasibility row in `SKILL.md`:** the same wording as item 2, kept specific to plans.
4. **`writing-plans/references/codex-plan-verification.md`:** add the step-content rule, Step scan and Proportion.
5. **Tests:** assert "What a Step Contains" and "Proportion" are present and "Complete code in plan" is absent.
6. **No change:** plan2beads (command and skill), `implementer-prompt.md`, `file-lists.md`.
7. **Do not port:** the reviewer-prompt deletion and the CLAUDE.md removal.

## Risks and limits

- Small n. The 4/4 vs 0/4 split is the robust result; the implementer test hit its ceiling.
- Implementers get more latitude, so the Interfaces blocks become the contract between parallel tasks.
- Test snippets in the plan are no longer executed while planning. A wrong one should surface as BLOCKED under the Test Integrity policy.
- Not tested:
  - the full in-session flow with rule-of-five sub-agents,
  - planning arcs that span multiple compactions,
  - planning with the plugin's hooks active,
  - Fable planners.
- The large-spec blowup (14 hours, 16k lines) is upstream's number, not measured here.

## Spend

| Experiment | Cost |
|---|---|
| E1 planning | $6.72 |
| E2 rule-of-five | $1.67 |
| E3 implementer chains | $0.64 |
| **Total** | **$9.02** |

## Artifacts

All under this directory:
- `fixture/` — the spec
- `hidden/test_hidden.py` — the 34 hidden probes
- `arms/A`, `arms/B`, `arms/B-vs-A.diff` — the two skill versions and their diff
- `scripts/{plan_run,r5_run,chain_run,common,regrade}.py`
- `results/e1-plan.jsonl`, `results/plans/*/` (all 8 plans), `results/e2-r5.jsonl`, `results/r5-*.md`, `results/e3-chain.jsonl`

The run transcripts were in the session scratchpad under `lp-runs/` and are ephemeral.
