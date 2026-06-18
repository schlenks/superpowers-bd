#!/usr/bin/env bash
# Test: subagent-driven-development skill
# Verifies that the skill is loaded and follows correct workflow
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: subagent-driven-development skill ==="
echo ""

# Test 1: Verify skill can be loaded
echo "Test 1: Skill loading..."

output=$(run_claude "What is the subagent-driven-development skill? Describe its key steps briefly." 30)

if assert_contains "$output" "[Ss]ubagent-driven-development" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Load epic\|bd show\|parse.*children" "Mentions loading beads epic"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify skill describes correct workflow order
echo "Test 2: Workflow ordering..."

output=$(run_claude "In the subagent-driven-development skill, what comes first: spec compliance review or code quality review? Be specific about the order." 30)

if assert_order "$output" "spec.*compliance" "code.*quality" "Spec compliance before code quality"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 3: Verify self-review is mentioned
echo "Test 3: Self-review requirement..."

output=$(run_claude "Does the subagent-driven-development skill require implementers to do self-review? What should they check?" 30)

if assert_contains "$output" "self-review\|self review" "Mentions self-review"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "completeness\|Completeness" "Checks completeness"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify session setup is restored from checkpoint
echo "Test 4: Checkpoint setup recovery..."

output=$(run_claude "In subagent-driven-development, what setup is chosen once and restored from checkpoint instead of being re-asked?" 30)

if assert_contains "$output" "budget tier.*once\|choose.*budget.*once\|chosen once" "Budget tier chosen once"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "checkpoint\|restore\|resume" "Checkpoint restores setup"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify spec compliance reviewer is skeptical
echo "Test 5: Spec compliance reviewer mindset..."

output=$(run_claude "What is the spec compliance reviewer's attitude toward the implementer's report in subagent-driven-development?" 30)

if assert_contains "$output" "not trust\|don't trust\|skeptical\|verify.*independently\|suspiciously" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code" "Reviewer reads code"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify review loops
echo "Test 6: Review loop requirements..."

output=$(run_claude "In subagent-driven-development, what happens if a reviewer finds issues? Is it a one-time review or a loop?" 30)

if assert_contains "$output" "loop\|again\|repeat\|until.*approved\|until.*compliant" "Review loops mentioned"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "implementer.*fix\|fix.*issues" "Implementer fixes issues"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify implementer self-read context
echo "Test 7: Task context provision..."

output=$(run_claude "In subagent-driven-development, how does the implementer subagent load task context? What does the controller provide?" 30)

if assert_contains "$output" "bd show\|self-read\|load.*context" "Implementer self-reads beads context"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "issue_id\|epic_id\|file ownership\|owned files" "Controller provides routing and ownership context"; then
    : # pass
else
    exit 1
fi

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
