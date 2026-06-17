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

# Extract fields via jq if available; fall back to unknown for audit continuity.
# parsed=1 only when we could actually read the payload — the gate below must NOT
# treat an unparsed (jq-less) payload as NO_VERDICT, or it would block every stop.
if command -v jq &>/dev/null; then
  parsed=1
  agent_type=$(echo "$input" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")
  agent_id=$(echo "$input" | jq -r '.agent_id // "unknown"' 2>/dev/null || echo "unknown")
  last_message=$(echo "$input" | jq -r '.last_assistant_message // ""' 2>/dev/null || echo "")
else
  parsed=0
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

# --- Verdict gate (enforcement) ---
# During an active SDD wave, a subagent that stops WITHOUT a verdict is sent back
# to emit one. Gated by the wave-active flag, NOT agent_type — every SDD subagent
# reports general-purpose/empty, so agent_type cannot distinguish reviewers from
# implementers (verified in verdict-audit.log). Bounded per agent_id so a subagent
# that genuinely cannot produce a verdict is not trapped in a loop.
# Escape hatch: SDD_ALLOW_NO_VERDICT=1.
if [[ "$parsed" == "1" && "$verdict" == "NO_VERDICT" && "${SDD_ALLOW_NO_VERDICT:-}" != "1" ]]; then
  wave_active=0
  for f in "$log_dir"/sdd-wave-active-*.flag; do
    [[ -f "$f" ]] && { wave_active=1; break; }
  done

  if [[ "$wave_active" == "1" ]]; then
    count_file="$log_dir/verdict-gate-${agent_id}.count"
    count=0
    [[ -f "$count_file" ]] && count=$(cat "$count_file" 2>/dev/null || echo 0)
    case "$count" in *[!0-9]*|"") count=0 ;; esac

    if [[ "$count" -lt 2 ]]; then
      printf '%s\n' "$((count + 1))" > "$count_file"
      printf '{"decision":"block","reason":"%s"}\n' "You stopped during an active SDD wave without a verdict. End your final message with a line that begins 'VERDICT:' (PASS, FAIL, or WITH_FIXES for reviews; DONE for implementation) plus brief evidence, then stop."
      exit 0
    fi

    # Retry budget exhausted — release the subagent but record the give-up.
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) agent_id=${agent_id} VERDICT_GATE_GIVEUP after ${count} blocks" >> "$log_file" || true
  fi
fi

exit 0
