#!/usr/bin/env bash
# Test: legacy Codex CLI fallback discovers Superpowers-BD skills cleanly
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

mkdir -p "$TEST_HOME/.codex"
ln -s "$REPO_ROOT" "$TEST_HOME/.codex/superpowers"

echo "=== Test: Codex CLI Fallback ==="

output=$(HOME="$TEST_HOME" "$TEST_HOME/.codex/superpowers/.codex/superpowers-codex" find-skills)

for expected in \
  "superpowers:using-superpowers" \
  "superpowers:plan2beads" \
  "superpowers:ad-hoc-code-review" \
  "superpowers:subagent-driven-development"; do
  if echo "$output" | grep -q "$expected"; then
    echo "  [PASS] found $expected"
  else
    echo "  [FAIL] missing $expected"
    echo "$output"
    exit 1
  fi
done

if echo "$output" | grep -q '  "Use when'; then
  echo "  [FAIL] quoted YAML descriptions leaked into skill list"
  echo "$output"
  exit 1
else
  echo "  [PASS] skill descriptions are unquoted"
fi

echo ""
echo "=== Codex CLI fallback tests passed ==="
