#!/usr/bin/env bash
# Unit tests for the checkpoint liveness guard in hooks/session-start.sh.
# The hook must only inject <sdd-checkpoint-recovery> when the epic still has
# open/in_progress work. A checkpoint for a fully-closed epic is stale and must
# be suppressed (and the stale file cleaned up). bd is stubbed via PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/../../hooks/session-start.sh"
PASS=0
FAIL=0
TOTAL=0

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

# Stub `bd` on PATH. It echoes $BD_STUB_OUTPUT for the `list` subcommand so the
# hook's `bd list --parent ... --json | jq length` sees a controlled count.
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

# Run the hook against a project dir holding a single checkpoint file.
# Args: name, bd_stub_json, expect_banner(yes|no), expect_file(present|gone)
run_test() {
  local name="$1" bd_json="$2" expect_banner="$3" expect_file="$4"
  TOTAL=$((TOTAL + 1))

  local proj="$TEST_ROOT/proj-$TOTAL"
  mkdir -p "$proj/temp"
  local ckpt="$proj/temp/sdd-checkpoint-fake-epic.json"
  printf '{"epic_id":"fake-epic","wave_completed":1,"closed_issues":[]}' > "$ckpt"

  local out
  out=$(echo '{}' | HOME="$proj" CLAUDE_PROJECT_DIR="$proj" \
        PATH="$STUB_BIN:$PATH" BD_STUB_OUTPUT="$bd_json" \
        bash "$HOOK_SCRIPT") || {
    echo "FAIL: $name — hook exited non-zero"; FAIL=$((FAIL + 1)); return; }

  local has_banner=no
  echo "$out" | grep -q 'sdd-checkpoint-recovery' && has_banner=yes

  if [ "$has_banner" != "$expect_banner" ]; then
    echo "FAIL: $name — expected banner=$expect_banner, got $has_banner"
    FAIL=$((FAIL + 1)); return
  fi

  local file_state=present
  [ -f "$ckpt" ] || file_state=gone
  if [ "$file_state" != "$expect_file" ]; then
    echo "FAIL: $name — expected file=$expect_file, got $file_state"
    FAIL=$((FAIL + 1)); return
  fi

  echo "PASS: $name"
  PASS=$((PASS + 1))
}

echo "=== Session-Start Checkpoint Liveness Tests ==="
echo ""

# Stale: epic has 0 open children → suppress banner AND remove stale file.
run_test "Completed epic suppresses recovery banner" '[]' no gone

# Live: epic has open children → inject banner, keep file.
run_test "Active epic injects recovery banner" '[{"id":"fake-epic.1"}]' yes present

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
