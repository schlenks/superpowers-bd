#!/usr/bin/env bash
# shellcheck disable=SC2329  # setup_* helpers are invoked indirectly via "$setup_fn"
# Unit tests for hooks/work-state-anchor.sh (UserPromptSubmit).
# The hook injects a terse <work-state> anchor ONLY when work is live (an SDD
# wave flag exists, or beads has in_progress work) and stays SILENT when idle.
# bd is stubbed via PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/../../hooks/work-state-anchor.sh"
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

# Args: name, setup_fn, bd_stub_json, expect_anchor(yes|no), expect_substr
run_test() {
  local name="$1" setup_fn="$2" bd_json="$3" expect_anchor="$4" expect_substr="${5:-}"
  TOTAL=$((TOTAL + 1))

  local proj="$TEST_ROOT/proj-$TOTAL"
  mkdir -p "$proj/temp"
  "$setup_fn" "$proj"

  local out
  out=$(echo '{"prompt":"do the thing"}' | CLAUDE_PROJECT_DIR="$proj" \
        PATH="$STUB_BIN:$PATH" BD_STUB_OUTPUT="$bd_json" \
        bash "$HOOK_SCRIPT") || {
    echo "FAIL: $name — hook exited non-zero"; FAIL=$((FAIL + 1)); return; }

  local has_anchor=no
  echo "$out" | grep -q '<work-state>' && has_anchor=yes

  if [ "$has_anchor" != "$expect_anchor" ]; then
    echo "FAIL: $name — expected anchor=$expect_anchor, got $has_anchor (out: $out)"
    FAIL=$((FAIL + 1)); return
  fi

  if [ -n "$expect_substr" ]; then
    if ! echo "$out" | grep -q "$expect_substr"; then
      echo "FAIL: $name — output missing '$expect_substr' (out: $out)"
      FAIL=$((FAIL + 1)); return
    fi
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
}

setup_idle()        { :; }
setup_wave_active() {
  printf '' > "$1/temp/sdd-wave-active-fake-epic.flag"
  printf '{"epic_id":"fake-epic","wave_completed":3}' > "$1/temp/sdd-checkpoint-fake-epic.json"
}
setup_noop()        { :; }

echo "=== Work-State Anchor Tests ==="
echo ""

# Idle: no flag, 0 in_progress → silent.
run_test "Idle session injects nothing" setup_idle '[]' no

# Wave in flight → anchor names the epic and wave.
run_test "Active wave injects anchor with epic+wave" setup_wave_active '[]' yes 'fake-epic'

# In-progress beads work, no wave → anchor names the count.
run_test "In-progress work injects count anchor" setup_noop '[{"id":"a"},{"id":"b"}]' yes '2 in_progress'

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
