#!/usr/bin/env bash
# shellcheck disable=SC1003
# PreCompact hook: block compaction when a subagent-driven-development wave
# is in flight. Mid-wave compaction truncates background Task IDs, wave
# file maps, and reviewer dispatches, corrupting the orchestrator's state.
#
# Requires Claude Code 2.1.105+ (PreCompact decision block support).

set -euo pipefail

# Resolve project directory — Claude provides CLAUDE_PROJECT_DIR for hooks.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    temp_dir="${CLAUDE_PROJECT_DIR}/temp"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    temp_dir="$(cd "${SCRIPT_DIR}/.." && pwd)/temp"
fi

# Escape hatch: set SDD_ALLOW_COMPACT=1 to override. Useful after a crash
# where the wave flag is stale and the user has accepted the risk.
if [ "${SDD_ALLOW_COMPACT:-}" = "1" ]; then
    printf '{"continue":true}\n'
    exit 0
fi

# Look for any sdd-wave-active-*.flag file (one per in-flight epic).
if [ -d "$temp_dir" ]; then
    for f in "${temp_dir}"/sdd-wave-active-*.flag; do
        [ -f "$f" ] || continue
        active_basename="${f##*/}"
        active_epic="${active_basename#sdd-wave-active-}"
        active_epic="${active_epic%.flag}"

        reason="Compaction blocked: SDD wave in flight for epic ${active_epic}. "
        reason+="Mid-wave compaction would lose background Task IDs, the wave file map, "
        reason+="and reviewer dispatches. Let the current wave finish (reach CLOSE phase), "
        reason+="then retry compaction. If this flag is stale from a crashed session, "
        reason+="run: rm ${f} or set SDD_ALLOW_COMPACT=1."

        # Escape reason for JSON (double quotes and backslashes only — no newlines).
        escaped=""
        i=0
        while [ $i -lt ${#reason} ]; do
            char="${reason:$i:1}"
            case "$char" in
                '\') escaped+='\\' ;;
                '"') escaped+='\"' ;;
                *) escaped+="$char" ;;
            esac
            i=$((i + 1))
        done

        printf '{"decision":"block","reason":"%s"}\n' "$escaped"
        exit 0
    done
fi

# No wave active — allow compaction.
printf '{"continue":true}\n'
exit 0
