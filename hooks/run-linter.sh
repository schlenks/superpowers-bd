#!/usr/bin/env bash
# PostToolUse linter guard for Write|Edit tool calls.
# Reads hook JSON from stdin, extracts tool_input.file_path via jq,
# runs appropriate linter based on file extension.
# Exit 2 blocks the operation and surfaces errors to Claude for self-correction.
# Exit 0 means no issues (or unsupported file type / missing tool).
#
# Supported: *.sh (shellcheck), *.json (jq),
#   *.py|*.js|*.ts|*.tsx|*.jsx|*.go|*.java|*.c|*.cpp|*.h|*.hpp|*.rb|*.swift|*.rs (lizard)
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
  *.py|*.js|*.ts|*.tsx|*.jsx|*.go|*.java|*.c|*.cpp|*.h|*.hpp|*.rb|*.swift|*.rs)
    if ! command -v lizard &>/dev/null; then
      echo "Tip: install lizard for complexity checking: pip install lizard" >&2
      exit 0
    fi
    # Pass 1: block on CC>15 or length>100
    block_output=$(lizard -C 15 -L 100 -w "$file_path" 2>/dev/null || true)
    if [[ -n "$block_output" ]]; then
      echo "COMPLEXITY ERROR: functions exceed critical thresholds in $file_path" >&2
      echo "$block_output" >&2
      echo "Functions with CC>15 must be decomposed. Functions >100 lines must be split." >&2
      exit 2
    fi
    # Pass 2: warn on CC>10 or length>50
    warn_output=$(lizard -C 10 -L 50 -w "$file_path" 2>/dev/null || true)
    if [[ -n "$warn_output" ]]; then
      echo "COMPLEXITY WARNING: functions exceed advisory thresholds in $file_path" >&2
      echo "$warn_output" >&2
      echo "Consider extracting branches into helper functions or splitting long functions." >&2
    fi
    ;;
esac

exit 0
