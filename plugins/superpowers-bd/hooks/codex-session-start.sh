#!/usr/bin/env bash
# SessionStart hook for Codex plugin-bundled Superpowers-BD usage.

set -euo pipefail

input=$(cat)

project_dir=""
if command -v jq >/dev/null 2>&1; then
  project_dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
fi

if [ -z "$project_dir" ]; then
  project_dir="$(pwd)"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
plugin_root="$(cd "${script_dir}/.." && pwd)"

escape_for_json() {
  local raw="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$raw" | jq -Rs .
  else
    local escaped="${raw//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//$'\n'/\\n}"
    printf '"%s"' "$escaped"
  fi
}

using_superpowers_content=$(cat "${plugin_root}/skills/using-superpowers/SKILL.md" 2>/dev/null || printf 'Error loading superpowers-bd:using-superpowers')

checkpoint_message=""
checkpoint_dir="${project_dir}/temp"
if [ -d "$checkpoint_dir" ]; then
  latest_checkpoint=""
  for candidate in "${checkpoint_dir}"/sdd-checkpoint-*.json; do
    [ -f "$candidate" ] || continue
    if [ -z "$latest_checkpoint" ] || [ "$candidate" -nt "$latest_checkpoint" ]; then
      latest_checkpoint="$candidate"
    fi
  done

  if [ -n "$latest_checkpoint" ]; then
    checkpoint_name="${latest_checkpoint##*/}"
    checkpoint_epic_id="${checkpoint_name#sdd-checkpoint-}"
    checkpoint_epic_id="${checkpoint_epic_id%.json}"

    epic_open_children=""
    if command -v bd >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
      epic_open_children=$(bd list --parent "$checkpoint_epic_id" --status open,in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
    fi

    if [ "$epic_open_children" = "0" ]; then
      rm -f "$latest_checkpoint" 2>/dev/null || true
    else
      checkpoint_message="

<sdd-checkpoint-recovery>SDD checkpoint found: ${checkpoint_name}. Restore the matching temp checkpoint before dispatching more work.</sdd-checkpoint-recovery>"
    fi
  fi
fi

additional_context="<EXTREMELY_IMPORTANT>
You have superpowers-bd.

Use the native Codex skill surface for bundled skills. The primary entry skill is superpowers-bd:using-superpowers.

${using_superpowers_content}${checkpoint_message}
</EXTREMELY_IMPORTANT>"

context_json=$(escape_for_json "$additional_context")

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$context_json"
