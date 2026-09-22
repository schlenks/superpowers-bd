#!/usr/bin/env bash
# Test: Codex project-local hook configuration and wrappers
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
export CODEX_HOME="$TEST_DIR/no-plugin"

pass=0
fail=0

mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/bd" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "list" ]; then
  if [ "${BD_TEST_CHILDREN:-nonempty}" = "empty" ]; then
    printf '[]\n'
  else
    printf '[{"id":"child"}]\n'
  fi
  exit 0
fi
exit 1
EOF
chmod +x "$TEST_DIR/bin/bd"
export PATH="$TEST_DIR/bin:$PATH"

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

check "plugin Codex hooks config exists" \
  test -f plugins/superpowers-bd/hooks.json

# shellcheck disable=SC2016
check_node "plugin Codex hooks config has expanded lifecycle command hooks" '
  const fs = require("fs");
  const config = JSON.parse(fs.readFileSync("plugins/superpowers-bd/hooks.json", "utf8"));
  const hooks = config.hooks || {};
  const command = (script) => "\"${PLUGIN_ROOT}/hooks/" + script + "\"";
  const expected = {
    SessionStart: { matcher: "startup|resume|clear|compact", command: command("codex-session-start.sh") },
    UserPromptSubmit: { command: command("codex-work-state-anchor.sh") },
    PostToolUse: { matcher: "apply_patch|Edit|Write", command: command("codex-post-tool-use.sh") },
    SubagentStop: { command: command("codex-verdict-audit.sh") },
    Stop: { command: command("codex-stop-gate.sh") },
    PreCompact: { matcher: "manual|auto", command: command("codex-pre-compact.sh") },
  };
  for (const [event, expectation] of Object.entries(expected)) {
    const entry = hooks[event]?.[0];
    const hook = entry?.hooks?.[0];
    if (!entry || hook?.type !== "command") process.exit(1);
    if (expectation.matcher && entry.matcher !== expectation.matcher) process.exit(1);
    if (hook.command !== expectation.command) process.exit(1);
  }
'

check_node "plugin Codex hooks config resolves to existing executable wrappers" '
  const fs = require("fs");
  const path = require("path");
  const config = JSON.parse(fs.readFileSync("plugins/superpowers-bd/hooks.json", "utf8"));
  const commands = Object.values(config.hooks || {})
    .flatMap((entries) => entries.flatMap((entry) => entry.hooks || []))
    .map((hook) => hook.command);
  const wrappers = commands.map((command) => {
    const match = command.match(/(?:^|\/)hooks\/([^"\s]+)/);
    if (!match) process.exit(1);
    return path.join("plugins/superpowers-bd/hooks", match[1]);
  });
  if (wrappers.length !== 6) process.exit(1);
  for (const wrapper of wrappers) {
    fs.accessSync(wrapper, fs.constants.X_OK);
  }
'

check "Codex session wrapper exists and is executable" \
  test -x hooks/codex-session-start.sh

check "Codex PostToolUse wrapper exists and is executable" \
  test -x hooks/codex-post-tool-use.sh

for hook_name in codex-work-state-anchor.sh codex-pre-compact.sh codex-stop-gate.sh codex-verdict-audit.sh; do
  check "Codex $hook_name wrapper exists and is executable" \
    test -x "hooks/$hook_name"
done

check "plugin Codex hooks config has no Claude environment variables" \
  bash -c "! grep -E '\\$\\{?CLAUDE_' plugins/superpowers-bd/hooks.json plugins/superpowers-bd/hooks/hooks.json"

check "Codex wrappers do not depend on Claude hook environment" \
  bash -c "! grep -E '\\$\\{?CLAUDE_|CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR' hooks/codex-*.sh"

mkdir -p "$TEST_DIR/subdir"
subdir_session_stdout="$TEST_DIR/subdir-session-stdout.json"
printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}\n' "$TEST_DIR" \
  | bash "$(cd "$TEST_DIR/subdir" && git -C "$REPO_ROOT" rev-parse --show-toplevel)/hooks/codex-session-start.sh" > "$subdir_session_stdout"

check_node "Configured SessionStart command resolves from a subdirectory" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$subdir_session_stdout', 'utf8'));
  if (payload.hookSpecificOutput?.hookEventName !== 'SessionStart') process.exit(1);
"

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

plugin_session_stdout="$TEST_DIR/plugin-session-stdout.json"
printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}\n' "$TEST_DIR" \
  | bash plugins/superpowers-bd/hooks/codex-session-start.sh > "$plugin_session_stdout"

check_node "Plugin-bundled SessionStart wrapper emits Codex hook context JSON" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$plugin_session_stdout', 'utf8'));
  const out = payload.hookSpecificOutput;
  if (out?.hookEventName !== 'SessionStart') process.exit(1);
  const context = out.additionalContext || '';
  if (!context.includes('superpowers-bd:using-superpowers')) process.exit(1);
  if (!context.includes('sdd-checkpoint-demo.json')) process.exit(1);
"

for source in resume compact; do
  local_output="$TEST_DIR/local-${source}-session.json"
  plugin_output="$TEST_DIR/plugin-${source}-session.json"
  printf '{"hook_event_name":"SessionStart","source":"%s","cwd":"%s"}\n' "$source" "$TEST_DIR" \
    | bash hooks/codex-session-start.sh > "$local_output"
  printf '{"hook_event_name":"SessionStart","source":"%s","cwd":"%s"}\n' "$source" "$TEST_DIR" \
    | bash plugins/superpowers-bd/hooks/codex-session-start.sh > "$plugin_output"
  check_node "Both hook layers support SessionStart source=$source independently" "
    const fs = require('fs');
    for (const file of ['$local_output', '$plugin_output']) {
      const context = JSON.parse(fs.readFileSync(file, 'utf8')).hookSpecificOutput?.additionalContext || '';
      if (!context.includes('superpowers-bd:using-superpowers')) process.exit(1);
    }
  "
done

# Both sources are loaded when developing this repository with the plugin installed.
mkdir -p "$TEST_DIR/codex-home"
cat > "$TEST_DIR/codex-home/config.toml" <<'EOF'
[plugins."superpowers-bd@test-marketplace"]
enabled = true

[hooks.state."superpowers-bd@test-marketplace:hooks/hooks.json:session_start:0:0"]
trusted_hash = "sha256:test"

[hooks.state."superpowers-bd@test-marketplace:hooks/hooks.json:user_prompt_submit:0:0"]
trusted_hash = "sha256:test"
EOF

plugin_enabled_local_stdout="$TEST_DIR/plugin-enabled-local-session.json"
printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}\n' "$TEST_DIR" \
  | CODEX_HOME="$TEST_DIR/codex-home" bash hooks/codex-session-start.sh > "$plugin_enabled_local_stdout"
check_node "Project-local SessionStart defers to a trusted installed plugin" "
  const fs = require('fs');
  const output = fs.readFileSync('$plugin_enabled_local_stdout', 'utf8').trim();
  if (output) process.exit(1);
"

plugin_enabled_compact_stdout="$TEST_DIR/plugin-enabled-local-compact.json"
printf '{"hook_event_name":"SessionStart","source":"compact","cwd":"%s"}\n' "$TEST_DIR" \
  | CODEX_HOME="$TEST_DIR/codex-home" bash hooks/codex-session-start.sh > "$plugin_enabled_compact_stdout"
check_node "Project-local compact SessionStart defers to a trusted installed plugin" "
  const fs = require('fs');
  const output = fs.readFileSync('$plugin_enabled_compact_stdout', 'utf8').trim();
  if (output) process.exit(1);
"

mkdir -p "$TEST_DIR/untrusted-home"
cat > "$TEST_DIR/untrusted-home/config.toml" <<'EOF'
[plugins."superpowers-bd@test-marketplace"]
enabled = true
EOF
untrusted_stdout="$TEST_DIR/untrusted-local-session.json"
printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}\n' "$TEST_DIR" \
  | CODEX_HOME="$TEST_DIR/untrusted-home" bash hooks/codex-session-start.sh > "$untrusted_stdout"
check_node "Project-local SessionStart remains active when plugin hook is untrusted" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$untrusted_stdout', 'utf8'));
  if (!payload.hookSpecificOutput?.additionalContext?.includes('superpowers-bd:using-superpowers')) process.exit(1);
"

mkdir -p "$TEST_DIR/stale/temp"
printf '{}\n' > "$TEST_DIR/stale/temp/sdd-checkpoint-finished.json"

stale_session_stdout="$TEST_DIR/stale-session-stdout.json"
printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}\n' "$TEST_DIR/stale" \
  | BD_TEST_CHILDREN=empty bash hooks/codex-session-start.sh > "$stale_session_stdout"

check_node "SessionStart wrapper removes stale checkpoint when epic has no open work" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$stale_session_stdout', 'utf8'));
  const context = payload.hookSpecificOutput?.additionalContext || '';
  if (context.includes('sdd-checkpoint-finished')) process.exit(1);
  if (fs.existsSync('$TEST_DIR/stale/temp/sdd-checkpoint-finished.json')) process.exit(1);
"

printf '{}\n' > "$TEST_DIR/stale/temp/sdd-checkpoint-finished.json"
plugin_stale_session_stdout="$TEST_DIR/plugin-stale-session-stdout.json"
printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}\n' "$TEST_DIR/stale" \
  | BD_TEST_CHILDREN=empty bash plugins/superpowers-bd/hooks/codex-session-start.sh > "$plugin_stale_session_stdout"

check_node "Plugin-bundled SessionStart wrapper removes stale checkpoint when epic has no open work" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$plugin_stale_session_stdout', 'utf8'));
  const context = payload.hookSpecificOutput?.additionalContext || '';
  if (context.includes('sdd-checkpoint-finished')) process.exit(1);
  if (fs.existsSync('$TEST_DIR/stale/temp/sdd-checkpoint-finished.json')) process.exit(1);
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

plugin_post_stdout="$TEST_DIR/plugin-post-stdout.json"
bash plugins/superpowers-bd/hooks/codex-post-tool-use.sh < "$post_input" > "$plugin_post_stdout"

check_node "Plugin-bundled PostToolUse wrapper returns linter feedback for edited files" "
  const fs = require('fs');
  const text = fs.readFileSync('$plugin_post_stdout', 'utf8').trim();
  const payload = JSON.parse(text);
  if (payload.decision !== 'block') process.exit(1);
  if (!/JSON syntax error/.test(payload.reason || '')) process.exit(1);
"

# Parity for the .sh shellcheck path (companion to the .json path above). Codex 0.142.0
# (#28365) now honors a blocking PostToolUse decision for code-mode tool calls, so both
# lint paths must emit decision:block. Guarded on shellcheck availability so the suite
# stays green on machines without it.
if command -v shellcheck >/dev/null 2>&1; then
  # shellcheck disable=SC2016  # literal $UNQUOTED is written into bad.sh on purpose
  printf 'ls $UNQUOTED\n' > "$TEST_DIR/src/bad.sh"
  sh_post_input="$TEST_DIR/sh-post-input.json"
  sh_post_stdout="$TEST_DIR/sh-post-stdout.json"
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
  ' "$TEST_DIR" "$TEST_DIR/src/bad.sh" "$sh_post_input"
  bash hooks/codex-post-tool-use.sh < "$sh_post_input" > "$sh_post_stdout"
  check_node "PostToolUse wrapper blocks a shellcheck-failing .sh edit" "
    const fs = require('fs');
    const payload = JSON.parse(fs.readFileSync('$sh_post_stdout', 'utf8').trim());
    if (payload.decision !== 'block') process.exit(1);
    if (!/shellcheck/.test(payload.reason || '')) process.exit(1);
  "
else
  echo "SKIP: shellcheck not installed — .sh block path not exercised"
fi

mkdir -p "$TEST_DIR/active/temp"
printf 'active\n' > "$TEST_DIR/active/temp/sdd-wave-active-demo.flag"

anchor_stdout="$TEST_DIR/anchor-stdout.json"
printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s"}\n' "$TEST_DIR/active" \
  | bash hooks/codex-work-state-anchor.sh > "$anchor_stdout"

check_node "UserPromptSubmit wrapper injects active work-state context" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$anchor_stdout', 'utf8'));
  const out = payload.hookSpecificOutput;
  if (out?.hookEventName !== 'UserPromptSubmit') process.exit(1);
  if (!String(out.additionalContext || '').includes('SDD wave in flight: epic demo')) process.exit(1);
"

plugin_enabled_anchor_stdout="$TEST_DIR/plugin-enabled-local-anchor.json"
printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s"}\n' "$TEST_DIR/active" \
  | CODEX_HOME="$TEST_DIR/codex-home" bash hooks/codex-work-state-anchor.sh > "$plugin_enabled_anchor_stdout"
check_node "Project-local work-state anchor defers to a trusted installed plugin" "
  const fs = require('fs');
  if (fs.readFileSync('$plugin_enabled_anchor_stdout', 'utf8').trim()) process.exit(1);
"

precompact_stdout="$TEST_DIR/precompact-stdout.json"
printf '{"hook_event_name":"PreCompact","trigger":"auto","cwd":"%s"}\n' "$TEST_DIR/active" \
  | bash hooks/codex-pre-compact.sh > "$precompact_stdout"

check_node "PreCompact wrapper blocks compaction during active SDD wave" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$precompact_stdout', 'utf8'));
  if (payload.decision !== 'block') process.exit(1);
  if (!/SDD wave in flight/.test(payload.reason || '')) process.exit(1);
"

verdict_stdout="$TEST_DIR/verdict-stdout.json"
printf '{"hook_event_name":"SubagentStop","cwd":"%s","agent_type":"worker","agent_id":"agent-1","last_assistant_message":"finished without structured verdict"}\n' "$TEST_DIR/active" \
  | bash hooks/codex-verdict-audit.sh > "$verdict_stdout"

check_node "SubagentStop wrapper blocks missing verdict during active SDD wave" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$verdict_stdout', 'utf8'));
  if (payload.decision !== 'block') process.exit(1);
  if (!/VERDICT/.test(payload.reason || '')) process.exit(1);
"

stop_stdout="$TEST_DIR/stop-stdout.json"
printf '{"hook_event_name":"Stop","cwd":"%s","session_id":"s1","last_assistant_message":"The implementation is complete."}\n' "$TEST_DIR/active" \
  | bash hooks/codex-stop-gate.sh > "$stop_stdout"

check_node "Stop wrapper blocks completion claim without verification evidence" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$stop_stdout', 'utf8'));
  if (payload.decision !== 'block') process.exit(1);
  if (!/verification evidence/.test(payload.reason || '')) process.exit(1);
"

stop_no_evidence_stdout="$TEST_DIR/stop-no-evidence-stdout.json"
printf '{"hook_event_name":"Stop","cwd":"%s","session_id":"s2","last_assistant_message":"The implementation is complete, but I ran out of time to run tests."}\n' "$TEST_DIR/active" \
  | bash hooks/codex-stop-gate.sh > "$stop_no_evidence_stdout"

check_node "Stop wrapper blocks completion claim with ran-out-of-time wording" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$stop_no_evidence_stdout', 'utf8'));
  if (payload.decision !== 'block') process.exit(1);
  if (!/verification evidence/.test(payload.reason || '')) process.exit(1);
"

stop_evidence_stdout="$TEST_DIR/stop-evidence-stdout.json"
printf '{"hook_event_name":"Stop","cwd":"%s","session_id":"s3","last_assistant_message":"The implementation is complete. I ran pytest, exit code 0, 42 passed."}\n' "$TEST_DIR/active" \
  | bash hooks/codex-stop-gate.sh > "$stop_evidence_stdout"

check "Stop wrapper allows explicit verification evidence" \
  test ! -s "$stop_evidence_stdout"

compact_stdout="$TEST_DIR/compact-stdout.json"
printf '{"hook_event_name":"SessionStart","source":"compact","cwd":"%s"}\n' "$TEST_DIR/active" \
  | bash hooks/codex-session-start.sh > "$compact_stdout"

check_node "SessionStart restores context after compaction" "
  const fs = require('fs');
  const payload = JSON.parse(fs.readFileSync('$compact_stdout', 'utf8'));
  const out = payload.hookSpecificOutput;
  if (out?.hookEventName !== 'SessionStart') process.exit(1);
  if (!String(out.additionalContext || '').includes('superpowers-bd:using-superpowers')) process.exit(1);
"

postcompact_stdout="$TEST_DIR/postcompact-stdout.json"
printf '{"hook_event_name":"PostCompact","trigger":"manual","cwd":"%s"}\n' "$TEST_DIR/active" \
  | bash hooks/codex-session-start.sh > "$postcompact_stdout"
check_node "Legacy project-local PostCompact emits no unsupported context" "
  const fs = require('fs');
  if (fs.readFileSync('$postcompact_stdout', 'utf8').trim()) process.exit(1);
"

check_node "Codex plugin manifest describes hooks without manifest-level hook declarations" '
  const fs = require("fs");
  const manifest = JSON.parse(fs.readFileSync(".codex-plugin/plugin.json", "utf8"));
  if (Object.prototype.hasOwnProperty.call(manifest, "hooks")) process.exit(1);
  if (!manifest.interface?.longDescription?.includes("Codex hooks")) process.exit(1);
'

# shellcheck disable=SC2016
check_node "Codex plugin wrapper bundles hook packaging" '
  const fs = require("fs");
  const manifest = JSON.parse(fs.readFileSync(".codex-plugin/plugin.json", "utf8"));
  const prompts = manifest.interface?.defaultPrompt;
  const wrapperHooks = JSON.parse(fs.readFileSync("plugins/superpowers-bd/hooks.json", "utf8"));
  const lifecycleHooks = JSON.parse(fs.readFileSync("plugins/superpowers-bd/hooks/hooks.json", "utf8"));
  const nativeSkillPattern = /\$[A-Za-z0-9:_-]+/;
  if (manifest.name !== "superpowers-bd") process.exit(1);
  if (manifest.skills !== "./skills/") process.exit(1);
  if (!Array.isArray(prompts) || prompts.length === 0) process.exit(1);
  if (!prompts.every((line) => typeof line === "string" && nativeSkillPattern.test(line))) process.exit(1);
  if (prompts.some((line) => line.includes("/superpowers-bd:"))) process.exit(1);
  if (!fs.existsSync(".codex/hooks.json")) process.exit(1);
  const pluginHookCommand = (script) => "\"${PLUGIN_ROOT}/hooks/" + script + "\"";
  if (wrapperHooks.hooks?.SessionStart?.[0]?.hooks?.[0]?.command !== pluginHookCommand("codex-session-start.sh")) process.exit(1);
  if (wrapperHooks.hooks?.PostToolUse?.[0]?.hooks?.[0]?.command !== pluginHookCommand("codex-post-tool-use.sh")) process.exit(1);
  if (JSON.stringify(wrapperHooks) !== JSON.stringify(lifecycleHooks)) process.exit(1);
  if (!wrapperHooks.hooks?.Stop || !wrapperHooks.hooks?.PreCompact || !wrapperHooks.hooks?.UserPromptSubmit) process.exit(1);
'

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
