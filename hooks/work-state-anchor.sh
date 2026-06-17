#!/usr/bin/env bash
# shellcheck disable=SC1003
# UserPromptSubmit hook: inject a terse work-state anchor so the model never
# operates on a stale picture of in-flight work between SessionStart re-injections.
#
# Injects ONLY when work is live — an SDD wave is in flight (sdd-wave-active flag)
# or beads has in_progress issues. Stays SILENT when idle, so ordinary sessions
# pay no per-turn noise. Always exits 0; never blocks the prompt.

set -euo pipefail

proj="${CLAUDE_PROJECT_DIR:-.}"
temp_dir="${proj}/temp"
parts=()

# 1. SDD waves in flight (one flag per epic). Annotate with the last completed
#    wave from the matching checkpoint when available.
if [ -d "$temp_dir" ]; then
    for f in "${temp_dir}"/sdd-wave-active-*.flag; do
        [ -f "$f" ] || continue
        base="${f##*/}"
        epic="${base#sdd-wave-active-}"
        epic="${epic%.flag}"
        wave=""
        ckpt="${temp_dir}/sdd-checkpoint-${epic}.json"
        if [ -f "$ckpt" ] && command -v jq >/dev/null 2>&1; then
            wave=$(jq -r '.wave_completed // empty' "$ckpt" 2>/dev/null || echo "")
        fi
        if [ -n "$wave" ]; then
            parts+=("SDD wave in flight: epic ${epic} (wave ${wave} complete)")
        else
            parts+=("SDD wave in flight: epic ${epic}")
        fi
    done
fi

# 2. In-progress beads work.
if command -v bd >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    ip=$(bd list --status in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
    if [ -n "$ip" ] && [ "$ip" -gt 0 ] 2>/dev/null; then
        parts+=("${ip} in_progress")
    fi
fi

# Idle → no injection. (Guards the empty-array expansion below on bash 3.2.)
if [ ${#parts[@]} -eq 0 ]; then
    exit 0
fi

# Join parts with "; ".
joined=""
for p in "${parts[@]}"; do
    [ -n "$joined" ] && joined+="; "
    joined+="$p"
done

# Escape for JSON (quotes/backslashes only — single-line anchor, no newlines).
escaped=""
i=0
while [ $i -lt ${#joined} ]; do
    char="${joined:$i:1}"
    case "$char" in
        '\') escaped+='\\' ;;
        '"') escaped+='\"' ;;
        *) escaped+="$char" ;;
    esac
    i=$((i + 1))
done

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<work-state>%s</work-state>"}}\n' "$escaped"
exit 0
