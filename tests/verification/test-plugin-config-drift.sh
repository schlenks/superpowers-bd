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

check "Codex hook wrappers do not depend on Claude hook environment" \
  bash -c "! grep -E 'CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR' hooks/codex-session-start.sh hooks/codex-post-tool-use.sh"

check "Codex hooks are project-local, not plugin-bundled manifest hooks" \
  node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(".codex-plugin/plugin.json","utf8")); process.exit(Object.prototype.hasOwnProperty.call(p,"hooks") ? 1 : 0)'

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
