#!/usr/bin/env bash
# Fast Codex compatibility tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

tests=(
  "test-plugin-manifest.sh"
  "test-codex-cli-fallback.sh"
  "test-codex-agents.sh"
)

passed=0
failed=0

for test in "${tests[@]}"; do
  echo "----------------------------------------"
  echo "Running: $test"
  echo "----------------------------------------"
  if bash "$SCRIPT_DIR/$test"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  echo ""
done

echo "Passed: $passed"
echo "Failed: $failed"

if [ "$failed" -gt 0 ]; then
  exit 1
fi
