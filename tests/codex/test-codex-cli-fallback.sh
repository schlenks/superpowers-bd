#!/usr/bin/env bash
# Test: manual Codex CLI fallback discovers Superpowers-BD skills cleanly
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

mkdir -p "$TEST_HOME/.codex"
ln -s "$REPO_ROOT" "$TEST_HOME/.codex/superpowers-bd"

echo "=== Test: Codex CLI Fallback ==="

output=$(HOME="$TEST_HOME" "$TEST_HOME/.codex/superpowers-bd/.codex/superpowers-bd-codex" find-skills)

for expected in \
  "superpowers-bd:using-superpowers" \
  "superpowers-bd:plan2beads" \
  "superpowers-bd:ad-hoc-code-review" \
  "superpowers-bd:subagent-driven-development"; do
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

skill_output=$(HOME="$TEST_HOME" "$TEST_HOME/.codex/superpowers-bd/.codex/superpowers-bd-codex" use-skill superpowers-bd:plan2beads)
if echo "$skill_output" | grep -q '# plan2beads' && echo "$skill_output" | grep -q 'Load `superpowers-bd:beads` first'; then
  echo "  [PASS] superpowers-bd: namespace loads bundled skills"
else
  echo "  [FAIL] superpowers-bd: namespace should load bundled skills"
  echo "$skill_output"
  exit 1
fi

old_namespace_output=$(HOME="$TEST_HOME" "$TEST_HOME/.codex/superpowers-bd/.codex/superpowers-bd-codex" use-skill superpowers:plan2beads)
if echo "$old_namespace_output" | grep -q 'Error: Skill not found: superpowers:plan2beads'; then
  echo "  [PASS] original superpowers: prefix is not captured by Superpowers-BD"
else
  echo "  [FAIL] original superpowers: prefix should not load from Superpowers-BD"
  echo "$old_namespace_output"
  exit 1
fi

echo ""
echo "=== Codex CLI fallback tests passed ==="
