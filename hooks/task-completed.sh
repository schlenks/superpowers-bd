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

# --- Bypass check ---
if echo "$task_subject" | grep -qi '\[skip-gate\]'; then
  exit 0
fi

# --- Check 1: Verification evidence ---
# Tasks with "verify"/"verification" in subject must have evidence in description
subject_lower=$(echo "$task_subject" | tr '[:upper:]' '[:lower:]')
if echo "$subject_lower" | grep -qE '(verify|verification)'; then
  # Check for evidence markers in description
  if [ -z "$task_description" ]; then
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
    echo "BLOCKED: Verification task \"${task_subject}\" lacks evidence. Before completing, update the task description with concrete evidence: test output, exit codes, command results, or confirmation of what was verified." >&2
    exit 2
  fi
fi

# --- Check 2: Implementation/close evidence ---
# Tasks with "implement" or "close evidence" in subject must have commit, files, and test evidence
if echo "$subject_lower" | grep -qE '(implement|close evidence)'; then
  missing=()

  if [ -z "$task_description" ]; then
    missing+=("commit hash" "files changed" "test results")
  else
    # Case-insensitive version for keyword matching (test results)
    desc_lower=$(echo "$task_description" | tr '[:upper:]' '[:lower:]')

    # Commit hash: 7-40 hex chars or "commit:" label (case-sensitive: hex is lowercase)
    if ! echo "$task_description" | grep -qE '([0-9a-f]{7,40}|[Cc]ommit:)'; then
      missing+=("commit hash")
    fi

    # Files changed: file extensions or "file(s) changed/modified/created"
    if ! echo "$task_description" | grep -qE '(\.[a-z]{1,4}\b|files? (changed|modified|created))'; then
      missing+=("files changed")
    fi

    # Test results: test/pass/fail/exit code/assertions
    if ! echo "$desc_lower" | grep -qE '(test|pass|fail|exit code|0 failures|assertion)'; then
      missing+=("test results")
    fi
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    missing_str=$(IFS=', '; echo "${missing[*]}")
    echo "BLOCKED: Task \"${task_subject}\" lacks completion evidence. Missing: ${missing_str}. Update task description with: commit hash (git rev-parse --short HEAD), files changed (git diff --stat), and test results before completing." >&2
    exit 2
  fi
fi

# --- All checks passed ---
exit 0
