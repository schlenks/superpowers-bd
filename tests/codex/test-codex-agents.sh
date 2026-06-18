#!/usr/bin/env bash
# Test: Codex plugin agent definitions and routing docs
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== Test: Codex Native Agents ==="

fail() {
  echo "  [FAIL] $1"
  exit 1
}

pass() {
  echo "  [PASS] $1"
}

assert_file() {
  local file="$1"
  if [ -f "$file" ]; then
    pass "$file exists"
  else
    fail "$file exists"
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -Eq "$pattern" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  else
    pass "$message"
  fi
}

assert_plugin_agent_roles() {
  python3 - <<'PY'
import pathlib
import re
import sys

required = {
    "code-reviewer.md": "code_reviewer",
    "epic-verifier.md": "epic_verifier",
    "spec-reviewer.md": "spec_reviewer",
    "review-aggregator.md": "review_aggregator",
}

agent_dir = pathlib.Path("plugins/superpowers-bd/agents")
names_by_file = {}
files_by_name = {}
for path in sorted(agent_dir.glob("*.md")):
    text = path.read_text()
    name_match = re.search(r"^name: ([A-Za-z0-9_-]+)$", text, re.MULTILINE)
    desc_match = re.search(r"^description: .+$", text, re.MULTILINE)
    if not name_match or not desc_match:
        print(f"{path}: missing name or description frontmatter", file=sys.stderr)
        sys.exit(1)
    if re.search(r"^model:", text, re.MULTILINE) or "gpt-5." in text:
        print(f"{path}: plugin Codex agents must inherit the active model", file=sys.stderr)
        sys.exit(1)
    name = name_match.group(1)
    names_by_file[path.name] = name
    files_by_name.setdefault(name, []).append(path.name)

duplicates = {
    name: files
    for name, files in files_by_name.items()
    if name is not None and len(files) > 1
}
if duplicates:
    print(f"duplicate Codex agent role names: {duplicates}", file=sys.stderr)
    sys.exit(1)

if names_by_file != required:
    print(f"expected plugin Codex agent files {required}, found {names_by_file}", file=sys.stderr)
    sys.exit(1)
PY
  pass "Plugin Codex native agent roles are explicit and inherit the active model"
}

assert_config_parses() {
  python3 - <<'PY'
import pathlib
import tomllib

tomllib.loads(pathlib.Path(".codex/config.toml").read_text())
PY
  pass "Codex config TOML parses"
}

assert_model_routing_docs() {
  python3 - <<'PY'
import pathlib
import sys

files = [
    pathlib.Path("docs/README.codex.md"),
    pathlib.Path("README.md"),
    pathlib.Path("skills/subagent-driven-development/SKILL.md"),
    pathlib.Path("skills/subagent-driven-development/budget-and-wave-cap.md"),
]
for path in files:
    text = path.read_text()
    if "inherit the active Codex model" not in text:
        print(f"{path}: missing active model inheritance guidance", file=sys.stderr)
        sys.exit(1)
    if "gpt-5.3-codex" in text or "codex_model_profile" in text:
        print(f"{path}: still references deprecated Codex profile routing", file=sys.stderr)
        sys.exit(1)
PY
  pass "Codex routing docs inherit active model"
}

assert_no_claude_tool_names() {
  local claude_tool_pattern='\b(Read|Glob|Task|AskUserQuestion|TaskCreate|TaskUpdate|TaskList|TaskGet|TodoWrite|Write|Edit|MultiEdit|NotebookEdit|ExitPlanMode|subagent_type|run_in_background|CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR)\b'
  local file
  for file in plugins/superpowers-bd/agents/*.md; do
    assert_not_contains "$file" "$claude_tool_pattern" "$file avoids Claude-only tool names and variables"
  done
}

assert_agent() {
  local file="$1"
  local name="$2"

  assert_file "$file"
  assert_contains "$file" "^name: $name$" "$file declares name $name"
  assert_contains "$file" '^description: .+$' "$file has description"
  assert_not_contains "$file" '^model:' "$file inherits active model"
}

assert_agent "plugins/superpowers-bd/agents/code-reviewer.md" "code_reviewer"
assert_agent "plugins/superpowers-bd/agents/epic-verifier.md" "epic_verifier"
assert_agent "plugins/superpowers-bd/agents/spec-reviewer.md" "spec_reviewer"
assert_agent "plugins/superpowers-bd/agents/review-aggregator.md" "review_aggregator"
assert_config_parses
assert_plugin_agent_roles
assert_model_routing_docs
assert_no_claude_tool_names

assert_file ".codex/config.toml"
assert_contains ".codex/config.toml" '^\[agents\]$' ".codex/config.toml has agents section"
assert_contains ".codex/config.toml" '^max_threads = [1-4]$' ".codex/config.toml sets conservative thread cap"
assert_contains ".codex/config.toml" '^max_depth = 1$' ".codex/config.toml limits agent depth"

assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'Precision Gate' "code reviewer preserves precision gate"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'Changed Files Manifest' "code reviewer requires changed files manifest"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'Requirement Mapping' "code reviewer requires requirement mapping"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'Uncovered Paths' "code reviewer requires uncovered paths"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'Not Checked' "code reviewer requires not checked section"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'stale references' "code reviewer checks stale references"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'Rules Consulted' "code reviewer records repo policy rules"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'Do not modify implementation files' "code reviewer remains read-only for implementation files"
assert_contains "plugins/superpowers-bd/agents/code-reviewer.md" 'write only the requested report artifact' "code reviewer may only persist requested reports"
assert_contains "plugins/superpowers-bd/agents/epic-verifier.md" 'rule-of-five' "epic verifier requires rule-of-five"
assert_contains "plugins/superpowers-bd/agents/epic-verifier.md" 'PASS or FAIL' "epic verifier uses pass fail verdict"
assert_contains "plugins/superpowers-bd/agents/epic-verifier.md" 'Do not fix issues' "epic verifier remains read-only"
assert_contains "plugins/superpowers-bd/agents/spec-reviewer.md" 'Do not modify implementation files' "spec reviewer remains read-only for implementation files"
assert_contains "plugins/superpowers-bd/agents/spec-reviewer.md" 'write only the requested report artifact' "spec reviewer may only persist requested reports"
assert_contains "plugins/superpowers-bd/agents/review-aggregator.md" 'provenance' "review aggregator preserves provenance"
assert_contains "plugins/superpowers-bd/agents/review-aggregator.md" 'Do not invent findings' "review aggregator does not invent findings"
assert_contains "plugins/superpowers-bd/agents/review-aggregator.md" 'write only the requested report artifact' "review aggregator may only persist requested reports"

assert_contains "skills/subagent-driven-development/SKILL.md" 'Codex native agents' "SDD mentions Codex native agents"
assert_contains "skills/subagent-driven-development/SKILL.md" 'spec_reviewer' "SDD references Codex spec reviewer"
assert_contains "skills/subagent-driven-development/SKILL.md" 'code_reviewer' "SDD references Codex code reviewer"
assert_contains "skills/subagent-driven-development/SKILL.md" 'review_aggregator' "SDD references Codex review aggregator"
assert_contains "skills/subagent-driven-development/SKILL.md" 'epic_verifier' "SDD references Codex epic verifier"

assert_contains "skills/ad-hoc-code-review/SKILL.md" 'Codex native agent' "ad-hoc review mentions Codex native agent"
assert_contains "skills/ad-hoc-code-review/SKILL.md" 'code_reviewer' "ad-hoc review references Codex code reviewer"
assert_contains "skills/ad-hoc-code-review/SKILL.md" 'review_aggregator' "ad-hoc review references Codex review aggregator"

echo ""
echo "=== Codex native agent tests passed ==="
