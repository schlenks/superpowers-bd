#!/usr/bin/env bash
# Unit tests for hooks/task-completed.sh quality gate hook
# Tests the script directly by piping JSON to stdin — no Claude Code session needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/../../hooks/task-completed.sh"
PASS=0
FAIL=0
TOTAL=0

# Use temp dir for log files
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

run_test() {
  local name="$1"
  local json="$2"
  local expected_exit="$3"
  local expected_stderr_pattern="${4:-}"

  TOTAL=$((TOTAL + 1))

  # Run hook with test log directory
  local actual_exit=0
  local stderr_output
  stderr_output=$(echo "$json" | CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$HOOK_SCRIPT" 2>&1 >/dev/null) || actual_exit=$?

  if [ "$actual_exit" -ne "$expected_exit" ]; then
    echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
    [ -n "$stderr_output" ] && echo "  stderr: $stderr_output"
    FAIL=$((FAIL + 1))
    return
  fi

  if [ -n "$expected_stderr_pattern" ] && [ "$expected_exit" -eq 2 ]; then
    if ! echo "$stderr_output" | grep -qi "$expected_stderr_pattern"; then
      echo "FAIL: $name — stderr missing pattern '$expected_stderr_pattern'"
      echo "  stderr: $stderr_output"
      FAIL=$((FAIL + 1))
      return
    fi
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
}

echo "=== Quality Gate Hook Tests ==="
echo ""

# --- Test 1: Verification task without evidence → exit 2 ---
run_test "Verification task without evidence blocks" \
  '{"task_id":"t-001","task_subject":"Verify: tests pass","task_description":"I checked the tests"}' \
  2 \
  "BLOCKED"

# --- Test 2: Verification task with evidence → exit 0 ---
run_test "Verification task with evidence passes" \
  '{"task_id":"t-002","task_subject":"Verify: tests pass","task_description":"Ran npm test — exit code 0, all 42 tests passed"}' \
  0

# --- Test 3: Verification task with 'output:' marker → exit 0 ---
run_test "Verification task with output marker passes" \
  '{"task_id":"t-003","task_subject":"Verification: lint clean","task_description":"Output: 0 errors, 0 warnings"}' \
  0

# --- Test 4: Verification task with 'confirmed' marker → exit 0 ---
run_test "Verification task with confirmed marker passes" \
  '{"task_id":"t-004","task_subject":"Verify build","task_description":"Confirmed build succeeds with no warnings"}' \
  0

# --- Test 5: Verification task with 'evidence:' marker → exit 0 ---
run_test "Verification task with evidence: marker passes" \
  '{"task_id":"t-005","task_subject":"Verify deployment","task_description":"Evidence: curl returns 200 OK from /health endpoint"}' \
  0

# --- Test 6: Non-verification task → exit 0 ---
run_test "Non-verification non-implementation task passes" \
  '{"task_id":"t-006","task_subject":"Update login form styling","task_description":"Added form with email/password fields"}' \
  0

# --- Test 7: Non-verification task with no description → exit 0 ---
run_test "Non-verification task with empty description passes" \
  '{"task_id":"t-007","task_subject":"Fix CSS layout","task_description":""}' \
  0

# --- Test 8: [skip-gate] bypass → exit 0 ---
run_test "Skip-gate bypass passes" \
  '{"task_id":"t-008","task_subject":"[skip-gate] Verify: tests pass","task_description":""}' \
  0

# --- Test 9: Verification task with empty description → exit 2 ---
run_test "Verification task with empty description blocks" \
  '{"task_id":"t-009","task_subject":"Verify: API works","task_description":""}' \
  2 \
  "BLOCKED"

# --- Test 10: Verification task with null description → exit 2 ---
run_test "Verification task with null description blocks" \
  '{"task_id":"t-010","task_subject":"Verify: smoke test","task_description":null}' \
  2 \
  "BLOCKED"

# --- Test 11: Case insensitive subject matching ---
run_test "Case insensitive VERIFY in subject" \
  '{"task_id":"t-011","task_subject":"VERIFY: All Good","task_description":"Ran tests, confirmed all pass"}' \
  0

# --- Test 12: 'Verification' in subject (not just 'verify') ---
run_test "Verification word in subject triggers check" \
  '{"task_id":"t-012","task_subject":"Verification of security","task_description":"no real evidence here just words"}' \
  2 \
  "BLOCKED"

# --- Test 13: Verification with 'pass' in description → exit 0 ---
run_test "Verification with pass keyword succeeds" \
  '{"task_id":"t-013","task_subject":"Verify integration","task_description":"All integration tests pass"}' \
  0

# --- Test 14: Missing fields handled gracefully ---
run_test "Missing fields handled gracefully" \
  '{}' \
  0

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
