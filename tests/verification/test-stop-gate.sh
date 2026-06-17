#!/usr/bin/env bash
# Unit tests for hooks/stop-gate.sh (Stop).
# Re-asserts verification-before-completion: when the main agent ends a turn
# claiming completion WITHOUT evidence AND there is live work, it is blocked and
# told to verify. Guarded against loops (stop_hook_active + per-session counter)
# and overridable (SDD_ALLOW_STOP=1). Silent when idle or when evidence is shown.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/../../hooks/stop-gate.sh"
PASS=0
FAIL=0
TOTAL=0

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

STUB_BIN="$TEST_ROOT/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/bd" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list) printf '%s' "${BD_STUB_OUTPUT:-[]}" ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$STUB_BIN/bd"

CLAIM_NO_EVIDENCE='The authentication refactor is complete.'
CLAIM_WITH_EVIDENCE='The authentication refactor is complete — ran pytest, exit code 0, 42 passed.'

payload() {
  jq -nc --arg sid "$1" --arg msg "$2" --argjson active "$3" \
    '{session_id:$sid, last_assistant_message:$msg, stop_hook_active:$active}'
}

# Args: name, json, wave_active(yes|no), bd_json, env_kv, expect_block(yes|no)
run_test() {
  local name="$1" json="$2" wave="$3" bd_json="$4" env_kv="$5" expect_block="$6"
  TOTAL=$((TOTAL + 1))

  local proj="$TEST_ROOT/proj-$TOTAL"
  mkdir -p "$proj/temp"
  [ "$wave" = yes ] && printf '' > "$proj/temp/sdd-wave-active-fake-epic.flag"

  local out
  # shellcheck disable=SC2086  # $env_kv is intentionally split into 0 or 1 env assignments
  out=$(echo "$json" | env CLAUDE_PROJECT_DIR="$proj" PATH="$STUB_BIN:$PATH" \
        BD_STUB_OUTPUT="$bd_json" $env_kv bash "$HOOK_SCRIPT") || {
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

echo "=== Stop Gate Tests ==="
echo ""

# Completion claim, no evidence, live work → block.
run_test "Claim without evidence during live work blocks" \
  "$(payload s1 "$CLAIM_NO_EVIDENCE" false)" yes '[]' "" yes

# Completion claim WITH evidence → no block.
run_test "Claim with evidence passes" \
  "$(payload s2 "$CLAIM_WITH_EVIDENCE" false)" yes '[]' "" no

# Completion claim, no evidence, but NO live work → no block.
run_test "Claim without evidence when idle passes" \
  "$(payload s3 "$CLAIM_NO_EVIDENCE" false)" no '[]' "" no

# stop_hook_active true → loop guard, no block.
run_test "stop_hook_active guard passes" \
  "$(payload s4 "$CLAIM_NO_EVIDENCE" true)" yes '[]' "" no

# Escape hatch → no block.
run_test "Escape hatch SDD_ALLOW_STOP=1 passes" \
  "$(payload s5 "$CLAIM_NO_EVIDENCE" false)" yes '[]' "SDD_ALLOW_STOP=1" no

# Liveness via in_progress beads (no wave flag) still gates the block on.
run_test "In-progress beads work triggers gate" \
  "$(payload s6 "$CLAIM_NO_EVIDENCE" false)" no '[{"id":"x"}]' "" yes

# Counter cap: same session, 4 stops → first 3 block, 4th releases.
echo "--- counter cap (same session_id, 4 stops) ---"
CAP_PROJ="$TEST_ROOT/cap"
mkdir -p "$CAP_PROJ/temp"
printf '' > "$CAP_PROJ/temp/sdd-wave-active-fake-epic.flag"
cap_blocks=0
for _ in 1 2 3 4; do
  cout=$(payload capS "$CLAIM_NO_EVIDENCE" false \
    | env CLAUDE_PROJECT_DIR="$CAP_PROJ" PATH="$STUB_BIN:$PATH" BD_STUB_OUTPUT='[]' \
      bash "$HOOK_SCRIPT")
  echo "$cout" | grep -q '"decision":"block"' && cap_blocks=$((cap_blocks + 1))
done
TOTAL=$((TOTAL + 1))
if [ "$cap_blocks" -eq 3 ]; then
  echo "PASS: Counter caps at 3 blocks across 4 stops (blocks=$cap_blocks)"
  PASS=$((PASS + 1))
else
  echo "FAIL: Counter cap — expected 3 blocks across 4 stops, got $cap_blocks"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
