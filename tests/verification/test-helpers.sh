#!/usr/bin/env bash
# Shared helpers for verification test scripts.
# Source this file: source "$(dirname "$0")/test-helpers.sh"

# Preflight: fail fast if TEST_DIR contains spaces (breaks JSON heredocs)
verify_no_spaces() {
    if [[ "$1" == *" "* ]]; then
        echo "FATAL: Path contains spaces: $1"
        echo "Hook commands and JSON heredocs will break. Use a path without spaces."
        exit 1
    fi
}

# Ensure temp git repos have a valid identity
setup_git_identity() {
    local dir="$1"
    git -C "$dir" config user.email "test@verification.local"
    git -C "$dir" config user.name "Verification Test"
}

# Run a Claude session with retry logic and failure tracking.
#
# Usage: run_claude_session LABEL RUN_NUM MAX_RETRIES TIMEOUT_SECS CLAUDE_ARGS...
#
# Outputs to: $TEST_DIR/output-$LABEL-$RUN_NUM.txt
# Appends to: $RESULTS_FILE (CSV: label,run,duration_ms,status,attempt,pass_label)
#
# Status values: succeeded, failed, timed_out
# Only "succeeded" runs should be used for primary metrics.
run_claude_session() {
    local label="$1"
    local run_num="$2"
    local max_retries="${3:-2}"
    local timeout_secs="${4:-180}"
    shift 4
    # Remaining args are passed to claude

    local attempt=0
    local status="failed"
    local duration=0

    while [ $attempt -lt $max_retries ]; do
        attempt=$((attempt + 1))

        # Clean up artifacts from prior attempts (set by caller)
        if [ -n "${PRE_ATTEMPT_CLEANUP:-}" ]; then
            eval "$PRE_ATTEMPT_CLEANUP"
        fi

        local output_file="$TEST_DIR/output-${label}-run${run_num}-attempt${attempt}.txt"

        local start_ms
        start_ms=$(python3 -c "import time; print(int(time.time() * 1000))")

        local exit_code=0
        timeout "$timeout_secs" "$@" > "$output_file" 2>&1 || exit_code=$?

        local end_ms
        end_ms=$(python3 -c "import time; print(int(time.time() * 1000))")
        duration=$((end_ms - start_ms))

        if [ $exit_code -eq 0 ]; then
            status="succeeded"
            # Copy successful output to canonical location
            cp "$output_file" "$TEST_DIR/output-${label}-run${run_num}.txt"
            break
        elif [ $exit_code -eq 124 ]; then
            status="timed_out"
            echo "    [TIMEOUT] Attempt $attempt timed out after ${timeout_secs}s"
        else
            status="failed"
            echo "    [FAILED] Attempt $attempt exited with code $exit_code"
        fi

        if [ $attempt -lt $max_retries ]; then
            echo "    Retrying (attempt $((attempt + 1))/$max_retries)..."
        fi
    done

    local pass_label="first-pass"
    if [ $attempt -gt 1 ] && [ "$status" = "succeeded" ]; then
        pass_label="retry-pass"
    fi

    echo "${label},${run_num},${duration},${status},${attempt},${pass_label}" >> "$RESULTS_FILE"

    if [ "$status" = "succeeded" ]; then
        echo "  Run $run_num: ${duration}ms (${pass_label})"
    else
        echo "  Run $run_num: FAILED after $attempt attempts (${status})"
    fi

    return 0  # Don't abort the script on individual run failure
}

# Find the most recent session transcript (.jsonl) for a given working directory.
# Claude Code writes transcripts to ~/.claude/projects/-<escaped-cwd>/<session>.jsonl
#
# Usage: find_session_transcript WORKING_DIR MAX_AGE_MINUTES
# Returns: path to most recent .jsonl file, or empty string if not found
find_session_transcript() {
    local working_dir="$1"
    local max_age_minutes="${2:-5}"
    local newer_than="${3:-}"  # optional: path to timestamp file for per-run isolation

    # Escape path: replace / with - (Claude Code keeps the leading dash)
    local escaped
    escaped=$(echo "$working_dir" | sed 's/\//-/g')
    local session_dir="$HOME/.claude/projects/$escaped"

    # Guard against nonexistent directory (find returns nonzero under pipefail)
    if [ ! -d "$session_dir" ]; then
        echo ""
        return 0
    fi

    # Sort by mtime (newest first), not lexicographic filename order
    if [ -n "$newer_than" ] && [ -f "$newer_than" ]; then
        find "$session_dir" -name "*.jsonl" -type f -newer "$newer_than" -print0 2>/dev/null \
            | xargs -0 ls -t 2>/dev/null | head -1
    else
        find "$session_dir" -name "*.jsonl" -type f -mmin "-${max_age_minutes}" -print0 2>/dev/null \
            | xargs -0 ls -t 2>/dev/null | head -1
    fi
}

# Check a session transcript for Task tool invocations targeting a specific agent.
# Uses structured JSON parsing (not regex) to verify that a Task tool-use event
# has subagent_type matching the expected agent name.
#
# Usage: verify_task_tool_used SESSION_FILE AGENT_NAME
# Returns: 0 if found, 1 if not found
verify_task_tool_used() {
    local session_file="$1"
    local agent_name="$2"

    if [ -z "$session_file" ] || [ ! -f "$session_file" ]; then
        return 1
    fi

    # Parse each JSONL line structurally: check for tool_use events where
    # name=="Task" and input.subagent_type matches the expected agent name.
    # This is authoritative proof — no false positives from text mentions.
    python3 -c "
import json, sys
with open('$session_file') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        # Tool use events can be nested in multiple locations:
        # - top-level event (rare)
        # - event.content[] (some formats)
        # - event.message.content[] (actual Claude transcript shape)
        blocks = [event]
        if isinstance(event.get('content'), list):
            blocks.extend(event['content'])
        msg = event.get('message', {})
        if isinstance(msg.get('content'), list):
            blocks.extend(msg['content'])
        for block in blocks:
            if block.get('type') == 'tool_use' and block.get('name') == 'Task':
                inp = block.get('input', {})
                if inp.get('subagent_type') == '$agent_name':
                    sys.exit(0)
    sys.exit(1)
"
}

# Check a session transcript for ANY tool_use event matching a given tool name.
# Unlike verify_task_tool_used (which checks for Task tool + specific agent),
# this searches for tool_use events where the "name" field matches TOOL_NAME.
#
# Usage: verify_tool_used SESSION_FILE TOOL_NAME
# Returns: 0 if found, 1 if not found
verify_tool_used() {
    local session_file="$1"
    local tool_name="$2"

    if [ -z "$session_file" ] || [ ! -f "$session_file" ]; then
        return 1
    fi

    python3 -c "
import json, sys

tool_name = sys.argv[1]
with open(sys.argv[2]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        blocks = [event]
        if isinstance(event.get('content'), list):
            blocks.extend(event['content'])
        msg = event.get('message', {})
        if isinstance(msg.get('content'), list):
            blocks.extend(msg['content'])
        for block in blocks:
            if block.get('type') == 'tool_use' and block.get('name') == tool_name:
                sys.exit(0)
sys.exit(1)
" "$tool_name" "$session_file"
}

# Check a session transcript for a Bash tool_use whose command contains a real
# 'bd close' invocation (not just echoed/quoted text).
#
# The regex requires 'bd close' at command-start or after a shell operator
# (&&, ||, ;, |), which filters out false positives like:
#   echo "bd close 123"   — bd appears inside quotes, preceded by echo
#   # bd close            — comment
#
# Usage: verify_bd_close_used SESSION_FILE
# Returns: 0 if found, 1 if not found
verify_bd_close_used() {
    local session_file="$1"

    if [ -z "$session_file" ] || [ ! -f "$session_file" ]; then
        return 1
    fi

    python3 -c "
import json, re, sys

pattern = re.compile(r'(?:^|&&|\|\||[;|])\s*bd\s+close\b')
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        blocks = [event]
        if isinstance(event.get('content'), list):
            blocks.extend(event['content'])
        msg = event.get('message', {})
        if isinstance(msg.get('content'), list):
            blocks.extend(msg['content'])
        for block in blocks:
            if block.get('type') == 'tool_use' and block.get('name') == 'Bash':
                cmd = block.get('input', {}).get('command', '')
                if pattern.search(cmd):
                    sys.exit(0)
sys.exit(1)
" "$session_file"
}

# Check a session transcript for a Bash tool_use whose command contains a real
# 'bd create' invocation (not just echoed/quoted text).
#
# Same false-positive resistance as verify_bd_close_used.
#
# Usage: verify_bd_create_used SESSION_FILE
# Returns: 0 if found, 1 if not found
verify_bd_create_used() {
    local session_file="$1"

    if [ -z "$session_file" ] || [ ! -f "$session_file" ]; then
        return 1
    fi

    python3 -c "
import json, re, sys

pattern = re.compile(r'(?:^|&&|\|\||[;|])\s*bd\s+create\b')
with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        blocks = [event]
        if isinstance(event.get('content'), list):
            blocks.extend(event['content'])
        msg = event.get('message', {})
        if isinstance(msg.get('content'), list):
            blocks.extend(msg['content'])
        for block in blocks:
            if block.get('type') == 'tool_use' and block.get('name') == 'Bash':
                cmd = block.get('input', {}).get('command', '')
                if pattern.search(cmd):
                    sys.exit(0)
sys.exit(1)
" "$session_file"
}
