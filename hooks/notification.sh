#!/usr/bin/env bash
# Notification hook — records background-agent notifications during an active SDD wave.
#
# Since Claude Code 2.1.198 the Notification event fires `agent_needs_input` /
# `agent_completed` for `claude agents` background sessions. Whether it ALSO fires for
# SDD's in-session Task/Agent-tool subagents is UNVERIFIED (the changelog scopes it to
# `claude agents`). This hook only LOGS (never blocks), so it is safe either way: it
# gives wave observability now and the evidence needed to decide whether a reactive
# MONITOR/stall gate on top of `agent_needs_input` is worth building. Always exits 0.

set -euo pipefail

log_dir="${CLAUDE_PROJECT_DIR:-.}/temp"
log_file="$log_dir/sdd-notifications.log"

input=$(cat)

# Only act during an active SDD wave; silent no-op otherwise so normal sessions are untouched.
wave_active=0
for f in "$log_dir"/sdd-wave-active-*.flag; do
  [[ -f "$f" ]] && { wave_active=1; break; }
done
[[ "$wave_active" == "1" ]] || exit 0

# Field names for the agent_needs_input / agent_completed payload are not yet documented,
# so capture broadly and fall back gracefully. jq-less shells still record that a
# notification occurred during the wave.
if command -v jq &>/dev/null; then
  message=$(echo "$input" | jq -r '.message // .notification // ""' 2>/dev/null || echo "")
  ntype=$(echo "$input" | jq -r '.notification_type // .type // .hook_event_name // ""' 2>/dev/null || echo "")
else
  message=""
  ntype=""
fi

[[ -d "$log_dir" ]] || mkdir -p "$log_dir"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) wave_active type=${ntype:-unknown} message=${message:-}" >> "$log_file" || true

exit 0
