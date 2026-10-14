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
probe 'r["logs"]["verdicts"]["aaa111"]=="PASS" and "zzz999" not in r["logs"]["verdicts"]'; check "real 'VERDICT: PASS' line parsed (status, not the token VERDICT:)" $?
probe 'r["logs"]["verdicts"]["bbb222"]=="NO_VERDICT" and r["logs"]["no_verdict"]==["bbb222"]'; check "NO_VERDICT then GIVEUP flagged; recovered NO_VERDICT (aaa111) not flagged" $?
probe 'r["logs"]["gate_giveups"]==["bbb222"] and len(r["logs"]["verdict_events"]["bbb222"])==2'; check "gate give-up is its own finding and history is kept" $?
probe 'len(r["logs"]["notifications"])==1 and r["logs"]["stop_gate_count"]==2'; check "notifications windowed to session; stop-gate counter joined" $?

TEXT=$(python3 "$SCRIPT" "$FX/with-subagents/sess-a.jsonl" --temp-dir "$FX/with-subagents/temp"); rc=$?
check "text run exits 0" "$rc"
grep -q 'unpriced' <<<"$TEXT"; check "text report flags unpriced" $?
grep -q 'FINDING: NO_VERDICT' <<<"$TEXT"; check "text report shows NO_VERDICT finding" $?
grep -q 'FINDING: verdict gate gave up on bbb222' <<<"$TEXT"; check "text report shows give-up finding" $?
grep -q 'from --temp-dir' <<<"$TEXT"; check "text report names the temp dir used" $?
! grep -q 'ASSUMED cache-read rate' <<<"$TEXT"; check "no assumed-rate note when no assumed model is used" $?

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

JSON=$(python3 "$SCRIPT" "$FX/tooluse-nested/sess-d.jsonl" --json --temp-dir "$FX/tooluse-nested/temp")
probe 'r["logs"]["verdicts"]=={"ddd444":"DONE","eee555":"FAIL"}'; check "DONE and FAIL verdicts reported (exact hook format)" $?

# idle classes: human prompt ends the 2h gap (awaiting user); tool result ends the 25m gap (agent)
JSON=$(python3 "$SCRIPT" "$FX/idle-user/sess-f.jsonl" --json --temp-dir "$FX/nonexistent")
probe 'len(r["awaiting_user_gaps"])==1 and r["awaiting_user_gaps"][0]["minutes"]==120.0 and len(r["idle_gaps"])==1 and r["idle_gaps"][0]["minutes"]==29.9'; check "idle gaps split into awaiting-user vs agent" $?

# malformed shapes: bad JSON lines, missing/non-dict usage, string and list counts, synthetic model,
# list-valued meta fields, naive timestamps, stray non-jsonl file in subagents/
OUT=$(python3 "$SCRIPT" "$FX/malformed/sess-m.jsonl" --temp-dir "$FX/nonexistent" 2>&1); rc=$?
check "malformed fixture exits 0" "$rc"
! grep -q Traceback <<<"$OUT"; check "malformed fixture no traceback" $?
JSON=$(python3 "$SCRIPT" "$FX/malformed/sess-m.jsonl" --json --temp-dir "$FX/nonexistent")
# main: m1 1000*4 + 500*20 + 2000(5m write)*5 = 0.024 ; m5 100*20 = 0.002 ; m4 synthetic = 0
probe 'abs(r["seats"]["main"]["cost"]-0.026)<1e-9 and r["seats"]["main"]["input"]==1005'; check "string counts coerced, bad fields counted as 0, synthetic free" $?
probe '"<synthetic>" in r["models"] and not r["models"]["<synthetic>"]["unpriced"] and r["totals"]["unpriced_models"]==["claude-mystery-1"]'; check "<synthetic> not reported as unpriced" $?
probe 'len(r["warnings"])==3'; check "each bad shape produces a counted warning (non-dict usage, cache_creation, list count)" $?
# fff666: sonnet 1000*2 + 100*10 = 0.003, plus an unpriced model -> partial; list/dict meta ignored
probe 'abs(r["seats"]["fff666"]["cost"]-0.003)<1e-9 and r["seats"]["fff666"]["partial"] is True and r["tree"]["fff666"]["depth"]==1'; check "mixed priced/unpriced seat marked partial; list-valued meta ignored" $?
probe 'list(r["transcripts"])==["main","fff666"]'; check "stray non-jsonl file in subagents/ ignored" $?

# unreadable subagent transcript -> warning, not traceback
TMP=$(mktemp -d); mkdir -p "$TMP/s/subagents"
echo '{"type":"user","timestamp":"2026-01-01T10:00:00Z"}' > "$TMP/s.jsonl"
echo '{}' > "$TMP/s/subagents/agent-uuu.jsonl"; chmod 000 "$TMP/s/subagents/agent-uuu.jsonl"
OUT=$(python3 "$SCRIPT" "$TMP/s.jsonl" --temp-dir "$TMP/none" 2>&1); rc=$?
check "unreadable transcript exits 0" "$rc"
grep -q 'unreadable' <<<"$OUT" && ! grep -q Traceback <<<"$OUT"; check "unreadable transcript is a warning" $?
chmod 600 "$TMP/s/subagents/agent-uuu.jsonl"; rm -rf "$TMP"

# parent-only: workers counted from the parent's toolUseResult usage; no double count with child transcripts
JSON=$(python3 "$SCRIPT" "$FX/parent-only/sess-p.jsonl" --json --temp-dir "$FX/nonexistent")
probe 'r["seats"]["hhh888"]["input"]==1000 and r["seats"]["hhh888"]["cache_read"]==10000 and r["seats"]["hhh888"]["cost"] is None and r["seats"]["hhh888"]["source"]=="toolUseResult"'; check "parent-only: tokens counted, model unknown -> unpriced" $?
probe 'abs(r["seats"]["iii999"]["cost"]-0.007)<1e-9'; check "parent-only: model from toolUseResult prices the seat" $?
probe 'abs(r["seats"]["jjj000"]["cost"]-0.0024)<1e-9 and r["seats"]["jjj000"]["calls"]==1 and r["seats"]["jjj000"]["source"]=="transcript"'; check "agent with child transcript is not double counted" $?
python3 "$SCRIPT" "$FX/parent-only/sess-p.jsonl" --temp-dir "$FX/nonexistent" | grep -q 'model unknown'; check "text report marks unknown model explicitly" $?

# default temp dir comes from the transcript cwd; assumed-rate models are marked
TMP=$(mktemp -d); mkdir -p "$TMP/proj/temp"
echo '2026-01-01T10:00:00Z agent_id=main VERDICT: PASS' > "$TMP/proj/temp/verdict-audit.log"
printf '{"type":"assistant","timestamp":"2026-01-01T10:00:00Z","cwd":"%s","message":{"id":"m","model":"claude-sonnet-5","usage":{"input_tokens":1,"output_tokens":1}}}\n' "$TMP/proj" > "$TMP/s.jsonl"
JSON=$(python3 "$SCRIPT" "$TMP/s.jsonl" --json)
probe 'r["logs"]["temp_dir"].endswith("/proj/temp") and r["logs"]["temp_dir_source"]=="transcript cwd" and r["logs"]["verdicts"]=={"main":"PASS"}'; check "default temp dir = transcript cwd/temp" $?
probe 'r["models"]["claude-sonnet-5"]["assumed_cache_read"] is True'; check "assumed cache-read flagged in JSON" $?
python3 "$SCRIPT" "$TMP/s.jsonl" | grep -q 'ASSUMED cache-read rate for claude-sonnet-5'; check "assumed rate shown in text report" $?
rm -rf "$TMP"

python3 "$SCRIPT" "$FX/does-not-exist.jsonl" >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 ]]; check "missing session file exits non-zero" $?

echo "$((total - fail))/$total passed"
[[ $fail -eq 0 ]]
