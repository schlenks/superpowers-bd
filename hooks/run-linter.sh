#!/usr/bin/env bash
# PostToolUse linter guard for Write|Edit tool calls.
# Reads hook JSON from stdin, extracts tool_input.file_path via jq,
# runs appropriate linter based on file extension.
# Exit 2 blocks the operation and surfaces errors to Claude for self-correction.
# Exit 0 means no issues (or unsupported file type / missing tool).
#
# Supported: *.sh (shellcheck), *.json (jq)
# Graceful degradation: exits 0 if linter tool not installed.

set -euo pipefail

input=$(cat)

# jq required to parse hook input
if ! command -v jq &>/dev/null; then exit 0; fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

case "$file_path" in
  *.sh)
    command -v shellcheck &>/dev/null || exit 0
    if ! output=$(shellcheck -f gcc "$file_path" 2>&1); then
      echo "LINTER ERROR: shellcheck found issues in $file_path" >&2
      echo "$output" >&2
      echo "Please fix the shellcheck errors above and retry." >&2
      exit 2
    fi
    ;;
  *.json)
    if ! output=$(jq empty "$file_path" 2>&1); then
      echo "LINTER ERROR: JSON syntax error in $file_path" >&2
      echo "$output" >&2
      echo "Please fix the JSON syntax error above and retry." >&2
      exit 2
    fi
    ;;
esac

exit 0
