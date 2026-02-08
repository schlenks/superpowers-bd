#!/usr/bin/env bash
# Test: Does Two-Phase Reflective catch more bugs than current review prompt?
#
# 8 areas evaluated (5 real bugs + 3 decoys):
#   AREA_A: GET endpoint behavior (REAL)
#   AREA_B: Rate limiting config (DECOY)
#   AREA_C: Input validation completeness (REAL)
#   AREA_D: Default value handling (DECOY)
#   AREA_E: DELETE endpoint behavior (REAL)
#   AREA_F: Response format compliance (REAL)
#   AREA_G: Endpoint coverage (DECOY)
#   AREA_H: Unrequested features (REAL)
#
# Score = true_positives - false_positives (penalizes shotgun marking)
#
# Verdict:
#   CONFIRMED — Two-Phase scores >= 1.0 higher on average
#   PARTIAL   — Same score (method works but no improvement)
#   DENIED    — Two-Phase scores lower
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Verification: Two-Phase Reflective (#1)"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo ""

# Load fixtures
SPEC=$(cat "$FIXTURES_DIR/known-buggy-spec.md")
IMPL=$(cat "$FIXTURES_DIR/known-buggy-impl.md")

TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
export TEST_DIR
RESULTS_FILE="$TEST_DIR/results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$RESULTS_FILE"
export RESULTS_FILE

NUM_RUNS=5

# Structured JSON output instructions (shared suffix for both prompts).
# Uses NEUTRAL area labels — no descriptions of what each bug is.
# Includes 3 decoy areas (correctly implemented features) to catch false positives.
JSON_SUFFIX='

## REQUIRED: Structured Output

After your analysis, evaluate each of the following areas. For each area, determine
whether you found a real issue (deviation from spec, missing requirement, or unrequested
behavior). Mark "found": true ONLY if your analysis above independently identified a
real problem in that area. Mark "found": false if the area is implemented correctly.

```json
{
  "areas": {
    "AREA_A": {"found": true, "evidence": "brief explanation"},
    "AREA_B": {"found": true, "evidence": "..."},
    "AREA_C": {"found": true, "evidence": "..."},
    "AREA_D": {"found": true, "evidence": "..."},
    "AREA_E": {"found": true, "evidence": "..."},
    "AREA_F": {"found": true, "evidence": "..."},
    "AREA_G": {"found": true, "evidence": "..."},
    "AREA_H": {"found": true, "evidence": "..."}
  }
}
```

Areas to evaluate:
- AREA_A: GET endpoint behavior
- AREA_B: Rate limiting configuration
- AREA_C: Input validation completeness
- AREA_D: Default value handling
- AREA_E: DELETE endpoint behavior
- AREA_F: Response format compliance
- AREA_G: Endpoint coverage
- AREA_H: Unrequested features

You MUST include this JSON block with all 8 areas evaluated.'

# --- Method A: Current review prompt (faithful to code-reviewer.md structure) ---
read -r -d '' CURRENT_PROMPT << 'CURRENT_EOF' || true
You are reviewing code changes for production readiness.

**Your task:**
1. Review Widget API implementation
2. Compare against the specification below
3. Check code quality, architecture, testing
4. Categorize issues by severity
5. Assess production readiness

## Requirements/Plan

CURRENT_EOF
CURRENT_PROMPT="$CURRENT_PROMPT
$SPEC

## Implementer's Report

$IMPL

## Review Checklist

**Code Quality:** Clean separation of concerns? Proper error handling? Edge cases handled?
**Architecture:** Sound design decisions? Scalability? Performance? Security?
**Testing:** Tests actually test logic? Edge cases covered? All tests passing?
**Requirements:** All plan requirements met? Implementation matches spec? No scope creep? Breaking changes documented?
**Production Readiness:** Migration strategy? Backward compatibility? Documentation complete? No obvious bugs?

## Output Format

### Issues

#### Critical (Must Fix)
[Bugs, security issues, data loss risks, broken functionality]

#### Important (Should Fix)
[Architecture problems, missing features, poor error handling, test gaps]

#### Minor (Nice to Have)
[Code style, optimization opportunities, documentation improvements]

For each issue: what's wrong, why it matters, how to fix.

### Assessment
**Ready to merge?** [Yes/No/With fixes]
$JSON_SUFFIX"

# --- Method B: Two-Phase Reflective prompt ---
read -r -d '' TWOPHASE_PROMPT << 'TWOPHASE_EOF' || true
You are reviewing whether an implementation matches its specification.

## Verification Method

Do NOT read the implementer's report first. Instead:

Step 1: Extract requirements from the spec below. Create a numbered checklist.
Step 2: Read the implementer's report. Audit each requirement against what they claim.
Step 3: Summarize unlisted behaviors not in the spec (scope creep check).
Step 4: Note discrepancies between your analysis and their claims.

## Specification

TWOPHASE_EOF
TWOPHASE_PROMPT="$TWOPHASE_PROMPT
$SPEC

## Implementer's Report

$IMPL

## Your Output

1. Requirements checklist (numbered, each marked PASS/FAIL/MISSING with evidence)
2. Unlisted behaviors (things built that weren't requested)
3. Discrepancies (claims vs evidence)
4. Overall verdict: PASS / FAIL with specific issues
$JSON_SUFFIX"

# Python scorer — extracts JSON and scores with decoy awareness
score_output() {
    local output_file="$1"
    local method="$2"
    local run_num="$3"

    python3 << PYEOF
import json, sys

with open("$output_file", "r") as f:
    content = f.read()

# Ground truth: which areas are real bugs vs decoys
REAL_BUGS = {"AREA_A", "AREA_C", "AREA_E", "AREA_F", "AREA_H"}
DECOYS = {"AREA_B", "AREA_D", "AREA_G"}
ALL_AREAS = sorted(REAL_BUGS | DECOYS)

# Extract JSON by finding balanced brace blocks containing "areas"
def find_json_objects(text):
    depth = 0
    start = None
    for i, ch in enumerate(text):
        if ch == '{':
            if depth == 0:
                start = i
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0 and start is not None:
                yield text[start:i+1]
                start = None

true_positives = 0
false_positives = 0
details = []
parsed = False

for block in find_json_objects(content):
    if "areas" not in block:
        continue
    try:
        data = json.loads(block)
        if "areas" not in data:
            continue
        areas = data["areas"]
        parsed = True
        for area_id in ALL_AREAS:
            entry = areas.get(area_id, {})
            # Strict boolean check — string "false" must not count as truthy
            found = entry.get("found", False) is True
            is_real = area_id in REAL_BUGS
            evidence = str(entry.get("evidence", ""))[:80]

            if found and is_real:
                true_positives += 1
                details.append(f"    [TP]    {area_id}: {evidence}")
            elif found and not is_real:
                false_positives += 1
                details.append(f"    [FP!!]  {area_id}: {evidence}")
            elif not found and is_real:
                details.append(f"    [MISS]  {area_id}")
            else:
                details.append(f"    [TN]    {area_id} (correctly marked clean)")
        break
    except (json.JSONDecodeError, AttributeError):
        continue

if not parsed:
    details.append("    [PARSE_FAIL] No valid areas JSON block in output — excluded from scoring")
    for d in details:
        print(d)
    # Record as parse failure — excluded from paired-cycle comparison
    with open("$TEST_DIR/scores.csv", "a") as f:
        f.write(f"$method,$run_num,0,0,0,true\n")
else:
    score = true_positives - false_positives
    for d in details:
        print(d)
    print(f"    TP: {true_positives}/5  FP: {false_positives}/3  Score: {score}")
    with open("$TEST_DIR/scores.csv", "a") as f:
        f.write(f"$method,$run_num,{true_positives},{false_positives},{score},false\n")
PYEOF
}

# Initialize scores file
echo "method,run,true_positives,false_positives,score,parse_failed" > "$TEST_DIR/scores.csv"

# Interleave methods to reduce order bias
METHODS=(current twophase)

for cycle in $(seq 1 $NUM_RUNS); do
    echo ""
    echo "=== Cycle $cycle / $NUM_RUNS ==="

    # Shuffle methods for this cycle
    shuffled=($(printf '%s\n' "${METHODS[@]}" | sort -R))

    for method in "${shuffled[@]}"; do
        echo "--- $method (run $cycle) ---"

        if [ "$method" = "current" ]; then
            prompt="$CURRENT_PROMPT"
        else
            prompt="$TWOPHASE_PROMPT"
        fi

        run_claude_session "$method" "$cycle" 2 180 \
            claude -p "$prompt" --permission-mode bypassPermissions --allowed-tools=all

        # Score only if run succeeded
        local_output="$TEST_DIR/output-${method}-run${cycle}.txt"
        if [ -f "$local_output" ]; then
            score_output "$local_output" "$method" "$cycle"
        else
            echo "    [SKIP] No output file (run failed)"
        fi
    done
done

# --- Summary ---
echo ""
echo "========================================"
echo " Results Summary"
echo "========================================"

SCORES_PATH="$TEST_DIR/scores.csv" RESULTS_PATH="$RESULTS_FILE" python3 << 'PYEOF'
import csv, os, math
from collections import defaultdict

scores_by_cycle = {}  # {(method, cycle): {score, tp, fp}}
parse_failures = 0
with open(os.environ['SCORES_PATH'], 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row.get('parse_failed', 'false') == 'true':
            parse_failures += 1
            continue  # Exclude parse failures from scoring entirely
        key = (row['method'], row['run'])
        scores_by_cycle[key] = {
            'score': int(row['score']),
            'tp': int(row['true_positives']),
            'fp': int(row['false_positives']),
        }

if parse_failures > 0:
    print(f"  [{parse_failures} run(s) excluded: JSON parse failure (output format, not analysis quality)]")

# Find paired cycles: both methods scored (non-parse-failed) in same cycle
all_cycles = set(c for _, c in scores_by_cycle.keys())
paired_cycles = sorted([c for c in all_cycles
    if ('current', c) in scores_by_cycle and ('twophase', c) in scores_by_cycle])

# Build per-method lists from paired cycles only
scores = defaultdict(list)
tp_scores = defaultdict(list)
fp_scores = defaultdict(list)
for c in paired_cycles:
    for m in ['current', 'twophase']:
        d = scores_by_cycle[(m, c)]
        scores[m].append(d['score'])
        tp_scores[m].append(d['tp'])
        fp_scores[m].append(d['fp'])

unpaired = len(all_cycles) - len(paired_cycles)
if unpaired > 0:
    print(f"  [{unpaired} unpaired cycle(s) excluded — method failed in one but not other]")

all_rows = []
with open(os.environ['RESULTS_PATH'], 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_rows.append(row)

def stdev(vals):
    if len(vals) < 2:
        return 0
    avg = sum(vals) / len(vals)
    return math.sqrt(sum((v - avg) ** 2 for v in vals) / (len(vals) - 1))

failed_count = sum(1 for r in all_rows if r['status'] != 'succeeded')
total_count = len(all_rows)
print(f"Runs: {total_count} total, {total_count - failed_count} succeeded, {failed_count} excluded")
print()

for method in ['current', 'twophase']:
    if method in scores and scores[method]:
        vals = scores[method]
        tp = tp_scores[method]
        fp = fp_scores[method]
        avg = sum(vals) / len(vals)
        sd = stdev(vals)
        tp_avg = sum(tp) / len(tp)
        fp_avg = sum(fp) / len(fp)
        print(f"{method:>10}: score {avg:.1f} (TP {tp_avg:.1f}/5, FP {fp_avg:.1f}/3, stdev {sd:.1f}, n={len(vals)}, runs: {vals})")
    else:
        print(f"{method:>10}: no successful runs")

MIN_PAIRED_CYCLES = 3
n_paired = len(paired_cycles)
print(f"Paired cycles: {n_paired} (from {len(all_cycles)} total cycles)")
print()

if n_paired >= MIN_PAIRED_CYCLES:
    current_vals = scores['current']
    twophase_vals = scores['twophase']

    current_avg = sum(current_vals) / n_paired
    twophase_avg = sum(twophase_vals) / n_paired
    diff = twophase_avg - current_avg

    print()
    if diff >= 1.0:
        print(f"VERDICT: CONFIRMED (Two-Phase scores {diff:.1f} higher on average)")
    elif diff > 0:
        print(f"VERDICT: PARTIAL (Two-Phase scores {diff:.1f} higher — marginal improvement)")
    elif diff == 0:
        print(f"VERDICT: PARTIAL (identical scores)")
    else:
        print(f"VERDICT: DENIED (Two-Phase scores {abs(diff):.1f} lower)")

    # Decision class with variance and FP checks (using paired data)
    retry_passes = sum(1 for r in all_rows if r.get('pass_label') == 'retry-pass')
    paired_stdevs = [stdev(scores[m]) for m in scores if len(scores[m]) >= 2]
    paired_avgs = [sum(scores[m]) / len(scores[m]) for m in scores if len(scores[m]) >= 2]
    high_variance = any(
        sd > 0.3 * abs(avg) for sd, avg in zip(paired_stdevs, paired_avgs) if avg != 0
    )

    # FP cap: avg FP > 1 for either method means scoring is unreliable
    high_fp = any(
        sum(fp_scores[m]) / len(fp_scores[m]) > 1.0
        for m in ['current', 'twophase'] if m in fp_scores and fp_scores[m]
    )

    # Parse failure gate: too many format failures → prompts aren't working
    # Denominator = all individual runs that produced output (parsed + parse-failed)
    total_runs_with_output = parse_failures + len(scores_by_cycle)
    if total_runs_with_output > 0 and parse_failures / total_runs_with_output > 0.3:
        print(f"Decision class: INCONCLUSIVE (parse failure rate {parse_failures}/{total_runs_with_output} > 30% — prompts not producing expected format)")
    elif failed_count > 0:
        print(f"Decision class: INCONCLUSIVE ({failed_count} runs failed — not all cycles succeeded)")
    elif retry_passes > 0:
        print(f"Decision class: INCONCLUSIVE ({retry_passes} retry-passes — results unstable)")
    elif high_fp:
        print("Decision class: INCONCLUSIVE (avg FP > 1 for a method — scoring unreliable)")
    elif high_variance:
        print("Decision class: INCONCLUSIVE (high variance — stdev > 30% of mean)")
    else:
        print("Decision class: VERIFIED (all first-pass successes, zero failures, low variance, FP controlled)")
else:
    print()
    print(f"VERDICT: INCONCLUSIVE (need >= {MIN_PAIRED_CYCLES} paired cycles; got {n_paired})")
    print(f"Decision class: INCONCLUSIVE (insufficient paired data)")
PYEOF

# Save results
cp "$TEST_DIR/scores.csv" "$SCRIPT_DIR/two-phase-reflective-results.csv" 2>/dev/null || true
rm -rf "$TEST_DIR"

echo ""
echo "Results saved to: tests/verification/two-phase-reflective-results.csv"
