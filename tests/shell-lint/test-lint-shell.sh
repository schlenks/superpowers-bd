#!/usr/bin/env bash
# Verify scripts/lint-shell.sh exits 0 on the current tree.
# Runs the wrapper directly — no Claude Code session needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LINT_SCRIPT="$SCRIPT_DIR/../../scripts/lint-shell.sh"

PASS=0
FAIL=0

echo "=== Shell Lint Tests ==="
echo ""

# --- Precondition: lint-shell.sh must exist and be executable ---
if [[ ! -x "$LINT_SCRIPT" ]]; then
  echo "FAIL: $LINT_SCRIPT not found or not executable"
  exit 1
fi

# --- Test 1: lint-shell.sh exits 0 on the current tree ---
actual_exit=0
"$LINT_SCRIPT" || actual_exit=$?

if [[ "$actual_exit" -eq 0 ]]; then
  echo "PASS: lint-shell.sh exits 0 on current tree (no shellcheck warnings/errors)"
  PASS=$((PASS + 1))
else
  echo "FAIL: lint-shell.sh exited $actual_exit — shellcheck warnings or errors detected"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
