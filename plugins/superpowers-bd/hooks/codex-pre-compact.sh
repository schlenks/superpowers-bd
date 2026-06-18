#!/usr/bin/env bash
# PreCompact hook for Codex: block compaction during active SDD waves.

set -euo pipefail

input=$(cat)

if [ "${SDD_ALLOW_COMPACT:-}" = "1" ]; then
  printf '{"continue":true}\n'
  exit 0
fi

project_dir=""
if command -v jq >/dev/null 2>&1; then
  project_dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
if [ -z "$project_dir" ]; then
  project_dir="$(pwd)"
fi

temp_dir="${project_dir}/temp"
if [ -d "$temp_dir" ]; then
  for flag in "${temp_dir}"/sdd-wave-active-*.flag; do
    [ -f "$flag" ] || continue
    base="${flag##*/}"
    epic="${base#sdd-wave-active-}"
    epic="${epic%.flag}"
    reason="Compaction blocked: SDD wave in flight for epic ${epic}. Let the current wave finish before compacting. If this flag is stale, remove ${flag} or set SDD_ALLOW_COMPACT=1."
    jq -nc --arg reason "$reason" '{decision:"block", reason:$reason}'
    exit 0
  done
fi

printf '{"continue":true}\n'
