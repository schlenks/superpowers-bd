#!/usr/bin/env bash
# shellcheck disable=SC2016  # bash -c bodies expand $1 in the child shell by design
# Unit tests for hooks/bd-in-progress-count.sh, the cached in_progress count the
# work-state-anchor and stop-gate hooks share. bd is stubbed via PATH; the stub
# counts `bd list` calls so the tests can tell a cache hit from a query. The fake
# .beads layout mirrors bd 1.3's embedded Dolt: metadata.json plus
# embeddeddolt/<db>/.dolt/noms/{manifest,<journal>}.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/hooks/bd-in-progress-count.sh"
JOURNAL=vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
PASS=0
FAIL=0
TOTAL=0

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

STUB_BIN="$TEST_ROOT/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/bd" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  where) printf '{"path":"%s"}' "$BD_STUB_BEADS_DIR" ;;
  list)
    printf 'x' >> "$BD_STUB_CALLS"
    printf '%s' "$BD_STUB_OUTPUT"
    ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$STUB_BIN/bd"

# make_beads DIR MODE: a fake .beads under DIR (MODE: embedded|server).
make_beads() {
  local beads="$1/.beads" mode="$2"
  mkdir -p "$beads/embeddeddolt/probe/.dolt/noms"
  printf '{"backend":"dolt","dolt_mode":"%s","dolt_database":"probe"}\n' "$mode" > "$beads/metadata.json"
  printf 'root-1\n' > "$beads/embeddeddolt/probe/.dolt/noms/manifest"
  printf 'chunk' > "$beads/embeddeddolt/probe/.dolt/noms/$JOURNAL"
}

# count_in DIR: run the helper from DIR in a fresh shell, print "<count>/<list calls so far>".
count_in() {
  local dir="$1" out
  out=$(cd "$dir" && env PATH="$STUB_BIN:$PATH" TMPDIR="$TEST_ROOT/tmp" \
    bash -c '. "$1"; bd_in_progress_count' _ "$HELPER")
  printf '%s/%s' "$out" "$(wc -c < "$BD_STUB_CALLS" | tr -d ' ')"
}

check() {
  local name="$1" got="$2" want="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$got" = "$want" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name — expected '$want', got '$got'"
    FAIL=$((FAIL + 1))
  fi
}

# fresh_case NAME MODE: a new project with its own call counter.
fresh_case() {
  PROJ="$TEST_ROOT/$1"
  mkdir -p "$PROJ" "$TEST_ROOT/tmp"
  make_beads "$PROJ" "$2"
  export BD_STUB_BEADS_DIR="$PROJ/.beads"
  export BD_STUB_CALLS="$TEST_ROOT/$1.calls"
  : > "$BD_STUB_CALLS"
  export BD_STUB_OUTPUT='[{"id":"a"},{"id":"b"}]'
}

echo "=== bd in_progress count cache tests ==="
echo ""

fresh_case embedded embedded
check "First call queries bd" "$(count_in "$PROJ")" "2/1"
check "Unchanged database is served from cache" "$(count_in "$PROJ")" "2/1"
# A read refreshes mtimes but not content; the key must ignore it.
touch "$PROJ/.beads/embeddeddolt/probe/.dolt/noms/manifest" "$PROJ/.beads/embeddeddolt/probe/.dolt/noms/$JOURNAL"
check "Touched-but-unchanged files stay cached" "$(count_in "$PROJ")" "2/1"
export BD_STUB_OUTPUT='[{"id":"a"}]'
printf 'more' >> "$PROJ/.beads/embeddeddolt/probe/.dolt/noms/$JOURNAL"
check "Journal append (a bd write) re-queries" "$(count_in "$PROJ")" "1/2"
export BD_STUB_OUTPUT='[]'
printf 'root-2\n' > "$PROJ/.beads/embeddeddolt/probe/.dolt/noms/manifest"
check "Manifest root change re-queries" "$(count_in "$PROJ")" "0/3"
check "Zero count is cached too" "$(count_in "$PROJ")" "0/3"

# A subdirectory resolves through `bd where` and shares the same database state.
mkdir -p "$PROJ/sub"
check "Subdirectory resolves the database via bd where" "$(count_in "$PROJ/sub")" "0/4"
check "Subdirectory then hits its own cache" "$(count_in "$PROJ/sub")" "0/4"

fresh_case server server
check "Server mode is never cached (1st)" "$(count_in "$PROJ")" "2/1"
check "Server mode is never cached (2nd)" "$(count_in "$PROJ")" "2/2"

fresh_case nojournal embedded
rm -f "$PROJ/.beads/embeddeddolt/probe/.dolt/noms/$JOURNAL"
check "Missing journal is never cached (1st)" "$(count_in "$PROJ")" "2/1"
check "Missing journal is never cached (2nd)" "$(count_in "$PROJ")" "2/2"

fresh_case beadsdb embedded
got1=$(cd "$PROJ" && env PATH="$STUB_BIN:$PATH" TMPDIR="$TEST_ROOT/tmp" BEADS_DB=/elsewhere \
  bash -c '. "$1"; bd_in_progress_count' _ "$HELPER")
got2=$(cd "$PROJ" && env PATH="$STUB_BIN:$PATH" TMPDIR="$TEST_ROOT/tmp" BEADS_DB=/elsewhere \
  bash -c '. "$1"; bd_in_progress_count' _ "$HELPER")
check "BEADS_DB override bypasses the cache" "$got1/$got2/$(wc -c < "$BD_STUB_CALLS" | tr -d ' ')" "2/2/2"

fresh_case badoutput embedded
export BD_STUB_OUTPUT='not json'
check "Unparseable bd output yields empty and is not cached (1st)" "$(count_in "$PROJ")" "/1"
check "Unparseable bd output yields empty and is not cached (2nd)" "$(count_in "$PROJ")" "/2"

TOTAL=$((TOTAL + 1))
if cmp -s "$HELPER" "$REPO_ROOT/plugins/superpowers-bd/hooks/bd-in-progress-count.sh"; then
  echo "PASS: Codex plugin copy matches hooks/bd-in-progress-count.sh"
  PASS=$((PASS + 1))
else
  echo "FAIL: plugins/superpowers-bd/hooks/bd-in-progress-count.sh differs from hooks/bd-in-progress-count.sh"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
