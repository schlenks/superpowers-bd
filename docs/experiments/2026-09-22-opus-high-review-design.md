# Opus 5 high-effort reviewer-fanout experiment

## Decision

Use a frozen, held-out beads-style epic with four task outcomes, then validate
the promising treatment in a real SDD run. The existing TaskFlow V3 fixture is
unsuitable for treatment selection: a single Opus 5 high-effort reviewer found
all 12 planted defects without the old area hints, and its V3.3 key missed a
webhook retry defect. A full live epic repeated from scratch would add
implementer and environment variance before reviewer behavior is understood.

## Task cases

1. **Spec failure:** a self-contained requirement violation. The baseline
   should stop after spec review; the treatment must reject closure.
2. **Quality failure after spec approval:** behavior meets the written task,
   but a concrete code-quality defect has an executable trigger. This is the
   case where current max-tier fanout is most expensive.
3. **Sibling dependency:** the reviewed diff relies on a symbol owned by a
   parallel sibling. Both treatments must report `CANNOT_VERIFY`; the
   controller must check the sibling receipt before closing either task.
4. **Clean task:** both treatments should approve and close without inventing
   findings.

Every case needs a task body, implementation report, file-ownership map,
reviewed diff, independent ground truth, and executable acceptance checks.
The implementation report is untrusted. Keep the key outside reviewer access.

## Matched comparison

- **Baseline:** current SDD order: one spec reviewer; on `PASS`, three
  independent code reviewers and one aggregation pass; on `FAIL` or unresolved
  `CANNOT_VERIFY`, stop and keep the task open.
- **Treatment:** one Opus reviewer returns separate spec and quality verdicts
  plus exact evidence. Apply the same fail-closed closure rule.
- Pin Opus 5 with `--effort high` in both arms. Use the same frozen task
  snapshot, Claude Code/plugin version, tools, and acceptance checks. Randomize
  arm order within each pair and retain prompts, raw stream, model identity,
  hashes, and command line. Report auxiliary model usage separately.
- Run a small plumbing pilot first, then at least six complete matched pairs
  per task case. Measure list-price model cost, input/output/cache tokens, wall
  time, tool calls, defect recall and severity, false positives, and correct
  task closure. Analyze by case as well as overall; do not hide a missed severe
  defect behind a cheaper average.

Adopt a smaller review pipeline only if it preserves detection of every
critical/important planted defect, resolves sibling dependencies before task
closure, and closes clean tasks correctly across the held-out runs. Treat
one-cycle cost differences as descriptive.

## Pilot stop rule

Stop before the six-pair phase if a treatment misses a self-contained task
requirement that the baseline finds, even when another defect keeps the task
open. A matching `KEEP_OPEN` decision does not prove equivalent review: the
remaining fix list can differ. Record that failure and retain the current
pipeline. Resume with a new treatment only after the prompt and ground truth
are revised and frozen for a fresh comparison.

The first historical replay reached this stop rule. See
[the replay results](2026-09-22-opus-high-historical-replay.md). The four-case
held-out trial above remains a proposed qualification gate, not a completed
experiment.
