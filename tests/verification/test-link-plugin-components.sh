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

# ─── Test 4: Hash-based skip — second run with unchanged source ──────────
echo "Test 4: Hash-based skip — second run with unchanged source"
setup

"$LINK_SCRIPT" "$PLUGIN_ROOT" >/dev/null 2>&1

# Verify .source-hash sidecar was created for agent
assert "agent .source-hash sidecar exists" \
  "$([[ -f "$TEST_PROJECT/.claude/agents/superpowers-bd:code-reviewer.md.source-hash" ]] && echo 0 || echo 1)"

output2=$("$LINK_SCRIPT" "$PLUGIN_ROOT" 2>&1)

assert "second run reports up to date" \
  "$(echo "$output2" | grep -q "up to date" && echo 0 || echo 1)"

teardown

# ─── Test 5: Hash mismatch — modified source triggers re-copy ────────────
echo "Test 5: Hash mismatch — modified source triggers re-copy"
setup

# Create a temp fixture plugin with a hooked agent
FIXTURE=$(mktemp -d)
mkdir -p "$FIXTURE/.claude-plugin" "$FIXTURE/agents"
echo '{"name": "test-plugin"}' > "$FIXTURE/.claude-plugin/plugin.json"
cat > "$FIXTURE/agents/my-agent.md" <<'AGENT'
---
name: my-agent
hooks:
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "echo hello"
          timeout: 5
---

Original body content.
AGENT

"$LINK_SCRIPT" "$FIXTURE" >/dev/null 2>&1
target="$TEST_PROJECT/.claude/agents/test-plugin:my-agent.md"
hash_file="${target}.source-hash"

assert "first run creates agent" "$([[ -f "$target" ]] && echo 0 || echo 1)"
assert "first run creates hash sidecar" "$([[ -f "$hash_file" ]] && echo 0 || echo 1)"

stored_hash_v1=$(cat "$hash_file")

# Modify source
cat > "$FIXTURE/agents/my-agent.md" <<'AGENT'
---
name: my-agent
hooks:
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "echo hello"
          timeout: 5
---

Modified body content with changes.
AGENT

output3=$("$LINK_SCRIPT" "$FIXTURE" 2>&1)
stored_hash_v2=$(cat "$hash_file")

assert "re-copy triggered on source change" \
  "$(echo "$output3" | grep -q "my-agent" && echo 0 || echo 1)"
assert "hash sidecar updated" \
  "$([[ "$stored_hash_v1" != "$stored_hash_v2" ]] && echo 0 || echo 1)"
assert "target has updated content" \
  "$(grep -q 'Modified body content' "$target" && echo 0 || echo 1)"

rm -rf "$FIXTURE"
teardown

# ─── Test 6: Prune — deleted agent source removes target ─────────────────
echo "Test 6: Prune — deleted agent source removes target"
setup

# Create fixture with two hooked agents
FIXTURE=$(mktemp -d)
mkdir -p "$FIXTURE/.claude-plugin" "$FIXTURE/agents"
echo '{"name": "test-plugin"}' > "$FIXTURE/.claude-plugin/plugin.json"

for name in keep-me remove-me; do
  cat > "$FIXTURE/agents/${name}.md" <<AGENT
---
name: ${name}
hooks:
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "echo test"
          timeout: 5
---

Body of ${name}.
AGENT
done

"$LINK_SCRIPT" "$FIXTURE" >/dev/null 2>&1

assert "both agents exist" \
  "$([[ -f "$TEST_PROJECT/.claude/agents/test-plugin:keep-me.md" && -f "$TEST_PROJECT/.claude/agents/test-plugin:remove-me.md" ]] && echo 0 || echo 1)"

# Delete one source
rm "$FIXTURE/agents/remove-me.md"

"$LINK_SCRIPT" "$FIXTURE" >/dev/null 2>&1

assert "kept agent still exists" \
  "$([[ -f "$TEST_PROJECT/.claude/agents/test-plugin:keep-me.md" ]] && echo 0 || echo 1)"
assert "removed agent pruned" \
  "$([[ ! -f "$TEST_PROJECT/.claude/agents/test-plugin:remove-me.md" ]] && echo 0 || echo 1)"
assert "removed agent hash sidecar pruned" \
  "$([[ ! -f "$TEST_PROJECT/.claude/agents/test-plugin:remove-me.md.source-hash" ]] && echo 0 || echo 1)"

rm -rf "$FIXTURE"
teardown

# ─── Test 7: Prune — deleted skill source removes target ─────────────────
echo "Test 7: Prune — deleted skill source removes target"
setup

# Create fixture with a hooked skill
FIXTURE=$(mktemp -d)
mkdir -p "$FIXTURE/.claude-plugin" "$FIXTURE/skills/my-skill"
echo '{"name": "test-plugin"}' > "$FIXTURE/.claude-plugin/plugin.json"
cat > "$FIXTURE/skills/my-skill/SKILL.md" <<'SKILL'
---
name: my-skill
description: Test skill
hooks:
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "echo test"
          timeout: 5
---

# My Skill
Content here.
SKILL

"$LINK_SCRIPT" "$FIXTURE" >/dev/null 2>&1

assert "skill copied" \
  "$([[ -d "$TEST_PROJECT/.claude/skills/test-plugin:my-skill" ]] && echo 0 || echo 1)"
assert "skill .source-hash exists" \
  "$([[ -f "$TEST_PROJECT/.claude/skills/test-plugin:my-skill/.source-hash" ]] && echo 0 || echo 1)"

# Delete skill source
rm -rf "$FIXTURE/skills/my-skill"

"$LINK_SCRIPT" "$FIXTURE" >/dev/null 2>&1

assert "skill directory pruned" \
  "$([[ ! -d "$TEST_PROJECT/.claude/skills/test-plugin:my-skill" ]] && echo 0 || echo 1)"

rm -rf "$FIXTURE"
teardown

# ─── Test 8: Legacy migration — target without hash gets refreshed ───────
echo "Test 8: Legacy migration — target without hash gets refreshed"
setup

# Create fixture
FIXTURE=$(mktemp -d)
mkdir -p "$FIXTURE/.claude-plugin" "$FIXTURE/agents"
echo '{"name": "test-plugin"}' > "$FIXTURE/.claude-plugin/plugin.json"
cat > "$FIXTURE/agents/legacy.md" <<'AGENT'
---
name: legacy
hooks:
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "echo test"
          timeout: 5
---

Legacy agent body.
AGENT

# Pre-create target WITHOUT hash sidecar (simulating legacy install)
mkdir -p "$TEST_PROJECT/.claude/agents"
echo "old stale content" > "$TEST_PROJECT/.claude/agents/test-plugin:legacy.md"
# No .source-hash file — legacy state

"$LINK_SCRIPT" "$FIXTURE" >/dev/null 2>&1

target="$TEST_PROJECT/.claude/agents/test-plugin:legacy.md"
hash_file="${target}.source-hash"

assert "legacy target refreshed with new content" \
  "$(grep -q 'Legacy agent body' "$target" && echo 0 || echo 1)"
assert "hash sidecar created after migration" \
  "$([[ -f "$hash_file" ]] && echo 0 || echo 1)"

rm -rf "$FIXTURE"
teardown

# ─── Test 9: Works via CLAUDE_PLUGIN_ROOT env var ─────────────────────────
echo "Test 9: Works via CLAUDE_PLUGIN_ROOT env var"
setup

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
output=$("$LINK_SCRIPT" 2>&1)

assert "copies via env var" \
  "$([[ -f "$TEST_PROJECT/.claude/agents/superpowers-bd:code-reviewer.md" ]] && echo 0 || echo 1)"

unset CLAUDE_PLUGIN_ROOT
teardown

# ─── Test 10: Output is valid JSON ────────────────────────────────────────
echo "Test 10: Output is valid JSON"
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
