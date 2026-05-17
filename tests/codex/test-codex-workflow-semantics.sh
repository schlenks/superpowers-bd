#!/usr/bin/env bash
# Test: Codex-native workflow entry docs avoid Claude command translation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== Test: Codex Workflow Semantics ==="

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

assert_same_file() {
  local left="$1"
  local right="$2"
  local message="$3"
  if cmp -s "$left" "$right"; then
    pass "$message"
  else
    fail "$message"
  fi
}

assert_reference_path_resolves() {
  local source_file="$1"
  local relative_path="$2"
  local message="$3"
  local resolved
  resolved="$(cd "$(dirname "$source_file")" && pwd)/$relative_path"
  if [ -f "$resolved" ]; then
    pass "$message"
  else
    fail "$message"
  fi
}

assert_codex_reference_clean() {
  local file="$1"
  assert_file "$file"
  assert_contains "$file" "Codex" "$file is explicitly Codex-native"
  assert_not_contains "$file" "AskUserQuestion|Task:|TaskCreate|ExitPlanMode|subagent_type|Claude .* maps" "$file avoids Claude-only tool translation"
}

codex_refs=(
  "skills/writing-plans/references/codex-plan-verification.md"
  "skills/executing-plans/references/codex-execution-checkpoints.md"
  "skills/plan2beads/references/codex-plan2beads-flow.md"
  "skills/ad-hoc-code-review/references/codex-review-flow.md"
)

for ref in "${codex_refs[@]}"; do
  assert_codex_reference_clean "$ref"
  assert_file "plugins/superpowers-bd/$ref"
  assert_same_file "$ref" "plugins/superpowers-bd/$ref" "plugin wrapper mirrors $ref"
done

assert_contains "skills/writing-plans/SKILL.md" "codex-plan-verification.md" "writing-plans links Codex verification reference"
assert_contains "skills/executing-plans/SKILL.md" "codex-execution-checkpoints.md" "executing-plans links Codex checkpoint reference"
assert_contains "skills/plan2beads/SKILL.md" "codex-plan2beads-flow.md" "plan2beads links Codex flow reference"
assert_contains "skills/ad-hoc-code-review/SKILL.md" "codex-review-flow.md" "ad-hoc-code-review links Codex review reference"

assert_not_contains "skills/plan2beads/SKILL.md" "Codex: invoke this skill.*read ../../commands" "plan2beads does not route Codex through Claude command docs"
assert_not_contains "skills/ad-hoc-code-review/SKILL.md" "Codex: invoke this skill.*read ../../commands" "ad-hoc-code-review does not route Codex through Claude command docs"
assert_not_contains "skills/plan2beads/SKILL.md" "AskUserQuestion|Task:|TaskCreate|ExitPlanMode|subagent_type|Claude .* maps" "plan2beads skill avoids Claude translation mappings"
assert_not_contains "skills/ad-hoc-code-review/SKILL.md" "AskUserQuestion|Task:|TaskCreate|ExitPlanMode|subagent_type|Claude .* maps" "ad-hoc-code-review skill avoids Claude translation mappings"

assert_contains "skills/ad-hoc-code-review/SKILL.md" "../requesting-code-review/code-reviewer.md" "ad-hoc review keeps shared review standard"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../requesting-code-review/code-reviewer.md" "Codex ad-hoc reference points to shared review standard"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../multi-review-aggregation/aggregator-prompt.md" "Codex ad-hoc reference points to shared aggregation standard"
assert_reference_path_resolves "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../requesting-code-review/code-reviewer.md" "Codex ad-hoc review standard path resolves"
assert_reference_path_resolves "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../multi-review-aggregation/aggregator-prompt.md" "Codex ad-hoc aggregation path resolves"
assert_contains "commands/cr.md" "Claude Code command implementation" "cr command declares Claude command ownership"
assert_contains "commands/cr.md" "Codex.*ad-hoc-code-review" "cr command points Codex users to native skill flow"

echo ""
echo "=== Codex workflow semantics tests passed ==="
