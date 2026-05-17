#!/usr/bin/env bash
# Test: Codex project-local hook configuration and wrappers
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0
fail=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    fail=$((fail + 1))
  fi
}

check_node() {
  local desc="$1"
  local script="$2"
  if node -e "$script"; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    fail=$((fail + 1))
  fi
}

echo "=== Test: Codex hooks ==="
echo ""

check "project-local Codex hooks config exists" \
  test -f .codex/hooks.json

check_node "Codex hooks config has SessionStart and PostToolUse command hooks" '
  const fs = require("fs");
  const config = JSON.parse(fs.readFileSync(".codex/hooks.json", "utf8"));
  const hooks = config.hooks || {};
  const session = hooks.SessionStart?.[0]?.hooks?.[0];
  const post = hooks.PostToolUse?.[0]?.hooks?.[0];
  if (hooks.Stop) process.exit(1);
  if (hooks.SessionStart?.[0]?.matcher !== "startup|resume|clear") process.exit(1);
  if (session?.type !== "command") process.exit(1);
  if (session?.command !== "bash hooks/codex-session-start.sh") process.exit(1);
  if (hooks.PostToolUse?.[0]?.matcher !== "apply_patch|Edit|Write") process.exit(1);
  if (post?.type !== "command") process.exit(1);
  if (post?.command !== "bash hooks/codex-post-tool-use.sh") process.exit(1);
'

check "Codex session wrapper exists and is executable" \
  test -x hooks/codex-session-start.sh

check "Codex PostToolUse wrapper exists and is executable" \
  test -x hooks/codex-post-tool-use.sh

check "Codex wrappers do not depend on Claude hook environment" \
  bash -c "! grep -E 'CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR' hooks/codex-session-start.sh hooks/codex-post-tool-use.sh"

mkdir -p "$TEST_DIR/temp"
printf '{}\n' > "$TEST_DIR/temp/sdd-checkpoint-demo.json"

session_stdout="$TEST_DIR/session-stdout.json"
printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}\n' "$TEST_DIR" \
  | bash hooks/codex-session-start.sh > "$session_stdout"

check_node "SessionStart wrapper emits Codex hook context JSON" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$session_stdout', 'utf8'));
  const out = payload.hookSpecificOutput;
  if (out?.hookEventName !== 'SessionStart') process.exit(1);
  const context = out.additionalContext || '';
  if (!context.includes('superpowers-bd:using-superpowers')) process.exit(1);
  if (!context.includes('sdd-checkpoint-demo.json')) process.exit(1);
"

mkdir -p "$TEST_DIR/src"
printf '{"broken": true\n' > "$TEST_DIR/src/broken.json"

post_stdout="$TEST_DIR/post-stdout.json"
post_input="$TEST_DIR/post-input.json"
# shellcheck disable=SC2016
node -e '
  const fs = require("fs");
  const [cwd, file, out] = process.argv.slice(1);
  const payload = {
    hook_event_name: "PostToolUse",
    cwd,
    tool_name: "apply_patch",
    tool_input: {
      command: `*** Begin Patch\n*** Update File: ${file}\n@@\n*** End Patch\n`
    }
  };
  fs.writeFileSync(out, `${JSON.stringify(payload)}\n`);
' "$TEST_DIR" "$TEST_DIR/src/broken.json" "$post_input"
bash hooks/codex-post-tool-use.sh < "$post_input" > "$post_stdout"

check_node "PostToolUse wrapper returns linter feedback for edited files" "
  const fs = require('fs');
  const text = fs.readFileSync('$post_stdout', 'utf8').trim();
  const payload = JSON.parse(text);
  if (payload.decision !== 'block') process.exit(1);
  if (!/JSON syntax error/.test(payload.reason || '')) process.exit(1);
"

check "PostToolUse wrapper records Codex audit log in cwd temp directory" \
  grep -q "$TEST_DIR/src/broken.json" "$TEST_DIR/temp/file-modifications.log"

check_node "Codex plugin manifest does not overclaim bundled hook support" '
  const fs = require("fs");
  const manifest = JSON.parse(fs.readFileSync(".codex-plugin/plugin.json", "utf8"));
  if (Object.prototype.hasOwnProperty.call(manifest, "hooks")) process.exit(1);
  if (!manifest.interface?.longDescription?.includes("Project-local Codex hooks")) process.exit(1);
'

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
