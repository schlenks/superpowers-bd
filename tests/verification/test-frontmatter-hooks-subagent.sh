#!/usr/bin/env bash
# Test: Do frontmatter-defined PostToolUse hooks fire for subagent tool calls?
#
# Method:
#   1. Positive control (3 runs): verify hook fires in non-subagent context
#   2. Experiment (3 runs): spawn subagent via Task tool, check if hook fires
#   3. Verdict based on aggregate results across runs
#
# Verdict:
#   CONFIRMED — hook fires in all experiment runs (and positive control passes in all runs)
#   DENIED    — hook never fires in experiment (but positive control passes)
#   PARTIAL   — hook fires in some but not all experiment runs
#   INCONCLUSIVE — positive control fails OR subagent doesn't execute
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Verification: Frontmatter Hooks (#42)"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo ""

# Setup
TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
export TEST_DIR
RESULTS_FILE="$TEST_DIR/results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$RESULTS_FILE"
export RESULTS_FILE

NUM_RUNS=3

echo "Test dir: $TEST_DIR"
echo ""

# ========================================
# Step 1: Positive control (non-subagent)
# ========================================
echo "--- Positive Control: Hook in non-subagent context (${NUM_RUNS} runs) ---"
echo "  (If this fails, the test harness is broken, not the feature)"
echo ""

POSITIVE_DIR="$TEST_DIR/positive-project"
mkdir -p "$POSITIVE_DIR/.claude"

git -C "$POSITIVE_DIR" init --quiet 2>/dev/null
setup_git_identity "$POSITIVE_DIR"
git -C "$POSITIVE_DIR" commit --allow-empty -m "init" --quiet 2>/dev/null

POSITIVE_PASS=0
for i in $(seq 1 $NUM_RUNS); do
    # Per-run marker and target files
    P_MARKER="$TEST_DIR/positive-marker-$i"
    P_TARGET="$TEST_DIR/positive-target-$i.txt"

    # Write settings.json with per-run marker path
    cat > "$POSITIVE_DIR/.claude/settings.json" << POSJSON
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "touch $P_MARKER",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
POSJSON

    P_PROMPT="Write the exact text 'hello' to the file $P_TARGET using the Write tool. Do nothing else."

    PRE_ATTEMPT_CLEANUP="rm -f $P_MARKER $P_TARGET" \
        CLAUDE_PROMPT="$P_PROMPT" CLAUDE_DIR="$POSITIVE_DIR" \
        run_claude_session "positive-control" "$i" 2 180 \
        sh -c 'cd "$CLAUDE_DIR" && claude -p "$CLAUDE_PROMPT" --permission-mode bypassPermissions --allowed-tools=all'

    if [ -f "$P_MARKER" ] && [ -f "$P_TARGET" ]; then
        echo "    [OK] Run $i: hook fired and file written"
        POSITIVE_PASS=$((POSITIVE_PASS + 1))
    elif [ -f "$P_TARGET" ]; then
        echo "    [!!] Run $i: file written but hook did NOT fire"
    else
        echo "    [!!] Run $i: file not written (session may have failed)"
    fi
done

echo ""
echo "  Positive control: $POSITIVE_PASS/$NUM_RUNS passed"

POSITIVE_CONTROL_PASSED=false
POS_FAILURES=$(awk -F, '$1=="positive-control" && $4!="succeeded" {n++} END {print n+0}' "$RESULTS_FILE")
POS_RETRIES=$(awk -F, '$1=="positive-control" && $6=="retry-pass" {n++} END {print n+0}' "$RESULTS_FILE")

if [ $POSITIVE_PASS -ne $NUM_RUNS ]; then
    echo "  [!!] Positive control FAILED ($POSITIVE_PASS/$NUM_RUNS passed — all runs required)"
elif [ "$POS_FAILURES" -gt 0 ]; then
    echo "  [!!] Positive control UNSTABLE ($POS_FAILURES run(s) failed)"
elif [ "$POS_RETRIES" -gt 0 ]; then
    echo "  [!!] Positive control UNSTABLE ($POS_RETRIES run(s) required retry)"
else
    echo "  [OK] Positive control PASSED ($NUM_RUNS/$NUM_RUNS, all first-pass)"
    POSITIVE_CONTROL_PASSED=true
fi
echo ""

# ========================================
# Step 2: Subagent test (the actual experiment)
# ========================================
echo "--- Subagent Test: PostToolUse hook via --agents (${NUM_RUNS} runs) ---"

EXPERIMENT_FIRED=0
EXPERIMENT_WROTE=0
SUBAGENT_INVOKED=0

for i in $(seq 1 $NUM_RUNS); do
    E_MARKER="$TEST_DIR/subagent-marker-$i"
    E_TARGET="$TEST_DIR/subagent-target-$i.txt"

    AGENTS_JSON=$(cat <<AGENTEOF
{
  "hooked-writer": {
    "description": "Test agent that writes a file. Has a PostToolUse hook that touches a marker file.",
    "prompt": "You are a test agent. Write the exact text 'hello' to the file path given in your task prompt. Use the Write tool exactly once. Do nothing else.",
    "hooks": {
      "PostToolUse": [
        {
          "matcher": "Write",
          "hooks": [
            {
              "type": "command",
              "command": "touch $E_MARKER",
              "timeout": 30
            }
          ]
        }
      ]
    }
  }
}
AGENTEOF
)

    PROMPT="Use the Task tool to spawn the 'hooked-writer' subagent with this prompt: 'Write the text hello to the file $E_TARGET using the Write tool.' Wait for it to finish."

    # Create per-run timestamp file BEFORE the session, so we only find transcripts newer than this
    RUN_TIMESTAMP="$TEST_DIR/timestamp-run-$i"
    touch "$RUN_TIMESTAMP"
    sleep 1  # ensure filesystem timestamp granularity separates pre/post

    PRE_ATTEMPT_CLEANUP="rm -f $E_MARKER $E_TARGET" \
        run_claude_session "subagent-hook" "$i" 2 180 \
        claude -p "$PROMPT" --permission-mode bypassPermissions --allowed-tools=all --agents "$AGENTS_JSON"

    # Check subagent invocation proof: parse session .jsonl for Task tool-use events
    # Uses per-run timestamp file to ensure we only check the transcript from THIS run
    SESSION_JSONL=$(find_session_transcript "$(pwd)" 5 "$RUN_TIMESTAMP")
    if verify_task_tool_used "$SESSION_JSONL" "hooked-writer"; then
        SUBAGENT_INVOKED=$((SUBAGENT_INVOKED + 1))
        echo "    [OK] Run $i: Task tool invocation for hooked-writer confirmed in session transcript"
    elif [ -n "$SESSION_JSONL" ]; then
        echo "    [!!] Run $i: session transcript found but no Task tool invocation for hooked-writer"
    else
        echo "    [!!] Run $i: no session transcript found (looked in ~/.claude/projects/)"
    fi

    if [ -f "$E_TARGET" ]; then
        EXPERIMENT_WROTE=$((EXPERIMENT_WROTE + 1))
        if [ -f "$E_MARKER" ]; then
            EXPERIMENT_FIRED=$((EXPERIMENT_FIRED + 1))
            echo "    [OK] Run $i: subagent wrote file AND hook fired"
        else
            echo "    [!!] Run $i: subagent wrote file but hook did NOT fire"
        fi
    else
        echo "    [!!] Run $i: subagent did not write file"
    fi
done

echo ""

# Check results
echo "========================================"
echo " Results"
echo "========================================"
echo ""
echo "  Positive control: $POSITIVE_PASS/$NUM_RUNS"
echo "  Subagent invoked: $SUBAGENT_INVOKED/$NUM_RUNS"
echo "  Experiment wrote: $EXPERIMENT_WROTE/$NUM_RUNS"
echo "  Experiment fired: $EXPERIMENT_FIRED/$NUM_RUNS"
echo ""

VERDICT="INCONCLUSIVE"
DECISION_CLASS="INCONCLUSIVE"

# Check run stability from CSV: any experiment failures or retry-passes?
EXP_FAILURES=$(awk -F, '$1=="subagent-hook" && $4!="succeeded" {n++} END {print n+0}' "$RESULTS_FILE")
EXP_RETRIES=$(awk -F, '$1=="subagent-hook" && $6=="retry-pass" {n++} END {print n+0}' "$RESULTS_FILE")

# Determine verdict (what happened)
if [ "$POSITIVE_CONTROL_PASSED" != "true" ]; then
    echo "  >>> VERDICT: INCONCLUSIVE (positive control failed) <<<"
elif [ $SUBAGENT_INVOKED -ne $NUM_RUNS ]; then
    echo "  >>> VERDICT: INCONCLUSIVE ($SUBAGENT_INVOKED/$NUM_RUNS runs had subagent proof — all required) <<<"
elif [ $EXPERIMENT_WROTE -eq 0 ]; then
    echo "  >>> VERDICT: INCONCLUSIVE (subagent never wrote — execution problem) <<<"
elif [ $EXPERIMENT_WROTE -ne $NUM_RUNS ]; then
    echo "  >>> VERDICT: INCONCLUSIVE ($EXPERIMENT_WROTE/$NUM_RUNS successful writes — all runs required) <<<"
elif [ "$EXP_FAILURES" -gt 0 ]; then
    echo "  >>> VERDICT: INCONCLUSIVE ($EXP_FAILURES experiment run(s) failed — unstable) <<<"
elif [ "$EXP_RETRIES" -gt 0 ]; then
    echo "  >>> VERDICT: INCONCLUSIVE ($EXP_RETRIES experiment run(s) required retry — unstable) <<<"
elif [ $EXPERIMENT_FIRED -eq $EXPERIMENT_WROTE ]; then
    echo "  >>> VERDICT: CONFIRMED <<<"
    echo "  Frontmatter PostToolUse hooks DO fire for subagent tool calls."
    echo "  ($EXPERIMENT_FIRED/$EXPERIMENT_WROTE runs, all first-pass, subagent proof in all runs)"
    VERDICT="CONFIRMED"
elif [ $EXPERIMENT_FIRED -gt 0 ]; then
    echo "  >>> VERDICT: PARTIAL (inconsistent) <<<"
    echo "  Hook fired in $EXPERIMENT_FIRED/$EXPERIMENT_WROTE runs — behavior is flaky."
    VERDICT="PARTIAL"
else
    echo "  >>> VERDICT: DENIED <<<"
    echo "  Hook never fired in $EXPERIMENT_WROTE successful subagent runs."
    VERDICT="DENIED"
fi

echo ""

# If DENIED, run secondary test with PreToolUse (single run — just probing)
# This runs BEFORE decision class computation so DECISION_CLASS reflects final VERDICT
if [ "$VERDICT" = "DENIED" ]; then
    echo "========================================"
    echo " Secondary Test: PreToolUse hook"
    echo "========================================"

    PRE_MARKER="$TEST_DIR/hook-pre-fired.marker"
    PRE_TARGET="$TEST_DIR/output-pre.txt"

    AGENTS_JSON_PRE=$(cat <<EOF2
{
  "hooked-writer-pre": {
    "description": "Test agent with PreToolUse hook.",
    "prompt": "You are a test agent. Write the exact text 'hello' to the file path given in your task prompt. Use the Write tool exactly once. Do nothing else.",
    "hooks": {
      "PreToolUse": [
        {
          "matcher": "Write",
          "hooks": [
            {
              "type": "command",
              "command": "touch $PRE_MARKER",
              "timeout": 30
            }
          ]
        }
      ]
    }
  }
}
EOF2
)

    PROMPT_PRE="Use the Task tool to spawn the 'hooked-writer-pre' subagent with this prompt: 'Write the text hello to the file $PRE_TARGET using the Write tool.' Wait for it to finish."

    run_claude_session "subagent-hook-pre" 1 2 180 \
        claude -p "$PROMPT_PRE" --permission-mode bypassPermissions --allowed-tools=all --agents "$AGENTS_JSON_PRE"

    if [ -f "$PRE_MARKER" ]; then
        echo "  PreToolUse hook DID fire (different behavior than PostToolUse!)"
        VERDICT="PARTIAL"
    else
        echo "  PreToolUse hook also did NOT fire"
        echo "  Neither Pre nor Post ToolUse hooks fire for subagent tool calls"
    fi
    echo ""
fi

# Determine decision class (confidence in evidence) — computed AFTER secondary probe
# so it reflects the final verdict state.
# VERIFIED requires: all runs first-pass, positive control perfect, zero failed/retry,
# subagent proof in all runs, and verdict is conclusive (not INCONCLUSIVE).
if [ "$VERDICT" != "INCONCLUSIVE" ] && \
   [ "$POSITIVE_CONTROL_PASSED" = "true" ] && \
   [ "$EXP_FAILURES" -eq 0 ] && \
   [ "$EXP_RETRIES" -eq 0 ] && \
   [ $SUBAGENT_INVOKED -eq $NUM_RUNS ] && \
   [ $EXPERIMENT_WROTE -eq $NUM_RUNS ]; then
    DECISION_CLASS="VERIFIED"
fi

echo "Verdict: $VERDICT"
echo "Decision class: $DECISION_CLASS"

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "Test complete."
echo "Final: Verdict=$VERDICT, Decision class=$DECISION_CLASS"

# Exit 0 for conclusive outcomes with VERIFIED decision class
# Exit 1 for INCONCLUSIVE decision class (harness/stability/evidence failure)
case "$DECISION_CLASS" in
    INCONCLUSIVE) exit 1 ;;
    *)            exit 0 ;;
esac
