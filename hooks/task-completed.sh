#!/usr/bin/env bash
# TaskCompleted hook — quality gate for task completion
# Reads JSON from stdin, checks quality criteria, exits 0 (allow) or 2 (block).
# Stderr feedback is shown to the model when blocking (per Claude Code docs).
# Only fires in interactive mode (not headless claude -p).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Read JSON input from stdin
INPUT=$(cat)

# Check jq availability
if ! command -v jq &>/dev/null; then
  echo '{"error": "jq not found — quality gate skipped"}' >&2
  exit 0
fi

# Parse fields
task_subject=$(echo "$INPUT" | jq -r '.task_subject // ""')
task_description=$(echo "$INPUT" | jq -r '.task_description // ""')
task_id=$(echo "$INPUT" | jq -r '.task_id // ""')

# Determine log directory — prefer CLAUDE_PROJECT_DIR, fall back to cwd/.claude
LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/quality-gate.log"

log_result() {
  local result="$1"
  local reason="$2"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "${ts} ${result} task=${task_id} subject=\"${task_subject}\" reason=\"${reason}\"" >> "$LOG_FILE" 2>/dev/null || true
}

# --- Bypass check ---
if echo "$task_subject" | grep -qi '\[skip-gate\]'; then
  log_result "ALLOWED" "skip-gate bypass"
  exit 0
fi

# --- Check 1: Verification evidence ---
# Tasks with "verify"/"verification" in subject must have evidence in description
subject_lower=$(echo "$task_subject" | tr '[:upper:]' '[:lower:]')
if echo "$subject_lower" | grep -qE '(verify|verification)'; then
  # Check for evidence markers in description
  if [ -z "$task_description" ]; then
    log_result "BLOCKED" "verification task with empty description"
    echo "BLOCKED: Verification task \"${task_subject}\" has no description. Add evidence of what was verified (e.g., test output, exit codes, confirmation of results) before completing." >&2
    exit 2
  fi

  desc_lower=$(echo "$task_description" | tr '[:upper:]' '[:lower:]')
  evidence_found=false
  for marker in "exit code" "0 failures" "pass" "passed" "output:" "evidence:" "confirmed" "verified" "success" "✓" "✅" "all.*pass" "no.*fail" "result:" "screenshot" "log:" "ran " "executed"; do
    if echo "$desc_lower" | grep -qiE "$marker"; then
      evidence_found=true
      break
    fi
  done

  if [ "$evidence_found" = false ]; then
    log_result "BLOCKED" "verification task without evidence markers"
    echo "BLOCKED: Verification task \"${task_subject}\" lacks evidence. Before completing, update the task description with concrete evidence: test output, exit codes, command results, or confirmation of what was verified." >&2
    exit 2
  fi
fi

# --- All checks passed ---
log_result "ALLOWED" "all checks passed"
exit 0
