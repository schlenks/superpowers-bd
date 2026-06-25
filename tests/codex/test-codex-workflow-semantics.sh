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
  if grep -Eq -- "$pattern" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -Eq -- "$pattern" "$file"; then
    fail "$message"
  else
    pass "$message"
  fi
}

assert_not_contains_i() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -Eiq -- "$pattern" "$file"; then
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

assert_section() {
  local file="$1"
  local heading="$2"
  assert_contains "$file" "^## $heading$" "$file has $heading section"
}

assert_codex_reference_clean() {
  local file="$1"
  assert_file "$file"
  assert_contains "$file" "Codex" "$file is explicitly Codex-native"
  assert_not_contains "$file" "AskUserQuestion|Task:|TaskCreate|ExitPlanMode|subagent_type" "$file avoids Claude-only tool names"
  assert_not_contains_i "$file" "Claude .* maps|tool mapping|translation table" "$file avoids Claude-only tool translation framing"
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
assert_not_contains "skills/writing-plans/SKILL.md" "For Claude:" "writing-plans header is platform-neutral"
assert_not_contains "skills/writing-plans/references/codex-plan-verification.md" "For Claude|/superpowers-bd:" "Codex plan guidance avoids Claude-only handoff text"

assert_section "skills/subagent-driven-development/SKILL.md" "Quick Start: Shared Workflow"
assert_section "skills/subagent-driven-development/SKILL.md" "Claude Code Dispatch Path"
assert_section "skills/subagent-driven-development/SKILL.md" "Codex Dispatch Path"
assert_section "skills/subagent-driven-development/SKILL.md" "Checkpoint Platform Fields"
assert_section "skills/subagent-driven-development/SKILL.md" "Review Rules"
assert_section "skills/subagent-driven-development/SKILL.md" "Guardrails"
assert_section "skills/subagent-driven-development/SKILL.md" "State Machine"
assert_contains "skills/subagent-driven-development/SKILL.md" '"platform": "codex"' "SDD checkpoint schema records native platform"
assert_contains "skills/subagent-driven-development/SKILL.md" '"spec_review": "spawn_agent agent=spec_reviewer"' "SDD checkpoint names Codex spec reviewer dispatch"
assert_contains "skills/subagent-driven-development/SKILL.md" '"code_review": "spawn_agent agent=code_reviewer"' "SDD checkpoint names Codex code reviewer dispatch"
assert_contains "skills/subagent-driven-development/SKILL.md" '"review_aggregation": "spawn_agent agent=review_aggregator when N > 1"' "SDD checkpoint names Codex aggregation dispatch"
assert_contains "skills/subagent-driven-development/SKILL.md" '"epic_verification": "spawn_agent agent=epic_verifier"' "SDD checkpoint names Codex verifier dispatch"
assert_contains "skills/subagent-driven-development/SKILL.md" 'native Codex sessions do not run a separate Codex cross-model advisory review' "SDD separates native Codex from Claude advisory review"
assert_contains "skills/subagent-driven-development/SKILL.md" "inherit the active Codex model" "SDD documents Codex active model inheritance"
assert_contains "skills/subagent-driven-development/SKILL.md" "request_user_input" "SDD names Codex structured question primitive"
assert_not_contains "skills/subagent-driven-development/SKILL.md" "codex_model_profile|gpt-5\\.3-codex|resolve_codex_model" "SDD avoids deprecated Codex model profile routing"
assert_section "skills/subagent-driven-development/background-execution.md" "Codex Verdict Validation"
assert_contains "skills/subagent-driven-development/background-execution.md" "missing or malformed .*VERDICT" "SDD documents missing/malformed Codex verdict handling"
assert_contains "skills/subagent-driven-development/background-execution.md" "re-dispatch.*same prompt" "SDD documents Codex verdict retry path"
assert_contains "skills/subagent-driven-development/background-execution.md" "SubagentStop hook" "SDD documents Codex SubagentStop hook support"
assert_not_contains "skills/subagent-driven-development/background-execution.md" "Codex has no SubagentStop hook|codex_model_profile|resolve_codex_model|gpt-5\\.3-codex" "SDD background reference avoids stale Codex hook/model assumptions"
assert_same_file "skills/subagent-driven-development/background-execution.md" "plugins/superpowers-bd/skills/subagent-driven-development/background-execution.md" "plugin wrapper mirrors SDD background execution reference"
assert_not_contains "skills/subagent-driven-development/budget-and-wave-cap.md" "codex_model_profile|gpt-5\\.3-codex|resolve_codex_model" "SDD budget reference avoids deprecated Codex model profile routing"
assert_not_contains "skills/subagent-driven-development/dispatch-and-conflict.md" "codex_model_profile|resolve_codex_model|gpt-5\\.3-codex" "SDD dispatch reference avoids deprecated Codex model profile routing"
assert_not_contains "skills/subagent-driven-development/failure-recovery.md" "codex_model_profile|resolve_codex_model|gpt-5\\.3-codex" "SDD recovery reference avoids deprecated Codex model profile routing"
assert_not_contains "skills/subagent-driven-development/implementer-prompt.md" "codex_model_profile|gpt-5\\.3-codex" "SDD implementer prompt avoids deprecated Codex model profile routing"
assert_contains "skills/brainstorming/SKILL.md" "request_user_input" "brainstorming uses Codex structured question primitive when available"

assert_not_contains "skills/plan2beads/SKILL.md" "Codex: invoke this skill.*read ../../commands" "plan2beads does not route Codex through Claude command docs"
assert_not_contains "skills/ad-hoc-code-review/SKILL.md" "Codex: invoke this skill.*read ../../commands" "ad-hoc-code-review does not route Codex through Claude command docs"
assert_not_contains "skills/plan2beads/SKILL.md" "AskUserQuestion|Task:|TaskCreate|ExitPlanMode|subagent_type|Claude .* maps" "plan2beads skill avoids Claude translation mappings"
assert_not_contains "skills/ad-hoc-code-review/SKILL.md" "AskUserQuestion|Task:|TaskCreate|ExitPlanMode|subagent_type|Claude .* maps" "ad-hoc-code-review skill avoids Claude translation mappings"
assert_contains "skills/plan2beads/SKILL.md" "unless the user explicitly asks for conversion-only" "plan2beads preserves mandatory execution handoff"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "SC-1234" "Codex plan2beads supports Shortcut-style IDs"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "short story <numeric-id> -f=markdown" "Codex plan2beads documents Shortcut fetch command"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "--external-ref \"sc-<id>\"" "Codex plan2beads preserves Shortcut external ref"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "completion:commit-only" "Codex plan2beads documents completion labels"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "bd ready is global" "Codex plan2beads documents global bd ready scoping"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "child IDs" "Codex plan2beads filters ready/blocked by epic child IDs"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "unless the user explicitly asked for conversion-only" "Codex plan2beads proceeds to execution by default"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "## Global Constraints" "Codex plan2beads parses the optional Global Constraints block"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "every child" "Codex plan2beads propagates Global Constraints into every child task"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "\\*\\*Interfaces:\\*\\*" "Codex plan2beads parses per-task Interfaces"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "Consumes" "Codex plan2beads preserves Interfaces Consumes"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "Produces" "Codex plan2beads preserves Interfaces Produces"
assert_contains "skills/plan2beads/references/codex-plan2beads-flow.md" "backward-compatible" "Codex plan2beads keeps the new sections backward-compatible"
assert_contains "skills/executing-plans/references/codex-execution-checkpoints.md" "bd ready is global" "Codex executing-plans documents global bd ready scoping"
assert_contains "skills/executing-plans/references/codex-execution-checkpoints.md" "child IDs" "Codex executing-plans filters ready/blocked by epic child IDs"
assert_contains "skills/executing-plans/references/codex-execution-checkpoints.md" "wait for user feedback" "Codex executing-plans preserves feedback checkpoint"
assert_not_contains "skills/executing-plans/references/codex-execution-checkpoints.md" "autonomous execution" "Codex executing-plans does not bypass feedback checkpoints"

assert_contains "skills/ad-hoc-code-review/SKILL.md" "../requesting-code-review/code-reviewer.md" "ad-hoc review keeps shared review standard"
assert_section "skills/ad-hoc-code-review/references/codex-review-flow.md" "Native Flow"
assert_section "skills/ad-hoc-code-review/references/codex-review-flow.md" "Scope Resolution"
assert_section "skills/ad-hoc-code-review/references/codex-review-flow.md" "Reviewer Standard"
assert_section "skills/ad-hoc-code-review/references/codex-review-flow.md" "Output Rules"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../requesting-code-review/code-reviewer.md" "Codex ad-hoc reference points to shared review standard"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../multi-review-aggregation/aggregator-prompt.md" "Codex ad-hoc reference points to shared aggregation standard"
assert_reference_path_resolves "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../requesting-code-review/code-reviewer.md" "Codex ad-hoc review standard path resolves"
assert_reference_path_resolves "skills/ad-hoc-code-review/references/codex-review-flow.md" "../../multi-review-aggregation/aggregator-prompt.md" "Codex ad-hoc aggregation path resolves"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "follow .*code-reviewer\\.md.*exactly" "Codex ad-hoc fallback follows shared report structure"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "final human presentation" "Codex ad-hoc findings-first applies only to final presentation"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "Do not edit code during this workflow" "Codex ad-hoc review flow is read-only"
assert_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "Present findings and stop" "Codex ad-hoc review stops after findings"
assert_not_contains "skills/ad-hoc-code-review/references/codex-review-flow.md" "Claude reviewer|Claude Code reviewer|Claude-only reviewer|Task tool|subagent_type" "Codex ad-hoc review has no stray Claude reviewer wording"
assert_contains "commands/cr.md" "Claude Code command implementation" "cr command declares Claude command ownership"
assert_contains "commands/cr.md" "Codex.*ad-hoc-code-review" "cr command points Codex users to native skill flow"

echo ""
echo "=== Codex workflow semantics tests passed ==="
