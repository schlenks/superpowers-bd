#!/usr/bin/env bash
# PostToolUse linter guard for Write|Edit tool calls.
# Reads hook JSON from stdin, extracts tool_input.file_path via jq,
# runs appropriate linter based on file extension.
# Exit 2 blocks the operation and surfaces errors to Claude for self-correction.
# Exit 0 means no issues (or unsupported file type / missing tool).
#
# Supported: *.sh (shellcheck), *.json (jq),
#   *.ts|*.tsx (cognitive-complexity-ts preferred, lizard fallback),
#   *.py|*.js|*.jsx|*.go|*.java|*.c|*.cpp|*.h|*.hpp|*.rb|*.swift|*.rs (lizard)
# Graceful degradation: exits 0 if linter tool not installed.

set -euo pipefail

input=$(cat)

# jq required to parse hook input
if ! command -v jq &>/dev/null; then exit 0; fi

block_with_reason() {
  local reason="$1"
  jq -nc --arg reason "$reason" '{decision:"block", reason:$reason}'
  exit 0
}

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

case "$file_path" in
  *.sh)
    command -v shellcheck &>/dev/null || exit 0
    if ! output=$(shellcheck -f gcc "$file_path" 2>&1); then
      echo "LINTER ERROR: shellcheck found issues in $file_path" >&2
      echo "$output" >&2
      echo "Please fix the shellcheck errors above and retry." >&2
      block_with_reason "shellcheck found issues in $file_path. Fix the reported shell warnings before continuing."
    fi
    ;;
  *.json)
    if ! output=$(jq empty "$file_path" 2>&1); then
      echo "LINTER ERROR: JSON syntax error in $file_path" >&2
      echo "$output" >&2
      echo "Please fix the JSON syntax error above and retry." >&2
      block_with_reason "JSON syntax error in $file_path. Fix the parse error before continuing."
    fi
    ;;
  *.ts|*.tsx)
    if command -v ccts-json &>/dev/null; then
      # "count<TAB>max<TAB>sum" of function scores > 25 in the given file
      ccts_over25_stats() {
        local target="$1" out
        out=$(ccts-json "$target" 2>/dev/null) || true
        if [[ -z "$out" ]]; then printf '0\t0\t0\n'; return; fi
        echo "$out" | jq -r \
          '[.. | objects | select(.kind == "function" and .score > 25) | .score]
           | "\(length)\t\(if length > 0 then max else 0 end)\t\(if length > 0 then add else 0 end)"' \
          2>/dev/null || printf '0\t0\t0\n'
      }
      # Cognitive complexity via ccts-json
      ccts_output=$(ccts-json "$file_path" 2>/dev/null) || true
      if [[ -n "$ccts_output" ]]; then
        # Block: cognitive complexity > 25 — ratchet: pre-existing debt is
        # tolerated; only edits that WORSEN the file (vs git HEAD) are blocked.
        violations_block=$(echo "$ccts_output" | jq -r \
          '.. | objects | select(.kind == "function" and .score > 25) | "\(.name)\t\(.line)\t\(.score)"' \
          2>/dev/null) || true
        if [[ -n "$violations_block" ]]; then
          IFS=$'\t' read -r cur_count cur_max cur_sum <<< "$(ccts_over25_stats "$file_path")"
          base_count=-1 base_max=0 base_sum=0
          file_dir=$(dirname "$file_path")
          file_base=$(basename "$file_path")
          if git -C "$file_dir" rev-parse --is-inside-work-tree &>/dev/null; then
            tmp_dir=$(mktemp -d)
            if git -C "$file_dir" show "HEAD:./$file_base" > "$tmp_dir/$file_base" 2>/dev/null; then
              IFS=$'\t' read -r base_count base_max base_sum <<< "$(ccts_over25_stats "$tmp_dir/$file_base")"
            fi
            rm -rf "$tmp_dir"
          fi
          if [[ "$base_count" -ge 1 && "$cur_count" -le "$base_count" && "$cur_max" -le "$base_max" && "$cur_sum" -le "$base_sum" ]]; then
            echo "COMPLEXITY RATCHET: $file_path already exceeded the limit at HEAD (over-25 count ${base_count}, max ${base_max}); this edit does not worsen it (count ${cur_count}, max ${cur_max}) — allowed." >&2
            echo "  Remaining functions with cognitive complexity > 25 (reduce when practical):" >&2
            while IFS=$'\t' read -r fname fline fscore; do
              echo "  ${file_path}:${fline} — ${fname}() cognitive complexity = ${fscore}" >&2
            done <<< "$violations_block"
          else
            echo "COMPLEXITY ERROR: functions exceed critical cognitive complexity in $file_path" >&2
            if [[ "$base_count" -ge 0 ]]; then
              echo "  This edit worsens the file vs HEAD (over-25 count ${base_count} -> ${cur_count}, max ${base_max} -> ${cur_max}, sum ${base_sum} -> ${cur_sum})." >&2
            fi
            echo "  Functions with cognitive complexity > 25 must be decomposed:" >&2
            while IFS=$'\t' read -r fname fline fscore; do
              echo "  ${file_path}:${fline} — ${fname}() cognitive complexity = ${fscore}" >&2
            done <<< "$violations_block"
            block_with_reason "Critical cognitive complexity found in $file_path. Decompose functions scoring above 25 (or at minimum do not add to a file already over the limit) before continuing."
          fi
        fi
        # Warn: cognitive complexity > 15
        violations_warn=$(echo "$ccts_output" | jq -r \
          '.. | objects | select(.kind == "function" and .score > 15) | "\(.name)\t\(.line)\t\(.score)"' \
          2>/dev/null) || true
        if [[ -n "$violations_warn" ]]; then
          echo "COMPLEXITY WARNING: functions exceed advisory cognitive complexity in $file_path" >&2
          while IFS=$'\t' read -r fname fline fscore; do
            echo "  ${file_path}:${fline} — ${fname}() cognitive complexity = ${fscore}" >&2
          done <<< "$violations_warn"
          echo "  Consider extracting nested logic into helper functions." >&2
        fi
      fi
    else
      # Fallback: lizard for TS/TSX when ccts-json not installed
      if command -v lizard &>/dev/null; then
        block_output=$(lizard -C 15 -L 100 -w "$file_path" 2>/dev/null || true)
        if [[ -n "$block_output" ]]; then
          echo "COMPLEXITY ERROR: functions exceed critical thresholds in $file_path" >&2
          echo "$block_output" >&2
          echo "Functions with CC>15 must be decomposed. Functions >100 lines must be split." >&2
          block_with_reason "Critical complexity thresholds exceeded in $file_path. Decompose CC>15 functions or split functions longer than 100 lines before continuing."
        fi
        warn_output=$(lizard -C 10 -L 50 -w "$file_path" 2>/dev/null || true)
        if [[ -n "$warn_output" ]]; then
          echo "COMPLEXITY WARNING: functions exceed advisory thresholds in $file_path" >&2
          echo "$warn_output" >&2
          echo "Consider extracting branches into helper functions or splitting long functions." >&2
        fi
      else
        echo "Tip: install cognitive-complexity-ts for TS complexity checking: npm install -g cognitive-complexity-ts" >&2
      fi
    fi
    ;;
  *.py|*.js|*.jsx|*.go|*.java|*.c|*.cpp|*.h|*.hpp|*.rb|*.swift|*.rs)
    if ! command -v lizard &>/dev/null; then
      echo "Tip: install lizard for complexity checking: pip install lizard" >&2
      exit 0
    fi
    # Pass 1: block on CC>15 or length>100
    block_output=$(lizard -C 15 -L 100 -w "$file_path" 2>/dev/null || true)
    if [[ -n "$block_output" ]]; then
      echo "COMPLEXITY ERROR: functions exceed critical thresholds in $file_path" >&2
      echo "$block_output" >&2
      echo "Functions with CC>15 must be decomposed. Functions >100 lines must be split." >&2
      block_with_reason "Critical complexity thresholds exceeded in $file_path. Decompose CC>15 functions or split functions longer than 100 lines before continuing."
    fi
    # Pass 2: warn on CC>10 or length>50
    warn_output=$(lizard -C 10 -L 50 -w "$file_path" 2>/dev/null || true)
    if [[ -n "$warn_output" ]]; then
      echo "COMPLEXITY WARNING: functions exceed advisory thresholds in $file_path" >&2
      echo "$warn_output" >&2
      echo "Consider extracting branches into helper functions or splitting long functions." >&2
    fi
    ;;
esac

exit 0
