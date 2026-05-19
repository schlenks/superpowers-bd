#!/usr/bin/env bash
# Fast drift checks for cross-agent plugin packaging and docs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

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

check_codex_manifest_native_skill_prompts() {
  node -e '
    const fs = require("fs");
    const p = JSON.parse(fs.readFileSync(".codex-plugin/plugin.json", "utf8"));
    const prompts = p.interface?.defaultPrompt;
    const nativeSkillPattern = /\$[A-Za-z0-9:_-]+/;
    process.exit(
      p.skills === "./skills/" &&
      Array.isArray(prompts) &&
      prompts.length > 0 &&
      prompts.every((line) => typeof line === "string" && nativeSkillPattern.test(line)) &&
      prompts.every((line) => !line.includes("/superpowers-bd:"))
        ? 0
        : 1
    );
  '
}

check_codex_sdd_specialist_roles() {
  python3 - <<'PY'
import pathlib
import sys
import tomllib

roles = {
    "spec_reviewer": "spec-reviewer.toml",
    "code_reviewer": "code-reviewer.toml",
    "review_aggregator": "review-aggregator.toml",
    "epic_verifier": "epic-verifier.toml",
}

config = tomllib.loads(pathlib.Path(".codex/config.toml").read_text())
if "agents" not in config:
    print(".codex/config.toml does not enable agents", file=sys.stderr)
    sys.exit(1)

sdd = pathlib.Path("skills/subagent-driven-development/SKILL.md").read_text()
for role, filename in roles.items():
    path = pathlib.Path(".codex/agents") / filename
    if not path.exists():
        print(f"missing {path}", file=sys.stderr)
        sys.exit(1)
    data = tomllib.loads(path.read_text())
    if data.get("name") != role:
        print(f"{path}: expected name {role!r}, found {data.get('name')!r}", file=sys.stderr)
        sys.exit(1)
    if role not in sdd:
        print(f"SDD skill does not reference {role}", file=sys.stderr)
        sys.exit(1)
PY
}

check_claude_hooks_use_exec_args() {
  node <<'NODE'
const fs = require("fs");

const config = JSON.parse(fs.readFileSync("hooks/hooks.json", "utf8"));
const expectedCommand = "${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd";
const errors = [];

for (const [eventName, entries] of Object.entries(config.hooks || {})) {
  for (const [entryIndex, entry] of entries.entries()) {
    for (const [hookIndex, hook] of (entry.hooks || []).entries()) {
      if (hook.type !== "command") continue;

      const label = `${eventName}[${entryIndex}].hooks[${hookIndex}]`;
      if (hook.command !== expectedCommand) {
        errors.push(`${label}: command must be ${expectedCommand}`);
      }
      if (!Array.isArray(hook.args) || hook.args.length === 0 || typeof hook.args[0] !== "string") {
        errors.push(`${label}: command hook must pass script name through args`);
      } else if (!hook.args[0].endsWith(".sh")) {
        errors.push(`${label}: first arg must be a hook shell script`);
      }
      if (typeof hook.command === "string" && /["']|\.sh(?:\s|$)/.test(hook.command)) {
        errors.push(`${label}: command must not embed shell quoting or script arguments`);
      }
      if (eventName === "PostToolUse" && entry.matcher === "Write|Edit" && hook.continueOnBlock !== true) {
        errors.push(`${label}: PostToolUse linter must set continueOnBlock true`);
      }
    }
  }
}

if (errors.length > 0) {
  console.error(errors.join("\n"));
  process.exit(1);
}
NODE
}

check_codex_plugin_wrapper_native_surfaces() {
  node <<'NODE'
const fs = require("fs");
const path = require("path");

const pluginRoot = path.join("plugins", "superpowers-bd");
const agents = {
  "code-reviewer.md": "code_reviewer",
  "spec-reviewer.md": "spec_reviewer",
  "review-aggregator.md": "review_aggregator",
  "epic-verifier.md": "epic_verifier",
};
const errors = [];

for (const [file, name] of Object.entries(agents)) {
  const agentPath = path.join(pluginRoot, "agents", file);
  if (!fs.existsSync(agentPath)) {
    errors.push(`missing ${agentPath}`);
    continue;
  }
  const text = fs.readFileSync(agentPath, "utf8");
  if (!new RegExp(`^name: ${name}$`, "m").test(text)) {
    errors.push(`${agentPath}: missing name ${name}`);
  }
  if (/^model:/m.test(text) || /gpt-5\./.test(text)) {
    errors.push(`${agentPath}: plugin-wide Codex agents must inherit the user's active Codex model`);
  }
}

const hooksPath = path.join(pluginRoot, "hooks.json");
if (!fs.existsSync(hooksPath)) {
  errors.push(`missing ${hooksPath}`);
} else {
  const hooksConfig = JSON.parse(fs.readFileSync(hooksPath, "utf8"));
  const session = hooksConfig.hooks?.SessionStart?.[0]?.hooks?.[0];
  const post = hooksConfig.hooks?.PostToolUse?.[0]?.hooks?.[0];
  if (hooksConfig.hooks?.SessionStart?.[0]?.matcher !== "startup|resume|clear") {
    errors.push(`${hooksPath}: unexpected SessionStart matcher`);
  }
  if (session?.command !== "./hooks/codex-session-start.sh") {
    errors.push(`${hooksPath}: unexpected SessionStart command`);
  }
  if (hooksConfig.hooks?.PostToolUse?.[0]?.matcher !== "apply_patch|Edit|Write") {
    errors.push(`${hooksPath}: unexpected PostToolUse matcher`);
  }
  if (post?.command !== "./hooks/codex-post-tool-use.sh") {
    errors.push(`${hooksPath}: unexpected PostToolUse command`);
  }
  if (/CLAUDE_|git rev-parse/.test(JSON.stringify(hooksConfig))) {
    errors.push(`${hooksPath}: plugin-bundled Codex hooks must not rely on Claude env or project git root`);
  }
}

for (const hookScript of ["codex-session-start.sh", "codex-post-tool-use.sh"]) {
  const scriptPath = path.join(pluginRoot, "hooks", hookScript);
  if (!fs.existsSync(scriptPath)) {
    errors.push(`missing ${scriptPath}`);
  }
}

if (errors.length > 0) {
  console.error(errors.join("\n"));
  process.exit(1);
}
NODE
}

json_value() {
  node -e "const fs=require('fs'); const o=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log($2)" "$1"
}

claude_version="$(json_value .claude-plugin/plugin.json 'o.version')"
codex_version="$(json_value .codex-plugin/plugin.json 'o.version')"

echo "=== Plugin config drift checks ==="
echo ""

check "Claude and Codex plugin manifests use the same version" \
  test "$claude_version" = "$codex_version"

check "Claude and Codex plugin manifests identify the same plugin" \
  node -e 'const fs=require("fs"); const c=JSON.parse(fs.readFileSync(".claude-plugin/plugin.json","utf8")); const x=JSON.parse(fs.readFileSync(".codex-plugin/plugin.json","utf8")); process.exit(c.name === x.name && c.homepage === x.homepage && c.repository === x.repository && c.license === x.license ? 0 : 1)'

check "Claude hooks use args exec form and PostToolUse continueOnBlock" \
  check_claude_hooks_use_exec_args

check "CLAUDE.md documents current plugin version" \
  grep -q "\\*\\*Plugin version:\\*\\* $claude_version" CLAUDE.md

check "AGENTS.md documents current plugin version" \
  grep -q "\\*\\*Plugin version:\\*\\* $claude_version" AGENTS.md

check "SessionStart context uses superpowers-bd namespace" \
  grep -q "superpowers-bd:using-superpowers" hooks/session-start.sh

check "SessionStart context no longer advertises legacy superpowers namespace" \
  bash -c "! grep -q \"superpowers:using-superpowers\" hooks/session-start.sh"

check "OpenCode source plugin is in .opencode/plugins" \
  test -f .opencode/plugins/superpowers-bd.js

check "OpenCode package metadata is available for dependency installation" \
  bash -c "test -f .opencode/package.json && ! git check-ignore -q .opencode/package.json"

check "OpenCode package metadata marks plugins as ESM" \
  node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(".opencode/package.json", "utf8")); process.exit(p.type === "module" ? 0 : 1)'

check "OpenCode test installer copies package metadata" \
  grep -q "\\.opencode/package.json" tests/opencode/setup.sh

check "Plugin root settings disables built-in git instructions" \
  node -e 'const fs=require("fs"); const s=JSON.parse(fs.readFileSync("settings.json", "utf8")); process.exit(s.includeGitInstructions === false ? 0 : 1)'

check "OpenCode install docs use global plugins directory" \
  grep -q "\\~/.config/opencode/plugins" .opencode/INSTALL.md

check "OpenCode README uses global plugins directory" \
  grep -q "\\~/.config/opencode/plugins" docs/README.opencode.md

check "OpenCode README includes dependency install step" \
  grep -q "npm install" docs/README.opencode.md

check "OpenCode docs no longer document singular plugin directory" \
  bash -c "! grep -R \"\\.opencode/plugin/\\|opencode/plugin/\" .opencode/INSTALL.md docs/README.opencode.md tests/opencode"

check "Runtime tests no longer request legacy superpowers namespace" \
  bash -c "! grep -R \"superpowers:subagent-driven-development\" tests/claude-code tests/subagent-driven-dev"

check "Codex hooks are documented in manifest" \
  grep -q "Codex hooks" .codex-plugin/plugin.json

check "Codex aggregate test runner includes hook parity tests" \
  grep -q "test-codex-hooks.sh" tests/codex/run-tests.sh

check "Codex manifest uses native skill prompts, not Claude slash commands" \
  check_codex_manifest_native_skill_prompts

check "Codex hook wrappers do not depend on Claude hook environment" \
  bash -c "! grep -E 'CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR' hooks/codex-session-start.sh hooks/codex-post-tool-use.sh"

check "Codex manifest avoids unproven manifest-level hook declarations" \
  node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(".codex-plugin/plugin.json","utf8")); process.exit(Object.prototype.hasOwnProperty.call(p,"hooks") ? 1 : 0)'

check "Codex native docs use Codex install path" \
  bash -c "grep -q '~/.codex/plugins' .codex/INSTALL.md && ! grep -q '~/.claude' .codex/INSTALL.md"

check "Codex and Claude have comparable review and verification roles" \
  bash -c "test -f agents/code-reviewer.md && test -f agents/epic-verifier.md && test -f .codex/agents/code-reviewer.toml && test -f .codex/agents/epic-verifier.toml"

check "Codex SDD specialist roles are backed by native agents" \
  check_codex_sdd_specialist_roles

check "Codex plugin wrapper bundles native agents and hooks" \
  check_codex_plugin_wrapper_native_surfaces

check "Codex native reference docs are mirrored into plugin wrapper" \
  node -e 'const fs=require("fs"); const refs=["skills/writing-plans/references/codex-plan-verification.md","skills/executing-plans/references/codex-execution-checkpoints.md","skills/plan2beads/references/codex-plan2beads-flow.md","skills/ad-hoc-code-review/references/codex-review-flow.md"]; for (const ref of refs) { const wrapped="plugins/superpowers-bd/"+ref; if (!fs.existsSync(ref) || !fs.existsSync(wrapped) || fs.readFileSync(ref,"utf8") !== fs.readFileSync(wrapped,"utf8")) process.exit(1); }'

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
