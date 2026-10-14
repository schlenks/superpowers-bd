: << 'CMDBLOCK'
@echo off
REM Polyglot wrapper: runs .sh scripts cross-platform
REM Usage: run-hook.cmd <script-name> [args...]
REM The script should be in the same directory as this wrapper

if "%~1"=="" (
    echo run-hook.cmd: missing script name >&2
    exit /b 1
)
"C:\Program Files\Git\bin\bash.exe" -l "%~dp0%~1" %2 %3 %4 %5 %6 %7 %8 %9
exit /b
CMDBLOCK

# Unix shell runs from here. Builtins only until the exec: PATH may be broken
# (cron, launchd, GUI app), so dirname and `env bash` are off-limits.
# Contract: run-hook.cmd <script> [args] runs <script> with bash >= 4 when one
# is available (known absolute paths first, then PATH), otherwise /bin/bash
# (hook scripts are bash 3.2-safe), without needing <script>'s exec bit.
# Absolute install locations win over PATH, so a PATH-relative or repo-planted
# bash is used only when no known absolute one qualifies. Every Claude hook
# launches here, so launcher trouble fails open: one "run-hook.cmd:" stderr
# line, exit 0, never a blocked session.
# SUPERPOWERS_BD_BASH_CANDIDATES (tests only) replaces the absolute lists.
skip() { echo "run-hook.cmd: $1; skipping hook" >&2; exit 0; }
case "$0" in */*) d=${0%/*} ;; *) skip "cannot locate hook directory from '$0'" ;; esac
script=${1:-}
[ "$#" -gt 0 ] && shift
if [ -z "$script" ] || [ ! -f "$d/$script" ]; then
    skip "hook script '$script' not found in $d"
fi
preferred=${SUPERPOWERS_BD_BASH_CANDIDATES-/opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash}
last_resort=${SUPERPOWERS_BD_BASH_CANDIDATES-/bin/bash}
# shellcheck disable=SC2016  # the version test runs inside the candidate bash
is_bash4() { "$1" -c '[ "${BASH_VERSINFO[0]}" -ge 4 ]' 2>/dev/null; }
interp=
# shellcheck disable=SC3028  # BASH_VERSINFO is read only when $BASH is a bash
case "${BASH:-}" in
    */bash) [ "${BASH_VERSINFO:-0}" -ge 4 ] 2>/dev/null && interp=$BASH ;;
esac
if [ -z "$interp" ]; then
    for candidate in $preferred; do
        if [ -x "$candidate" ]; then interp=$candidate; break; fi
    done
fi
if [ -z "$interp" ]; then
    found=$(command -v bash 2>/dev/null) || found=
    case "$found" in /*) is_bash4 "$found" && interp=$found ;; esac
fi
if [ -z "$interp" ]; then
    for candidate in $last_resort; do
        if [ -x "$candidate" ]; then interp=$candidate; break; fi
    done
fi
[ -n "$interp" ] || skip "no bash found for $script"
exec "$interp" "$d/$script" "$@"
