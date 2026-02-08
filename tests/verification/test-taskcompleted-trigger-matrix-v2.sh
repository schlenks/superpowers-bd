#!/usr/bin/env bash
# Experiment A: TaskCompleted Trigger Matrix
#
# Purpose: Determine which completion actions actually emit TaskCompleted events,
#          and whether headless vs interactive mode matters.
#
# Matrix:
#   A1 (native TaskCreate+TaskUpdate) x M1 (headless)     — REQUIRED, n=5
#   A2 (bd create + bd close)         x M1 (headless)     — REQUIRED, n=5
#   A1 (native TaskCreate+TaskUpdate) x M2 (interactive)  — OPTIONAL, n=3
#   A2 (bd create + bd close)         x M2 (interactive)  — OPTIONAL, n=3
#
# Each cell tests two hooks:
#   E1: TaskCompleted command hook (primary — creates marker file)
#   E2: PostToolUse control hook   (control — proves action executed)
#
# Transcript probes verify:
#   proof_action:   TaskCreate/bd create was actually called
#   proof_complete: TaskUpdate/bd close was actually called
#
# Verdict per cell: FIRES / DOES_NOT_FIRE / UNSTABLE
# Overall: VERIFIED / OBSERVED / INCONCLUSIVE
#
# Gate file output: trigger-gate.json
#   - recommended_latency_cell: which cell to use for Experiment B (or null)
#   - m2_only: boolean if only interactive mode fires
set -euo pipefail

# Preflight: required tools
for cmd in python3 claude; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "FATAL: $cmd not found in PATH" >&2
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Experiment A: TaskCompleted Trigger Matrix"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# --- Configuration ---
REQUIRED_RUNS=5
OPTIONAL_RUNS=3
MAX_RETRIES=2
TIMEOUT_SECS=180

# --- Setup ---
TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
trap 'rm -rf "$TEST_DIR"' EXIT
export TEST_DIR

RESULTS_FILE="$TEST_DIR/results.csv"
echo "action,mode,run,status,attempt,marker_taskcompleted,marker_control,proof_action,proof_complete,duration_ms" > "$RESULTS_FILE"
export RESULTS_FILE

# Internal CSV for run_claude_session helper (it writes its own format)
INTERNAL_CSV="$TEST_DIR/internal-results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$INTERNAL_CSV"

echo "Test dir: $TEST_DIR"
echo ""

# --- Hook configuration generators ---

# Generate settings.json with TaskCompleted (E1) and PostToolUse (E2) hooks.
# For A1: PostToolUse matches TaskUpdate (control evidence the tool was called)
# For A2: PostToolUse matches Bash (control evidence bd command was called)
generate_hooks_a1() {
    local tc_marker="$1"
    local ctrl_marker="$2"
    cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch $tc_marker",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "TaskUpdate",
        "hooks": [
          {
            "type": "command",
            "command": "touch $ctrl_marker",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
HOOKEOF
}

generate_hooks_a2() {
    local tc_marker="$1"
    local ctrl_marker="$2"
    cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch $tc_marker",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "touch $ctrl_marker",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
HOOKEOF
}

# --- Prompts ---
# A1: Native task tools
PROMPT_A1="Create a task using TaskCreate with subject 'Trigger test' and description 'Testing TaskCompleted hook'. Then immediately mark it as completed using TaskUpdate. Say only 'Done' when finished."

# A2: Beads completion
# bd needs to be initialized in the project directory
PROMPT_A2_TEMPLATE="Run these commands: first 'bd create --title trigger-test --priority 3', then 'bd close ISSUE_ID' where ISSUE_ID is the ID returned by bd create. Say only 'Done' when finished."

# --- Cell runner functions ---

# Run a single headless (M1) session for a given action type
run_cell_m1() {
    local action="$1"   # a1 or a2
    local run_num="$2"
    local cell_label="${action}_m1"

    local project_dir="$TEST_DIR/project-${cell_label}-${run_num}"
    local tc_marker="$TEST_DIR/tc-${cell_label}-${run_num}.marker"
    local ctrl_marker="$TEST_DIR/ctrl-${cell_label}-${run_num}.marker"

    mkdir -p "$project_dir/.claude"
    git -C "$project_dir" init --quiet 2>/dev/null
    setup_git_identity "$project_dir"
    git -C "$project_dir" commit --allow-empty -m "init" --quiet 2>/dev/null

    # Write hook configuration
    if [ "$action" = "a1" ]; then
        generate_hooks_a1 "$tc_marker" "$ctrl_marker" > "$project_dir/.claude/settings.json"
    else
        generate_hooks_a2 "$tc_marker" "$ctrl_marker" > "$project_dir/.claude/settings.json"
        # Initialize beads in the project directory for A2
        (cd "$project_dir" && bd init 2>/dev/null || true) >/dev/null
    fi

    # Per-run timestamp for transcript isolation
    local ts_file="$TEST_DIR/timestamp-${cell_label}-${run_num}"
    touch "$ts_file"
    sleep 1  # filesystem timestamp granularity

    # Select prompt
    local prompt
    if [ "$action" = "a1" ]; then
        prompt="$PROMPT_A1"
    else
        prompt="$PROMPT_A2_TEMPLATE"
    fi

    # Use RESULTS_FILE override for internal CSV (run_claude_session writes to RESULTS_FILE)
    local saved_results="$RESULTS_FILE"
    export RESULTS_FILE="$INTERNAL_CSV"

    PRE_ATTEMPT_CLEANUP="rm -f $tc_marker $ctrl_marker" \
        CLAUDE_PROMPT="$prompt" CLAUDE_DIR="$project_dir" \
        run_claude_session "$cell_label" "$run_num" "$MAX_RETRIES" "$TIMEOUT_SECS" \
        sh -c 'cd "$CLAUDE_DIR" && claude -p "$CLAUDE_PROMPT" --permission-mode bypassPermissions --allowed-tools=all'

    export RESULTS_FILE="$saved_results"

    # Extract status and duration from internal CSV (last line for this label+run)
    local last_line
    last_line=$(grep "^${cell_label},${run_num}," "$INTERNAL_CSV" | tail -1)
    local status duration attempt
    status=$(echo "$last_line" | cut -d, -f4)
    duration=$(echo "$last_line" | cut -d, -f3)
    attempt=$(echo "$last_line" | cut -d, -f5)

    # Check markers
    local marker_tc="false"
    local marker_ctrl="false"
    if [ -f "$tc_marker" ]; then marker_tc="true"; fi
    if [ -f "$ctrl_marker" ]; then marker_ctrl="true"; fi

    # Transcript probes for proof
    local proof_action="false"
    local proof_complete="false"

    local session_jsonl
    session_jsonl=$(find_session_transcript "$project_dir" 5 "$ts_file")

    if [ -n "$session_jsonl" ] && [ -f "$session_jsonl" ]; then
        if [ "$action" = "a1" ]; then
            if verify_tool_used "$session_jsonl" "TaskCreate"; then
                proof_action="true"
            fi
            if verify_tool_used "$session_jsonl" "TaskUpdate"; then
                proof_complete="true"
            fi
        else
            if verify_bd_create_used "$session_jsonl"; then
                proof_action="true"
            fi
            if verify_bd_close_used "$session_jsonl"; then
                proof_complete="true"
            fi
        fi
    fi

    # Write to main results CSV
    echo "${action},m1,${run_num},${status},${attempt},${marker_tc},${marker_ctrl},${proof_action},${proof_complete},${duration}" >> "$RESULTS_FILE"

    # Report
    echo "    markers: tc=$marker_tc ctrl=$marker_ctrl | proofs: action=$proof_action complete=$proof_complete"
}

# Run a single interactive (M2) session using expect.
# Note: M2 cells do NOT use run_claude_session (which is designed for headless mode).
# Instead they run expect directly with a single attempt — no retry logic.
# This is acceptable because M2 cells are optional.
run_cell_m2() {
    local action="$1"   # a1 or a2
    local run_num="$2"
    local cell_label="${action}_m2"

    local project_dir="$TEST_DIR/project-${cell_label}-${run_num}"
    local tc_marker="$TEST_DIR/tc-${cell_label}-${run_num}.marker"
    local ctrl_marker="$TEST_DIR/ctrl-${cell_label}-${run_num}.marker"

    mkdir -p "$project_dir/.claude"
    git -C "$project_dir" init --quiet 2>/dev/null
    setup_git_identity "$project_dir"
    git -C "$project_dir" commit --allow-empty -m "init" --quiet 2>/dev/null

    # Write hook configuration
    if [ "$action" = "a1" ]; then
        generate_hooks_a1 "$tc_marker" "$ctrl_marker" > "$project_dir/.claude/settings.json"
    else
        generate_hooks_a2 "$tc_marker" "$ctrl_marker" > "$project_dir/.claude/settings.json"
        (cd "$project_dir" && bd init 2>/dev/null || true) >/dev/null
    fi

    # Per-run timestamp for transcript isolation
    local ts_file="$TEST_DIR/timestamp-${cell_label}-${run_num}"
    touch "$ts_file"
    sleep 1

    # Select prompt
    local prompt
    if [ "$action" = "a1" ]; then
        prompt="$PROMPT_A1"
    else
        prompt="$PROMPT_A2_TEMPLATE"
    fi

    # Write prompt to temp file for expect to read (avoids quoting issues)
    local prompt_file="$TEST_DIR/prompt-${cell_label}-${run_num}.txt"
    printf '%s' "$prompt" > "$prompt_file"

    # Write expect script
    local expect_script="$TEST_DIR/expect-${cell_label}-${run_num}.exp"
    cat > "$expect_script" << 'EXPECT_TEMPLATE'
#!/usr/bin/expect -f
set timeout TIMEOUT_PLACEHOLDER
set prompt_file [lindex $argv 0]
set project_dir [lindex $argv 1]

# Read prompt from file
set fp [open $prompt_file r]
set prompt_text [read $fp]
close $fp

cd $project_dir
spawn claude --permission-mode bypassPermissions --allowed-tools=all

# Wait for the initial prompt indicator
expect {
    ">" {
        send -- "$prompt_text\r"
    }
    "claude" {
        send -- "$prompt_text\r"
    }
    timeout {
        puts "EXPECT_TIMEOUT: waiting for initial prompt"
        exit 1
    }
}

# Wait for completion: look for Done or the prompt returning
expect {
    -re {Done|done|DONE} {
        # Give hooks time to fire
        sleep 3
    }
    ">" {
        sleep 3
    }
    timeout {
        puts "EXPECT_TIMEOUT: waiting for response"
        exit 1
    }
}

# Send exit command
send "/exit\r"
expect eof
EXPECT_TEMPLATE

    # Replace timeout placeholder (portable: write to temp then move)
    local tmp_script="${expect_script}.tmp"
    sed "s/TIMEOUT_PLACEHOLDER/${TIMEOUT_SECS}/" "$expect_script" > "$tmp_script"
    mv "$tmp_script" "$expect_script"
    chmod +x "$expect_script"

    # Remove old markers
    rm -f "$tc_marker" "$ctrl_marker"

    local start_ms
    start_ms=$(python3 -c "import time; print(int(time.time() * 1000))")

    local exit_code=0
    local output_file="$TEST_DIR/output-${cell_label}-run${run_num}.txt"
    timeout "$TIMEOUT_SECS" expect "$expect_script" "$prompt_file" "$project_dir" > "$output_file" 2>&1 || exit_code=$?

    local end_ms
    end_ms=$(python3 -c "import time; print(int(time.time() * 1000))")
    local duration=$((end_ms - start_ms))

    local status="failed"
    local attempt=1
    if [ $exit_code -eq 0 ]; then
        status="succeeded"
    elif [ $exit_code -eq 124 ]; then
        status="timed_out"
    fi

    echo "  Run $run_num: ${duration}ms (${status})"

    # Check markers
    local marker_tc="false"
    local marker_ctrl="false"
    if [ -f "$tc_marker" ]; then marker_tc="true"; fi
    if [ -f "$ctrl_marker" ]; then marker_ctrl="true"; fi

    # Transcript probes
    local proof_action="false"
    local proof_complete="false"

    local session_jsonl
    session_jsonl=$(find_session_transcript "$project_dir" 5 "$ts_file")

    if [ -n "$session_jsonl" ] && [ -f "$session_jsonl" ]; then
        if [ "$action" = "a1" ]; then
            if verify_tool_used "$session_jsonl" "TaskCreate"; then proof_action="true"; fi
            if verify_tool_used "$session_jsonl" "TaskUpdate"; then proof_complete="true"; fi
        else
            if verify_bd_create_used "$session_jsonl"; then proof_action="true"; fi
            if verify_bd_close_used "$session_jsonl"; then proof_complete="true"; fi
        fi
    fi

    # Write to main results CSV
    echo "${action},m2,${run_num},${status},${attempt},${marker_tc},${marker_ctrl},${proof_action},${proof_complete},${duration}" >> "$RESULTS_FILE"

    echo "    markers: tc=$marker_tc ctrl=$marker_ctrl | proofs: action=$proof_action complete=$proof_complete"
}

# ========================================
# Run Required Cells (M1 headless)
# ========================================

echo "========================================"
echo " Required Cells: Headless Mode (M1)"
echo "========================================"
echo ""

echo "--- Cell A1xM1: Native TaskCreate+TaskUpdate, headless (n=$REQUIRED_RUNS) ---"
for i in $(seq 1 $REQUIRED_RUNS); do
    echo "  [A1xM1] Run $i/$REQUIRED_RUNS"
    run_cell_m1 "a1" "$i"
done
echo ""

echo "--- Cell A2xM1: Beads bd create+close, headless (n=$REQUIRED_RUNS) ---"
for i in $(seq 1 $REQUIRED_RUNS); do
    echo "  [A2xM1] Run $i/$REQUIRED_RUNS"
    run_cell_m1 "a2" "$i"
done
echo ""

# ========================================
# Run Optional Cells (M2 interactive)
# ========================================

HAS_EXPECT=false
if command -v expect >/dev/null 2>&1; then
    HAS_EXPECT=true
fi

if [ "$HAS_EXPECT" = "true" ]; then
    echo "========================================"
    echo " Optional Cells: Interactive Mode (M2)"
    echo "========================================"
    echo " (expect is available — running M2 cells)"
    echo ""

    echo "--- Cell A1xM2: Native TaskCreate+TaskUpdate, interactive (n=$OPTIONAL_RUNS) ---"
    for i in $(seq 1 $OPTIONAL_RUNS); do
        echo "  [A1xM2] Run $i/$OPTIONAL_RUNS"
        run_cell_m2 "a1" "$i"
    done
    echo ""

    echo "--- Cell A2xM2: Beads bd create+close, interactive (n=$OPTIONAL_RUNS) ---"
    for i in $(seq 1 $OPTIONAL_RUNS); do
        echo "  [A2xM2] Run $i/$OPTIONAL_RUNS"
        run_cell_m2 "a2" "$i"
    done
    echo ""
else
    echo "========================================"
    echo " Optional Cells: SKIPPED"
    echo "========================================"
    echo " (expect not found — skipping M2 interactive cells)"
    echo ""
fi

# ========================================
# Analysis and Verdicts
# ========================================

echo "========================================"
echo " Results and Verdicts"
echo "========================================"
echo ""

GATE_FILE="$SCRIPT_DIR/trigger-gate.json"

RESULTS_PATH="$RESULTS_FILE" GATE_PATH="$GATE_FILE" HAS_EXPECT="$HAS_EXPECT" python3 << 'PYEOF'
import csv, json, os, sys
from collections import defaultdict

results_path = os.environ['RESULTS_PATH']
gate_path = os.environ['GATE_PATH']
has_expect = os.environ.get('HAS_EXPECT', 'false') == 'true'

# Parse results CSV
rows = []
with open(results_path, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Validate required columns
        try:
            required = ['action', 'mode', 'run', 'status', 'attempt',
                       'marker_taskcompleted', 'marker_control',
                       'proof_action', 'proof_complete', 'duration_ms']
            for col in required:
                _ = row[col]
            rows.append(row)
        except KeyError as e:
            print(f"  [WARN] Skipping row with missing column: {e}")
            continue

if not rows:
    print("FATAL: No valid rows in results CSV")
    print("")
    print("VERDICT: INCONCLUSIVE")
    print("Decision class: INCONCLUSIVE (no data)")
    gate = {"recommended_latency_cell": None, "m2_only": False,
            "cell_verdicts": {}, "overall_verdict": "INCONCLUSIVE",
            "decision_class": "INCONCLUSIVE"}
    with open(gate_path, 'w') as f:
        json.dump(gate, f, indent=2)
    sys.exit(0)

# Group rows by cell (action x mode)
cells = defaultdict(list)
for row in rows:
    cell_key = f"{row['action']}x{row['mode']}"
    cells[cell_key].append(row)

# Print raw data table
print("Raw Results:")
print(f"{'Cell':<10} {'Run':<5} {'Status':<12} {'TC':<6} {'Ctrl':<6} {'PrAct':<6} {'PrCmp':<6} {'ms':<10}")
print("-" * 65)
for row in rows:
    cell = f"{row['action']}x{row['mode']}"
    print(f"{cell:<10} {row['run']:<5} {row['status']:<12} "
          f"{row['marker_taskcompleted']:<6} {row['marker_control']:<6} "
          f"{row['proof_action']:<6} {row['proof_complete']:<6} "
          f"{row['duration_ms']:<10}")
print("")

# Compute verdict per cell
cell_verdicts = {}

def compute_cell_verdict(cell_key, cell_rows, required_n):
    """Compute FIRES/DOES_NOT_FIRE/UNSTABLE for a single cell."""
    succeeded = [r for r in cell_rows if r['status'] == 'succeeded']
    failed = [r for r in cell_rows if r['status'] != 'succeeded']
    n_total = len(cell_rows)
    n_succeeded = len(succeeded)
    n_failed = len(failed)

    # Count marker hits among succeeded runs
    tc_hits = sum(1 for r in succeeded if r['marker_taskcompleted'] == 'true')
    ctrl_hits = sum(1 for r in succeeded if r['marker_control'] == 'true')

    # Count proof presence among succeeded runs
    proof_action_hits = sum(1 for r in succeeded if r['proof_action'] == 'true')
    proof_complete_hits = sum(1 for r in succeeded if r['proof_complete'] == 'true')

    # Threshold for FIRES verdict: >=80% of required runs (4/5 or 3/3)
    fire_threshold = max(1, int(required_n * 0.8))

    info = {
        "n_total": n_total,
        "n_succeeded": n_succeeded,
        "n_failed": n_failed,
        "tc_hits": tc_hits,
        "ctrl_hits": ctrl_hits,
        "proof_action_hits": proof_action_hits,
        "proof_complete_hits": proof_complete_hits,
    }

    if n_succeeded == 0:
        return "UNSTABLE", info, "all runs failed"

    if tc_hits >= fire_threshold and n_failed == 0:
        return "FIRES", info, f"tc marker in {tc_hits}/{n_succeeded} succeeded runs, no failures"
    elif tc_hits == 0 and proof_action_hits > 0:
        return "DOES_NOT_FIRE", info, f"tc marker never appeared, action proof in {proof_action_hits}/{n_succeeded} runs"
    else:
        return "UNSTABLE", info, f"tc marker in {tc_hits}/{n_succeeded}, failures={n_failed}"

# Required cells
required_cells = ['a1xm1', 'a2xm1']
optional_cells = ['a1xm2', 'a2xm2']

for cell_key in required_cells + optional_cells:
    if cell_key not in cells:
        if cell_key in required_cells:
            cell_verdicts[cell_key] = ("UNSTABLE", {"n_total": 0}, "no data")
        continue
    required_n = 5 if cell_key in required_cells else 3
    verdict, info, reason = compute_cell_verdict(cell_key, cells[cell_key], required_n)
    cell_verdicts[cell_key] = (verdict, info, reason)

# Print per-cell verdicts
print("Per-Cell Verdicts:")
print(f"{'Cell':<10} {'Verdict':<18} {'TC Hits':<10} {'Ctrl Hits':<10} {'Proof Act':<10} {'Proof Cmp':<10} {'Reason'}")
print("-" * 100)
for cell_key in required_cells + optional_cells:
    if cell_key in cell_verdicts:
        verdict, info, reason = cell_verdicts[cell_key]
        tag = " [REQUIRED]" if cell_key in required_cells else " [OPTIONAL]"
        print(f"{cell_key:<10} {verdict:<18} "
              f"{info.get('tc_hits', 0)}/{info.get('n_succeeded', 0):<7} "
              f"{info.get('ctrl_hits', 0)}/{info.get('n_succeeded', 0):<7} "
              f"{info.get('proof_action_hits', 0)}/{info.get('n_succeeded', 0):<7} "
              f"{info.get('proof_complete_hits', 0)}/{info.get('n_succeeded', 0):<7} "
              f"{reason}{tag}")
    else:
        print(f"{cell_key:<10} {'SKIPPED':<18} {'—':<10} {'—':<10} {'—':<10} {'—':<10} not run")
print("")

# Overall verdict
# VERIFIED: at least one required headless cell is FIRES, or both required cells are
#           DOES_NOT_FIRE with strong action proof
# OBSERVED: signal exists but instability/retries remain
# INCONCLUSIVE: action proof missing or most cells unstable

required_verdicts = {k: cell_verdicts.get(k, ("UNSTABLE", {}, "missing"))[0] for k in required_cells}
any_required_fires = any(v == "FIRES" for v in required_verdicts.values())
all_required_dnf = all(v == "DOES_NOT_FIRE" for v in required_verdicts.values())
any_required_unstable = any(v == "UNSTABLE" for v in required_verdicts.values())

# Check for strong action proof in DOES_NOT_FIRE cells
strong_proof = True
for cell_key in required_cells:
    if cell_key in cell_verdicts:
        verdict, info, _ = cell_verdicts[cell_key]
        if verdict == "DOES_NOT_FIRE":
            if info.get('proof_action_hits', 0) < info.get('n_succeeded', 1):
                strong_proof = False

# Check if any optional M2 cell fires
optional_fires = False
for cell_key in optional_cells:
    if cell_key in cell_verdicts and cell_verdicts[cell_key][0] == "FIRES":
        optional_fires = True

# Compute total failure and retry counts
total_runs = len(rows)
total_failed = sum(1 for r in rows if r['status'] != 'succeeded')
total_succeeded = total_runs - total_failed

# Count retries from internal CSV (run_claude_session tracks attempt count)
# For M2 cells, attempt is always 1 (no retry logic)
total_retries = sum(1 for r in rows if r['status'] == 'succeeded' and int(r.get('attempt', '1')) > 1)

# Determine overall verdict
if any_required_fires and total_retries == 0:
    overall_verdict = "VERIFIED"
    decision_reason = "at least one required headless cell fires, no retries"
elif any_required_fires and total_retries > 0:
    overall_verdict = "OBSERVED"
    decision_reason = f"required headless cell fires but {total_retries} retry(ies) indicate instability"
elif all_required_dnf and strong_proof and total_retries == 0:
    overall_verdict = "VERIFIED"
    decision_reason = "both required cells confirmed DOES_NOT_FIRE with strong action proof"
elif all_required_dnf and strong_proof and total_retries > 0:
    overall_verdict = "OBSERVED"
    decision_reason = f"both required cells DOES_NOT_FIRE with action proof, but {total_retries} retry(ies)"
elif any_required_unstable and total_failed > 0:
    overall_verdict = "INCONCLUSIVE"
    decision_reason = f"required cells unstable, {total_failed} failed runs"
elif all_required_dnf and not strong_proof:
    overall_verdict = "INCONCLUSIVE"
    decision_reason = "DOES_NOT_FIRE but action proof missing in some runs"
else:
    # Check for any signal at all
    any_tc_hit = any(
        cell_verdicts[k][1].get('tc_hits', 0) > 0
        for k in cell_verdicts
    )
    if any_tc_hit:
        overall_verdict = "OBSERVED"
        decision_reason = "some TaskCompleted signal but unstable"
    else:
        overall_verdict = "INCONCLUSIVE"
        decision_reason = "no TaskCompleted signal and unstable results"

# Decision class follows overall verdict
decision_class = overall_verdict

# Determine recommended latency cell
recommended_cell = None
m2_only = False

# Prefer required headless cells
for cell_key in required_cells:
    if cell_key in cell_verdicts and cell_verdicts[cell_key][0] == "FIRES":
        recommended_cell = cell_key
        break

# Fall back to optional interactive cells
if recommended_cell is None:
    for cell_key in optional_cells:
        if cell_key in cell_verdicts and cell_verdicts[cell_key][0] == "FIRES":
            recommended_cell = cell_key
            m2_only = True
            break

# Print overall results
print("=" * 60)
print(f"VERDICT: {overall_verdict}")
print(f"Decision class: {decision_class}")
print(f"Reason: {decision_reason}")
print("")
print(f"Total runs: {total_runs}")
print(f"  Succeeded: {total_succeeded}")
print(f"  Failed: {total_failed}")
print(f"  Retries: {total_retries}")
print("")
print(f"Recommended latency cell: {recommended_cell if recommended_cell else 'null (no cell fires)'}")
print(f"M2 only: {m2_only}")
print("=" * 60)

# Write gate file
gate = {
    "recommended_latency_cell": recommended_cell,
    "m2_only": m2_only,
    "cell_verdicts": {
        k: {"verdict": v[0], "info": v[1], "reason": v[2]}
        for k, v in cell_verdicts.items()
    },
    "overall_verdict": overall_verdict,
    "decision_class": decision_class,
    "decision_reason": decision_reason,
    "total_runs": total_runs,
    "total_succeeded": total_succeeded,
    "total_failed": total_failed,
    "total_retries": total_retries,
}
with open(gate_path, 'w') as f:
    json.dump(gate, f, indent=2)
print(f"\nGate file written: {gate_path}")
PYEOF

# Save results CSV alongside script
cp "$RESULTS_FILE" "$SCRIPT_DIR/taskcompleted-trigger-matrix-results.csv" 2>/dev/null || true

echo ""
echo "Results CSV saved to: tests/verification/taskcompleted-trigger-matrix-results.csv"
echo "Gate file saved to: tests/verification/trigger-gate.json"
echo ""
echo "Experiment A complete."
