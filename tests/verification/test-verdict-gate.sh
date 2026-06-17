#!/usr/bin/env bash
# Unit tests for the verdict gate in hooks/verdict-audit.sh (SubagentStop).
# During an active SDD wave, a subagent that stops without a VERDICT line is
# blocked (sent back to emit one), bounded by a per-agent retry cap. Outside a
# wave, or with a verdict present, or with the escape hatch set, it never blocks.
# The audit log is always written.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/../../hooks/verdict-audit.sh"
PASS=0
FAIL=0
TOTAL=0

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

NO_VERDICT_MSG='Implemented the feature and ran the tests.'
VERDICT_MSG='Done.
VERDICT: DONE'

# Args: name, json, wave_active(yes|no), env_kv, expect_block(yes|no)
run_test() {
  local name="$1" json="$2" wave="$3" env_kv="$4" expect_block="$5"
  TOTAL=$((TOTAL + 1))

  local proj="$TEST_ROOT/proj-$TOTAL"
  mkdir -p "$proj/temp"
  [ "$wave" = yes ] && printf '' > "$proj/temp/sdd-wave-active-fake-epic.flag"

  local out
  # shellcheck disable=SC2086  # $env_kv is intentionally split into 0 or 1 env assignments
  out=$(echo "$json" | env CLAUDE_PROJECT_DIR="$proj" $env_kv bash "$HOOK_SCRIPT") || {
    echo "FAIL: $name — hook exited non-zero"; FAIL=$((FAIL + 1)); return; }

  local has_block=no
  echo "$out" | grep -q '"decision":"block"' && has_block=yes

  if [ "$has_block" != "$expect_block" ]; then
    echo "FAIL: $name — expected block=$expect_block, got $has_block (out: $out)"
    FAIL=$((FAIL + 1)); return
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
}

# Build a SubagentStop JSON payload with jq (handles message escaping).
payload() {
  local agent_id="$1" msg="$2"
  jq -nc --arg id "$agent_id" --arg msg "$msg" \
    '{agent_type:"general-purpose", agent_id:$id, last_assistant_message:$msg}'
}

echo "=== Verdict Gate Tests ==="
echo ""

# No verdict + active wave → block.
run_test "No verdict during wave blocks" "$(payload a1 "$NO_VERDICT_MSG")" yes "" yes

# No verdict + no wave → audit only, no block.
run_test "No verdict outside wave passes" "$(payload a2 "$NO_VERDICT_MSG")" no "" no

# Verdict present + active wave → no block.
run_test "Verdict present during wave passes" "$(payload a3 "$VERDICT_MSG")" yes "" no

# Escape hatch overrides the gate.
run_test "Escape hatch SDD_ALLOW_NO_VERDICT=1 passes" "$(payload a4 "$NO_VERDICT_MSG")" yes "SDD_ALLOW_NO_VERDICT=1" no

# Retry cap: same agent_id blocked twice, then let through on the third stop.
echo "--- retry cap (same agent_id, 3 stops) ---"
RETRY_PROJ="$TEST_ROOT/retry"
mkdir -p "$RETRY_PROJ/temp"
printf '' > "$RETRY_PROJ/temp/sdd-wave-active-fake-epic.flag"
cap_block_count=0
for _ in 1 2 3; do
  rout=$(payload loop1 "$NO_VERDICT_MSG" | CLAUDE_PROJECT_DIR="$RETRY_PROJ" bash "$HOOK_SCRIPT")
  echo "$rout" | grep -q '"decision":"block"' && cap_block_count=$((cap_block_count + 1))
done
TOTAL=$((TOTAL + 1))
if [ "$cap_block_count" -eq 2 ]; then
  echo "PASS: Retry cap blocks twice then releases (blocks=$cap_block_count)"
  PASS=$((PASS + 1))
else
  echo "FAIL: Retry cap — expected 2 blocks across 3 stops, got $cap_block_count"
  FAIL=$((FAIL + 1))
fi

# jq-absent environment must NOT enforce the gate (audit-only), even with a wave
# flag — otherwise jq-less hosts block every SubagentStop under agent_id=unknown.
echo "--- jq-absent environment ---"
JQLESS_BIN="$TEST_ROOT/jqless-bin"
mkdir -p "$JQLESS_BIN"
for tool in cat grep date mkdir rm; do
  real=$(command -v "$tool" || true)
  [ -n "$real" ] && ln -s "$real" "$JQLESS_BIN/$tool"
done
BASH_BIN=$(command -v bash)
JQLESS_PROJ="$TEST_ROOT/jqless"
mkdir -p "$JQLESS_PROJ/temp"
printf '' > "$JQLESS_PROJ/temp/sdd-wave-active-fake-epic.flag"
# Payload is built with the test's real jq; the hook runs under a jq-less PATH.
jqless_out=$(payload jl1 "$NO_VERDICT_MSG" \
  | env CLAUDE_PROJECT_DIR="$JQLESS_PROJ" PATH="$JQLESS_BIN" "$BASH_BIN" "$HOOK_SCRIPT")
TOTAL=$((TOTAL + 1))
if echo "$jqless_out" | grep -q '"decision":"block"'; then
  echo "FAIL: jq-absent env must not enforce gate (out: $jqless_out)"
  FAIL=$((FAIL + 1))
else
  echo "PASS: jq-absent env does not enforce verdict gate"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
