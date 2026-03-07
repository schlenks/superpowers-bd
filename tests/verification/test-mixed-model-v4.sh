#!/usr/bin/env bash
# shellcheck disable=SC1091
# Test: Does mixed-model review (2xSonnet + 1xOpus) outperform uniform review (3xSonnet)?
# (v4: 3 reviewers per condition, 15 paired cycles, union-rule aggregation)
#
# 28 areas evaluated (12 real bugs B1-B12 + 16 decoys D1-D16):
#   B1:  Bulk update field processing order (correctness, medium)
#   B2:  Webhook retry counter reset on partial success (correctness, hard)
#   B3:  Pagination cursor uses timestamp not ID (correctness, medium)
#   B4:  Rate limiter keys on raw Authorization header (security, easy)
#   B5:  Auth error leaks resource existence (security, hard)
#   B6:  CORS wildcard origin + credentials (security, medium)
#   B7:  Status filter bypasses index, full scan (performance, medium)
#   B8:  Synchronous audit log blocks requests (performance, very hard)
#   B9:  Bulk delete non-atomic, no early termination (performance, medium)
#   B10: Repository returns raw references (architecture, hard)
#   B11: Webhook payload missing changed_fields (architecture, easy)
#   B12: Zero webhook tests in test suite (architecture, very hard)
#   D1-D16: Correctly implemented features that look suspicious
#
# Conditions:
#   uniform: 3 copies of same generalist prompt, all default Sonnet model
#   mixed:   3 copies of same generalist prompt, reviewer 1 gets --model opus, reviewers 2-3 default Sonnet
#
# Scoring:
#   Individual: score = TP - FP per reviewer
#   Aggregate: union rule -- area "found" if ANY of 3 reviewers found it
#   Both individual and aggregate scores recorded
#
# Statistical analysis:
#   - Wilcoxon signed-rank test on per-cycle aggregate delta_score
#   - Bootstrap 95% CI for mean aggregate delta_score
#   - CONFIRMED requires: delta >= 1.0, CI excludes 0, p < 0.05,
#     recall_delta >= 0.10 OR fp_delta <= -1.0
#
# Verdict:
#   CONFIRMED    -- Mixed-model aggregate is statistically superior
#   PARTIAL      -- CI excludes zero but practical threshold not met
#   DENIED       -- Mixed-model aggregate is statistically worse
#   INCONCLUSIVE -- Insufficient evidence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Verification: Mixed-Model V4"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo ""

# -- Step 1: Load fixtures ------------------------------------------------

SPEC=$(cat "$FIXTURES_DIR/spec-v3.md")
IMPL=$(cat "$FIXTURES_DIR/impl-v3.md")
API=$(cat "$FIXTURES_DIR/api-v3.ts")
VALIDATION=$(cat "$FIXTURES_DIR/validation-v3.ts")
MIDDLEWARE=$(cat "$FIXTURES_DIR/middleware-v3.ts")
REPOSITORY=$(cat "$FIXTURES_DIR/repository-v3.ts")
TESTS=$(cat "$FIXTURES_DIR/tests-v3.md")

# -- Test setup ------------------------------------------------------------

TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
export TEST_DIR
RESULTS_FILE="$TEST_DIR/results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$RESULTS_FILE"
export RESULTS_FILE

NUM_CYCLES=15
NUM_REVIEWERS=3

# -- Step 2: JSON output suffix (28 areas) ---------------------------------
# Neutral area descriptions -- identical for all prompts.

JSON_SUFFIX='

You MUST include this JSON block with ALL 28 areas evaluated (B1-B12, D1-D16).
Each area MUST have a boolean "found" value. Set "found": true only if you identified
a genuine issue in that area. Set "found": false if the implementation in that area is correct.

Area descriptions (neutral -- do not infer bug vs. correct from the name):

- B1: Bulk update field processing order
- B2: Webhook retry counter logic
- B3: Pagination cursor implementation
- B4: Rate limiter key derivation
- B5: Authentication error response content
- B6: CORS origin and credentials configuration
- B7: Status filter query implementation in repository
- B8: Audit log write pattern
- B9: Bulk delete operation sequencing
- B10: Repository method return value encapsulation
- B11: Webhook payload field completeness
- B12: Test suite webhook coverage
- D1: Token minimum-length validation in auth middleware
- D2: Rate limit storage backend (in-memory vs. distributed)
- D3: Priority field boundary validation
- D4: Dynamic sort key type assertion
- D5: Webhook delivery Promise handling pattern
- D6: CORS preflight response status code
- D7: Request body size limit enforcement
- D8: Soft-delete implementation behavior
- D9: Repository storage data structure choice
- D10: Audit log timestamp format and timezone
- D11: Bulk operation item count enforcement
- D12: Webhook registration authorization scope check
- D13: Test suite clock control mechanism
- D14: Pagination response for out-of-range page number
- D15: Request logging metadata fields
- D16: Task title uniqueness enforcement

```json
{
  "areas": {
    "B1": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B2": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B3": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B4": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B5": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B6": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B7": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B8": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B9": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B10": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B11": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "B12": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D1": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D2": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D3": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D4": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D5": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D6": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D7": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D8": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D9": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D10": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D11": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D12": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D13": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D14": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D15": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" },
    "D16": { "found": false, "severity": "critical|important|minor|none", "summary": "one sentence" }
  }
}
```'

# -- Shared fixture context block ------------------------------------------
# Identical for all prompts -- injected into each prompt body.

FIXTURE_BLOCK="## Specification

$SPEC

## Implementation Report

$IMPL

## Source Code: api-v3.ts

\`\`\`typescript
$API
\`\`\`

## Source Code: validation-v3.ts

\`\`\`typescript
$VALIDATION
\`\`\`

## Source Code: middleware-v3.ts

\`\`\`typescript
$MIDDLEWARE
\`\`\`

## Source Code: repository-v3.ts

\`\`\`typescript
$REPOSITORY
\`\`\`

## Test Suite Summary

$TESTS"

# -- Step 3: Generalist prompt construction --------------------------------
# Template with {i} and {n} placeholders -- replaced per reviewer in the loop.

read -r -d '' GENERALIST_TEMPLATE << 'GEN_EOF' || true
You are reviewing code changes for production readiness. Reviewer {i} of {n}. Review independently.

**Your focus areas -- cover all of the following:**
- **Requirement compliance:** Every spec requirement must be implemented exactly as stated. Read each spec section and trace it to the implementing code. Flag missing implementations, field omissions from response payloads, and deviations from stated behavior.
- **Correctness and state transitions:** Validate that status transitions, derived field computation (e.g., `closed_at`), field application order, retry counter logic, and pagination cursor encoding match the spec. Look for off-by-one errors, wrong ordering, and counter reset bugs.
- **Security and trust boundaries:** Verify auth checks occur at the right points. Do error responses leak resource existence? Is rate limiting keyed on authenticated user identity or raw credentials? Does the CORS policy restrict origins and handle credentials mode correctly per browser standards?
- **Performance:** Are there O(N) operations where a pre-built index makes O(1) possible? Do middleware functions perform synchronous blocking writes before calling `next()`? Do bulk handlers use sequential per-item loops when a single-pass approach is required?
- **Architecture and encapsulation:** Can callers mutate internal repository state by modifying returned objects? Are all required fields present in webhook payloads? Does the test suite cover all major spec feature areas, or are entire sections untested?

**Your task -- follow these steps in order:**
1. Read the specification and list every behavioral, security, and performance requirement.
2. Read the implementation report and all source files in full -- entire files, not just suspicious sections.
3. Map each spec requirement to the implementing code. Note any requirement with no implementing code.
4. Trace data flow per function: inputs, validation points, outputs, trust boundaries, async patterns.
5. Hunt for what is missing: unhandled error conditions, unvalidated inputs, untested spec sections, absent test coverage for entire feature areas.
6. Check test quality: do tests verify behavior? Are edge cases covered? Are webhook endpoints tested?
7. Produce findings with precise location, what is wrong, and why it matters.

**Precision gate -- no finding unless tied to at least one of:**
- A specific spec requirement that the code violates
- A concrete failing input or code path you can describe specifically
- A missing test for a specific scenario you can name

Speculative "what if" concerns without a demonstrable trigger are NOT findings.

**Severity levels:**
- Critical (must fix): Bugs, security flaws, data loss, broken functionality, spec payload requirements violated
- Important (should fix): Missing error handling, test gaps for likely scenarios, incorrect edge cases, blocking operations
- Minor (consider): Missing validation for unlikely inputs, suboptimal patterns, low-impact deviations
- Suggestion (nice to have): Style, readability -- only if zero Critical/Important/Minor findings

Do NOT inflate severity. Style is not Important. Do not praise the implementation.
GEN_EOF

GENERALIST_OUTPUT_FMT='## Output Format

### Issues

#### Critical (Must Fix)
[Bugs, security issues, data loss risks, broken functionality]

#### Important (Should Fix)
[Architecture problems, missing features, poor error handling, test gaps]

#### Minor (Nice to Have)
[Code style, optimization opportunities, documentation improvements]

For each issue: location, what is wrong, why it matters, how to fix.

### Assessment
**Ready to merge?** [Yes / With fixes / No]'

# -- Step 4: Python scorer function ----------------------------------------
# Hardcoded ground truth matching ground-truth-v3.json.
# Extracts JSON blocks from output, computes TP/FP/FN/score/precision/recall.
# Outputs per_area_json for domain analysis in analyze-v4.py.

score_output() {
    local output_file="$1"
    local condition="$2"
    local cycle_num="$3"
    local reviewer_num="$4"

    python3 << PYEOF
import json

output_file = "$output_file"
condition = "$condition"
cycle_num = "$cycle_num"
reviewer_num = "$reviewer_num"
test_dir = "$TEST_DIR"

with open(output_file, "r") as f:
    content = f.read()

# Ground truth: hardcoded from ground-truth-v3.json
REAL_BUGS = {"B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "B10", "B11", "B12"}
DECOYS = {"D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D11", "D12", "D13", "D14", "D15", "D16"}
AREA_IDS = sorted(REAL_BUGS | DECOYS)
TOTAL_BUGS = 12

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
per_area = {}

for block in find_json_objects(content):
    if "areas" not in block:
        continue
    try:
        data = json.loads(block)
        if "areas" not in data:
            continue
        areas = data["areas"]
        # Require at least 23 of 28 areas present (tolerance: 5 missing)
        missing_areas = [a for a in AREA_IDS if a not in areas]
        if len(missing_areas) > 5:
            continue
        parsed = True
        for area_id in AREA_IDS:
            entry = areas.get(area_id, {})
            # Strict boolean check -- string "false" must not count as truthy
            found = entry.get("found", False) is True
            severity = str(entry.get("severity", "none"))
            is_real = area_id in REAL_BUGS
            summary = str(entry.get("summary", ""))[:80]

            per_area[area_id] = {"found": found, "severity": severity}

            if found and is_real:
                tp += 1
                details.append(f"    [TP]    {area_id}: {summary}")
            elif found and not is_real:
                fp += 1
                details.append(f"    [FP!!]  {area_id}: {summary}")
            elif not found and is_real:
                fn += 1
                details.append(f"    [MISS]  {area_id}")
            else:
                details.append(f"    [TN]    {area_id} (correctly marked clean)")
        break
    except (json.JSONDecodeError, AttributeError):
        continue

scores_file = f"{test_dir}/scores.csv"
per_area_json = json.dumps(per_area) if per_area else "{}"

if not parsed:
    details.append("    [PARSE_FAIL] No valid areas JSON block in output")
    for d in details:
        print(d)
    with open(scores_file, "a") as f:
        # Quote per_area_json to protect commas inside JSON from CSV parsing
        escaped = per_area_json.replace('"', '""')
        f.write(f'{cycle_num},{condition},{reviewer_num},0,0,0,0,0.0,0.0,false,"{escaped}"\n')
else:
    score = tp - fp
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / TOTAL_BUGS
    for d in details:
        print(d)
    print(f"    TP: {tp}/{TOTAL_BUGS}  FP: {fp}/{len(DECOYS)}  FN: {fn}  Score: {score}  Precision: {precision:.2f}  Recall: {recall:.2f}")
    with open(scores_file, "a") as f:
        escaped = per_area_json.replace('"', '""')
        f.write(f'{cycle_num},{condition},{reviewer_num},{score},{tp},{fp},{fn},{precision:.4f},{recall:.4f},true,"{escaped}"\n')
PYEOF
}

# -- Step 5: Aggregate scoring function (union rule) -----------------------
# After all 3 reviewers in a condition finish, compute union aggregate.

compute_aggregate() {
    local cycle_num="$1"
    local condition="$2"

    python3 << PYEOF
import csv
import json

cycle_num = "$cycle_num"
condition = "$condition"
test_dir = "$TEST_DIR"
num_reviewers_expected = $NUM_REVIEWERS

REAL_BUGS = {"B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "B10", "B11", "B12"}
DECOYS = {"D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D11", "D12", "D13", "D14", "D15", "D16"}
AREA_IDS = sorted(REAL_BUGS | DECOYS)
TOTAL_BUGS = 12

# Read per-reviewer scores for this cycle and condition
reviewer_areas = []
all_parsed = True

with open(f"{test_dir}/scores.csv", "r") as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row["cycle"] == cycle_num and row["condition"] == condition:
            parse_ok = row["parse_ok"].lower() in ("true", "1", "yes")
            if not parse_ok:
                all_parsed = False
                continue
            per_area = json.loads(row["per_area_json"])
            reviewer_areas.append(per_area)

# Union rule: area is "found" if ANY reviewer found it
agg_found = {}
for area_id in AREA_IDS:
    agg_found[area_id] = any(
        ra.get(area_id, {}).get("found", False)
        for ra in reviewer_areas
    )

# Compute aggregate metrics
tp = sum(1 for a in AREA_IDS if agg_found.get(a, False) and a in REAL_BUGS)
fp = sum(1 for a in AREA_IDS if agg_found.get(a, False) and a in DECOYS)
fn = sum(1 for a in AREA_IDS if not agg_found.get(a, False) and a in REAL_BUGS)
score = tp - fp
precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
recall = tp / TOTAL_BUGS
n_reviewers = len(reviewer_areas)
agg_parse_ok = "true" if all_parsed and n_reviewers == num_reviewers_expected else "false"

agg_per_area = json.dumps({a: {"found": agg_found[a]} for a in AREA_IDS})
escaped_agg = agg_per_area.replace('"', '""')

with open(f"{test_dir}/aggregates.csv", "a") as f:
    f.write(f'{cycle_num},{condition},{n_reviewers},{score},{tp},{fp},{fn},{precision:.4f},{recall:.4f},{agg_parse_ok},"{escaped_agg}"\n')

print(f"  Aggregate ({condition}, cycle {cycle_num}): TP={tp} FP={fp} Score={score} Recall={recall:.2f} Reviewers={n_reviewers} Parse={'OK' if agg_parse_ok == 'true' else 'PARTIAL'}")
PYEOF
}

# -- Initialize output files -----------------------------------------------

echo "cycle,condition,reviewer,score,tp,fp,fn,precision,recall,parse_ok,per_area_json" > "$TEST_DIR/scores.csv"
echo "cycle,condition,n_reviewers,score,tp,fp,fn,precision,recall,parse_ok,per_area_json" > "$TEST_DIR/aggregates.csv"

# -- Step 6: Main experiment loop ------------------------------------------

CONDITIONS=(uniform mixed)

for cycle in $(seq 1 $NUM_CYCLES); do
    echo ""
    echo "=== Cycle $cycle / $NUM_CYCLES ==="

    # Randomize condition order for this cycle to prevent systematic bias
    # Use Python-based shuffle (portable -- BSD sort does not support -R on macOS)
    mapfile -t shuffled < <(python3 -c "import random,sys; c=sys.argv[1:]; random.shuffle(c); print('\n'.join(c))" "${CONDITIONS[@]}")

    for condition in "${shuffled[@]}"; do
        echo "--- $condition (cycle $cycle) ---"

        for reviewer_num in $(seq 1 $NUM_REVIEWERS); do
            echo "  Reviewer $reviewer_num / $NUM_REVIEWERS ($condition)"

            # Build prompt: same generalist prompt for all reviewers in both conditions
            prompt_body="${GENERALIST_TEMPLATE//\{i\}/$reviewer_num}"
            prompt_body="${prompt_body//\{n\}/$NUM_REVIEWERS}"
            output_fmt="$GENERALIST_OUTPUT_FMT"

            full_prompt="$prompt_body

$FIXTURE_BLOCK

$output_fmt
$JSON_SUFFIX"

            label="${condition}-r${reviewer_num}"

            # Write prompt to temp file to avoid CLI argument size limit
            # (>60KB prompts hang when passed as -p argument)
            prompt_file="$TEST_DIR/prompt-${label}-cycle${cycle}.txt"
            echo "$full_prompt" > "$prompt_file"

            # Model selection: mixed condition reviewer 1 gets --model opus
            if [ "$condition" = "mixed" ] && [ "$reviewer_num" -eq 1 ]; then
                run_claude_session_stdin "$label" "$cycle" 2 600 "$prompt_file" \
                    claude -p - --model opus --permission-mode bypassPermissions
            else
                run_claude_session_stdin "$label" "$cycle" 2 600 "$prompt_file" \
                    claude -p - --permission-mode bypassPermissions
            fi

            # Score only if run succeeded
            local_output="$TEST_DIR/output-${label}-run${cycle}.txt"
            if [ -f "$local_output" ]; then
                score_output "$local_output" "$condition" "$cycle" "$reviewer_num"
            else
                echo "    [SKIP] No output file (run failed)"
                echo "${cycle},${condition},${reviewer_num},0,0,0,0,0.0,0.0,false,\"{}\"" >> "$TEST_DIR/scores.csv"
            fi
        done

        # Compute union aggregate for this condition in this cycle
        compute_aggregate "$cycle" "$condition"
    done
done

# -- Step 7: Persist results before analysis --------------------------------
# Copy raw data FIRST so it is preserved even if the analyzer fails.

cp "$TEST_DIR/scores.csv" "$SCRIPT_DIR/mixed-model-v4-results.csv"
cp "$TEST_DIR/aggregates.csv" "$SCRIPT_DIR/mixed-model-v4-aggregate.csv"

echo ""
echo "Results saved to:"
echo "  tests/verification/mixed-model-v4-results.csv"
echo "  tests/verification/mixed-model-v4-aggregate.csv"

# -- Step 8: Analysis invocation -------------------------------------------

echo ""
echo "========================================"
echo " Statistical Analysis"
echo "========================================"
echo ""

python3 "$SCRIPT_DIR/analyze-v4.py" "$TEST_DIR/scores.csv" "$TEST_DIR/aggregates.csv"

# Copy summary JSON if analyzer created it
if [ -f "$TEST_DIR/mixed-model-v4-summary.json" ]; then
    cp "$TEST_DIR/mixed-model-v4-summary.json" "$SCRIPT_DIR/mixed-model-v4-summary.json"
    echo "  tests/verification/mixed-model-v4-summary.json"
fi

# -- Inline summary for reporting contract ---------------------------------

echo ""
echo "========================================"
echo " Reporting Summary"
echo "========================================"
echo ""

SCORES_PATH="$TEST_DIR/scores.csv" AGGREGATES_PATH="$TEST_DIR/aggregates.csv" RESULTS_PATH="$RESULTS_FILE" python3 << 'PYEOF'
import csv, os

scores_path = os.environ['SCORES_PATH']
aggregates_path = os.environ['AGGREGATES_PATH']
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

# Count individual parse status
total_scored = 0
parse_failures = 0
parse_successes = 0
with open(scores_path, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        total_scored += 1
        parse_ok = row['parse_ok'].lower() in ('true', '1', 'yes')
        if not parse_ok:
            parse_failures += 1
        else:
            parse_successes += 1

# Count aggregate parse status
agg_total = 0
agg_ok = 0
by_cycle = {}
with open(aggregates_path, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        agg_total += 1
        cycle = row['cycle']
        condition = row['condition']
        parse_ok = row['parse_ok'].lower() in ('true', '1', 'yes')
        if parse_ok:
            agg_ok += 1
        if cycle not in by_cycle:
            by_cycle[cycle] = {}
        by_cycle[cycle][condition] = parse_ok

# Count paired cycles (both conditions parsed successfully at aggregate level)
paired_cycles = 0
for cycle, conditions in by_cycle.items():
    if conditions.get('uniform', False) and conditions.get('mixed', False):
        paired_cycles += 1

print(f"Total sessions: {total_runs}")
print(f"Succeeded: {total_runs - failed_runs}")
print(f"Failed: {failed_runs}")
print(f"Retries: {retry_runs}")
print(f"Individual parse successes: {parse_successes}/{total_scored}")
print(f"Individual parse failures: {parse_failures}/{total_scored}")
print(f"Aggregate parse successes: {agg_ok}/{agg_total}")
print(f"Paired cycles (both conditions parsed): {paired_cycles}")

parse_rate = parse_failures / total_scored if total_scored > 0 else 0
print(f"Individual parse failure rate: {parse_rate:.1%}")
PYEOF

rm -rf "$TEST_DIR"
