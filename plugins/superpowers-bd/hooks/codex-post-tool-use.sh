#!/usr/bin/env bash
# PostToolUse hook for Codex plugin-bundled audit logging and lint feedback.

set -euo pipefail

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

project_dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
if [ -z "$project_dir" ]; then
  project_dir="$(pwd)"
fi

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // "unknown"' 2>/dev/null || printf 'unknown')

extract_paths_from_patch() {
  jq -r '
    .tool_input.command // .tool_input.patch // "" |
    split("\n")[] |
    select(startswith("*** Update File: ") or startswith("*** Add File: ")) |
    sub("^\\*\\*\\* (Update|Add) File: "; "")
  ' 2>/dev/null
}

paths=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
if [ -z "$paths" ]; then
  paths=$(printf '%s' "$input" | extract_paths_from_patch || true)
fi

log_dir="${project_dir}/temp"
log_file="${log_dir}/file-modifications.log"
mkdir -p "$log_dir"

reason=""
while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in
    /*) absolute_path="$path" ;;
    *) absolute_path="${project_dir}/${path}" ;;
  esac

  printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tool_name" "$absolute_path" >> "$log_file"

  if [ -f "$absolute_path" ]; then
    case "$absolute_path" in
      *.json)
        if ! output=$(jq empty "$absolute_path" 2>&1); then
          reason="JSON syntax error in ${absolute_path}. ${output}"
        fi
        ;;
      *.sh)
        if command -v shellcheck >/dev/null 2>&1; then
          if ! output=$(shellcheck -f gcc "$absolute_path" 2>&1); then
            reason="shellcheck found issues in ${absolute_path}. ${output}"
          fi
        fi
        ;;
    esac
  fi
done <<< "$paths"

if [ -n "$reason" ]; then
  jq -nc --arg reason "$reason" '{decision:"block", reason:$reason}'
fi
