#!/usr/bin/env bash
# Test: subagent-driven-development skill
#
# Structural contract test: verifies the skill SOURCE documents its key workflow
# properties. Deterministic and fast — it greps the skill's own markdown rather
# than probing a live model.
#
# History: this file used to ask a live `claude -p` a question per property and
# grep the free-text answer. That was flaky (assert_order on "spec compliance" vs
# "code quality" positions — superpowers_bd-ei5/ajn) and, once the ordering probe
# was fixed, the six sequential model calls blew past the runner's 300s per-file
# timeout. The model always answered these correctly; the flakiness was pure
# phrasing/latency variance that added no signal over checking the skill content
# the answers are derived from. Behavioral skill-invocation is covered by the
# skill-triggering/ and explicit-skill-requests/ suites.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

skill_dir="$SCRIPT_DIR/../../skills/subagent-driven-development"
skill_file="$skill_dir/SKILL.md"

# Assert that some markdown file in the skill documents a property. Greps the
# files directly (extended regex, recursive) — no huge concatenated variable.
assert_skill_tree_documents() {
    local pattern="$1"
    local name="$2"
    if grep -rqE "$pattern" --include='*.md' "$skill_dir"; then
        echo "  [PASS] $name"
    else
        echo "  [FAIL] $name"
        echo "  Expected the skill source to match: $pattern"
        exit 1
    fi
}

echo "=== Test: subagent-driven-development skill ==="
echo ""

# Test 1: Skill is defined and documents loading a beads epic
echo "Test 1: Skill definition..."

if grep -qE "name:[[:space:]]*subagent-driven-development" "$skill_file"; then
    echo "  [PASS] Skill is defined with name"
else
    echo "  [FAIL] Skill is defined with name"
    exit 1
fi

assert_skill_tree_documents "bd show.*epic|[Ll]oad.*epic|epic goal" "Skill tree documents loading beads epic"

echo ""

# Test 2: Skill documents correct workflow order (spec review before code review)
echo "Test 2: Workflow ordering..."

assert_skill_tree_documents "[Ss]pec review.*before.*code|[Cc]ode.*review.*after.*spec|[Ss]pec.*review.*then.*code" "Skill tree documents spec review before code review"

echo ""

# Test 3: Skill mandates implementer self-review, including completeness
echo "Test 3: Self-review requirement..."

assert_skill_tree_documents "[Ss]elf-[Rr]eview" "Skill tree mentions self-review"
assert_skill_tree_documents "[Cc]omplete|requirement|[Ee]dge case" "Skill tree checks completeness"

echo ""

# Test 4: Budget tier is stored once and restored from checkpoint (not re-asked)
echo "Test 4: Checkpoint setup recovery..."

assert_skill_tree_documents "budget[_ ]tier" "Skill tree tracks the budget tier"
assert_skill_tree_documents "[Ss]kip budget tier|already stored or restored|checkpoint|[Rr]estore|resume" "Skill tree restores setup instead of re-asking"

echo ""

# Test 5: Spec reviewer is skeptical and verifies by reading code
echo "Test 5: Spec compliance reviewer mindset..."

assert_skill_tree_documents "[Dd]o [Nn]ot [Tt]rust|not trust|skeptical|suspiciously" "Skill tree requires reviewer skepticism"
assert_skill_tree_documents "read.*code|reading code|against code|inspect.*code|verify.*code" "Skill tree requires reading code"

echo ""

# Test 6: Review is a loop — implementer fixes, reviewers re-check
echo "Test 6: Review loop requirements..."

assert_skill_tree_documents "loop|[Rr]ejection [Ll]oop|re-check|re-dispatch" "Skill tree documents review loops"
assert_skill_tree_documents "implementer fixes|fix.*issue|redispatch|re-dispatch" "Skill tree documents implementer fixes"

echo ""

# Test 7: Implementer self-reads beads context; controller supplies routing + ownership
echo "Test 7: Task context provision..."

assert_skill_tree_documents "Load Your Context|bd show" "Skill tree documents implementer context loading"
assert_skill_tree_documents "file_ownership|owned files|issue_id|epic_id" "Skill tree documents routing and ownership context"

echo ""

# Test 8: Wave orchestration is discoverable from the main skill and owns the flag lifecycle
echo "Test 8: Wave flag lifecycle..."

if grep -q "wave-orchestration.md" "$skill_file"; then
    echo "  [PASS] Main skill links wave orchestration"
else
    echo "  [FAIL] Main skill links wave orchestration"
    exit 1
fi

assert_skill_tree_documents "sdd-wave-active-.*\\.flag" "Skill tree documents the active-wave flag"
assert_skill_tree_documents "remove.*flag|rm.*sdd-wave-active|cleanup.*flag" "Skill tree documents flag cleanup"

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
