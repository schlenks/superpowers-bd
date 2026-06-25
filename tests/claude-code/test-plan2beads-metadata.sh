#!/usr/bin/env bash
# Test: plan2beads preserves optional plan metadata through markdown -> beads import.
#
# Round-trip intent (what a live import MUST achieve):
#   - A `## Global Constraints` block in the plan appears in EVERY child task body.
#   - A per-task `**Interfaces:**` line (Consumes/Produces) appears in THAT task's body.
#   - A plan with NEITHER section imports exactly as before (backward-compatible).
#
# This file is statically runnable in the harness: it asserts the fixture carries the
# new sections and that BOTH parser surfaces (Claude command + Codex reference) document
# recognizing and propagating them. The actual live `plan2beads` import (which needs a
# real Claude session) is GUARDED behind RUN_LIVE_IMPORT=1 and is driven by the
# orchestrator, not spawned here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE="tests/claude-code/fixtures/plan-constraints-interfaces.md"
CLAUDE_PARSER="commands/plan2beads.md"
CODEX_PARSER="skills/plan2beads/references/codex-plan2beads-flow.md"
PLAN2BEADS_SKILL="skills/plan2beads/SKILL.md"
WRITING_PLANS_SKILL="skills/writing-plans/SKILL.md"

echo "=== Test: plan2beads metadata round-trip ==="

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

# --- Fixture carries both optional sections ---
assert_file "$FIXTURE"
assert_contains "$FIXTURE" "^## Global Constraints$" "fixture has a Global Constraints block"
assert_contains "$FIXTURE" "\*\*Interfaces:\*\*" "fixture has a per-task Interfaces line"
assert_contains "$FIXTURE" "Consumes:" "fixture Interfaces declares Consumes"
assert_contains "$FIXTURE" "Produces:" "fixture Interfaces declares Produces"

# --- Claude parser documents recognition + propagation (round-trip contract) ---
assert_file "$CLAUDE_PARSER"
assert_contains "$CLAUDE_PARSER" "## Global Constraints" "Claude parser recognizes Global Constraints"
assert_contains "$CLAUDE_PARSER" "every child task body" "Claude parser threads Global Constraints into every child task body"
assert_contains "$CLAUDE_PARSER" "\*\*Interfaces:\*\*" "Claude parser recognizes per-task Interfaces"
assert_contains "$CLAUDE_PARSER" "Consumes" "Claude parser preserves Interfaces Consumes"
assert_contains "$CLAUDE_PARSER" "Produces" "Claude parser preserves Interfaces Produces"
assert_contains "$CLAUDE_PARSER" "OPTIONAL" "Claude parser marks the new sections optional (backward-compatible)"
assert_contains "$CLAUDE_PARSER" "identically to prior behavior" "Claude parser guarantees section-less plans import unchanged"

# --- Codex parser documents the SAME contract (both surfaces agree) ---
assert_file "$CODEX_PARSER"
assert_contains "$CODEX_PARSER" "## Global Constraints" "Codex parser recognizes Global Constraints"
assert_contains "$CODEX_PARSER" "every child" "Codex parser threads Global Constraints into every child"
assert_contains "$CODEX_PARSER" "Interfaces" "Codex parser recognizes per-task Interfaces"
assert_contains "$CODEX_PARSER" "Consumes" "Codex parser preserves Interfaces Consumes"
assert_contains "$CODEX_PARSER" "Produces" "Codex parser preserves Interfaces Produces"
assert_contains "$CODEX_PARSER" "backward-compatible" "Codex parser marks the new sections backward-compatible"

# --- Shared rules + header contract document preservation ---
assert_contains "$PLAN2BEADS_SKILL" "Global Constraints" "plan2beads shared rules note Global Constraints preservation"
assert_contains "$PLAN2BEADS_SKILL" "Interfaces" "plan2beads shared rules note Interfaces preservation"
assert_contains "$WRITING_PLANS_SKILL" "## Global Constraints" "writing-plans header contract documents Global Constraints"
assert_contains "$WRITING_PLANS_SKILL" "\*\*Interfaces:\*\*" "writing-plans header contract documents Interfaces"

# --- GUARDED: live import round-trip (orchestrator-driven, not spawned here) ---
if [ "${RUN_LIVE_IMPORT:-0}" = "1" ]; then
  echo "  [LIVE] RUN_LIVE_IMPORT=1 — performing live plan2beads import round-trip..."
  : "${LIVE_EPIC_ID:?Set LIVE_EPIC_ID to the epic created by the live plan2beads import}"
  # After the orchestrator runs `/superpowers-bd:plan2beads $FIXTURE`, every child body
  # must contain the Global Constraints text, and each task body must carry its Interfaces.
  child_ids="$(bd show "$LIVE_EPIC_ID" --json | grep -Eo '"id":[[:space:]]*"[^"]+"' | grep -Eo '"[^"]+"$' | tr -d '"')"
  [ -n "$child_ids" ] || fail "live import produced no child issues for $LIVE_EPIC_ID"
  for cid in $child_ids; do
    body="$(bd show "$cid")"
    echo "$body" | grep -q "No new runtime dependencies" || fail "child $cid missing threaded Global Constraints text"
  done
  pass "live import threaded Global Constraints into every child body"
else
  echo "  [SKIP] live plan2beads import round-trip (set RUN_LIVE_IMPORT=1; orchestrator drives this)"
fi

echo ""
echo "=== plan2beads metadata tests passed ==="
