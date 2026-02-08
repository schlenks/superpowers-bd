# Verification Experiment Specs v2

Date: 2026-02-08
Scope: Follow-up experiments for `#5` (TaskCompleted hook latency) and `#1` (Two-Phase Reflective effectiveness)
Baseline: v1 results from 2026-02-07

## Goals

1. Turn v1 inconclusive outcomes into conclusive evidence.
2. Separate trigger semantics from performance measurement.
3. Use decision rules that combine statistical confidence and practical effect size.

## Decision Classes

- `VERIFIED`: Stable runs, direct evidence for key claims, thresholds met.
- `OBSERVED`: Signal exists but with indirect evidence, narrower scope, or minor instability.
- `INCONCLUSIVE`: Missing direct evidence, unstable harness, ceiling effects, or insufficient power.

---

## Experiment A (`#5`): TaskCompleted Trigger Matrix

### Why v1 was inconclusive

v1 measured latency before confirming that `TaskCompleted` actually fired in the tested path (`TaskCreate` + `TaskUpdate` in `claude -p`). Marker files never appeared, so timing deltas were uninterpretable.

### Primary Questions

1. Which completion actions emit `TaskCompleted`?
2. Does emission differ between headless (`claude -p`) and interactive mode?
3. Can we identify at least one stable, directly observed trigger path for latency measurement?

### Hypotheses

- `H1`: `TaskCompleted` is event-source specific, not universal.
- `H2`: Headless and interactive modes may differ in event emission.

### Factors and Matrix

Completion action (`A`):
- `A1`: Native task tools (`TaskCreate` then `TaskUpdate` to completed)
- `A2`: Beads completion (`bd create` then `bd close`)
- `A3`: Interactive task completion flow (only if automation harness available)

Runtime mode (`M`):
- `M1`: Headless (`claude -p`)
- `M2`: Interactive (`claude` with expect/tmux harness)

Hook event (`E`):
- `E1`: `TaskCompleted` command hook with marker file (primary evidence)
- `E2`: `PostToolUse` control hook on the exact completion tool path (control evidence)

Test cells:
- Required: `A1xM1`, `A2xM1`
- Optional but recommended for root-cause clarity: `A1xM2`, `A2xM2`, `A3xM2`

Runs per required cell: `n=5`
Runs per optional cell: `n=3`

### Instrumentation

- Marker file per run: direct proof hook executed.
- Transcript parser proof:
  - `A1`: verify both `TaskCreate` and `TaskUpdate` tool-use records.
  - `A2`: verify `Bash`/tool execution includes `bd close`.
- Per-run metadata CSV:
  - `action,mode,run,status,attempt,marker_taskcompleted,marker_control,proof_action,proof_complete,duration_ms`

### Verdict Logic (Trigger Phase)

For each cell:
- `FIRES`: `marker_taskcompleted` true in `>=4/5` required runs and no failed runs.
- `DOES_NOT_FIRE`: `marker_taskcompleted` false in all runs, with action proof present.
- `UNSTABLE`: mixed firing with retries/failures.

Overall for `#5` trigger semantics:
- `VERIFIED` if at least one required headless cell is `FIRES` or both required cells are `DOES_NOT_FIRE` with strong action proof.
- `OBSERVED` if signal exists but instability/retries remain.
- `INCONCLUSIVE` if action proof is missing or most cells are unstable.

### Exit Gate to Latency

Proceed to latency only for cells classified `FIRES`.
If no cell fires in headless, do not run headless latency for `TaskCompleted`; document as "not measurable in tested headless paths."

---

## Experiment B (`#5`): Latency by Hook Type (Gated)

### Entry Criteria

- A trigger cell from Experiment A classified `FIRES`.
- Same completion action and mode used across all latency variants.

### Design

Variants:
- `none` (baseline)
- `command`
- `prompt`
- `agent`

Run structure:
- Warmup: 2 runs per variant (discarded)
- Measured: 12 runs per variant
- Randomize variant order each cycle (cycle = one run of each variant)
- Total measured sessions: 48

### Measurements

- Wall-clock `duration_ms`
- Marker proof:
  - `command`: must create marker (direct)
  - `prompt`/`agent`: use response-side marker or transcript hook result where possible; otherwise classify as timing-inferred
- Failure and retry counts

CSV:
- `variant,cycle,duration_ms,status,attempt,hook_observed,proof_type`

### Analysis

Primary statistic:
- Median overhead vs baseline per variant.

Uncertainty:
- Bootstrap 95% CI on median overhead (`10,000` resamples).

Classification thresholds:
- `FAST`: `<5s`
- `MODERATE`: `5-15s`
- `SLOW`: `15-60s`
- `BLOCKING`: `>60s`

### Decision Rules (Latency Phase)

- `VERIFIED`:
  - `>=10` successful measured runs per variant
  - command hook observed in `100%` of successful runs
  - no variant has failure rate `>10%`
  - CI width for each variant overhead `<=5s`
- `OBSERVED`:
  - sufficient runs but prompt/agent remain timing-inferred or CI is wider
- `INCONCLUSIVE`:
  - hook evidence missing, high failure/variance, or unstable baseline

### Expected Deliverables

- `taskcompleted-trigger-matrix-results.csv`
- `taskcompleted-latency-v2-results.csv`
- Summary with:
  - Which paths emit `TaskCompleted`
  - Overhead classification only for emitting paths

---

## Experiment C (`#1`): Two-Phase Reflective v2 (Harder Fixture + Power)

### Why v1 was partial

v1 fixture was near-ceiling: both methods found all 5 bugs every run. Only false positives differed slightly, so effect size was too small for conclusive superiority.

### Objectives

1. Create realistic difficulty where true-positive recall can diverge.
2. Stress false-positive resistance with more decoys.
3. Use enough paired runs for confidence intervals and significance.

### Fixture v2 Specification

Replace single simple spec/report pair with multi-file synthetic review pack:
- `spec-v2.md`: requirements, constraints, and acceptance criteria
- `impl-v2.md`: implementation report with claims
- `api-v2.ts`: endpoint behavior
- `validation-v2.ts`: input/edge validation
- `tests-v2.md`: test summary and selected assertions

Ground truth areas: 14 total
- Real bugs: 6 (`B1-B6`)
- Decoys: 8 (`D1-D8`)

Required bug types:
- Cross-section mismatch (requires joining two spec sections)
- Off-by-one/range boundary error
- Ambiguous requirement resolved incorrectly
- Unrequested behavior (scope creep) with plausible justification
- Error-envelope inconsistency in one endpoint only
- Test-suite blind spot that hides a functional miss

Decoy requirements:
- Look suspicious but fully compliant
- At least 3 decoys adjacent to real bugs in nearby context

### Prompt Methods

- `current`: current review prompt (unchanged except new area IDs)
- `twophase`: Two-Phase reflective prompt

Both methods must:
- Output strict JSON for all 14 areas.
- Include `found` as boolean only.

### Run Plan

- Paired cycles: both methods run on same fixture variant and seed order.
- Minimum paired cycles: `n=20`.
- Randomize method order each cycle.
- Optional variant rotation (`variant-A/B/C`) to reduce memorization.

### Scoring

Per run:
- `TP`, `FP`, `FN`
- `score = TP - FP`
- `precision = TP / (TP + FP)` when denominator > 0
- `recall = TP / 6`

Primary endpoint:
- `delta_score = score_twophase - score_current`

Secondary endpoints:
- `delta_recall`
- `delta_fp` (expected negative)
- `parse_failure_rate`

### Statistical Decision Rules

Use paired non-parametric test:
- Wilcoxon signed-rank on per-cycle `delta_score`
- Bootstrap 95% CI for mean `delta_score`

`CONFIRMED` (method superiority) requires all:
- Mean `delta_score >= 0.5`
- 95% CI for `delta_score` excludes `0`
- Wilcoxon `p < 0.05`
- Mean `delta_recall >= 0.15` OR mean `delta_fp <= -0.5`

`PARTIAL`:
- CI excludes 0 but practical threshold not met, or only FP improves materially.

`DENIED`:
- Mean `delta_score < 0` with CI excluding 0.

### Decision Class Rules

- `VERIFIED`:
  - `>=20` paired successful cycles
  - parse failures `<=5%`
  - no retries required
  - stable variance (score stdev ratio <= 0.35)
- `OBSERVED`:
  - signal present but one stability criterion missed
- `INCONCLUSIVE`:
  - insufficient paired cycles, high parse failure, or unstable runs

### Deliverables

- `two-phase-reflective-v2-results.csv`
- `two-phase-reflective-v2-summary.json`
- Printed summary:
  - TP/FP/FN by method
  - effect sizes and confidence intervals
  - verdict + decision class

---

## Implementation Notes (Script-Level)

### New Scripts

- `tests/verification/test-taskcompleted-trigger-matrix-v2.sh`
- `tests/verification/test-taskcompleted-latency-v2.sh`
- `tests/verification/test-two-phase-reflective-v2.sh`

### Shared Helper Additions (`test-helpers.sh`)

- Add transcript probes:
  - `verify_tool_used SESSION_FILE TOOL_NAME`
  - `verify_bd_close_used SESSION_FILE`
- Add bootstrap/wilcoxon analysis helper (python inline or `tests/verification/analyze-v2.py`)
- Add optional interactive harness wrapper:
  - skip with explicit reason if `expect`/`tmux` unavailable

### Stop Conditions

- Abort latency phase if no trigger cell fires.
- Abort reflective phase early only for hard harness failures (not performance outcomes).

### Reporting Contract

Each script must print:
- `VERDICT: ...`
- `Decision class: ...`
- Exact run counts, failure counts, retry counts, parse-failure counts.

