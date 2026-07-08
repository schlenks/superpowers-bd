#!/usr/bin/env bash
# Stop hook: re-assert verification-before-completion. When the main agent ends a
# turn claiming completion WITHOUT evidence, AND there is live work in flight,
# send it back to verify. Deliberately narrow to avoid false-positive nags:
#
#   - fires only when work is live (an SDD wave flag, or in_progress beads work)
#   - fires only on completion-claim language with NO evidence markers present
#
# Loop safety (the Stop-hook footgun): bail if stop_hook_active is already set,
# and cap blocks per session via a counter file. Override with SDD_ALLOW_STOP=1.
# Always exits 0; a block is expressed via the decision JSON, never a non-zero exit.

set -euo pipefail

# Escape hatch — accept the risk and let the turn end.
if [ "${SDD_ALLOW_STOP:-}" = "1" ]; then
  exit 0
fi

input=$(cat)

# jq is required to parse the payload; without it, fail safe (never block).
command -v jq >/dev/null 2>&1 || exit 0

stop_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
last_message=$(printf '%s' "$input" | jq -r '.last_assistant_message // ""' 2>/dev/null || echo "")
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Loop guard: we are already in a stop-hook-triggered continuation.
if [ "$stop_active" = "true" ]; then
  exit 0
fi

temp_dir="${CLAUDE_PROJECT_DIR:-.}/temp"

# Liveness gate: only enforce while there is work in flight, so ordinary
# conversation that happens to say "done" is never interrupted.
work_live=0
for f in "$temp_dir"/sdd-wave-active-*.flag; do
  [ -f "$f" ] && { work_live=1; break; }
done
if [ "$work_live" = 0 ] && command -v bd >/dev/null 2>&1; then
  ip=$(bd list --status in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || echo "")
  if [ -n "$ip" ] && [ "$ip" -gt 0 ] 2>/dev/null; then
    work_live=1
  fi
fi
[ "$work_live" = 0 ] && exit 0

# Completion claim with no evidence?
# NOTE: 'ready to merge'/'ready for review' are deliberately absent — those are
# reviewer-verdict vocabulary, not the orchestrator's own claim. During SDD the
# main agent relays those constantly (MONITOR/REVIEW), so matching them here is a
# category error that fires on every status turn.
claim_re='is (now )?complete|is (now )?fixed|is (now )?done|implementation (is )?complete|successfully (implemented|completed|fixed)|all tests pass|everything works|work is done|task is done'
evidence_re='exit code[ :]*[0-9]+|[0-9]+ (tests? )?(passed|passing)|0 failures|output:|evidence:|✓|✅|ran (npm|pnpm|yarn|pytest|go test|cargo|make|bash|sh|node|python|python3|\./[^[:space:]]+)|executed (npm|pnpm|yarn|pytest|go test|cargo|make|bash|sh|node|python|python3|\./[^[:space:]]+)|result:|passed|no .*fail'

printf '%s' "$last_message" | grep -qiE "$claim_re" || exit 0
printf '%s' "$last_message" | grep -qiE "$evidence_re" && exit 0

# Not a sign-off? A warranted block is a declarative, terminal "it's done" claim.
# Completion vocabulary also shows up when the turn is NOT signing off — either
# reporting work still in flight (relaying subagent/reviewer status) or soliciting
# the user's direction (a question / offer to proceed). Neither is a completion
# claim, so don't nag. Declarative claims fall through to the block below.
inflight_re='still (work|runn|go|pend|open|await)|waiting (on|for)|holding|in flight|in progress|not (yet )?(complete|done|finish)|stays open|remains open|[0-9]+ of [0-9]+|awaiting'
solicit_re='want me to|shall i|should i|do you want|would you like|awaiting your|your (go-ahead|call|decision|preference)'
printf '%s' "$last_message" | grep -qiE "$inflight_re" && exit 0
printf '%s' "$last_message" | grep -qiE "$solicit_re" && exit 0
# Trailing question mark → soliciting input, not declaring done.
trimmed=$(printf '%s' "$last_message" | sed -e 's/[[:space:]]*$//')
case "$trimmed" in *\?) exit 0 ;; esac

# Bounded per-session counter so a degenerate case cannot nag indefinitely.
count_file="$temp_dir/stop-gate-${session_id}.count"
count=0
[ -f "$count_file" ] && count=$(cat "$count_file" 2>/dev/null || echo 0)
case "$count" in *[!0-9]*|"") count=0 ;; esac
[ "$count" -ge 3 ] && exit 0

[ -d "$temp_dir" ] || mkdir -p "$temp_dir"
printf '%s\n' "$((count + 1))" > "$count_file"

printf '{"decision":"block","reason":"%s"}\n' "You are ending the turn with a completion claim but no verification evidence. Run the relevant check (tests, build, or lint) and quote its output — or invoke the verification-before-completion skill — before stopping. Set SDD_ALLOW_STOP=1 to override."
exit 0
