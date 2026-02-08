#!/usr/bin/env bash
# Test: Does Two-Phase Reflective catch more bugs than current review prompt?
# (v2: harder fixture with 14 areas, 20 paired cycles, statistical rigor)
#
# 14 areas evaluated (6 real bugs B1-B6 + 8 decoys D1-D8):
#   B1: Cross-section mismatch (PATCH doesn't clear closed_at on reopen) — medium
#   B2: Off-by-one/range boundary (no future-date validation for due_date) — easy-medium
#   B3: Ambiguous requirement resolved incorrectly (soft-delete vs permanent) — medium
#   B4: Scope creep (email notification not in spec) — easy
#   B5: Missing input validation (GET /tasks doesn't validate status) — medium
#   B6: Test-suite blind spot (no test for future-date validation) — medium-hard
#   D1-D8: Correctly implemented features that look suspicious
#
# Score = TP - FP (penalizes shotgun marking)
#
# Statistical analysis:
#   - Wilcoxon signed-rank test on per-cycle delta_score
#   - Bootstrap 95% CI for mean delta_score
#   - CONFIRMED requires: delta>=0.5, CI excludes 0, p<0.05, recall or FP improvement
#
# Verdict:
#   CONFIRMED — Two-Phase is statistically superior
#   PARTIAL   — CI excludes zero but practical threshold not met
#   DENIED    — Two-Phase is statistically worse
#   INCONCLUSIVE — Insufficient evidence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Verification: Two-Phase Reflective v2"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo ""

# ─── Load fixtures ────────────────────────────────────────────────────

SPEC=$(cat "$FIXTURES_DIR/spec-v2.md")
IMPL=$(cat "$FIXTURES_DIR/impl-v2.md")
API=$(cat "$FIXTURES_DIR/api-v2.ts")
VALIDATION=$(cat "$FIXTURES_DIR/validation-v2.ts")
TESTS=$(cat "$FIXTURES_DIR/tests-v2.md")

# ─── Test setup ───────────────────────────────────────────────────────

TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
export TEST_DIR
RESULTS_FILE="$TEST_DIR/results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$RESULTS_FILE"
export RESULTS_FILE

NUM_CYCLES=20

# ─── Structured JSON output instructions ──────────────────────────────
# Uses neutral area labels. Includes 8 decoys to catch false positives.
# The model must evaluate all 14 areas with strict boolean `found` values.

JSON_SUFFIX='

## REQUIRED: Structured Output

After your analysis, evaluate each of the following 14 areas. For each area,
determine whether you found a real issue (deviation from spec, missing requirement,
incorrect behavior, or unrequested behavior). Mark "found": true ONLY if your
analysis above independently identified a real problem in that area. Mark
"found": false if the area is implemented correctly per the specification.

IMPORTANT: "found" MUST be a boolean (true or false), not a string.

```json
{
  "areas": {
    "B1": {"found": true, "evidence": "brief explanation"},
    "B2": {"found": false, "evidence": "why this is correct"},
    "B3": {"found": true, "evidence": "..."},
    "B4": {"found": false, "evidence": "..."},
    "B5": {"found": true, "evidence": "..."},
    "B6": {"found": false, "evidence": "..."},
    "D1": {"found": true, "evidence": "..."},
    "D2": {"found": false, "evidence": "..."},
    "D3": {"found": true, "evidence": "..."},
    "D4": {"found": false, "evidence": "..."},
    "D5": {"found": true, "evidence": "..."},
    "D6": {"found": false, "evidence": "..."},
    "D7": {"found": true, "evidence": "..."},
    "D8": {"found": false, "evidence": "..."}
  }
}
```

Areas to evaluate:
- B1: PATCH endpoint status transition behavior
- B2: Due date validation rules
- B3: DELETE endpoint behavior
- B4: POST /tasks endpoint behavior
- B5: GET /tasks query parameter handling
- B6: Test suite coverage completeness
- D1: Authentication middleware
- D2: Rate limiting behavior
- D3: Priority validation
- D4: Task sorting and ordering
- D5: Title input handling
- D6: Request body limits
- D7: PATCH partial update behavior
- D8: Title uniqueness constraints

You MUST include this JSON block with ALL 14 areas evaluated (B1-B6, D1-D8).
Each area MUST have a boolean "found" value (true or false).'

# ─── Method A: Current review prompt ─────────────────────────────────
# Faithful to code-reviewer.md structure: severity categorization, checklist.

read -r -d '' CURRENT_PROMPT << 'CURRENT_EOF' || true
You are reviewing code changes for production readiness.

**Your task:**
1. Review the TaskFlow API implementation
2. Compare against the specification
3. Check code quality, architecture, testing
4. Categorize issues by severity
5. Assess production readiness

## Specification

CURRENT_EOF
CURRENT_PROMPT="$CURRENT_PROMPT
$SPEC

## Implementation Report

$IMPL

## Source Code: api-v2.ts

\`\`\`typescript
$API
\`\`\`

## Source Code: validation-v2.ts

\`\`\`typescript
$VALIDATION
\`\`\`

## Test Suite Summary

$TESTS

## Review Checklist

**Code Quality:** Clean separation of concerns? Proper error handling? Edge cases handled?
**Architecture:** Sound design decisions? Scalability? Performance? Security?
**Testing:** Tests actually test logic? Edge cases covered? All tests passing?
**Requirements:** All spec requirements met? Implementation matches spec? No scope creep? Breaking changes documented?
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

# ─── Method B: Two-Phase Reflective prompt ────────────────────────────
# Phase 1: Extract requirements checklist from spec.
# Phase 2: Audit each requirement against implementation, tests, and report.

read -r -d '' TWOPHASE_PROMPT << 'TWOPHASE_EOF' || true
You are reviewing whether an implementation matches its specification.

## Verification Method

Use a two-phase approach:

**Phase 1 — Extract Requirements:**
Read the specification below FIRST. Create a numbered checklist of every
testable requirement, constraint, validation rule, and behavior.
Do NOT read the implementation report yet.

**Phase 2 — Audit Implementation:**
Now read the implementation report, source code, and test suite.
For each requirement in your checklist, audit whether:
- The code implements it correctly
- The tests verify it
- The implementation report's claims are accurate
Also check for unlisted behaviors not in the spec (scope creep).

## Specification

TWOPHASE_EOF
TWOPHASE_PROMPT="$TWOPHASE_PROMPT
$SPEC

## Implementation Report

$IMPL

## Source Code: api-v2.ts

\`\`\`typescript
$API
\`\`\`

## Source Code: validation-v2.ts

\`\`\`typescript
$VALIDATION
\`\`\`

## Test Suite Summary

$TESTS

## Your Output

1. Requirements checklist (numbered, each marked PASS/FAIL/MISSING with evidence)
2. Unlisted behaviors (things built that were not requested in the spec)
3. Discrepancies (claims in impl report vs actual code behavior)
4. Overall verdict: PASS / FAIL with specific issues listed
$JSON_SUFFIX"

# ─── Python scorer ────────────────────────────────────────────────────
# Hardcoded ground truth matching ground-truth-v2.json.
# Extracts JSON blocks from output, computes TP/FP/FN/score/precision/recall.

score_output() {
    local output_file="$1"
    local method="$2"
    local cycle_num="$3"

    python3 << PYEOF
import json

output_file = "$output_file"
method = "$method"
cycle_num = "$cycle_num"
test_dir = "$TEST_DIR"

with open(output_file, "r") as f:
    content = f.read()

# Ground truth: hardcoded from ground-truth-v2.json
# B1-B6 are real bugs, D1-D8 are decoys (correctly implemented)
REAL_BUGS = {"B1", "B2", "B3", "B4", "B5", "B6"}
DECOYS = {"D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"}
ALL_AREAS = sorted(REAL_BUGS | DECOYS)
TOTAL_BUGS = 6

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

tp = 0
fp = 0
fn = 0
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
        # Require all 14 areas present
        missing_areas = [a for a in ALL_AREAS if a not in areas]
        if len(missing_areas) > 3:
            # Too many missing — probably wrong JSON block
            continue
        parsed = True
        for area_id in ALL_AREAS:
            entry = areas.get(area_id, {})
            # Strict boolean check — string "false" must not count as truthy
            found = entry.get("found", False) is True
            is_real = area_id in REAL_BUGS
            evidence = str(entry.get("evidence", ""))[:80]

            if found and is_real:
                tp += 1
                details.append(f"    [TP]    {area_id}: {evidence}")
            elif found and not is_real:
                fp += 1
                details.append(f"    [FP!!]  {area_id}: {evidence}")
            elif not found and is_real:
                fn += 1
                details.append(f"    [MISS]  {area_id}")
            else:
                details.append(f"    [TN]    {area_id} (correctly marked clean)")
        break
    except (json.JSONDecodeError, AttributeError):
        continue

scores_file = f"{test_dir}/scores.csv"

if not parsed:
    details.append("    [PARSE_FAIL] No valid areas JSON block in output")
    for d in details:
        print(d)
    # Record as parse failure — excluded from paired-cycle comparison
    with open(scores_file, "a") as f:
        f.write(f"{cycle_num},{method},0,0,0,0,0.0,0.0,false\n")
else:
    score = tp - fp
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / TOTAL_BUGS
    for d in details:
        print(d)
    print(f"    TP: {tp}/{TOTAL_BUGS}  FP: {fp}/{len(DECOYS)}  FN: {fn}  Score: {score}  Precision: {precision:.2f}  Recall: {recall:.2f}")
    with open(scores_file, "a") as f:
        f.write(f"{cycle_num},{method},{score},{tp},{fp},{fn},{precision:.4f},{recall:.4f},true\n")
PYEOF
}

# ─── Initialize scores file ──────────────────────────────────────────
echo "cycle,method,score,tp,fp,fn,precision,recall,parse_ok" > "$TEST_DIR/scores.csv"

# ─── Run paired cycles ───────────────────────────────────────────────
METHODS=(current twophase)

for cycle in $(seq 1 $NUM_CYCLES); do
    echo ""
    echo "=== Cycle $cycle / $NUM_CYCLES ==="

    # Randomize method order for this cycle to prevent systematic bias
    shuffled=($(printf '%s\n' "${METHODS[@]}" | sort -R))

    for method in "${shuffled[@]}"; do
        echo "--- $method (cycle $cycle) ---"

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
            # Record parse failure for failed runs
            echo "${cycle},${method},0,0,0,0,0.0,0.0,false" >> "$TEST_DIR/scores.csv"
        fi
    done
done

# ─── Analysis via analyze-v2.py ──────────────────────────────────────
echo ""
echo "========================================"
echo " Statistical Analysis"
echo "========================================"
echo ""

# Run the shared analyzer
python3 "$SCRIPT_DIR/analyze-v2.py" reflective "$TEST_DIR/scores.csv"

# ─── Inline summary for reporting contract ────────────────────────────
echo ""
echo "========================================"
echo " Reporting Summary"
echo "========================================"
echo ""

SCORES_PATH="$TEST_DIR/scores.csv" RESULTS_PATH="$RESULTS_FILE" python3 << 'PYEOF'
import csv, os

scores_path = os.environ['SCORES_PATH']
results_path = os.environ['RESULTS_PATH']

# Count runs
total_runs = 0
failed_runs = 0
retry_runs = 0
with open(results_path, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        total_runs += 1
        if row['status'] != 'succeeded':
            failed_runs += 1
        if row.get('pass_label') == 'retry-pass':
            retry_runs += 1

# Count parse status
total_scored = 0
parse_failures = 0
parse_successes = 0
by_cycle = {}

with open(scores_path, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        total_scored += 1
        cycle = row['cycle']
        method = row['method']
        parse_ok = row['parse_ok'].lower() in ('true', '1', 'yes')

        if not parse_ok:
            parse_failures += 1
        else:
            parse_successes += 1

        if cycle not in by_cycle:
            by_cycle[cycle] = {}
        by_cycle[cycle][method] = parse_ok

# Count paired cycles (both methods parsed successfully)
paired_cycles = 0
for cycle, methods in by_cycle.items():
    if methods.get('current', False) and methods.get('twophase', False):
        paired_cycles += 1

print(f"Total sessions: {total_runs}")
print(f"Succeeded: {total_runs - failed_runs}")
print(f"Failed: {failed_runs}")
print(f"Retries: {retry_runs}")
print(f"Parse successes: {parse_successes}/{total_scored}")
print(f"Parse failures: {parse_failures}/{total_scored}")
print(f"Paired cycles (both parsed): {paired_cycles}")

parse_rate = parse_failures / total_scored if total_scored > 0 else 0
print(f"Parse failure rate: {parse_rate:.1%}")
PYEOF

# ─── Save results ────────────────────────────────────────────────────

cp "$TEST_DIR/scores.csv" "$SCRIPT_DIR/two-phase-reflective-v2-results.csv" 2>/dev/null || true
# Copy summary JSON if analyzer created it
if [ -f "$TEST_DIR/scores-summary.json" ]; then
    cp "$TEST_DIR/scores-summary.json" "$SCRIPT_DIR/two-phase-reflective-v2-summary.json" 2>/dev/null || true
fi

rm -rf "$TEST_DIR"

echo ""
echo "Results saved to: tests/verification/two-phase-reflective-v2-results.csv"
