#!/usr/bin/env bash
# Tests scripts/sdd-postmortem.py against synthetic fixtures with hand-computed dollars.
# Prices used (per M tokens, claude-api table cached 2026-10-06): opus-5-5 in 4 / out 20 /
# cache-read 0.20 / write5m 5; sonnet-5-5 in 2 / out 10 / cache-read 0.20 / write1h 4;
# haiku-5-5 <=100K request: 0.10/0.50, >100K: 0.50/2.50, cache-read 0.1x input.
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

# controller: 1000*4 + 2000*20 + 100000*0.2 + 10000*5 (+ m2 1000*20) per M = 0.134
probe 'abs(r["seats"]["main"]["cost"]-0.134)<1e-9'; check "controller dollars (cache read at cache rate)" $?
# aaa111: 2000*2 + 1000*10 + 200000*0.2 + 4000*4 per M = 0.070 ; duplicate message id counted once
probe 'abs(r["seats"]["aaa111"]["cost"]-0.070)<1e-9'; check "subagent dollars (dedupe by message id, 1h write rate)" $?
probe 'r["seats"]["bbb222"]["cost"] is None and r["seats"]["bbb222"]["unpriced"]'; check "unknown model reported unpriced, not guessed" $?
probe 'abs(r["totals"]["cost"]-0.204)<1e-9 and r["totals"]["unpriced_models"]==["claude-mystery-1"]'; check "total excludes unpriced and names it" $?
probe 'abs(r["models"]["claude-opus-5-5"]["cost"]-0.134)<1e-9 and r["models"]["claude-sonnet-5-5"]["cache_read"]==200000'; check "per-model tokens and dollars" $?
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
probe 'abs(r["seats"]["ccc333"]["cost"]-0.012)<1e-9 and r["tree"]["ccc333"]["depth"]==1'; check "missing meta.json: seat priced, attached to controller" $?

# toolUseId-only meta: ddd444 launched by main (toolu_A), eee555 by ddd444 (toolu_B) -> depth 2
JSON=$(python3 "$SCRIPT" "$FX/tooluse-nested/sess-d.jsonl" --json --temp-dir "$FX/nonexistent")
probe 'r["tree"]["ddd444"]["depth"]==1 and r["tree"]["eee555"]["depth"]==2 and r["tree"]["eee555"]["parent"]=="ddd444"'; check "toolUseId-only meta derives nested parent" $?
# haiku-5-5 tiers per request: ddd444 50000in(<=100K): 50000*0.1+1000*0.5 = 0.0055
#   eee555 10000in+100000cr (110K, >100K): 10000*0.5+1000*2.5+100000*0.05 = 0.0125
probe 'abs(r["seats"]["ddd444"]["cost"]-0.0055)<1e-9 and abs(r["seats"]["eee555"]["cost"]-0.0125)<1e-9'; check "haiku-5-5 tier chosen per request input size" $?

python3 "$SCRIPT" "$FX/does-not-exist.jsonl" >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 ]]; check "missing session file exits non-zero" $?

echo "$((total - fail))/$total passed"
[[ $fail -eq 0 ]]
