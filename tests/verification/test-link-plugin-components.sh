#!/usr/bin/env bash
# Unit tests for hooks/link-plugin-components.sh
# Tests linking behavior in isolation — no Claude session needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINK_SCRIPT="$PLUGIN_ROOT/hooks/link-plugin-components.sh"

pass=0
fail=0
total=0

assert() {
  local desc="$1"
  local result="$2"
  total=$((total + 1))
  if [[ "$result" == "0" ]]; then
    echo "  ✓ $desc"
    pass=$((pass + 1))
  else
    echo "  ✗ $desc"
    fail=$((fail + 1))
  fi
}

# Create a clean temp project dir for each test
setup() {
  TEST_PROJECT=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TEST_PROJECT"
  # Unset CLAUDE_PLUGIN_ROOT so the script uses the argument
  unset CLAUDE_PLUGIN_ROOT 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_PROJECT"
}

# ─── Test 1: Only hooked components are copied ───────────────────────────
echo "Test 1: Only hooked components are copied"
setup

output=$("$LINK_SCRIPT" "$PLUGIN_ROOT" 2>&1)

# code-reviewer.md has hooks: → should be copied
assert "code-reviewer agent copied" \
  "$([[ -f "$TEST_PROJECT/.claude/agents/superpowers-bd:code-reviewer.md" ]] && echo 0 || echo 1)"

# epic-verifier.md has NO hooks: → should NOT be copied
assert "epic-verifier agent NOT copied" \
  "$([[ ! -f "$TEST_PROJECT/.claude/agents/superpowers-bd:epic-verifier.md" ]] && echo 0 || echo 1)"

# Output should mention what was copied
assert "output mentions code-reviewer" \
  "$(echo "$output" | grep -q "code-reviewer" && echo 0 || echo 1)"

teardown

# ─── Test 2: name: field updated with plugin prefix ──────────────────────
echo "Test 2: name: field updated with plugin prefix"
setup

"$LINK_SCRIPT" "$PLUGIN_ROOT" >/dev/null 2>&1

copied_file="$TEST_PROJECT/.claude/agents/superpowers-bd:code-reviewer.md"
if [[ -f "$copied_file" ]]; then
  assert "name field has plugin prefix" \
    "$(grep -q '^name: superpowers-bd:code-reviewer$' "$copied_file" && echo 0 || echo 1)"
  assert "original name not present" \
    "$(grep -q '^name: code-reviewer$' "$copied_file" && echo 1 || echo 0)"
else
  assert "name field has plugin prefix" "1"
  assert "original name not present" "1"
fi

teardown

# ─── Test 3: $CLAUDE_PLUGIN_ROOT resolved to absolute path ───────────────
echo "Test 3: \$CLAUDE_PLUGIN_ROOT resolved to absolute path"
setup

"$LINK_SCRIPT" "$PLUGIN_ROOT" >/dev/null 2>&1

copied_file="$TEST_PROJECT/.claude/agents/superpowers-bd:code-reviewer.md"
if [[ -f "$copied_file" ]]; then
  assert "no \$CLAUDE_PLUGIN_ROOT references remain" \
    "$(grep -q 'CLAUDE_PLUGIN_ROOT' "$copied_file" && echo 1 || echo 0)"
  assert "absolute path present in hook command" \
    "$(grep -q "$PLUGIN_ROOT/hooks/log-file-modification.sh" "$copied_file" && echo 0 || echo 1)"
else
  assert "no \$CLAUDE_PLUGIN_ROOT references remain" "1"
  assert "absolute path present in hook command" "1"
fi

teardown

# ─── Test 4: Idempotent — second run copies nothing ──────────────────────
echo "Test 4: Idempotent — second run copies nothing"
setup

"$LINK_SCRIPT" "$PLUGIN_ROOT" >/dev/null 2>&1
output2=$("$LINK_SCRIPT" "$PLUGIN_ROOT" 2>&1)

assert "second run reports up to date" \
  "$(echo "$output2" | grep -q "up to date" && echo 0 || echo 1)"

teardown

# ─── Test 5: Works via CLAUDE_PLUGIN_ROOT env var ─────────────────────────
echo "Test 5: Works via CLAUDE_PLUGIN_ROOT env var"
setup

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
output=$("$LINK_SCRIPT" 2>&1)

assert "copies via env var" \
  "$([[ -f "$TEST_PROJECT/.claude/agents/superpowers-bd:code-reviewer.md" ]] && echo 0 || echo 1)"

unset CLAUDE_PLUGIN_ROOT
teardown

# ─── Test 6: Output is valid JSON ────────────────────────────────────────
echo "Test 6: Output is valid JSON"
setup

output=$("$LINK_SCRIPT" "$PLUGIN_ROOT" 2>&1)

if command -v jq &>/dev/null; then
  assert "output is valid JSON" \
    "$(echo "$output" | jq . >/dev/null 2>&1 && echo 0 || echo 1)"
  assert "has hookEventName" \
    "$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null | grep -q "SessionStart" && echo 0 || echo 1)"
else
  echo "  (skipped — jq not available)"
fi

teardown

# ─── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "Results: $pass/$total passed, $fail failed"

if [[ $fail -gt 0 ]]; then
  exit 1
fi
