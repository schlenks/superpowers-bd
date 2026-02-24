#!/usr/bin/env bash
# shellcheck disable=SC1091
# Test: Does decorrelated specialist review outperform same-prompt multi-review?
# (v3: 4 specialists vs 4 generalists, 28 areas, 15 paired cycles, union-rule aggregation)
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
#   generalist: 4 copies of same generalist prompt, each "Reviewer {i} of 4"
#   specialist: 4 domain-specific prompts (correctness, security, performance, architecture)
#
# Scoring:
#   Individual: score = TP - FP per reviewer
#   Aggregate: union rule — area "found" if ANY of 4 reviewers found it
#   Both individual and aggregate scores recorded
#
# Statistical analysis:
#   - Wilcoxon signed-rank test on per-cycle aggregate delta_score
#   - Bootstrap 95% CI for mean aggregate delta_score
#   - CONFIRMED requires: delta >= 1.0, CI excludes 0, p < 0.05,
#     recall_delta >= 0.10 OR fp_delta <= -1.0
#
# Verdict:
#   CONFIRMED    — Specialist aggregate is statistically superior
#   PARTIAL      — CI excludes zero but practical threshold not met
#   DENIED       — Specialist aggregate is statistically worse
#   INCONCLUSIVE — Insufficient evidence
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Verification: Decorrelated V3"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo ""

# ── Step 1: Load fixtures ────────────────────────────────────────────

SPEC=$(cat "$FIXTURES_DIR/spec-v3.md")
IMPL=$(cat "$FIXTURES_DIR/impl-v3.md")
API=$(cat "$FIXTURES_DIR/api-v3.ts")
VALIDATION=$(cat "$FIXTURES_DIR/validation-v3.ts")
MIDDLEWARE=$(cat "$FIXTURES_DIR/middleware-v3.ts")
REPOSITORY=$(cat "$FIXTURES_DIR/repository-v3.ts")
TESTS=$(cat "$FIXTURES_DIR/tests-v3.md")

# ── Test setup ───────────────────────────────────────────────────────

TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
export TEST_DIR
RESULTS_FILE="$TEST_DIR/results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$RESULTS_FILE"
export RESULTS_FILE

NUM_CYCLES=15

# ── Step 2: JSON output suffix (28 areas) ────────────────────────────
# Neutral area descriptions — identical for all prompts.

JSON_SUFFIX='

You MUST include this JSON block with ALL 28 areas evaluated (B1-B12, D1-D16).
Each area MUST have a boolean "found" value. Set "found": true only if you identified
a genuine issue in that area. Set "found": false if the implementation in that area is correct.

Area descriptions (neutral — do not infer bug vs. correct from the name):

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

# ── Shared fixture context block ─────────────────────────────────────
# Identical for all prompts — injected into each prompt body.

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

# ── Step 3: Generalist prompt construction ───────────────────────────
# Template with {i} placeholder — replaced per reviewer in the loop.

read -r -d '' GENERALIST_TEMPLATE << 'GEN_EOF' || true
You are reviewing code changes for production readiness. Reviewer {i} of 4. Review independently.

**Your focus areas — cover all of the following:**
- **Requirement compliance:** Every spec requirement must be implemented exactly as stated. Read each spec section and trace it to the implementing code. Flag missing implementations, field omissions from response payloads, and deviations from stated behavior.
- **Correctness and state transitions:** Validate that status transitions, derived field computation (e.g., `closed_at`), field application order, retry counter logic, and pagination cursor encoding match the spec. Look for off-by-one errors, wrong ordering, and counter reset bugs.
- **Security and trust boundaries:** Verify auth checks occur at the right points. Do error responses leak resource existence? Is rate limiting keyed on authenticated user identity or raw credentials? Does the CORS policy restrict origins and handle credentials mode correctly per browser standards?
- **Performance:** Are there O(N) operations where a pre-built index makes O(1) possible? Do middleware functions perform synchronous blocking writes before calling `next()`? Do bulk handlers use sequential per-item loops when a single-pass approach is required?
- **Architecture and encapsulation:** Can callers mutate internal repository state by modifying returned objects? Are all required fields present in webhook payloads? Does the test suite cover all major spec feature areas, or are entire sections untested?

**Your task — follow these steps in order:**
1. Read the specification and list every behavioral, security, and performance requirement.
2. Read the implementation report and all source files in full — entire files, not just suspicious sections.
3. Map each spec requirement to the implementing code. Note any requirement with no implementing code.
4. Trace data flow per function: inputs, validation points, outputs, trust boundaries, async patterns.
5. Hunt for what is missing: unhandled error conditions, unvalidated inputs, untested spec sections, absent test coverage for entire feature areas.
6. Check test quality: do tests verify behavior? Are edge cases covered? Are webhook endpoints tested?
7. Produce findings with precise location, what is wrong, and why it matters.

**Precision gate — no finding unless tied to at least one of:**
- A specific spec requirement that the code violates
- A concrete failing input or code path you can describe specifically
- A missing test for a specific scenario you can name

Speculative "what if" concerns without a demonstrable trigger are NOT findings.

**Severity levels:**
- Critical (must fix): Bugs, security flaws, data loss, broken functionality, spec payload requirements violated
- Important (should fix): Missing error handling, test gaps for likely scenarios, incorrect edge cases, blocking operations
- Minor (consider): Missing validation for unlikely inputs, suboptimal patterns, low-impact deviations
- Suggestion (nice to have): Style, readability — only if zero Critical/Important/Minor findings

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

# ── Step 4: Specialist prompt construction ───────────────────────────
# 4 domain-specific prompts. Template with {i} placeholder for reviewer number.

read -r -d '' CORRECTNESS_TEMPLATE << 'CORR_EOF' || true
You are a correctness specialist. Reviewer {i} of 4. Review independently.

Your expertise is requirement compliance and behavioral correctness. You focus on whether the implementation does what the specification requires — no more, no less. Other domains (security, performance, architecture) are handled by other reviewers; you focus on functional correctness.

**Your focus areas:**
- **Requirement compliance:** Every spec requirement must be implemented exactly as stated. Read each spec section and trace it to the implementing code. Flag deviations, omissions, and misinterpretations.
- **State transitions:** Validate that status transitions, derived field computation (e.g., `closed_at`), and field application order match the spec precisely. Look for off-by-one errors, wrong ordering, incorrect defaults.
- **Data integrity:** Concurrent access, pagination stability, ordering guarantees. Can two concurrent writes corrupt state? Does pagination remain stable under concurrent inserts? Are cursors implemented as the spec requires (ID-based, not timestamp-based)?
- **Control flow correctness:** Loop termination, counter management, retry logic. Does retry counting increment on every failure type the spec defines? Does early-exit logic match all-or-nothing semantics the spec requires?
- **Edge cases and boundary conditions:** Validate boundary checks, empty inputs, max-size inputs, null handling. Look for conditions where the code appears correct on the happy path but fails at boundaries.

**Your task — follow these steps in order:**
1. Read the specification carefully and list every behavioral requirement, including field ordering rules, cursor encoding rules, retry semantics, and derived-field computation rules.
2. Read the implementation report and all source files in full — entire files, not just suspicious sections.
3. For each spec requirement, locate the implementing code. Note any requirement that has no implementing code or is only partially implemented.
4. Trace control flow for state-dependent operations: bulk updates (field application order), pagination (cursor encoding), retry loops (counter increment conditions), status transitions (closed_at computation).
5. Check boundary conditions and counter logic: loop counters, cursor encoding strategy, counter resets on unexpected response codes, field application sequencing.
6. Verify that all-or-nothing semantics are implemented where the spec requires them. Look for partial success paths that should not exist.
7. Produce findings with precise location and spec reference for each correctness violation.

**Precision gate — no finding unless tied to at least one of:**
- A specific spec section that states a requirement the code violates
- A concrete input or sequence of operations that triggers the incorrect behavior
- A missing test for a specific correctness scenario you can name

**Severity levels:**
- Critical (must fix): Spec requirement violated, incorrect behavior demonstrable
- Important (should fix): Edge case mishandling, boundary error for plausible inputs
- Minor (consider): Ambiguous spec interpretation, style that obscures intent
- Suggestion (nice to have): Only if zero Critical/Important/Minor findings
CORR_EOF

CORRECTNESS_OUTPUT_FMT='## Output Format

### Issues

#### Critical (Must Fix)
[Spec violations, incorrect state transitions, wrong control flow]

#### Important (Should Fix)
[Edge case errors, boundary condition failures, ambiguous behavior]

#### Minor (Nice to Have)
[Minor spec deviations, unclear variable naming that obscures intent]

For each issue: location, spec reference, what is wrong, why it matters, how to fix.

### Assessment
**Ready to merge?** [Yes / With fixes / No]'

read -r -d '' SECURITY_TEMPLATE << 'SEC_EOF' || true
You are a security specialist. Reviewer {i} of 4. Review independently.

Your expertise is identifying security vulnerabilities in API implementations. You focus on trust boundaries, authentication, authorization, data exposure, and resource protection. Other domains (correctness, performance, architecture) are handled by other reviewers; you focus on security.

**Your focus areas:**
- **Authentication and authorization:** Verify that auth checks occur at the right points. Does unauthenticated access reveal information about protected resources? Are scope checks applied correctly and in the right order?
- **Data exposure:** Can unauthenticated or unauthorized users learn the existence of resources they should not see? Do error messages, timing differences, or response shapes leak internal state?
- **Rate limiting and resource exhaustion:** Is rate limiting keyed on the correct identity? Can shared credentials exhaust a single rate-limit bucket that belongs to multiple independent users? Is the key derived from authenticated identity or raw credentials?
- **CORS and browser security:** Does the CORS policy correctly handle credentials mode? Does it restrict allowed origins to an approved allowlist as required? Does the wildcard origin interact correctly with the credentials flag per browser standards?
- **Input trust boundaries:** Is user input validated before being used in key derivation, error messages, or access control decisions? Are tokens inspected before being used as map keys or lookup values?

**Your task — follow these steps in order:**
1. Read the specification authentication, rate limiting, CORS, and error handling sections carefully, noting all security-specific requirements.
2. Read the implementation report and all source files in full — entire files, not just the middleware layer.
3. Trace each auth-adjacent code path: token validation flow, error response construction, rate limit key derivation, scope check ordering.
4. Check for information disclosure at every error response site: what does an unauthenticated or unauthorized request reveal about protected resources?
5. Verify rate limit key derivation: is it derived from authenticated user identity or from the raw credential string? Can shared credentials cause cross-client exhaustion?
6. Verify CORS configuration against both the spec requirements and browser standards (Fetch Standard section on credentials mode + wildcard origin).
7. Produce findings with precise location, attack scenario, and security impact for each vulnerability.

**Precision gate — no finding unless tied to at least one of:**
- A concrete attack scenario you can describe (who does what, what they learn or gain)
- A specific spec security requirement that the code violates
- A specific input or credential pattern that triggers unauthorized behavior or information disclosure

**Severity levels:**
- Critical (must fix): Exploitable vulnerability, data exposure, auth bypass
- Important (should fix): Defense-in-depth gap, spec security requirement violated
- Minor (consider): Low-likelihood edge case, conservative hardening opportunity
- Suggestion (nice to have): Only if zero Critical/Important/Minor findings
SEC_EOF

SECURITY_OUTPUT_FMT='## Output Format

### Issues

#### Critical (Must Fix)
[Exploitable vulnerabilities, auth bypass, data exposure]

#### Important (Should Fix)
[Spec security requirements violated, information leakage, resource exhaustion]

#### Minor (Nice to Have)
[Low-likelihood hardening opportunities, defense-in-depth gaps]

For each issue: location, attack scenario, why it matters, how to fix.

### Assessment
**Ready to merge?** [Yes / With fixes / No]'

read -r -d '' PERFORMANCE_TEMPLATE << 'PERF_EOF' || true
You are a performance specialist. Reviewer {i} of 4. Review independently.

Your expertise is identifying performance problems in API implementations: algorithmic inefficiency, blocking operations, memory growth, and resource misuse. Other domains (correctness, security, architecture) are handled by other reviewers; you focus on performance.

**Your focus areas:**
- **Algorithmic complexity:** Are operations O(N) when a pre-built index makes O(1) possible? Does the code bypass an existing index and fall back to a full scan? Are secondary indexes maintained but never used at the call site?
- **Blocking operations:** Does synchronous I/O or CPU-bound work block the event loop before calling `next()`? Does a middleware function perform serialization or storage writes that delay the HTTP response?
- **Memory growth patterns:** Are in-memory collections unbounded? Does serialization cost grow with total accumulated data (e.g., JSON.stringify on the entire array on every write)? Do writes append to a structure that is never pruned?
- **Sequential vs. batch operations:** Does a bulk handler process items one at a time in a loop when a single-pass approach is required? Does it perform N sequential operations for N items without early termination when the spec requires all-or-nothing semantics?
- **Missed optimization opportunities:** Are there indexes defined in the data layer that are not used by the query layer? Do list operations load all items and filter afterward rather than using indexed lookup?

**Your task — follow these steps in order:**
1. Read the specification performance-relevant sections (status filtering, audit logging, bulk operations).
2. Read the implementation report and all source files in full.
3. Identify every index, cache, or optimized data structure defined in the codebase.
4. For each index or optimized structure, verify it is actually used at the call site that needs it.
5. Trace each middleware function for synchronous blocking before `next()` is called.
6. Check bulk operation handlers for sequential processing and early-exit behavior.
7. Produce findings with location, complexity analysis, and expected impact at scale.

**Precision gate — no finding unless tied to at least one of:**
- A spec requirement that mandates efficient behavior (indexed lookup, non-blocking writes)
- A demonstrable O(N) or worse path where a faster path exists and is unused
- A blocking operation that measurably delays request processing

**Severity levels:**
- Critical (must fix): Spec-required performance constraint violated, O(N) when O(1) index exists
- Important (should fix): Synchronous blocking of request thread, memory growth without bound
- Minor (consider): Suboptimal but not spec-violating, low-traffic impact
- Suggestion (nice to have): Only if zero Critical/Important/Minor findings
PERF_EOF

PERFORMANCE_OUTPUT_FMT='## Output Format

### Issues

#### Critical (Must Fix)
[Spec-required efficiency violated, O(N) scans ignoring existing indexes, blocking event loop]

#### Important (Should Fix)
[Synchronous writes blocking requests, unbounded memory growth, sequential bulk operations]

#### Minor (Nice to Have)
[Suboptimal patterns with low measured impact]

For each issue: location, complexity analysis, impact at scale, how to fix.

### Assessment
**Ready to merge?** [Yes / With fixes / No]'

read -r -d '' ARCHITECTURE_TEMPLATE << 'ARCH_EOF' || true
You are an architecture specialist. Reviewer {i} of 4. Review independently.

Your expertise is evaluating structural quality: encapsulation, API contract adherence, separation of concerns, and test completeness. Other domains (correctness, security, performance) are handled by other reviewers; you focus on architecture.

**Your focus areas:**
- **Encapsulation:** Does the repository layer enforce data ownership? Can callers mutate internal store state by modifying returned objects, bypassing validation and index maintenance? Do repository methods return copies or frozen objects, or raw internal references?
- **API contract adherence:** Does the implementation satisfy the full payload contract defined in the spec? Are all required fields present in response and event payloads? Does omitting a spec-required field (e.g., `changed_fields` in webhook payload) break consumer contracts?
- **Separation of concerns:** Does each layer (middleware, repository, API handler) stay within its responsibility? Is business logic bleeding into middleware? Is data access logic scattered across handler functions instead of the repository layer?
- **Test completeness:** Does the test suite cover all major feature areas? Are there entire spec sections with zero test coverage? Would a bug in an untested subsystem go undetected in CI? Count covered vs. uncovered spec sections explicitly.
- **Structural risks:** Patterns that allow state corruption, bypass validation, or make future maintenance harder — even if they do not cause an immediate bug.

**Your task — follow these steps in order:**
1. Read the specification and identify every major feature area (endpoints, webhooks, bulk ops, auth, CORS, audit logging).
2. Read the implementation report and all source files in full, including the test suite summary.
3. For each major spec feature area, check whether any tests exist in the test summary.
4. Examine repository methods for encapsulation: what do `findAll`, `findById`, and similar methods return?
5. Examine all API response and event payload constructors for spec contract completeness.
6. Identify cross-layer concerns: does middleware or handler code reach into the repository internals?
7. Produce findings with location, structural impact, and specific fix for each architectural issue.

**Precision gate — no finding unless tied to at least one of:**
- A spec contract requirement that the implementation violates
- A specific mutation path that bypasses repository validation (describe the exact call chain)
- A spec feature area with demonstrably zero test coverage (name the section and count the tests)

**Severity levels:**
- Critical (must fix): Encapsulation violated with demonstrable bypass path, spec payload contract missing required fields
- Important (should fix): Entire spec section untested in CI, architectural coupling that enables future bugs
- Minor (consider): Structural weakness without immediate impact, suboptimal layering
- Suggestion (nice to have): Only if zero Critical/Important/Minor findings
ARCH_EOF

ARCHITECTURE_OUTPUT_FMT='## Output Format

### Issues

#### Critical (Must Fix)
[Encapsulation violations with mutation bypass, missing required payload fields]

#### Important (Should Fix)
[Untested spec sections, architectural coupling, layer responsibility violations]

#### Minor (Nice to Have)
[Structural weaknesses with low immediate impact]

For each issue: location, structural impact, why it matters, how to fix.

### Assessment
**Ready to merge?** [Yes / With fixes / No]'

# Specialist templates and output formats indexed by domain
SPECIALIST_TEMPLATES=(
    "$CORRECTNESS_TEMPLATE"
    "$SECURITY_TEMPLATE"
    "$PERFORMANCE_TEMPLATE"
    "$ARCHITECTURE_TEMPLATE"
)
SPECIALIST_OUTPUT_FMTS=(
    "$CORRECTNESS_OUTPUT_FMT"
    "$SECURITY_OUTPUT_FMT"
    "$PERFORMANCE_OUTPUT_FMT"
    "$ARCHITECTURE_OUTPUT_FMT"
)
# ── Step 5: Python scorer function ───────────────────────────────────
# Hardcoded ground truth matching ground-truth-v3.json.
# Extracts JSON blocks from output, computes TP/FP/FN/score/precision/recall.
# Outputs per_area_json for domain analysis in analyze-v3.py.

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
            # Strict boolean check — string "false" must not count as truthy
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

# ── Step 6: Aggregate scoring function (union rule) ──────────────────
# After all 4 reviewers in a condition finish, compute union aggregate.

compute_aggregate() {
    local cycle_num="$1"
    local condition="$2"

    python3 << PYEOF
import csv
import json

cycle_num = "$cycle_num"
condition = "$condition"
test_dir = "$TEST_DIR"

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
agg_parse_ok = "true" if all_parsed and n_reviewers == 4 else "false"

agg_per_area = json.dumps({a: {"found": agg_found[a]} for a in AREA_IDS})
escaped_agg = agg_per_area.replace('"', '""')

with open(f"{test_dir}/aggregates.csv", "a") as f:
    f.write(f'{cycle_num},{condition},{n_reviewers},{score},{tp},{fp},{fn},{precision:.4f},{recall:.4f},{agg_parse_ok},"{escaped_agg}"\n')

print(f"  Aggregate ({condition}, cycle {cycle_num}): TP={tp} FP={fp} Score={score} Recall={recall:.2f} Reviewers={n_reviewers} Parse={'OK' if agg_parse_ok == 'true' else 'PARTIAL'}")
PYEOF
}

# ── Initialize output files ──────────────────────────────────────────

echo "cycle,condition,reviewer,score,tp,fp,fn,precision,recall,parse_ok,per_area_json" > "$TEST_DIR/scores.csv"
echo "cycle,condition,n_reviewers,score,tp,fp,fn,precision,recall,parse_ok,per_area_json" > "$TEST_DIR/aggregates.csv"

# ── Step 7: Main experiment loop ─────────────────────────────────────

CONDITIONS=(generalist specialist)

for cycle in $(seq 1 $NUM_CYCLES); do
    echo ""
    echo "=== Cycle $cycle / $NUM_CYCLES ==="

    # Randomize condition order for this cycle to prevent systematic bias
    mapfile -t shuffled < <(printf '%s\n' "${CONDITIONS[@]}" | sort -R)

    for condition in "${shuffled[@]}"; do
        echo "--- $condition (cycle $cycle) ---"

        for reviewer_num in 1 2 3 4; do
            echo "  Reviewer $reviewer_num / 4 ($condition)"

            if [ "$condition" = "generalist" ]; then
                # Generalist: same prompt, different reviewer number
                prompt_body="${GENERALIST_TEMPLATE//\{i\}/$reviewer_num}"
                output_fmt="$GENERALIST_OUTPUT_FMT"
            else
                # Specialist: domain-specific prompt
                idx=$((reviewer_num - 1))
                prompt_body="${SPECIALIST_TEMPLATES[$idx]//\{i\}/$reviewer_num}"
                output_fmt="${SPECIALIST_OUTPUT_FMTS[$idx]}"
            fi

            full_prompt="$prompt_body

$FIXTURE_BLOCK

$output_fmt
$JSON_SUFFIX"

            label="${condition}-r${reviewer_num}"
            run_claude_session "$label" "$cycle" 2 300 \
                claude -p "$full_prompt" --permission-mode bypassPermissions --allowed-tools=all

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

# ── Step 8: Analysis invocation ──────────────────────────────────────

echo ""
echo "========================================"
echo " Statistical Analysis"
echo "========================================"
echo ""

python3 "$SCRIPT_DIR/analyze-v3.py" "$TEST_DIR/scores.csv" "$TEST_DIR/aggregates.csv"

# ── Inline summary for reporting contract ────────────────────────────

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
    if conditions.get('generalist', False) and conditions.get('specialist', False):
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

# ── Step 9: Save results ─────────────────────────────────────────────

cp "$TEST_DIR/scores.csv" "$SCRIPT_DIR/decorrelated-v3-results.csv" 2>/dev/null || true
cp "$TEST_DIR/aggregates.csv" "$SCRIPT_DIR/decorrelated-v3-aggregate.csv" 2>/dev/null || true

# Copy summary JSON if analyzer created it
if [ -f "$TEST_DIR/aggregates-summary.json" ]; then
    cp "$TEST_DIR/aggregates-summary.json" "$SCRIPT_DIR/decorrelated-v3-summary.json" 2>/dev/null || true
fi

rm -rf "$TEST_DIR"

echo ""
echo "Results saved to:"
echo "  tests/verification/decorrelated-v3-results.csv"
echo "  tests/verification/decorrelated-v3-aggregate.csv"
echo "  tests/verification/decorrelated-v3-summary.json"
