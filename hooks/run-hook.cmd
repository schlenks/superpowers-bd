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
# is available, otherwise /bin/bash, without needing PATH or <script>'s exec
# bit. Every Claude hook launches here, so launcher trouble fails open: one
# stderr line, exit 0, never a blocked session.
case "$0" in */*) d=${0%/*} ;; *) d=. ;; esac
script=${1:-}
[ "$#" -gt 0 ] && shift
if [ -z "$script" ] || [ ! -f "$d/$script" ]; then
    echo "run-hook.cmd: hook script '$script' not found in $d; skipping" >&2
    exit 0
fi
interp=
case "${BASH:-}" in
    */bash) [ "${BASH_VERSINFO:-0}" -ge 4 ] 2>/dev/null && interp=$BASH ;;
esac
if [ -z "$interp" ]; then
    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /bin/bash; do
        if [ -x "$candidate" ]; then interp=$candidate; break; fi
    done
fi
if [ -z "$interp" ]; then
    echo "run-hook.cmd: no bash found for $script; skipping hook" >&2
    exit 0
fi
exec "$interp" "$d/$script" "$@"
