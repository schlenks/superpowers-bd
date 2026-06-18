#!/usr/bin/env bash
# Stop hook for Codex: require verification evidence before ending live work.

set -euo pipefail

if [ "${SDD_ALLOW_STOP:-}" = "1" ]; then
  exit 0
fi

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

project_dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
if [ -z "$project_dir" ]; then
  project_dir="$(pwd)"
fi

stop_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || printf 'false')
last_message=$(printf '%s' "$input" | jq -r '.last_assistant_message // ""' 2>/dev/null || printf '')
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || printf 'unknown')

if [ "$stop_active" = "true" ]; then
  exit 0
fi

temp_dir="${project_dir}/temp"
work_live=0
for flag in "${temp_dir}"/sdd-wave-active-*.flag; do
  [ -f "$flag" ] && { work_live=1; break; }
done
if [ "$work_live" = 0 ] && command -v bd >/dev/null 2>&1; then
  in_progress=$(bd list --status in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || printf '')
  if [ -n "$in_progress" ] && [ "$in_progress" -gt 0 ] 2>/dev/null; then
    work_live=1
  fi
fi
[ "$work_live" = 0 ] && exit 0

claim_re='is (now )?complete|is (now )?fixed|is (now )?done|implementation (is )?complete|successfully (implemented|completed|fixed)|ready to merge|ready for review|all tests pass|everything works|work is done|task is done'
evidence_re='exit code[ :]*[0-9]+|[0-9]+ (tests? )?(passed|passing)|0 failures|output:|evidence:|all .*pass|ran (npm|pnpm|yarn|pytest|go test|cargo|make|bash|sh|node|python|python3|\./[^[:space:]]+)|executed (npm|pnpm|yarn|pytest|go test|cargo|make|bash|sh|node|python|python3|\./[^[:space:]]+)|result:|passed|no .*fail'

printf '%s' "$last_message" | grep -qiE "$claim_re" || exit 0
printf '%s' "$last_message" | grep -qiE "$evidence_re" && exit 0

mkdir -p "$temp_dir"
count_file="${temp_dir}/stop-gate-${session_id}.count"
count=0
[ -f "$count_file" ] && count=$(cat "$count_file" 2>/dev/null || printf '0')
case "$count" in *[!0-9]*|"") count=0 ;; esac
[ "$count" -ge 3 ] && exit 0

printf '%s\n' "$((count + 1))" > "$count_file"

jq -nc --arg reason "You are ending the turn with a completion claim but no verification evidence. Run the relevant check and quote its output before stopping. Set SDD_ALLOW_STOP=1 to override." \
  '{decision:"block", reason:$reason}'
