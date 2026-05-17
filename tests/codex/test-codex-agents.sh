#!/usr/bin/env bash
# Test: Codex-native agent definitions and routing docs
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

assert_agent_roles() {
  python3 - <<'PY'
import pathlib
import sys
import tomllib

required = {
    "code_reviewer": "code-reviewer.toml",
    "epic_verifier": "epic-verifier.toml",
    "spec_reviewer": "spec-reviewer.toml",
    "review_aggregator": "review-aggregator.toml",
}

agent_dir = pathlib.Path(".codex/agents")
found = {}
for path in agent_dir.glob("*.toml"):
    data = tomllib.loads(path.read_text())
    found[data.get("name")] = path.name

if found != required:
    print(f"expected Codex agent roles {required}, found {found}", file=sys.stderr)
    sys.exit(1)
PY
  pass "Codex native agent roles are explicit and complete"
}

assert_toml_parses() {
  python3 - <<'PY'
import pathlib
import tomllib

for path in pathlib.Path(".codex/agents").glob("*.toml"):
    tomllib.loads(path.read_text())
tomllib.loads(pathlib.Path(".codex/config.toml").read_text())
PY
  pass "Codex agent TOML and config parse"
}

assert_agent_required_fields() {
  python3 - <<'PY'
import pathlib
import sys
import tomllib

required_fields = {
    "name",
    "description",
    "model",
    "model_reasoning_effort",
    "sandbox_mode",
    "developer_instructions",
}
expected_effort = {
    "code_reviewer": "high",
    "epic_verifier": "xhigh",
    "spec_reviewer": "high",
    "review_aggregator": "medium",
}

for path in pathlib.Path(".codex/agents").glob("*.toml"):
    data = tomllib.loads(path.read_text())
    missing = sorted(required_fields - data.keys())
    if missing:
        print(f"{path}: missing fields {missing}", file=sys.stderr)
        sys.exit(1)
    name = data["name"]
    if data["model"] != "gpt-5.3-codex":
        print(f"{path}: unexpected model {data['model']!r}", file=sys.stderr)
        sys.exit(1)
    if data["model_reasoning_effort"] != expected_effort.get(name):
        print(f"{path}: unexpected reasoning effort", file=sys.stderr)
        sys.exit(1)
    if data["sandbox_mode"] != "workspace-write":
        print(f"{path}: unexpected sandbox mode", file=sys.stderr)
        sys.exit(1)
PY
  pass "Codex agents carry required TOML fields and role-specific effort"
}

assert_no_claude_tool_names() {
  local claude_tool_pattern='\b(Read|Glob|Task|AskUserQuestion|TaskCreate|TaskUpdate|TaskList|TaskGet|TodoWrite|Write|Edit|MultiEdit|NotebookEdit|ExitPlanMode|subagent_type|run_in_background|CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR)\b'
  local file
  for file in .codex/agents/*.toml; do
    assert_not_contains "$file" "$claude_tool_pattern" "$file avoids Claude-only tool names and variables"
  done
}

assert_agent() {
  local file="$1"
  local name="$2"

  assert_file "$file"
  assert_contains "$file" "^name = \"$name\"$" "$file declares name $name"
  assert_contains "$file" '^description = ".+"$' "$file has description"
  assert_contains "$file" '^model = ".+"$' "$file has model"
  assert_contains "$file" '^model_reasoning_effort = "(low|medium|high|xhigh)"$' "$file has reasoning effort"
  assert_contains "$file" '^sandbox_mode = "workspace-write"$' "$file uses workspace-write sandbox"
  assert_contains "$file" '^developer_instructions = """$' "$file has multiline developer instructions"
}

assert_agent ".codex/agents/code-reviewer.toml" "code_reviewer"
assert_agent ".codex/agents/epic-verifier.toml" "epic_verifier"
assert_agent ".codex/agents/spec-reviewer.toml" "spec_reviewer"
assert_agent ".codex/agents/review-aggregator.toml" "review_aggregator"
assert_toml_parses
assert_agent_roles
assert_agent_required_fields
assert_no_claude_tool_names

assert_file ".codex/config.toml"
assert_contains ".codex/config.toml" '^\[agents\]$' ".codex/config.toml has agents section"
assert_contains ".codex/config.toml" '^max_threads = [1-4]$' ".codex/config.toml sets conservative thread cap"
assert_contains ".codex/config.toml" '^max_depth = 1$' ".codex/config.toml limits agent depth"

assert_contains ".codex/agents/code-reviewer.toml" 'Precision Gate' "code reviewer preserves precision gate"
assert_contains ".codex/agents/code-reviewer.toml" 'Changed Files Manifest' "code reviewer requires changed files manifest"
assert_contains ".codex/agents/code-reviewer.toml" 'Requirement Mapping' "code reviewer requires requirement mapping"
assert_contains ".codex/agents/code-reviewer.toml" 'Uncovered Paths' "code reviewer requires uncovered paths"
assert_contains ".codex/agents/code-reviewer.toml" 'Not Checked' "code reviewer requires not checked section"
assert_contains ".codex/agents/code-reviewer.toml" 'stale references' "code reviewer checks stale references"
assert_contains ".codex/agents/code-reviewer.toml" 'Rules Consulted' "code reviewer records repo policy rules"
assert_contains ".codex/agents/code-reviewer.toml" 'Do not modify implementation files' "code reviewer remains read-only for implementation files"
assert_contains ".codex/agents/code-reviewer.toml" 'write only the requested report artifact' "code reviewer may only persist requested reports"
assert_contains ".codex/agents/epic-verifier.toml" 'rule-of-five' "epic verifier requires rule-of-five"
assert_contains ".codex/agents/epic-verifier.toml" 'PASS or FAIL' "epic verifier uses pass fail verdict"
assert_contains ".codex/agents/epic-verifier.toml" 'Do not fix issues' "epic verifier remains read-only"
assert_contains ".codex/agents/spec-reviewer.toml" 'Do not modify implementation files' "spec reviewer remains read-only for implementation files"
assert_contains ".codex/agents/spec-reviewer.toml" 'write only the requested report artifact' "spec reviewer may only persist requested reports"
assert_contains ".codex/agents/review-aggregator.toml" 'provenance' "review aggregator preserves provenance"
assert_contains ".codex/agents/review-aggregator.toml" 'Do not invent findings' "review aggregator does not invent findings"
assert_contains ".codex/agents/review-aggregator.toml" 'write only the requested report artifact' "review aggregator may only persist requested reports"

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
