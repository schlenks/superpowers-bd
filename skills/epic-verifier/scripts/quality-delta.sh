#!/usr/bin/env bash
# Maintainability delta for an epic: compares complexity and duplication of the
# code files changed between two commits, at base versus head.
#
# Usage: quality-delta.sh <base-sha> [head-sha]   (head defaults to HEAD)
# Prints a Markdown report. Informational: always exits 0 unless arguments or
# git refs are invalid (exit 2). Requires lizard (pip install lizard); without
# it the report says the delta is unavailable.
set -euo pipefail

CCN_LIMIT=10
CODE_EXT_RE='\.(ts|tsx|py|js|jsx|go|java|c|cpp|h|hpp|rb|swift|rs)$'

base="${1:-}"
head="${2:-HEAD}"
if [[ -z "$base" ]]; then
  echo "usage: quality-delta.sh <base-sha> [head-sha]" >&2
  exit 2
fi
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null ||
   ! git rev-parse --verify --quiet "$head^{commit}" >/dev/null; then
  echo "quality-delta: unknown commit ($base or $head)" >&2
  exit 2
fi

echo "## Maintainability delta (${base:0:12}..${head:0:12})"
echo
if ! command -v lizard &>/dev/null; then
  echo "Unavailable: lizard is not installed (pip install lizard)."
  exit 0
fi

files=()
while IFS= read -r f; do
  [[ "$f" =~ $CODE_EXT_RE ]] && files+=("$f")
done < <(git diff --name-only --diff-filter=AM "$base" "$head")

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No changed code files in a language lizard supports."
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Materialize each changed file at a revision under $work/<label>/<path>.
snapshot() {
  local rev="$1" label="$2" f
  for f in "${files[@]}"; do
    if git cat-file -e "$rev:$f" 2>/dev/null; then
      mkdir -p "$work/$label/$(dirname "$f")"
      git show "$rev:$f" > "$work/$label/$f"
    fi
  done
}
snapshot "$base" base
snapshot "$head" head

# "max_ccn over_limit_count" for one file; "- -" when absent at that revision.
ccn_stats() {
  local path="$1"
  if [[ ! -f "$path" ]]; then echo "- -"; return; fi
  lizard --csv "$path" 2>/dev/null |
    awk -F, -v lim="$CCN_LIMIT" '{ if ($2 > max) max = $2; if ($2 > lim) n++ }
      END { printf "%d %d\n", max, n }'
}

# Duplicate blocks lizard finds across every file under a directory.
dup_blocks() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then echo 0; return; fi
  lizard -Eduplicate "$dir" 2>/dev/null | grep -c '^Duplicate block:' || true
}

echo "| File | Max CCN (base → head) | Functions CCN>${CCN_LIMIT} (base → head) | Trend |"
echo "|------|------------------------|------------------------------|-------|"
worse=0
for f in "${files[@]}"; do
  read -r bmax bn <<< "$(ccn_stats "$work/base/$f")"
  read -r hmax hn <<< "$(ccn_stats "$work/head/$f")"
  trend="same"
  if [[ "$bmax" == "-" ]]; then
    trend="new"
    [[ "$hn" -gt 0 ]] && { trend="new, over limit"; worse=$((worse + 1)); }
  elif [[ "$hn" -gt "$bn" || "$hmax" -gt "$bmax" ]]; then
    trend="WORSE"; worse=$((worse + 1))
  elif [[ "$hn" -lt "$bn" || "$hmax" -lt "$bmax" ]]; then
    trend="better"
  fi
  echo "| \`$f\` | $bmax → $hmax | $bn → $hn | $trend |"
done

bdup=$(dup_blocks "$work/base")
hdup=$(dup_blocks "$work/head")
echo
echo "Duplicate code blocks across changed files: $bdup → $hdup"
echo
if [[ "$worse" -gt 0 || "$hdup" -gt "$bdup" ]]; then
  echo "Result: WORSENED — $worse file(s) with higher complexity; duplicate blocks $bdup → $hdup."
  echo "Inspect with \`lizard -C $CCN_LIMIT -w <file>\` and \`lizard -Eduplicate <files>\`."
else
  echo "Result: NOT WORSENED"
fi
