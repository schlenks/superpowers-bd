#!/usr/bin/env bash
# Test: What latency overhead do TaskCompleted hooks add?
#
# Method:
#   1. Run identical Claude sessions (create task + complete task)
#   2. Vary only the hook config: none, command, prompt, agent
#   3. Randomize hook-type order per cycle to avoid order bias
#   4. Measure wall-clock time per session
#   5. Exclude failed/timed-out runs from primary metrics
#   6. Overhead = (hook variant avg) - (no-hook baseline avg)
#   7. Command variant: marker file proves hook fired
#   8. Prompt/agent: timing delta vs baseline is execution evidence
#
# Thresholds:
#   FAST:     < 5s overhead  → acceptable for all workflows
#   MODERATE: 5-15s overhead → acceptable for important tasks only
#   SLOW:     15-60s         → only for critical quality gates
#   BLOCKING: > 60s          → impractical, needs redesign
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Verification: TaskCompleted Latency (#5)"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo ""

TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
export TEST_DIR
RESULTS_FILE="$TEST_DIR/results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$RESULTS_FILE"
export RESULTS_FILE

# Separate file for hook verification (command variant only)
HOOK_VERIFY_FILE="$TEST_DIR/hook_verify.csv"
echo "label,run,hook_fired" > "$HOOK_VERIFY_FILE"

NUM_RUNS=5

# The identical prompt used for every run
TASK_PROMPT="Create a task using TaskCreate with subject 'Latency test' and description 'Measuring hook latency'. Then immediately mark it as completed using TaskUpdate. Say only 'Done' when finished."

# Hook configurations — each variant uses ONLY its own type.
# No companion command hooks that would contaminate overhead measurement.
generate_hook_config() {
    local hook_type="$1"
    local marker_file="$2"  # Only used for command type

    case "$hook_type" in
        none)
            echo '{}'
            ;;
        command)
            cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch $marker_file",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
HOOKEOF
            ;;
        prompt)
            cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Is this task complete? Respond with JSON: {\"ok\": true}",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
HOOKEOF
            ;;
        agent)
            cat <<HOOKEOF
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "This task is complete. Respond with JSON: {\"ok\": true}",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
HOOKEOF
            ;;
    esac
}

run_hook_variant() {
    local label="$1"
    local run_num="$2"

    local project_dir="$TEST_DIR/project-$label-$run_num"
    local marker_file="$TEST_DIR/hook-fired-$label-$run_num.marker"
    mkdir -p "$project_dir/.claude"
    generate_hook_config "$label" "$marker_file" > "$project_dir/.claude/settings.json"

    git -C "$project_dir" init --quiet 2>/dev/null
    setup_git_identity "$project_dir"
    git -C "$project_dir" commit --allow-empty -m "init" --quiet 2>/dev/null

    PRE_ATTEMPT_CLEANUP="rm -f $marker_file" \
        CLAUDE_PROMPT="$TASK_PROMPT" CLAUDE_DIR="$project_dir" \
        run_claude_session "$label" "$run_num" 2 180 \
        sh -c 'cd "$CLAUDE_DIR" && claude -p "$CLAUDE_PROMPT" --permission-mode bypassPermissions --allowed-tools=all'

    # Verify hook fired — only for command type (which has a marker file)
    if [ "$label" = "command" ]; then
        if [ -f "$marker_file" ]; then
            echo "    [OK] Hook fired (marker file exists)"
            echo "$label,$run_num,true" >> "$HOOK_VERIFY_FILE"
        else
            echo "    [!!] Hook did NOT fire (marker file missing)"
            echo "$label,$run_num,false" >> "$HOOK_VERIFY_FILE"
        fi
    fi
}

# Randomize hook-type order per cycle
HOOK_TYPES=(none command prompt agent)

for cycle in $(seq 1 $NUM_RUNS); do
    echo ""
    echo "=== Cycle $cycle / $NUM_RUNS ==="

    # Shuffle hook types for this cycle
    shuffled=($(printf '%s\n' "${HOOK_TYPES[@]}" | sort -R))

    for hook_type in "${shuffled[@]}"; do
        echo "--- $hook_type (run $cycle) ---"
        run_hook_variant "$hook_type" "$cycle"
    done
done

# --- Summary ---
echo ""
echo "========================================"
echo " Results Summary"
echo "========================================"
echo ""

RESULTS_PATH="$RESULTS_FILE" HOOK_VERIFY_PATH="$HOOK_VERIFY_FILE" python3 << 'PYEOF'
import csv, os, math
from collections import defaultdict

results = defaultdict(list)
all_rows = []
with open(os.environ['RESULTS_PATH'], 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_rows.append(row)
        if row['status'] == 'succeeded':
            results[row['label']].append(int(row['duration_ms']))

# Load hook verification for command variant
hook_verify = {}
with open(os.environ['HOOK_VERIFY_PATH'], 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        key = (row['label'], row['run'])
        hook_verify[key] = row['hook_fired'] == 'true'

# Filter out command runs where hook didn't fire — count as instability
hook_miss_count = 0
if 'command' in results:
    verified_command = []
    for row in all_rows:
        if row['label'] == 'command' and row['status'] == 'succeeded':
            key = ('command', row['run'])
            if hook_verify.get(key, False):
                verified_command.append(int(row['duration_ms']))
            else:
                print(f"  [EXCLUDED] command run {row['run']}: hook didn't fire (counted as instability)")
                hook_miss_count += 1
    results['command'] = verified_command

failed_count = sum(1 for r in all_rows if r['status'] != 'succeeded')
total_count = len(all_rows)
print(f"Runs: {total_count} total, {total_count - failed_count} succeeded, {failed_count} excluded")
print()

def stdev(vals):
    if len(vals) < 2:
        return 0
    avg = sum(vals) / len(vals)
    return math.sqrt(sum((v - avg) ** 2 for v in vals) / (len(vals) - 1))

print(f"{'Type':<12} {'N':<4} {'Avg (ms)':<12} {'Stdev':<12} {'Min (ms)':<12} {'Max (ms)':<12}")
print("-" * 64)

for hook_type in ['none', 'command', 'prompt', 'agent']:
    if hook_type in results and results[hook_type]:
        vals = results[hook_type]
        avg = sum(vals) // len(vals)
        sd = stdev(vals)
        print(f"{hook_type:<12} {len(vals):<4} {avg:<12} {sd:<12.0f} {min(vals):<12} {max(vals):<12}")

if 'none' in results and len(results['none']) >= 2:
    baseline_vals = results['none']
    baseline_avg = sum(baseline_vals) / len(baseline_vals)
    baseline_sd = stdev(baseline_vals)
    print()
    print("Hook overhead (avg - baseline):")
    unconfirmed_types = []
    insufficient_types = []
    timing_inferred_types = []
    MIN_RUNS_PER_TYPE = 3
    for hook_type in ['command', 'prompt', 'agent']:
        if hook_type in results and len(results[hook_type]) >= MIN_RUNS_PER_TYPE:
            vals = results[hook_type]
            avg = sum(vals) / len(vals)
            overhead = avg - baseline_avg
            sd = stdev(vals)

            if overhead < 5000:
                verdict = "FAST"
            elif overhead < 15000:
                verdict = "MODERATE"
            elif overhead < 60000:
                verdict = "SLOW"
            else:
                verdict = "BLOCKING"

            # For prompt/agent: execution is timing-inferred, not directly observed
            note = ""
            if hook_type in ('prompt', 'agent'):
                if abs(overhead) < 2 * baseline_sd:
                    note = " [UNCONFIRMED: timing-inferred, within baseline variance]"
                    unconfirmed_types.append(hook_type)
                else:
                    note = " [timing-inferred, distinguishable from baseline]"
                    timing_inferred_types.append(hook_type)

            print(f"  {hook_type}: +{overhead:.0f}ms ({verdict}){note}")
        else:
            n_have = len(results.get(hook_type, []))
            print(f"  {hook_type}: insufficient successful runs ({n_have}/{MIN_RUNS_PER_TYPE} required)")
            insufficient_types.append(hook_type)

    # Decision class with variance check
    print()
    retry_passes = sum(1 for r in all_rows if r.get('pass_label') == 'retry-pass')
    high_variance = any(
        stdev(results[t]) > 0.3 * (sum(results[t]) / len(results[t]))
        for t in results if len(results[t]) >= 2 and sum(results[t]) > 0
    )

    if failed_count > 0:
        print(f"Decision class: INCONCLUSIVE ({failed_count} runs failed — not all types consistently succeeded)")
    elif hook_miss_count > 0:
        print(f"Decision class: INCONCLUSIVE ({hook_miss_count} command run(s) succeeded but hook didn't fire — direct evidence inconsistent)")
    elif insufficient_types:
        types_str = ", ".join(insufficient_types)
        print(f"Decision class: INCONCLUSIVE (insufficient data for: {types_str})")
    elif unconfirmed_types:
        types_str = ", ".join(unconfirmed_types)
        print(f"Decision class: INCONCLUSIVE ({types_str} execution timing-inferred, not directly observed)")
    elif retry_passes > 0:
        print(f"Decision class: INCONCLUSIVE ({retry_passes} retry-passes — results unstable)")
    elif high_variance:
        print("Decision class: INCONCLUSIVE (high variance — stdev > 30% of mean for some types)")
    elif timing_inferred_types:
        types_str = ", ".join(timing_inferred_types)
        print(f"Decision class: OBSERVED ({types_str} timing-inferred with distinguishable overhead, command directly observed)")
    else:
        print("Decision class: VERIFIED (all first-pass successes, zero failures, low variance, all types directly observed)")
else:
    print()
    print("Decision class: INCONCLUSIVE (insufficient baseline data)")
PYEOF

# Save results
cp "$RESULTS_FILE" "$SCRIPT_DIR/taskcompleted-latency-results.csv" 2>/dev/null || true
rm -rf "$TEST_DIR"

echo ""
echo "Results saved to: tests/verification/taskcompleted-latency-results.csv"
