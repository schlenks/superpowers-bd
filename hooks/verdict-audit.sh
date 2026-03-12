#!/usr/bin/env bash
# SubagentStop audit hook — parses VERDICT from subagent final messages.
# Reads hook JSON from stdin, extracts agent_type/agent_id/last_assistant_message,
# greps for the VERDICT line, and appends an audit entry to temp/verdict-audit.log.
# Always exits 0 (audit-only, never blocks).

set -euo pipefail

log_dir="${CLAUDE_PROJECT_DIR:-.}/temp"
log_file="$log_dir/verdict-audit.log"

# Read stdin (SubagentStop hook provides JSON with agent_type, agent_id, last_assistant_message)
input=$(cat)

# Extract fields via jq if available; fall back to unknown for audit continuity
if command -v jq &>/dev/null; then
  agent_type=$(echo "$input" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")
  agent_id=$(echo "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null || echo "unknown")
  last_message=$(echo "$input" | jq -r '.last_assistant_message // ""' 2>/dev/null || echo "")
else
  agent_type="unknown"
  agent_id="unknown"
  last_message=""
fi

# Extract VERDICT line from the final message (first match wins)
# grep exits non-zero when no match; || true prevents set -e from aborting
verdict=$(echo "$last_message" | grep -m1 '^VERDICT:' || true)
if [[ -z "$verdict" ]]; then
  verdict="NO_VERDICT"
fi

# temp/ directory should already exist; create only if missing (e.g. fresh clone)
[[ -d "$log_dir" ]] || mkdir -p "$log_dir"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) agent_type=${agent_type} agent_id=${agent_id} ${verdict}" >> "$log_file" || true

exit 0
