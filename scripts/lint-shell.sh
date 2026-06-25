#!/usr/bin/env bash
# lint-shell.sh — Run shellcheck over all hook scripts.
# Discovers hooks/*.sh and plugins/superpowers-bd/hooks/*.sh (includes codex-*.sh
# in both locations since they live directly under the hooks directories).
# Exits non-zero if any file has warnings or errors at the configured severity.
#
# Usage: scripts/lint-shell.sh
# Run manually or in CI — NOT as a pre-commit hook (pre-commit.com destroys beads hooks, Issue #3450).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHELLCHECK="$(command -v shellcheck || true)"
SEVERITY=warning

if [[ -z "$SHELLCHECK" ]]; then
  echo "error: shellcheck not found on PATH (install: brew install shellcheck)" >&2
  exit 1
fi

failures=0
checked=0

for f in \
  "$REPO_ROOT"/hooks/*.sh \
  "$REPO_ROOT"/plugins/superpowers-bd/hooks/*.sh; do
  [[ -f "$f" ]] || continue
  checked=$((checked + 1))
  if ! "$SHELLCHECK" --severity="$SEVERITY" "$f"; then
    failures=$((failures + 1))
  fi
done

echo ""
echo "shellcheck summary: checked=$checked  failures=$failures  severity=$SEVERITY"

if [[ "$failures" -gt 0 ]]; then
  echo "FAIL: $failures file(s) have shellcheck warnings or errors" >&2
  exit 1
fi

echo "PASS: all $checked files clean"
