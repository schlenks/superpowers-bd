#!/usr/bin/env bash
# PostToolUse audit logger for Write|Edit tool calls.
# Reads hook JSON from stdin, extracts tool_name and file_path,
# appends to $CLAUDE_PROJECT_DIR/.claude/file-modifications.log.
# Always exits 0 (never blocks the agent).
#
# Workaround context: This hook is defined in agent frontmatter.
# Plugin frontmatter hooks are broken (#17688), so link-plugin-components.sh
# copies hooked agents to .claude/agents/ where hooks fire correctly.

set -euo pipefail

log_dir="${CLAUDE_PROJECT_DIR:-.}/.claude"
log_file="$log_dir/file-modifications.log"

# Read stdin (hook provides JSON with tool_name, tool_input, etc.)
input=$(cat)

# Extract fields via jq if available, otherwise skip gracefully
if command -v jq &>/dev/null; then
  tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null || echo "unknown")
else
  tool_name="unknown"
  file_path="unknown"
fi

mkdir -p "$log_dir"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ${tool_name} ${file_path}" >> "$log_file"

exit 0
