#!/usr/bin/env bash
# Tests for skills/epic-verifier/scripts/quality-delta.sh using throwaway repos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DELTA="$SCRIPT_DIR/../../skills/epic-verifier/scripts/quality-delta.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0
fail=0

check() {
  local name="$1" output="$2" pattern="$3"
  if grep -q -- "$pattern" <<< "$output"; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name — missing: $pattern"
    printf '  %s\n' "$output"
    fail=$((fail + 1))
  fi
}

commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=t -c user.email=t@example.com commit -qm "$2"
}

# One function with 12 branches (CCN 13) and one simple function.
write_branchy() {
  {
    echo "def classify(a):"
    for i in $(seq 0 11); do
      printf '    if a == %d:\n        return %d\n' "$i" "$i"
    done
    echo "    return -1"
  } > "$1"
}

if ! command -v lizard &>/dev/null; then
  echo "SKIP: quality-delta tests (lizard not installed)"
  exit 0
fi

# Worsened: a new over-limit function is added.
repo="$TEST_DIR/worse"
mkdir -p "$repo" && git -C "$repo" init -q
echo "def ok(x):
    return x + 1" > "$repo/app.py"
commit_all "$repo" base
base=$(git -C "$repo" rev-parse HEAD)
write_branchy "$repo/rules.py"
commit_all "$repo" head
out=$(cd "$repo" && "$DELTA" "$base")
check "new over-limit file flagged" "$out" "new, over limit"
check "worsened result" "$out" "Result: WORSENED"

# Better: the branchy function is replaced by a lookup.
repo="$TEST_DIR/better"
mkdir -p "$repo" && git -C "$repo" init -q
write_branchy "$repo/rules.py"
commit_all "$repo" base
base=$(git -C "$repo" rev-parse HEAD)
echo "def classify(a):
    return a if 0 <= a <= 11 else -1" > "$repo/rules.py"
commit_all "$repo" head
out=$(cd "$repo" && "$DELTA" "$base")
check "refactor reported as better" "$out" "| better |"
check "not worsened result" "$out" "Result: NOT WORSENED"

# Non-code changes only.
repo="$TEST_DIR/docs"
mkdir -p "$repo" && git -C "$repo" init -q
echo "# readme" > "$repo/README.md"
commit_all "$repo" base
base=$(git -C "$repo" rev-parse HEAD)
echo "more" >> "$repo/README.md"
commit_all "$repo" head
out=$(cd "$repo" && "$DELTA" "$base")
check "no code files" "$out" "No changed code files"

# Invalid ref exits 2.
code=0
(cd "$repo" && "$DELTA" no-such-ref >/dev/null 2>&1) || code=$?
if [[ "$code" -eq 2 ]]; then
  echo "PASS: invalid ref exits 2"
  pass=$((pass + 1))
else
  echo "FAIL: invalid ref exits 2 — got $code"
  fail=$((fail + 1))
fi

echo ""
echo "=== Results: $pass passed, $fail failed ($(( pass + fail )) total) ==="
[[ "$fail" -eq 0 ]]
