#!/usr/bin/env bash
# Structural checks on what the installed skill directories ship.
#
# 1. Size: after a compaction, Claude Code re-attaches each invoked skill cut
#    to its first 5,000 tokens, observed as 20,000 characters (upstream
#    obra/superpowers#2481). Anything past the cut is gone for the rest of the
#    session, so every SKILL.md must stay under it. Bytes are measured, which
#    is stricter than characters for non-ASCII text.
# 2. Dev files: everything under skills/<name>/ is installed next to SKILL.md,
#    and agents read those directories during normal work. Pressure scenarios
#    open with "This is a real scenario. You must choose and act" and can be
#    taken as live instructions (upstream obra/superpowers#2277). They belong
#    under tests/<skill>/.
#
# Both the root skills and the Codex plugin mirror are checked.
# SKILL_LAYOUT_ROOTS (tests only) replaces the directories scanned.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIMIT=20000

roots=${SKILL_LAYOUT_ROOTS-"$REPO_ROOT/skills $REPO_ROOT/plugins/superpowers-bd/skills"}

failed=0
checked=0
for root in $roots; do
  [ -d "$root" ] || continue
  for skill in "$root"/*/SKILL.md; do
    [ -f "$skill" ] || continue
    checked=$((checked + 1))
    size=$(wc -c <"$skill" | tr -d ' ')
    if [ "$size" -ge "$LIMIT" ]; then
      echo "FAIL: ${skill#"$REPO_ROOT"/} is $size bytes (limit: under $LIMIT)" >&2
      failed=1
    fi
  done

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    echo "FAIL: ${file#"$REPO_ROOT"/} is skill-development material inside an installed skill" >&2
    failed=1
  done < <(find "$root" -type f \( -name 'CREATION-LOG.md' -o -name 'test-pressure-*.md' -o -name 'test-academic*.md' \) | sort)
done

if [ "$checked" -eq 0 ]; then
  echo "FAIL: found no SKILL.md files to check" >&2
  exit 1
fi
if [ "$failed" -ne 0 ]; then
  echo "Move rarely needed content into the skill's reference files, and pressure scenarios or creation logs under tests/<skill>/." >&2
  exit 1
fi
echo "PASS: $checked SKILL.md files are under $LIMIT bytes and ship no dev files"
