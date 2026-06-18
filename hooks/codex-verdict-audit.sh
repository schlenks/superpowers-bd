#!/usr/bin/env bash
# SubagentStop hook for Codex: audit and enforce structured SDD verdicts.

set -euo pipefail

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

project_dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
if [ -z "$project_dir" ]; then
  project_dir="$(pwd)"
fi

log_dir="${project_dir}/temp"
log_file="${log_dir}/verdict-audit.log"
agent_type=$(printf '%s' "$input" | jq -r '.agent_type // "unknown"' 2>/dev/null || printf 'unknown')
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null || printf 'unknown')
last_message=$(printf '%s' "$input" | jq -r '.last_assistant_message // ""' 2>/dev/null || printf '')

verdict=$(printf '%s' "$last_message" | grep -m1 '^VERDICT:' || true)
if [ -z "$verdict" ]; then
  verdict="NO_VERDICT"
fi

mkdir -p "$log_dir"
printf '%s agent_type=%s agent_id=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_type" "$agent_id" "$verdict" >> "$log_file" || true

if [ "$verdict" != "NO_VERDICT" ] || [ "${SDD_ALLOW_NO_VERDICT:-}" = "1" ]; then
  exit 0
fi

wave_active=0
for flag in "${log_dir}"/sdd-wave-active-*.flag; do
  [ -f "$flag" ] && { wave_active=1; break; }
done
[ "$wave_active" = 0 ] && exit 0

count_file="${log_dir}/verdict-gate-${agent_id}.count"
count=0
[ -f "$count_file" ] && count=$(cat "$count_file" 2>/dev/null || printf '0')
case "$count" in *[!0-9]*|"") count=0 ;; esac

if [ "$count" -lt 2 ]; then
  printf '%s\n' "$((count + 1))" > "$count_file"
  jq -nc --arg reason "You stopped during an active SDD wave without a verdict. End your final message with a line that begins 'VERDICT:' plus brief evidence, then stop." \
    '{decision:"block", reason:$reason}'
  exit 0
fi

printf '%s agent_id=%s VERDICT_GATE_GIVEUP after %s blocks\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent_id" "$count" >> "$log_file" || true
