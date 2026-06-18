#!/usr/bin/env bash
# UserPromptSubmit hook for Codex: inject live work-state context when needed.

set -euo pipefail

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

project_dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
if [ -z "$project_dir" ]; then
  project_dir="$(pwd)"
fi

temp_dir="${project_dir}/temp"
parts=()

if [ -d "$temp_dir" ]; then
  for flag in "${temp_dir}"/sdd-wave-active-*.flag; do
    [ -f "$flag" ] || continue
    base="${flag##*/}"
    epic="${base#sdd-wave-active-}"
    epic="${epic%.flag}"
    wave=""
    checkpoint="${temp_dir}/sdd-checkpoint-${epic}.json"
    if [ -f "$checkpoint" ]; then
      wave=$(jq -r '.wave_completed // empty' "$checkpoint" 2>/dev/null || printf '')
    fi
    if [ -n "$wave" ]; then
      parts+=("SDD wave in flight: epic ${epic} (wave ${wave} complete)")
    else
      parts+=("SDD wave in flight: epic ${epic}")
    fi
  done
fi

if command -v bd >/dev/null 2>&1; then
  in_progress=$(bd list --status in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || printf '')
  if [ -n "$in_progress" ] && [ "$in_progress" -gt 0 ] 2>/dev/null; then
    parts+=("${in_progress} in_progress")
  fi
fi

if [ ${#parts[@]} -eq 0 ]; then
  exit 0
fi

joined=""
for part in "${parts[@]}"; do
  [ -n "$joined" ] && joined+="; "
  joined+="$part"
done

jq -nc --arg context "<work-state>${joined}</work-state>" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$context}}'
