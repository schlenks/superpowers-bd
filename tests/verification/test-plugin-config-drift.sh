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
  grep -q "~/.config/opencode/plugins" .opencode/INSTALL.md

check "OpenCode README uses global plugins directory" \
  grep -q "~/.config/opencode/plugins" docs/README.opencode.md

check "OpenCode README includes dependency install step" \
  grep -q "npm install" docs/README.opencode.md

check "OpenCode docs no longer document singular plugin directory" \
  bash -c "! grep -R \"\\.opencode/plugin/\\|opencode/plugin/\" .opencode/INSTALL.md docs/README.opencode.md tests/opencode"

check "Runtime tests no longer request legacy superpowers namespace" \
  bash -c "! grep -R \"superpowers:subagent-driven-development\" tests/claude-code tests/subagent-driven-dev"

check "Codex project-local hooks config is documented in manifest" \
  grep -q "Project-local Codex hooks" .codex-plugin/plugin.json

check "Codex aggregate test runner includes hook parity tests" \
  grep -q "test-codex-hooks.sh" tests/codex/run-tests.sh

check "Codex manifest uses native skill prompts, not Claude slash commands" \
  node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(".codex-plugin/plugin.json","utf8")); const prompts=p.interface && p.interface.defaultPrompt || []; process.exit(p.skills === "./skills/" && prompts.length > 0 && prompts.every((line) => line.includes("$")) && prompts.every((line) => !line.includes("/superpowers-bd:")) ? 0 : 1)'

check "Codex hook wrappers do not depend on Claude hook environment" \
  bash -c "! grep -E 'CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR' hooks/codex-session-start.sh hooks/codex-post-tool-use.sh"

check "Codex hooks are project-local, not plugin-bundled manifest hooks" \
  node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(".codex-plugin/plugin.json","utf8")); process.exit(Object.prototype.hasOwnProperty.call(p,"hooks") ? 1 : 0)'

check "Codex native docs use Codex install path" \
  bash -c "grep -q '~/.codex/plugins' .codex/INSTALL.md && ! grep -q '~/.claude' .codex/INSTALL.md"

check "Codex and Claude have comparable review and verification roles" \
  bash -c "test -f agents/code-reviewer.md && test -f agents/epic-verifier.md && test -f .codex/agents/code-reviewer.toml && test -f .codex/agents/epic-verifier.toml"

check "Codex SDD specialist roles are backed by native agents" \
  node -e 'const fs=require("fs"); const sdd=fs.readFileSync("skills/subagent-driven-development/SKILL.md","utf8"); const roles=["spec_reviewer","code_reviewer","review_aggregator","epic_verifier"]; for (const role of roles) { const path=".codex/agents/"+role.replaceAll("_","-")+".toml"; if (!fs.existsSync(path) || !sdd.includes(role)) process.exit(1); }'

check "Codex native reference docs are mirrored into plugin wrapper" \
  node -e 'const fs=require("fs"); const refs=["skills/writing-plans/references/codex-plan-verification.md","skills/executing-plans/references/codex-execution-checkpoints.md","skills/plan2beads/references/codex-plan2beads-flow.md","skills/ad-hoc-code-review/references/codex-review-flow.md"]; for (const ref of refs) { const wrapped="plugins/superpowers-bd/"+ref; if (!fs.existsSync(ref) || !fs.existsSync(wrapped) || fs.readFileSync(ref,"utf8") !== fs.readFileSync(wrapped,"utf8")) process.exit(1); }'

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
