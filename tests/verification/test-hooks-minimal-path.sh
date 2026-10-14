#!/usr/bin/env bash
# Hooks must survive the launch environments Claude Code gives them outside a
# login shell: cron, launchd and the GUI app (minimal PATH), a broken PATH, the
# macOS /bin/bash 3.2, and repackagers that strip exec bits.
#
# Each hooks/hooks.json command is run the way Claude Code runs it
# (/bin/sh -c '<command>') under PATH=/nonexistent and PATH=/usr/bin:/bin:/usr/sbin:/sbin.
# A hook may exit 0 or block with 2; it must never crash with "unbound variable"
# or vanish with 126/127 because the launcher could not resolve a binary.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

pass=0
fail=0

ok() { echo "  ✓ $1"; pass=$((pass + 1)); }
bad() { echo "  ✗ $1"; fail=$((fail + 1)); }

payload() { # $1 = script, $2 = project dir
  case "$1" in
    session-start.sh|link-plugin-components.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$2" ;;
    work-state-anchor.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"continue"}' "$2" ;;
    run-linter.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s/a.sh"},"tool_response":{"success":true}}' "$2" "$2" ;;
    task-completed.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"TaskCompleted","task_id":"1","task_subject":"Verify implementation"}' "$2" ;;
    verdict-audit.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"SubagentStop","agent_id":"a1","agent_type":"general-purpose","stop_hook_active":false,"last_assistant_message":"Done."}' "$2" ;;
    notification.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Notification","message":"done","notification_type":"agent_completed"}' "$2" ;;
    stop-gate.sh) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"The implementation is complete."}' "$2" ;;
    *) printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Other"}' "$2" ;;
  esac
}

mkproj() {
  mkdir -p "$1/temp"
  git -C "$1" init -q -b main
  printf '#!/bin/bash\necho hi\n' > "$1/a.sh"
}

# ─── Test 1: every hooks.json command under broken and minimal PATH ──────
echo "Test 1: hooks.json commands under broken and minimal PATH"
commands=$(node -e '
  const c = require(process.argv[1]).hooks;
  for (const entries of Object.values(c))
    for (const e of entries) for (const h of e.hooks) console.log(h.command);
' "$REPO_ROOT/hooks/hooks.json")

for regime in /nonexistent /usr/bin:/bin:/usr/sbin:/sbin; do
  proj="$SCRATCH/proj-${regime//[^a-z]/_}"
  mkproj "$proj"
  while IFS= read -r cmd; do
    script=${cmd##* }
    out="$SCRATCH/out"
    err="$SCRATCH/err"
    rc=0
    payload "$script" "$proj" | (cd "$proj" && /usr/bin/env -i PATH="$regime" HOME="$HOME" \
      CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PROJECT_DIR="$proj" /bin/sh -c "$cmd") \
      >"$out" 2>"$err" || rc=$?
    label="$script PATH=$regime"
    if grep -q 'run-hook.cmd:' "$err"; then
      # Exit 0 is also the launcher's fail-open exit; the marker means it skipped the hook.
      bad "$label: launcher skipped the hook ($(head -1 "$err"))"
    elif grep -q 'unbound variable' "$err"; then
      bad "$label: unbound variable ($(head -1 "$err"))"
    elif [[ $rc -ne 0 && $rc -ne 2 ]]; then
      bad "$label: exit $rc ($(head -1 "$err"))"
    elif [[ "$script" == session-start.sh || "$script" == link-plugin-components.sh ]] \
      && ! grep -q '"hookEventName": *"SessionStart"' "$out"; then
      bad "$label: exit $rc but no SessionStart JSON on stdout"
    else
      ok "$label: exit $rc"
    fi
  done <<< "$commands"
done

# ─── Test 2: link-plugin-components.sh under the system bash ─────────────
# /bin/bash is 3.2 on macOS, where "${empty[@]}" is unbound under set -u.
echo "Test 2: link-plugin-components.sh under /bin/bash"
proj="$SCRATCH/link-proj"
mkdir -p "$proj"
for run in first-copy up-to-date; do
  rc=0
  CLAUDE_PROJECT_DIR="$proj" /bin/bash "$REPO_ROOT/hooks/link-plugin-components.sh" "$REPO_ROOT" \
    >"$SCRATCH/out" 2>"$SCRATCH/err" || rc=$?
  if [[ $rc -eq 0 ]] && grep -q '"hookEventName": "SessionStart"' "$SCRATCH/out"; then
    ok "$run run exits 0 with SessionStart JSON"
  else
    bad "$run run: exit $rc ($(head -1 "$SCRATCH/err"))"
  fi
done

# ─── Test 3: run-hook.cmd launcher contract ──────────────────────────────
echo "Test 3: run-hook.cmd launcher contract"
launch="$SCRATCH/launch dir"  # the space checks quoting end to end
mkdir -p "$launch"
cp "$REPO_ROOT/hooks/run-hook.cmd" "$launch/run-hook.cmd"
chmod 0755 "$launch/run-hook.cmd"
# Target scripts stay 0644: the launcher must not need their exec bit.
# shellcheck disable=SC2016  # literal $ vars belong to the generated scripts
printf 'echo "major=${BASH_VERSINFO[0]} arg=$1"\n' > "$launch/probe.sh"
# shellcheck disable=SC2016
printf 'IFS= read -r line; echo "stdin=$line"\n' > "$launch/stdin.sh"
printf 'echo blocked >&2; exit 2\n' > "$launch/block.sh"
chmod 0644 "$launch/probe.sh" "$launch/stdin.sh" "$launch/block.sh"
quoted="\"$launch/run-hook.cmd\""

# Run the launcher the way Claude Code does (/bin/sh -c), with a scrubbed env.
# $1 = extra VAR=val or "", $2 = PATH, $3 = command string.
launch_sh() {
  if [[ -n "$1" ]]; then
    /usr/bin/env -i PATH="$2" HOME="$HOME" "$1" /bin/sh -c "$3"
  else
    /usr/bin/env -i PATH="$2" HOME="$HOME" /bin/sh -c "$3"
  fi
}

out=$(launch_sh "" /nonexistent "$quoted probe.sh hello" 2>&1 || true)
if [[ "$out" == *"arg=hello"* ]]; then
  ok "runs a 0644 script from a path with spaces, PATH=/nonexistent ($out)"
else
  bad "0644 script under PATH=/nonexistent: $out"
fi

out=$(echo 'payload-123' | launch_sh "" /nonexistent "$quoted stdin.sh" 2>&1 || true)
if [[ "$out" == "stdin=payload-123" ]]; then
  ok "stdin reaches the hook"
else
  bad "stdin not forwarded: '$out'"
fi

rc=0
launch_sh "" /nonexistent "$quoted block.sh" >/dev/null 2>&1 || rc=$?
if [[ $rc -eq 2 ]]; then
  ok "exit 2 (blocking) survives the launcher"
else
  bad "block.sh exit 2 came back as $rc"
fi

if [[ -x /opt/homebrew/bin/bash || -x /usr/local/bin/bash ]]; then
  out=$(/usr/bin/env -i PATH=/nonexistent /bin/bash "$launch/run-hook.cmd" probe.sh x 2>&1 || true)
  major=${out#major=}; major=${major%% *}
  if [[ "$major" =~ ^[0-9]+$ && "$major" -ge 4 ]]; then
    ok "prefers bash >= 4 over /bin/bash 3.2 ($out)"
  else
    bad "picked bash $out when a bash >= 4 is installed"
  fi
  bash4_dir=/opt/homebrew/bin
  [[ -x $bash4_dir/bash ]] || bash4_dir=/usr/local/bin
  out=$(launch_sh SUPERPOWERS_BD_BASH_CANDIDATES=/nonexistent/bash "$bash4_dir" "$quoted probe.sh y" 2>&1 || true)
  if [[ "$out" == major=[4-9]*"arg=y" ]]; then
    ok "falls back to a PATH bash >= 4 when no absolute candidate exists ($out)"
  else
    bad "PATH fallback: '$out'"
  fi
else
  echo "  - skipped bash >= 4 preference and PATH fallback: no Homebrew bash installed"
fi

# $1 = label, $2 = rc, $3 = combined output. Fail-open = exit 0, the marker, no hook run.
check_fail_open() {
  if [[ $2 -eq 0 && "$3" == "run-hook.cmd: "* && "$3" != *major=* ]]; then
    ok "$1 fails open with the marker ($3)"
  else
    bad "$1: exit $2, output '$3'"
  fi
}

rc=0
out=$(launch_sh "" /nonexistent "$quoted missing.sh" 2>&1) || rc=$?
check_fail_open "missing script" "$rc" "$out"

rc=0
out=$(launch_sh SUPERPOWERS_BD_BASH_CANDIDATES=/nonexistent/bash /nonexistent "$quoted probe.sh z" 2>&1) || rc=$?
check_fail_open "no bash found" "$rc" "$out"

rc=0
out=$(cd "$launch" && /usr/bin/env -i PATH=/nonexistent /bin/sh run-hook.cmd probe.sh 2>&1) || rc=$?
check_fail_open "slash-less \$0 (no CWD fallback)" "$rc" "$out"

# ─── Test 4: entry scripts find bd under minimal PATH ────────────────────
echo "Test 4: entry scripts backfill PATH so bd resolves under minimal PATH"
bd_dir=""
for d in /opt/homebrew/bin /usr/local/bin; do
  [[ -x "$d/bd" ]] && { bd_dir=$d; break; }
done
if [[ -z "$bd_dir" ]]; then
  echo "  - skipped: bd is not installed in /opt/homebrew/bin or /usr/local/bin"
else
  for f in "$REPO_ROOT"/hooks/*.sh "$REPO_ROOT"/plugins/superpowers-bd/hooks/codex-*.sh; do
    case "${f##*/}" in bd-in-progress-count.sh|codex-plugin-owns-hook.sh) continue ;; esac
    line=$(grep -m1 '^export PATH=' "$f" || true)
    rel=${f#"$REPO_ROOT"/}
    if [[ -z "$line" ]]; then
      bad "$rel: no PATH backfill line"
      continue
    fi
    found=$(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$HOME" /bin/bash -c "$line; command -v bd" || true)
    if [[ "$found" == "$bd_dir/bd" ]]; then
      ok "$rel resolves bd"
    else
      bad "$rel resolved bd to '$found'"
    fi
  done
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
