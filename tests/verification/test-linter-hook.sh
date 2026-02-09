#!/usr/bin/env bash
# Unit tests for hooks/run-linter.sh
# Pipes JSON directly to the hook script — no Claude Code session needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../../hooks/run-linter.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0
fail=0

run_test() {
  local name="$1"
  local input="$2"
  local expected_exit="$3"
  local expected_stderr_pattern="${4:-}"

  local stderr_file="$TEST_DIR/stderr"
  local actual_exit=0
  echo "$input" | "$HOOK" 2>"$stderr_file" || actual_exit=$?

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
    if [[ -s "$stderr_file" ]]; then
      echo "  stderr: $(cat "$stderr_file")"
    fi
    fail=$((fail + 1))
    return
  fi

  if [[ -n "$expected_stderr_pattern" ]]; then
    if ! grep -q "$expected_stderr_pattern" "$stderr_file" 2>/dev/null; then
      echo "FAIL: $name — stderr missing pattern: $expected_stderr_pattern"
      echo "  stderr: $(cat "$stderr_file")"
      fail=$((fail + 1))
      return
    fi
  fi

  echo "PASS: $name"
  pass=$((pass + 1))
}

# --- Test fixtures ---

# Valid shell script
cat > "$TEST_DIR/valid.sh" << 'SHELL'
#!/usr/bin/env bash
set -euo pipefail
echo "hello"
SHELL
chmod +x "$TEST_DIR/valid.sh"

# Invalid shell script (unquoted variable)
cat > "$TEST_DIR/invalid.sh" << 'SHELL'
#!/usr/bin/env bash
echo $unquoted_var
files=$(ls *.txt)
SHELL
chmod +x "$TEST_DIR/invalid.sh"

# Valid JSON
echo '{"key": "value", "list": [1, 2, 3]}' > "$TEST_DIR/valid.json"

# Invalid JSON (missing closing brace)
echo '{"key": "value"' > "$TEST_DIR/invalid.json"

# Python file (no linter configured)
echo 'print("hello")' > "$TEST_DIR/script.py"

# --- Tests ---

echo "=== run-linter.sh unit tests ==="
echo ""

# 1. Valid .sh file
run_test "Valid .sh file" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/valid.sh\"}}" \
  0

# 2. Invalid .sh file
run_test "Invalid .sh file (shellcheck errors)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/invalid.sh\"}}" \
  2 \
  "LINTER ERROR"

# 3. Valid .json file
run_test "Valid .json file" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/valid.json\"}}" \
  0

# 4. Invalid .json file
run_test "Invalid .json file (missing brace)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/invalid.json\"}}" \
  2 \
  "LINTER ERROR"

# 5. .py file (no linter)
run_test ".py file (no linter configured)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/script.py\"}}" \
  0

# 6. Missing file_path field
run_test "Missing file_path field" \
  "{\"tool_input\":{}}" \
  0

# 7. Empty JSON input
run_test "Empty JSON input" \
  "{}" \
  0

# 8. Non-existent .json file
run_test "Non-existent .json file" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/does-not-exist.json\"}}" \
  2 \
  "LINTER ERROR"

# --- Summary ---
echo ""
echo "=== Results: $pass passed, $fail failed ($(( pass + fail )) total) ==="

if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
