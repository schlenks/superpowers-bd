#!/usr/bin/env bash
# Integration Test: subagent-driven-development workflow
# Executes a disposable Beads epic and verifies the current workflow behaviors.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Integration Test: subagent-driven-development"
echo "========================================"
echo ""
echo "This test executes a real Beads epic using the skill and verifies:"
echo "  1. A Beads epic is the source of truth"
echo "  2. Claude dispatches through the Agent tool"
echo "  3. Native progress tracking is used"
echo "  4. Spec review runs before code-quality review"
echo "  5. Passing child issues are closed"
echo "  6. The implementation and its tests work"
echo ""
echo "WARNING: This test may take 10-30 minutes to complete."
echo ""

# Create test project
TEST_PROJECT=$(create_test_project)
echo "Test project: $TEST_PROJECT"

# Trap to cleanup
trap 'cleanup_test_project "$TEST_PROJECT"' EXIT

# Set up minimal Node.js project
cd "$TEST_PROJECT"

cat > package.json <<'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF

mkdir -p src test

# Initialize git repo
git init --quiet
git config user.email "test@test.com"
git config user.name "Test User"
git add .
git commit -m "Initial commit" --quiet

# Create an isolated Beads epic. The two child issues own disjoint files so SDD
# can place them in the same wave.
bd init --non-interactive --skip-hooks --skip-agents --setup-exclude --prefix sddtest --quiet
EPIC_ID=$(bd create --silent --type=epic --priority=2 \
    --title="Implement arithmetic helpers" \
    --description="Exercise the current subagent-driven-development workflow against a real Beads epic." \
    --acceptance="Both child issues are reviewed, closed, and verified by npm test.")
ADD_ID=$(bd create --silent --type=task --priority=2 --parent="$EPIC_ID" \
    --title="Implement add helper" \
    --description="Create src/add.js exporting add(a, b). Create test/add.test.js covering positive, zero, and negative operands. Run npm test. Commit only these owned files." \
    --acceptance="add(2,3)=5, add(0,0)=0, and add(-1,1)=0; npm test passes.")
MULTIPLY_ID=$(bd create --silent --type=task --priority=2 --parent="$EPIC_ID" \
    --title="Implement multiply helper" \
    --description="Create src/multiply.js exporting multiply(a, b). Create test/multiply.test.js covering positive, zero, and negative operands. Run npm test. Commit only these owned files. Do not add divide, power, or subtract helpers." \
    --acceptance="multiply(2,3)=6, multiply(0,5)=0, and multiply(-2,3)=-6; npm test passes.")

echo ""
echo "Project setup complete. Starting epic $EPIC_ID..."
echo ""

# Run Claude with subagent-driven-development
# Capture full output to analyze
OUTPUT_FILE="$TEST_PROJECT/claude-output.txt"

# The Claude process starts at the plugin repository so local development skills
# are available. Every project and Beads command must target the isolated
# fixture explicitly.
PROMPT="Execute epic $EPIC_ID using the superpowers-bd:subagent-driven-development skill.

The disposable project root is $TEST_PROJECT. Treat it as the only implementation
workspace. Prefix every Beads command with: bd -C \"$TEST_PROJECT\"
Run each project shell command as: cd \"$TEST_PROJECT\" && <command>
Use absolute paths under $TEST_PROJECT for file operations.

Use the pro/api budget tier. Follow the current Beads self-read workflow: load the
epic and each child issue from Beads, dispatch implementers with Agent, run spec
review before code-quality review, close passing child issues, and verify npm test.
Do not read or create a markdown implementation plan. Do not push. After epic
verification passes, leave the disposable branch as-is and report completion."

echo "Running Claude (output will be shown below and saved to $OUTPUT_FILE)..."
echo "================================================================================"
CLAUDE_STATE_ROOT="${CLAUDE_INTEGRATION_CONFIG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
SESSION_ENV_ROOT="$CLAUDE_STATE_ROOT/session-env"
SESSION_ENV_PROBE="$SESSION_ENV_ROOT/sdd-integration-$$"
if ! mkdir -p "$SESSION_ENV_ROOT" 2>/dev/null ||
    ! mkdir "$SESSION_ENV_PROBE" 2>/dev/null; then
    echo "SKIP: nested Claude cannot write $SESSION_ENV_ROOT"
    echo "Run from a host with a writable authenticated Claude config, or set"
    echo "CLAUDE_INTEGRATION_CONFIG_DIR to an authenticated writable config."
    exit 77
fi
rmdir "$SESSION_ENV_PROBE"

SESSION_ID=$(python3 -c 'import uuid; print(uuid.uuid4())')
set +e
(
    cd "$REPO_ROOT" &&
        if [ -n "${CLAUDE_INTEGRATION_CONFIG_DIR:-}" ]; then
            export CLAUDE_CONFIG_DIR="$CLAUDE_INTEGRATION_CONFIG_DIR"
        fi
        timeout 1800 claude -p "$PROMPT" \
            --allowed-tools=all \
            --add-dir "$TEST_PROJECT" \
            --permission-mode bypassPermissions \
            --plugin-dir "$REPO_ROOT" \
            --session-id "$SESSION_ID"
) 2>&1 | tee "$OUTPUT_FILE"
claude_exit=${PIPESTATUS[0]}
set -e
if [ "$claude_exit" -ne 0 ]; then
    echo ""
    echo "================================================================================"
    echo "EXECUTION FAILED (exit code: $claude_exit)"
    exit 1
fi
echo "================================================================================"

echo ""
echo "Execution complete. Analyzing results..."
echo ""

# Find the session transcript
# Session files are in ~/.claude/projects/-<working-dir>/<session-id>.jsonl
WORKING_DIR_ESCAPED=$(printf '%s' "$REPO_ROOT" | sed 's/\//-/g')
SESSION_DIR="$CLAUDE_STATE_ROOT/projects/$WORKING_DIR_ESCAPED"
SESSION_FILE="$SESSION_DIR/$SESSION_ID.jsonl"

if [ ! -f "$SESSION_FILE" ]; then
    echo "ERROR: Could not find session transcript file"
    echo "Looked for: $SESSION_FILE"
    exit 1
fi

echo "Analyzing session transcript: $(basename "$SESSION_FILE")"
echo ""

# Verification tests
FAILED=0

echo "=== Verification Tests ==="
echo ""

# Test 1: Skill was invoked
echo "Test 1: Skill tool invoked..."
if grep -q '"name":"Skill".*"skill":"superpowers-bd:subagent-driven-development"' "$SESSION_FILE"; then
    echo "  [PASS] subagent-driven-development skill was invoked"
else
    echo "  [FAIL] Skill was not invoked"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2: Subagents were used through the current Agent tool
echo "Test 2: Subagents dispatched..."
agent_count=$(grep -c '"name":"Agent"' "$SESSION_FILE" || true)
if [ "$agent_count" -ge 2 ]; then
    echo "  [PASS] $agent_count Agent dispatches observed"
else
    echo "  [FAIL] Only $agent_count Agent dispatch(es) observed (expected >= 2)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3: Native progress tracking was used
echo "Test 3: Task tracking..."
task_create_count=$(grep -c '"name":"TaskCreate"' "$SESSION_FILE" || true)
task_update_count=$(grep -c '"name":"TaskUpdate"' "$SESSION_FILE" || true)
if [ "$task_create_count" -ge 1 ] && [ "$task_update_count" -ge 1 ]; then
    echo "  [PASS] Native task tools used (TaskCreate: $task_create_count, TaskUpdate: $task_update_count)"
else
    echo "  [FAIL] Expected both TaskCreate and TaskUpdate"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 4: Spec review was dispatched before code-quality review
echo "Test 4: Review ordering..."
spec_review_line=$(grep -n -m 1 '"description":"Spec review:' "$SESSION_FILE" | cut -d: -f1 || true)
code_review_line=$(grep -n -m 1 '"description":"Code review' "$SESSION_FILE" | cut -d: -f1 || true)
if [ -n "$spec_review_line" ] &&
    [ -n "$code_review_line" ] &&
    [ "$spec_review_line" -lt "$code_review_line" ]; then
    echo "  [PASS] Spec review precedes code-quality review"
else
    echo "  [FAIL] Expected a Spec review Agent dispatch before Code review"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: Both Beads child issues were closed
echo "Test 5: Beads issue closure..."
closed_count=$(bd -C "$TEST_PROJECT" list --parent "$EPIC_ID" --status=closed --json |
    python3 -c 'import json, sys; print(len(json.load(sys.stdin)))')
if [ "$closed_count" -eq 2 ]; then
    echo "  [PASS] Both child issues closed"
else
    echo "  [FAIL] $closed_count child issue(s) closed (expected 2: $ADD_ID, $MULTIPLY_ID)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: Implementation actually works
echo "Test 6: Implementation verification..."
if [ -f "$TEST_PROJECT/src/add.js" ] &&
    grep -q "export function add" "$TEST_PROJECT/src/add.js"; then
    echo "  [PASS] add helper exists"
else
    echo "  [FAIL] src/add.js or add export missing"
    FAILED=$((FAILED + 1))
fi

if [ -f "$TEST_PROJECT/src/multiply.js" ] &&
    grep -q "export function multiply" "$TEST_PROJECT/src/multiply.js"; then
    echo "  [PASS] multiply helper exists"
else
    echo "  [FAIL] src/multiply.js or multiply export missing"
    FAILED=$((FAILED + 1))
fi

if [ -f "$TEST_PROJECT/test/add.test.js" ] &&
    [ -f "$TEST_PROJECT/test/multiply.test.js" ]; then
    echo "  [PASS] Both test files exist"
else
    echo "  [FAIL] One or both test files are missing"
    FAILED=$((FAILED + 1))
fi

# Try running tests
if cd "$TEST_PROJECT" && npm test > test-output.txt 2>&1; then
    echo "  [PASS] Tests pass"
else
    echo "  [FAIL] Tests failed"
    cat test-output.txt
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 7: Git commits show proper workflow
echo "Test 7: Git commit history..."
commit_count=$(git -C "$TEST_PROJECT" log --oneline | wc -l)
if [ "$commit_count" -gt 2 ]; then  # Initial + at least 2 task commits
    echo "  [PASS] Multiple commits created ($commit_count total)"
else
    echo "  [FAIL] Too few commits ($commit_count, expected >2)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 8: Check for extra features (spec compliance should catch)
echo "Test 8: No extra features added (spec compliance)..."
if grep -R -q "export function divide\|export function power\|export function subtract" "$TEST_PROJECT/src" 2>/dev/null; then
    echo "  [WARN] Extra features found (spec review should have caught this)"
    # Not failing on this as it tests reviewer effectiveness
else
    echo "  [PASS] No extra features added"
fi
echo ""

# Token Usage Analysis
echo "========================================="
echo " Token Usage Analysis"
echo "========================================="
echo ""
python3 "$SCRIPT_DIR/analyze-token-usage.py" "$SESSION_FILE"
echo ""

# Summary
echo "========================================"
echo " Test Summary"
echo "========================================"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "STATUS: PASSED"
    echo "All verification tests passed!"
    echo ""
    echo "The subagent-driven-development skill correctly:"
    echo "  ✓ Uses a Beads epic as the source of truth"
    echo "  ✓ Dispatches through the Agent tool"
    echo "  ✓ Uses native progress tracking"
    echo "  ✓ Runs spec compliance before code quality"
    echo "  ✓ Closes passing child issues"
    echo "  ✓ Produces working implementation"
    exit 0
else
    echo "STATUS: FAILED"
    echo "Failed $FAILED verification tests"
    echo ""
    echo "Output saved to: $OUTPUT_FILE"
    echo ""
    echo "Review the output to see what went wrong."
    exit 1
fi
