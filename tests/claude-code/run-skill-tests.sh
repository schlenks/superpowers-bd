#!/usr/bin/env bash
# Test runner for Claude Code skills
# Runs fast structural skill tests and optional Claude Code integration tests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo " Claude Code Skills Test Suite"
echo "========================================"
echo ""
echo "Repository: $(cd ../.. && pwd)"
echo "Test time: $(date)"
echo ""

# Parse command line arguments
VERBOSE=false
SPECIFIC_TEST=""
TIMEOUT_OVERRIDE=""
FAST_TEST_TIMEOUT=300
INTEGRATION_TEST_TIMEOUT=1860  # 30 minutes for Claude plus 1 minute for teardown
RUN_INTEGRATION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --test|-t)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_OVERRIDE="$2"
            shift 2
            ;;
        --integration|-i)
            RUN_INTEGRATION=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v        Show verbose output"
            echo "  --test, -t NAME      Run only the specified test"
            echo "  --timeout SECONDS    Override the timeout for every selected test"
            echo "  --integration, -i    Run integration tests (slow, 10-30 min)"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Tests:"
            echo "  test-subagent-driven-development.sh  Test skill loading and requirements"
            echo "  test-reviewer-prompt-parity.sh       Verify agent/template prompt match"
            echo "  ../verification/test-workflow-contract-audit.sh  Verify cross-surface workflow contracts"
            echo ""
            echo "Integration Tests (use --integration):"
            echo "  test-subagent-driven-development-integration.sh  Full workflow execution"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# List of skill tests to run (fast unit tests)
tests=(
    "test-subagent-driven-development.sh"
    "test-reviewer-prompt-parity.sh"
    "../verification/test-workflow-contract-audit.sh"
)

# Integration tests (slow, full execution)
integration_tests=(
    "test-subagent-driven-development-integration.sh"
)

# Add integration tests if requested
if [ "$RUN_INTEGRATION" = true ]; then
    tests+=("${integration_tests[@]}")
fi

# Filter to specific test if requested
if [ -n "$SPECIFIC_TEST" ]; then
    tests=("$SPECIFIC_TEST")
fi

requires_claude=false
for test in "${tests[@]}"; do
    case "$test" in
        *integration*)
            requires_claude=true
            ;;
    esac
done

if [ "$requires_claude" = true ]; then
    claude_path="$(command -v claude || true)"
    if [ -z "$claude_path" ]; then
        echo "ERROR: Claude Code CLI not found"
        echo "Install Claude Code first: https://code.claude.com"
        exit 1
    fi
    echo "Claude version: $(claude --version)"
else
    echo "Claude CLI: not required for structural tests"
fi
echo ""

# Track results
passed=0
failed=0
skipped=0

# Run each test
for test in "${tests[@]}"; do
    echo "----------------------------------------"
    echo "Running: $test"
    echo "----------------------------------------"

    test_path="$SCRIPT_DIR/$test"

    if [ ! -f "$test_path" ]; then
        echo "  [FAIL] Required test file not found: $test"
        failed=$((failed + 1))
        echo ""
        continue
    fi

    if [ ! -x "$test_path" ]; then
        echo "  Making $test executable..."
        chmod +x "$test_path"
    fi

    start_time=$(date +%s)
    test_timeout="$FAST_TEST_TIMEOUT"
    case "$test" in
        *integration*)
            test_timeout="$INTEGRATION_TEST_TIMEOUT"
            ;;
    esac
    if [ -n "$TIMEOUT_OVERRIDE" ]; then
        test_timeout="$TIMEOUT_OVERRIDE"
    fi

    if [ "$VERBOSE" = true ]; then
        if timeout "$test_timeout" bash "$test_path"; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            echo ""
            echo "  [PASS] $test (${duration}s)"
            passed=$((passed + 1))
        else
            exit_code=$?
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            echo ""
            if [ $exit_code -eq 77 ]; then
                echo "  [SKIP] $test (environment prerequisite unavailable)"
                skipped=$((skipped + 1))
            elif [ $exit_code -eq 124 ]; then
                echo "  [FAIL] $test (timeout after ${test_timeout}s)"
                failed=$((failed + 1))
            else
                echo "  [FAIL] $test (${duration}s)"
                failed=$((failed + 1))
            fi
        fi
    else
        # Capture output for non-verbose mode
        if output=$(timeout "$test_timeout" bash "$test_path" 2>&1); then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            echo "  [PASS] (${duration}s)"
            passed=$((passed + 1))
        else
            exit_code=$?
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            if [ $exit_code -eq 77 ]; then
                echo "  [SKIP] (environment prerequisite unavailable)"
                skipped=$((skipped + 1))
            elif [ $exit_code -eq 124 ]; then
                echo "  [FAIL] (timeout after ${test_timeout}s)"
                failed=$((failed + 1))
            else
                echo "  [FAIL] (${duration}s)"
                failed=$((failed + 1))
            fi
            if [ -n "$output" ]; then
                echo ""
                echo "  Output:"
                indented_output="    ${output//$'\n'/$'\n'    }"
                printf '%s\n' "$indented_output"
            fi
        fi
    fi

    echo ""
done

# Print summary
echo "========================================"
echo " Test Results Summary"
echo "========================================"
echo ""
echo "  Passed:  $passed"
echo "  Failed:  $failed"
echo "  Skipped: $skipped"
echo ""

if [ "$RUN_INTEGRATION" = false ] &&
    [ "$requires_claude" = false ] &&
    [ ${#integration_tests[@]} -gt 0 ]; then
    echo "Note: Integration tests were not run (they take 10-30 minutes)."
    echo "Use --integration flag to run full workflow execution tests."
    echo ""
fi

if [ $failed -gt 0 ]; then
    echo "STATUS: FAILED"
    exit 1
elif [ $skipped -gt 0 ]; then
    echo "STATUS: PASSED WITH SKIPS"
    exit 0
else
    echo "STATUS: PASSED"
    exit 0
fi
