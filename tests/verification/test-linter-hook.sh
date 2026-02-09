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

# Python file (simple, no functions)
echo 'print("hello")' > "$TEST_DIR/script.py"

# Python file with low complexity (CC=4, well below threshold)
cat > "$TEST_DIR/cc_low.py" << 'PYEOF'
def simple_check(x, y, z):
    if x > 0:
        print("positive")
    elif y > 0:
        print("y positive")
    elif z > 0:
        print("z positive")
    else:
        print("all non-positive")
    return x + y + z
PYEOF

# Python file with medium complexity (CC=12, warn but not block)
cat > "$TEST_DIR/cc_warn.py" << 'PYEOF'
def complex_validator(data, mode, strict):
    result = []
    if not data:
        return result
    if mode == "alpha":
        if strict:
            result.append("strict_alpha")
        else:
            result.append("alpha")
    elif mode == "beta":
        if strict:
            result.append("strict_beta")
        else:
            result.append("beta")
    elif mode == "gamma":
        result.append("gamma")
    elif mode == "delta":
        result.append("delta")
    for item in data:
        if item > 100:
            result.append("large")
        elif item > 50:
            result.append("medium")
        elif item > 10:
            result.append("small")
        else:
            result.append("tiny")
    return result
PYEOF

# Python file with high complexity (CC=18, must block)
cat > "$TEST_DIR/cc_block.py" << 'PYEOF'
def overly_complex(data, mode, level, strict, verbose):
    result = []
    if not data:
        return result
    if mode == "alpha":
        if strict:
            if level > 5:
                result.append("high_strict_alpha")
            else:
                result.append("low_strict_alpha")
        else:
            result.append("alpha")
    elif mode == "beta":
        if strict:
            result.append("strict_beta")
        elif verbose:
            result.append("verbose_beta")
        else:
            result.append("beta")
    elif mode == "gamma":
        if level > 10:
            result.append("high_gamma")
        else:
            result.append("low_gamma")
    elif mode == "delta":
        result.append("delta")
    for item in data:
        if item > 100:
            if verbose:
                result.append("very_large")
            else:
                result.append("large")
        elif item > 50:
            result.append("medium")
        elif item > 25:
            result.append("small")
        else:
            result.append("tiny")
    if strict and verbose:
        result.append("audit")
    return result
PYEOF

# Python file with very long function (105 NLOC, CC=1)
cat > "$TEST_DIR/long_func.py" << 'PYEOF'
def very_long_function(x):
    a = x + 1
    b = x + 2
    c = x + 3
    d = x + 4
    e = x + 5
    f = x + 6
    g = x + 7
    h = x + 8
    i = x + 9
    j = x + 10
    k = x + 11
    l = x + 12
    m = x + 13
    n = x + 14
    o = x + 15
    p = x + 16
    q = x + 17
    r = x + 18
    s = x + 19
    t = x + 20
    u = x + 21
    v = x + 22
    w = x + 23
    y = x + 24
    z = x + 25
    aa = x + 26
    ab = x + 27
    ac = x + 28
    ad = x + 29
    ae = x + 30
    af = x + 31
    ag = x + 32
    ah = x + 33
    ai = x + 34
    aj = x + 35
    ak = x + 36
    al = x + 37
    am = x + 38
    an = x + 39
    ao = x + 40
    ap = x + 41
    aq = x + 42
    ar = x + 43
    as_ = x + 44
    at = x + 45
    au = x + 46
    av = x + 47
    aw = x + 48
    ax = x + 49
    ay = x + 50
    az = x + 51
    ba = x + 52
    bb = x + 53
    bc = x + 54
    bd = x + 55
    be = x + 56
    bf = x + 57
    bg = x + 58
    bh = x + 59
    bi = x + 60
    bj = x + 61
    bk = x + 62
    bl = x + 63
    bm = x + 64
    bn = x + 65
    bo = x + 66
    bp = x + 67
    bq = x + 68
    br = x + 69
    bs = x + 70
    bt = x + 71
    bu = x + 72
    bv = x + 73
    bw = x + 74
    bx = x + 75
    by = x + 76
    bz = x + 77
    ca = x + 78
    cb = x + 79
    cc = x + 80
    cd = x + 81
    ce = x + 82
    cf = x + 83
    cg = x + 84
    ch = x + 85
    ci = x + 86
    cj = x + 87
    ck = x + 88
    cl = x + 89
    cm = x + 90
    cn = x + 91
    co = x + 92
    cp = x + 93
    cq = x + 94
    cr = x + 95
    cs = x + 96
    ct = x + 97
    cu = x + 98
    cv = x + 99
    cw = x + 100
    cx = x + 101
    cy = x + 102
    cz = x + 103
    return a + b + c + d + e
PYEOF

# TypeScript file with low cognitive complexity (score=4, well below 15)
cat > "$TEST_DIR/cc_low.ts" << 'TSEOF'
function simpleCheck(x: number, y: number, z: number): string {
    if (x > 0) {
        return "positive";
    } else if (y > 0) {
        return "y positive";
    } else if (z > 0) {
        return "z positive";
    } else {
        return "all non-positive";
    }
}
TSEOF

# TypeScript file with medium cognitive complexity (score=22, warn but not block)
cat > "$TEST_DIR/cc_warn.ts" << 'TSEOF'
function complexValidator(
    data: number[],
    mode: string,
    strict: boolean,
    level: number
): string[] {
    const result: string[] = [];
    if (!data) {
        return result;
    }
    if (mode === "alpha") {
        if (strict) {
            if (level > 5) {
                result.push("high_strict");
            } else {
                result.push("low_strict");
            }
        } else {
            result.push("alpha");
        }
    } else if (mode === "beta") {
        if (strict) {
            if (level > 5) {
                result.push("strict_beta_high");
            } else {
                result.push("strict_beta_low");
            }
        } else {
            result.push("beta");
        }
    } else if (mode === "gamma") {
        result.push("gamma");
    }
    for (const item of data) {
        if (item > 100) {
            result.push("large");
        } else if (item > 50) {
            result.push("medium");
        }
    }
    return result;
}
TSEOF

# TypeScript file with high cognitive complexity (score=31, must block)
cat > "$TEST_DIR/cc_block.ts" << 'TSEOF'
function overlyComplex(data: number[], mode: string, strict: boolean, level: number): string[] {
    const result: string[] = [];
    if (!data) {
        return result;
    }
    if (mode === "alpha") {
        if (strict) {
            if (level > 5) {
                if (level > 10) {
                    result.push("very_high");
                } else {
                    result.push("high");
                }
            } else {
                result.push("low");
            }
        } else {
            result.push("alpha");
        }
    } else if (mode === "beta") {
        if (strict) {
            if (level > 5) {
                result.push("strict_beta_high");
            } else {
                result.push("strict_beta_low");
            }
        } else {
            result.push("beta");
        }
    } else if (mode === "gamma") {
        result.push("gamma");
    }
    for (const item of data) {
        if (item > 100) {
            if (strict) {
                result.push("strict_large");
            } else {
                result.push("large");
            }
        } else if (item > 50) {
            result.push("medium");
        }
    }
    return result;
}
TSEOF

# TypeScript long function (105+ NLOC, low cognitive complexity)
{
  echo 'function veryLongFunction(x: number): number {'
  for i in $(seq 1 103); do
    printf '    const v%d = x + %d;\n' "$i" "$i"
  done
  echo '    return v1 + v2 + v3;'
  echo '}'
} > "$TEST_DIR/long_func.ts"

# Simple TSX file (verify .tsx extension matching)
cat > "$TEST_DIR/simple.tsx" << 'TSEOF'
function SimpleComponent({ name }: { name: string }) {
    return <div>{name}</div>;
}
TSEOF

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

# 5. .py file (simple, no functions for lizard to analyze)
run_test ".py file — simple, no functions" \
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

# 9. Python file with low complexity (CC=4, clean)
run_test ".py file — low complexity (CC=4, clean)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/cc_low.py\"}}" \
  0

# 10. Python file with medium complexity (CC=12, warn but pass)
run_test ".py file — medium complexity (CC=12, warning)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/cc_warn.py\"}}" \
  0 \
  "COMPLEXITY WARNING"

# 11. Python file with high complexity (CC=18, must block)
run_test ".py file — high complexity (CC=18, blocked)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/cc_block.py\"}}" \
  2 \
  "COMPLEXITY ERROR"

# 12. Python file with very long function (105 NLOC, must block)
run_test ".py file — long function (105 NLOC, blocked)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/long_func.py\"}}" \
  2 \
  "COMPLEXITY ERROR"

# --- TypeScript / cognitive-complexity-ts tests ---

# 13. TS file with low cognitive complexity (clean)
run_test ".ts file — low cognitive complexity (clean)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/cc_low.ts\"}}" \
  0

# 14. TS file with medium cognitive complexity (warn but pass)
run_test ".ts file — medium cognitive complexity (warning)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/cc_warn.ts\"}}" \
  0 \
  "COMPLEXITY WARNING"

# 15. TS file with high cognitive complexity (must block)
run_test ".ts file — high cognitive complexity (blocked)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/cc_block.ts\"}}" \
  2 \
  "COMPLEXITY ERROR"

# 16. TS file with very long function (low cognitive complexity — passes)
run_test ".ts file — long function (low cognitive complexity, clean)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/long_func.ts\"}}" \
  0

# 17. TSX extension matching (clean file)
run_test ".tsx file — extension matching (clean)" \
  "{\"tool_input\":{\"file_path\":\"$TEST_DIR/simple.tsx\"}}" \
  0

# 18. TS fallback to lizard when ccts-json unavailable
_test_ts_fallback() {
  local stderr_file="$TEST_DIR/stderr_fallback"
  local actual_exit=0
  local restricted_path=""
  while IFS= read -r -d: p || [[ -n "$p" ]]; do
    if [[ -n "$p" ]] && ! [[ -x "$p/ccts-json" ]]; then
      restricted_path="${restricted_path:+$restricted_path:}$p"
    fi
  done <<< "$PATH:"
  echo "{\"tool_input\":{\"file_path\":\"$TEST_DIR/cc_low.ts\"}}" \
    | env PATH="$restricted_path" "$HOOK" 2>"$stderr_file" || actual_exit=$?
  if [[ "$actual_exit" -eq 0 ]]; then
    echo "PASS: .ts file — fallback to lizard (ccts-json unavailable)"
    pass=$((pass + 1))
  else
    echo "FAIL: .ts file — fallback to lizard — expected exit 0, got $actual_exit"
    [[ -s "$stderr_file" ]] && echo "  stderr: $(cat "$stderr_file")"
    fail=$((fail + 1))
  fi
}
_test_ts_fallback

# --- Summary ---
echo ""
echo "=== Results: $pass passed, $fail failed ($(( pass + fail )) total) ==="

if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
