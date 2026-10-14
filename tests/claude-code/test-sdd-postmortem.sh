#!/usr/bin/env bash
# Tests scripts/sdd-postmortem.py against synthetic fixtures with hand-computed dollars.
# Prices used (per M tokens): opus-5-5 in 5 / out 25 / cache-read 0.5 / write5m 6.25;
# sonnet-5-5 in 3 / out 15 / cache-read 0.3 / write1h 6.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/sdd-postmortem.py"
FX="$ROOT/tests/claude-code/fixtures/postmortem"
fail=0; total=0

check() { # name, condition-exit
  total=$((total + 1))
  if [[ "$2" -eq 0 ]]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=$((fail + 1)); fi
}

# jq-free JSON probe: python3 -c with expression over parsed report "r"
probe() { python3 -c 'import json,sys; r=json.load(sys.stdin); sys.exit(0 if ('"$1"') else 1)' <<<"$JSON"; }

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: $SCRIPT missing"; exit 1
fi

JSON=$(python3 "$SCRIPT" "$FX/with-subagents/sess-a.jsonl" --json --temp-dir "$FX/with-subagents/temp"); rc=$?
check "json run exits 0" "$rc"

# controller: 1000*5 + 2000*25 + 100000*0.5 + 10000*6.25 (+ m2 1000*25) per M = 0.1925
probe 'abs(r["seats"]["main"]["cost"]-0.1925)<1e-9'; check "controller dollars (cache read at cache rate)" $?
# aaa111: 2000*3 + 1000*15 + 200000*0.3 + 4000*6 per M = 0.105 ; duplicate message id counted once
probe 'abs(r["seats"]["aaa111"]["cost"]-0.105)<1e-9'; check "subagent dollars (dedupe by message id, 1h write rate)" $?
probe 'r["seats"]["bbb222"]["cost"] is None and r["seats"]["bbb222"]["unpriced"]'; check "unknown model reported unpriced, not guessed" $?
probe 'abs(r["totals"]["cost"]-0.2975)<1e-9 and r["totals"]["unpriced_models"]==["claude-mystery-1"]'; check "total excludes unpriced and names it" $?
probe 'abs(r["models"]["claude-opus-5-5"]["cost"]-0.1925)<1e-9 and r["models"]["claude-sonnet-5-5"]["cache_read"]==200000'; check "per-model tokens and dollars" $?
probe 'r["tree"]["bbb222"]["depth"]==2 and r["tree"]["bbb222"]["parent"]=="aaa111" and r["tree"]["aaa111"]["depth"]==1'; check "nested depth in tree" $?
probe 'len(r["idle_gaps"])==1 and r["idle_gaps"][0]["minutes"]>16 and ":" in r["idle_gaps"][0]["evidence"]'; check "idle gap over 10 minutes detected with path:line" $?
probe 'len(r["waves"])>=1'; check "wave timeline present" $?
probe 'r["logs"]["verdicts"]["aaa111"]=="DONE" and r["logs"]["verdicts"]["bbb222"]=="NO_VERDICT" and "zzz999" not in r["logs"]["verdicts"]'; check "verdict-audit joined by agent id" $?
probe 'len(r["logs"]["notifications"])==1 and r["logs"]["stop_gate_count"]==2'; check "notifications windowed to session; stop-gate counter joined" $?

TEXT=$(python3 "$SCRIPT" "$FX/with-subagents/sess-a.jsonl" --temp-dir "$FX/with-subagents/temp"); rc=$?
check "text run exits 0" "$rc"
grep -q 'unpriced' <<<"$TEXT"; check "text report flags unpriced" $?
grep -q 'NO_VERDICT' <<<"$TEXT"; check "text report shows NO_VERDICT" $?

for f in no-subagents/sess-b no-meta/sess-c; do
  OUT=$(python3 "$SCRIPT" "$FX/$f.jsonl" --temp-dir "$FX/nonexistent" 2>&1); rc=$?
  check "degenerate $f exits 0" "$rc"
  ! grep -q Traceback <<<"$OUT"; check "degenerate $f no traceback" $?
done
JSON=$(python3 "$SCRIPT" "$FX/no-subagents/sess-b.jsonl" --json --temp-dir "$FX/nonexistent")
probe 'list(r["seats"])==["main"] and r["tree"]=={}'; check "zero subagents: only controller seat" $?
JSON=$(python3 "$SCRIPT" "$FX/no-meta/sess-c.jsonl" --json --temp-dir "$FX/nonexistent")
probe 'abs(r["seats"]["ccc333"]["cost"]-0.018)<1e-9 and r["tree"]["ccc333"]["depth"]==1'; check "missing meta.json: seat priced, attached to controller" $?

python3 "$SCRIPT" "$FX/does-not-exist.jsonl" >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 ]]; check "missing session file exits non-zero" $?

echo "$((total - fail))/$total passed"
[[ $fail -eq 0 ]]
