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
  assert_not_contains "$file" '\b(Read|Glob|Task|AskUserQuestion)\b' "$file avoids unqualified Claude-only tool names"
}

assert_agent ".codex/agents/code-reviewer.toml" "code_reviewer"
assert_agent ".codex/agents/epic-verifier.toml" "epic_verifier"
assert_agent ".codex/agents/spec-reviewer.toml" "spec_reviewer"
assert_agent ".codex/agents/review-aggregator.toml" "review_aggregator"

assert_file ".codex/config.toml"
assert_contains ".codex/config.toml" '^\[agents\]$' ".codex/config.toml has agents section"
assert_contains ".codex/config.toml" '^max_parallel_agents = [1-4]$' ".codex/config.toml sets conservative parallel cap"

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
