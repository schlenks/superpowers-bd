#!/usr/bin/env bash
# Experiment B: TaskCompleted Latency by Hook Type (Gated)
#
# Purpose: Measure the overhead of different hook types (command/prompt/agent)
#          on TaskCompleted events, relative to a no-hook baseline.
#
# GATED: This experiment only runs if Experiment A (trigger matrix) confirmed
#        that TaskCompleted fires for at least one trigger path. Reads
#        trigger-gate.json to determine the recommended cell and aborts with
#        NOT_MEASURABLE if no FIRES path exists.
#
# Variants:
#   none    — baseline: no hooks configured
#   command — TaskCompleted command hook (creates marker file)
#   prompt  — TaskCompleted prompt hook
#   agent   — TaskCompleted agent hook
#
# Run structure:
#   Warmup:   2 runs per variant (discarded, not in CSV)
#   Measured: 12 runs per variant
#   Total:    56 sessions (8 warmup + 48 measured)
#
# Cycle randomization: each cycle runs all 4 variants in shuffled order.
#
# CSV output: variant,cycle,duration_ms,status,attempt,hook_observed,proof_type
# Analysis:   delegated to analyze-v2.py latency mode
set -euo pipefail

# --- Preflight: required tools ---
for cmd in python3 claude; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "FATAL: $cmd not found in PATH" >&2
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Experiment B: TaskCompleted Latency by Hook Type"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# --- Configuration ---
WARMUP_RUNS=2
MEASURED_RUNS=12
MAX_RETRIES=2
TIMEOUT_SECS=180
VARIANTS="none command prompt agent"

# --- Gate Check: Read trigger-gate.json ---
GATE_FILE="$SCRIPT_DIR/trigger-gate.json"

if [ ! -f "$GATE_FILE" ]; then
    echo "FATAL: Gate file not found: $GATE_FILE"
    echo "Run Experiment A (test-taskcompleted-trigger-matrix-v2.sh) first."
    exit 1
fi

echo "Reading gate file: $GATE_FILE"

# Parse gate file with Python to avoid shell JSON parsing issues
GATE_INFO=$(python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    gate = json.load(f)

cell = gate.get('recommended_latency_cell')
m2_only = gate.get('m2_only', False)

if cell is None:
    print('CELL=null')
    print('M2_ONLY=false')
    print('ACTION=null')
elif m2_only:
    print(f'CELL={cell}')
    print('M2_ONLY=true')
    # Extract action from cell name (e.g., 'a1xm2' -> 'a1')
    print(f'ACTION={cell.split(\"x\")[0]}')
else:
    print(f'CELL={cell}')
    print('M2_ONLY=false')
    # Extract action from cell name (e.g., 'a1xm1' -> 'a1')
    print(f'ACTION={cell.split(\"x\")[0]}')
" "$GATE_FILE")

eval "$GATE_INFO"

echo "  Recommended cell: $CELL"
echo "  M2 only: $M2_ONLY"
echo "  Action: $ACTION"
echo ""

# Abort if no FIRES path
if [ "$CELL" = "null" ]; then
    echo "========================================"
    echo " RESULT: NOT_MEASURABLE"
    echo "========================================"
    echo ""
    echo "No trigger cell from Experiment A classified as FIRES."
    echo "TaskCompleted latency cannot be measured in any tested path."
    echo ""
    echo "VERDICT: NOT_MEASURABLE"
    echo "Decision class: INCONCLUSIVE"
    exit 0
fi

# Abort if only interactive mode fires (latency measurement not supported)
if [ "$M2_ONLY" = "true" ]; then
    echo "========================================"
    echo " RESULT: NOT_MEASURABLE"
    echo "========================================"
    echo ""
    echo "TaskCompleted only fires in interactive mode (M2)."
    echo "Automated latency measurement requires headless mode (M1)."
    echo ""
    echo "VERDICT: NOT_MEASURABLE"
    echo "Decision class: INCONCLUSIVE"
    exit 0
fi

echo "Gate PASSED: cell $CELL fires in headless mode."
echo "Using action $ACTION for all latency variants."
echo ""

# --- Setup ---
TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
trap 'rm -rf "$TEST_DIR"' EXIT
export TEST_DIR

RESULTS_FILE="$TEST_DIR/results.csv"
echo "variant,cycle,duration_ms,status,attempt,hook_observed,proof_type" > "$RESULTS_FILE"
export RESULTS_FILE

# Internal CSV for run_claude_session helper
INTERNAL_CSV="$TEST_DIR/internal-results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$INTERNAL_CSV"

echo "Test dir: $TEST_DIR"
echo ""

# --- Prompt ---
# Use the same completion action that Experiment A confirmed fires.
# Pass via environment variable to avoid shell quoting issues.
if [ "$ACTION" = "a1" ]; then
    TASK_PROMPT="Create a task using TaskCreate with subject 'Latency test' and description 'Testing hook overhead'. Then immediately mark it as completed using TaskUpdate. Say only 'Done' when finished."
elif [ "$ACTION" = "a2" ]; then
    TASK_PROMPT="Run these commands: first 'bd create --title latency-test --priority 3', then 'bd close ISSUE_ID' where ISSUE_ID is the ID returned by bd create. Say only 'Done' when finished."
else
    echo "FATAL: Unknown action '$ACTION' from gate file"
    exit 1
fi

# --- Hook configuration generators ---

# No hooks (baseline)
generate_hooks_none() {
    echo '{}'
}

# Command hook: creates marker file (direct proof)
generate_hooks_command() {
    local marker="$1"
    cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch $marker",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
HOOKEOF
}

# Prompt hook: adds system prompt on TaskCompleted
generate_hooks_prompt() {
    cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Task completed event received. Acknowledge by including HOOK_PROMPT_FIRED in your response.",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
HOOKEOF
}

# Agent hook: runs agent subcommand on TaskCompleted
generate_hooks_agent() {
    local marker="$1"
    cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "claude -p 'Write the word AGENT_HOOK_FIRED to stdout and nothing else' --max-turns 1 > $marker 2>/dev/null || true",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
HOOKEOF
}

# --- Session runner ---
# Runs a single Claude session for a given variant and records results.
#
# Arguments: VARIANT CYCLE_NUM IS_WARMUP
run_latency_session() {
    local variant="$1"
    local cycle_num="$2"
    local is_warmup="${3:-false}"

    local label="${variant}-c${cycle_num}"
    if [ "$is_warmup" = "true" ]; then
        label="${variant}-warmup${cycle_num}"
    fi

    local project_dir="$TEST_DIR/project-${label}"
    local tc_marker="$TEST_DIR/tc-${label}.marker"
    local agent_marker="$TEST_DIR/agent-${label}.marker"

    mkdir -p "$project_dir/.claude"
    git -C "$project_dir" init --quiet 2>/dev/null
    setup_git_identity "$project_dir"
    git -C "$project_dir" commit --allow-empty -m "init" --quiet 2>/dev/null

    # Write hook configuration based on variant
    case "$variant" in
        none)
            generate_hooks_none > "$project_dir/.claude/settings.json"
            ;;
        command)
            generate_hooks_command "$tc_marker" > "$project_dir/.claude/settings.json"
            ;;
        prompt)
            generate_hooks_prompt > "$project_dir/.claude/settings.json"
            ;;
        agent)
            generate_hooks_agent "$agent_marker" > "$project_dir/.claude/settings.json"
            ;;
        *)
            echo "FATAL: Unknown variant '$variant'"
            exit 1
            ;;
    esac

    # Initialize beads if using A2 action
    if [ "$ACTION" = "a2" ]; then
        (cd "$project_dir" && bd init 2>/dev/null || true) >/dev/null
    fi

    # Per-run timestamp for transcript isolation
    local ts_file="$TEST_DIR/timestamp-${label}"
    touch "$ts_file"
    sleep 1  # filesystem timestamp granularity

    # Use RESULTS_FILE override for internal CSV
    local saved_results="$RESULTS_FILE"
    export RESULTS_FILE="$INTERNAL_CSV"

    PRE_ATTEMPT_CLEANUP="rm -f $tc_marker $agent_marker" \
        CLAUDE_PROMPT="$TASK_PROMPT" CLAUDE_DIR="$project_dir" \
        run_claude_session "$label" "$cycle_num" "$MAX_RETRIES" "$TIMEOUT_SECS" \
        sh -c 'cd "$CLAUDE_DIR" && claude -p "$CLAUDE_PROMPT" --permission-mode bypassPermissions --allowed-tools=all'

    export RESULTS_FILE="$saved_results"

    # Extract status and duration from internal CSV
    local last_line
    last_line=$(grep "^${label},${cycle_num}," "$INTERNAL_CSV" | tail -1)
    local status duration attempt
    status=$(echo "$last_line" | cut -d, -f4)
    duration=$(echo "$last_line" | cut -d, -f3)
    attempt=$(echo "$last_line" | cut -d, -f5)

    # Determine hook observation and proof type
    local hook_observed="false"
    local proof_type="none"

    case "$variant" in
        none)
            # Baseline: no hook expected
            hook_observed="n/a"
            proof_type="n/a"
            ;;
        command)
            # Direct proof: marker file must exist
            if [ -f "$tc_marker" ]; then
                hook_observed="true"
                proof_type="direct"
            else
                hook_observed="false"
                proof_type="none"
            fi
            ;;
        prompt)
            # Check output for the prompt marker string
            local output_file="$TEST_DIR/output-${label}-run${cycle_num}.txt"
            if [ -f "$output_file" ] && grep -q "HOOK_PROMPT_FIRED" "$output_file" 2>/dev/null; then
                hook_observed="true"
                proof_type="response-marker"
            else
                hook_observed="timing-inferred"
                proof_type="timing-inferred"
            fi
            ;;
        agent)
            # Check agent marker output file
            if [ -f "$agent_marker" ] && grep -q "AGENT_HOOK_FIRED" "$agent_marker" 2>/dev/null; then
                hook_observed="true"
                proof_type="agent-marker"
            else
                hook_observed="timing-inferred"
                proof_type="timing-inferred"
            fi
            ;;
    esac

    # Write to main results CSV (skip warmup runs)
    if [ "$is_warmup" = "false" ]; then
        echo "${variant},${cycle_num},${duration},${status},${attempt},${hook_observed},${proof_type}" >> "$saved_results"
        echo "    hook_observed=$hook_observed proof_type=$proof_type"
    fi
}

# ========================================
# Warmup Phase (discarded)
# ========================================

echo "========================================"
echo " Warmup Phase: $WARMUP_RUNS runs per variant (discarded)"
echo "========================================"
echo ""

for warmup_cycle in $(seq 1 $WARMUP_RUNS); do
    echo "--- Warmup cycle $warmup_cycle/$WARMUP_RUNS ---"
    # Shuffle variant order for each warmup cycle
    SHUFFLED_VARIANTS=$(echo $VARIANTS | tr ' ' '\n' | sort -R | tr '\n' ' ')
    for variant in $SHUFFLED_VARIANTS; do
        echo "  [$variant] warmup $warmup_cycle"
        run_latency_session "$variant" "$warmup_cycle" "true"
    done
    echo ""
done

echo "Warmup complete. Starting measured runs."
echo ""

# ========================================
# Measured Phase (12 cycles x 4 variants = 48 sessions)
# ========================================

echo "========================================"
echo " Measured Phase: $MEASURED_RUNS cycles x 4 variants = $((MEASURED_RUNS * 4)) sessions"
echo "========================================"
echo ""

for cycle in $(seq 1 $MEASURED_RUNS); do
    echo "--- Cycle $cycle/$MEASURED_RUNS ---"
    # Shuffle variant order for each cycle (randomization)
    SHUFFLED_VARIANTS=$(echo $VARIANTS | tr ' ' '\n' | sort -R | tr '\n' ' ')
    for variant in $SHUFFLED_VARIANTS; do
        echo "  [$variant] cycle $cycle"
        run_latency_session "$variant" "$cycle" "false"
    done
    echo ""
done

# ========================================
# Analysis
# ========================================

echo "========================================"
echo " Analysis"
echo "========================================"
echo ""

# Save results CSV alongside script
FINAL_CSV="$SCRIPT_DIR/taskcompleted-latency-v2-results.csv"
cp "$RESULTS_FILE" "$FINAL_CSV"
echo "Results CSV saved to: $FINAL_CSV"
echo ""

# Print raw data summary
echo "--- Raw Data Summary ---"
FINAL_CSV_PATH="$FINAL_CSV" python3 << 'PYEOF'
import csv, os
from collections import defaultdict

csv_path = os.environ['FINAL_CSV_PATH']
with open(csv_path, newline='') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

by_variant = defaultdict(lambda: {'total': 0, 'succeeded': 0, 'failed': 0, 'durations': []})

for row in rows:
    v = row['variant']
    by_variant[v]['total'] += 1
    if row['status'] == 'succeeded':
        by_variant[v]['succeeded'] += 1
        by_variant[v]['durations'].append(float(row['duration_ms']))
    else:
        by_variant[v]['failed'] += 1

print(f"{'Variant':<12} {'Total':>6} {'OK':>4} {'Fail':>4} {'Fail%':>7}")
print('-' * 36)
for v in ('none', 'command', 'prompt', 'agent'):
    d = by_variant[v]
    fail_pct = d['failed'] / d['total'] * 100 if d['total'] > 0 else 0
    print(f"{v:<12} {d['total']:>6} {d['succeeded']:>4} {d['failed']:>4} {fail_pct:>6.1f}%")

print()
PYEOF

# Delegate full analysis to analyze-v2.py
echo "--- Statistical Analysis (via analyze-v2.py) ---"
python3 "$SCRIPT_DIR/analyze-v2.py" latency "$FINAL_CSV"

# Extract decision class from the summary JSON for final reporting
SUMMARY_JSON="${FINAL_CSV%.csv}-summary.json"

if [ -f "$SUMMARY_JSON" ]; then
    echo ""
    echo "--- Final Verdict ---"
    SUMMARY_PATH="$SUMMARY_JSON" python3 << 'PYEOF'
import json, os

summary_path = os.environ['SUMMARY_PATH']
with open(summary_path) as f:
    summary = json.load(f)

decision_class = summary.get('decision_class', 'UNKNOWN')
print(f'VERDICT: {decision_class}')
print(f'Decision class: {decision_class}')
print()

# Report per-variant classification
variants = summary.get('variants', {})
for v_name in ('command', 'prompt', 'agent'):
    v = variants.get(v_name, {})
    if v:
        classification = v.get('classification', 'UNKNOWN')
        overhead = v.get('overhead_ms', 0)
        n = v.get('n', 0)
        proof = v.get('proof_level', 'UNKNOWN')
        ci = v.get('bootstrap_ci_overhead', {})
        ci_lower = ci.get('ci_lower', 0)
        ci_upper = ci.get('ci_upper', 0)
        print(f'{v_name}: {classification} (overhead={overhead:+.0f}ms, n={n}, '
              f'CI=[{ci_lower:.0f},{ci_upper:.0f}], proof={proof})')
PYEOF
fi

echo ""
echo "Results CSV: tests/verification/taskcompleted-latency-v2-results.csv"
echo "Summary JSON: tests/verification/taskcompleted-latency-v2-results-summary.json"
echo ""
echo "Experiment B complete."
