#!/bin/bash
# Broken/minimal-PATH probe for superpowers-bd Claude hooks.
# Invokes each hooks.json command the way Claude Code does (/bin/sh -c '<command>')
# under three PATH regimes, with a representative stdin payload, in a scratch git
# repo. Records exit code, stdout, stderr. Read-only w.r.t. the repo (writes only
# to the scratch project dir).
set -u
REPO=/Users/schlenks/Developer/personal/superpowers-bd
OUT=$REPO/temp/research-2026-10/execution-modes/probes/out/path
SCR=/private/tmp/claude-501/-Users-schlenks-Developer-personal-superpowers-bd/f106b9af-86ea-49c2-9f8f-6dd4bdaf5523/scratchpad/execmodes-path
rm -rf "$SCR" "$OUT"; mkdir -p "$SCR" "$OUT"

mkproj() { # $1 = dir, $2 = wave(0/1)
  mkdir -p "$1/temp"; ( cd "$1" && /usr/bin/git init -q -b main . && printf 'echo hi\n' > a.sh && /usr/bin/git add -A && /usr/bin/git -c user.name=p -c user.email=p@p commit -qm init )
  # shellcheck disable=SC2016
  printf '#!/bin/bash\nx=$1\necho $x\n' > "$1/a.sh"
  [ "$2" = 1 ] && : > "$1/temp/sdd-wave-active-probe.flag"
}

payload() { # $1 = event, $2 = projdir
  case "$1" in
    session-start.sh|link-plugin-components.sh) printf '{"session_id":"s1","transcript_path":"/nonexistent","cwd":"%s","hook_event_name":"SessionStart","source":"startup","model":"claude-opus-5-5[1m]"}' "$2" ;;
    work-state-anchor.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"continue"}' "$2" ;;
    run-linter.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s/a.sh","content":"x"},"tool_response":{"success":true}}' "$2" "$2" ;;
    task-completed.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"TaskCompleted","task_id":"1","task_subject":"Verify implementation","task_description":"run tests"}' "$2" ;;
    verdict-audit.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"SubagentStop","agent_id":"a1","agent_type":"general-purpose","stop_hook_active":false,"last_assistant_message":"I finished the work."}' "$2" ;;
    notification.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Notification","message":"done","notification_type":"agent_completed"}' "$2" ;;
    stop-gate.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"The implementation is complete."}' "$2" ;;
    session-end.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"SessionEnd","reason":"other"}' "$2" ;;
    pre-compact.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreCompact","trigger":"auto"}' "$2" ;;
  esac
}

HOOKS="session-start.sh link-plugin-components.sh work-state-anchor.sh run-linter.sh task-completed.sh verdict-audit.sh notification.sh stop-gate.sh session-end.sh pre-compact.sh"
printf 'regime\twave\thook\texit\tstdout_bytes\tstdout_json\tstderr_first_line\n' > "$OUT/summary.tsv"
for regime in normal minimal broken; do
  case "$regime" in
    normal)  P="$PATH" ;;
    minimal) P="/usr/bin:/bin:/usr/sbin:/sbin" ;;
    broken)  P="/nonexistent" ;;
  esac
  for wave in 0 1; do
    proj="$SCR/$regime-w$wave"; mkproj "$proj" "$wave"
    for h in $HOOKS; do
      base="$OUT/$regime-w$wave-$h"
      payload "$h" "$proj" > "$base.in"
      cmd="\"\${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" $h"
      ( cd "$proj" && /usr/bin/env -i PATH="$P" HOME="$HOME" CLAUDE_PLUGIN_ROOT="$REPO" CLAUDE_PROJECT_DIR="$proj" \
          /usr/bin/perl -e 'alarm 30; exec @ARGV' /bin/sh -c "$cmd" < "$base.in" > "$base.out" 2> "$base.err" )
      rc=$?
      if /usr/bin/python3 -c 'import json,sys; s=open(sys.argv[1]).read().strip(); json.loads(s) if s else None' "$base.out" 2>/dev/null; then js=ok; else js=INVALID; fi
      [ -s "$base.out" ] || js=empty
      e1=$(/usr/bin/head -1 "$base.err" | /usr/bin/cut -c1-160)
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$regime" "$wave" "$h" "$rc" "$(/usr/bin/wc -c < "$base.out" | /usr/bin/tr -d ' ')" "$js" "$e1" >> "$OUT/summary.tsv"
    done
  done
done
/usr/bin/column -t -s $'\t' "$OUT/summary.tsv"
