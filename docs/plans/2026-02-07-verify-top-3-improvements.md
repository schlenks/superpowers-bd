# Top 3 Improvement Verification Plan

> **For Claude:** After human approval, use plan2beads to convert this plan to a beads epic, then use `superpowers:subagent-driven-development` for parallel execution.

**Goal:** Conclusively verify three unproven assumptions in the improvements doc (#42 frontmatter hooks for subagents, #5 TaskCompleted hook latency, #1 Two-Phase Reflective generalization) and update the improvements doc with findings.

**Architecture:** Three independent verification experiments run as isolated test scripts. A shared runner function handles retries, failure detection, and timeout classification. Each experiment produces a verdict (CONFIRMED/DENIED/PARTIAL/INCONCLUSIVE) describing what was found, paired with a decision class (VERIFIED/OBSERVED/INCONCLUSIVE) describing confidence in the evidence. Tasks 1 and 3 emit a verdict (CONFIRMED/DENIED/PARTIAL/INCONCLUSIVE) and a decision class (VERIFIED/INCONCLUSIVE). Task 2 emits a decision class (VERIFIED/OBSERVED/INCONCLUSIVE) with per-type latency bands (FAST/MODERATE/SLOW/BLOCKING) instead of verdicts. Task 4 gates on decision class first, then acts on verdict or latency data. Results feed back into the improvements doc as research-verified updates.

**Tech Stack:** Bash test scripts, Claude Code CLI (`claude -p`), `python3` for timing/analysis/JSON parsing.

**Key Decisions:**
- **`--agents` CLI flag for test agents** — Official docs confirm this supports all frontmatter fields including `hooks`. Avoids polluting project agent directories.
- **Bash scripts over manual testing** — Reproducible, can be re-run after Claude Code updates, stored as project artifacts
- **Three separate tasks, no dependencies** — Each verification is independent; all three can run in parallel
- **Verdicts with pre-defined thresholds** — Pass/fail criteria decided before running, so results are objective
- **Shared runner with retry logic** — All scripts use `run_claude_session()` which tracks exit codes, detects timeouts, retries failed runs, and excludes failures from primary metrics
- **Neutral-label JSON scoring with decoys** — Task 3 uses neutral area IDs (no answer leakage) plus 3 decoy areas. Score = true positives - false positives (Findings v3-#4)
- **`--allowed-tools=all` on all headless invocations** — Matches established repo test patterns
- **Positive control in Task 1** — Non-subagent hook test rules out harness failure, 3 runs for reliability
- **Pure per-type measurement in Task 2** — Each hook variant uses ONLY its own type (no companion command hook that would contaminate overhead). Command variant has marker proof; prompt/agent use timing delta as execution evidence (Findings v3-#2, v3-#3)

**Decision Classes** (confidence in evidence quality):
- **VERIFIED** — Zero failures, all first-pass, low variance, ALL evaluated types directly observed. No timing-inferred types present.
- **OBSERVED** — Same stability as VERIFIED but some types rely on timing inference (distinguishable from baseline but not directly observed). Command type directly observed.
- **INCONCLUSIVE** — Any failures, retry-passes, high variance (stdev > 30% of mean), insufficient data, unconfirmed execution, hook-miss on direct evidence, FP > 1, or parse failure rate > 30%

**Verdicts** (what the experiment found):
- **CONFIRMED** — Evidence supports the hypothesis
- **PARTIAL** — Mixed or marginal results
- **DENIED** — Evidence contradicts the hypothesis
- **INCONCLUSIVE** — Cannot determine (harness/stability issue)

Decision class gates whether to act; verdict determines what action to take.

---

## Shared: `run_claude_session()` Helper

All three test scripts source this shared function. It handles retry logic, timeout detection, and failure exclusion.

**File:** Create `tests/verification/test-helpers.sh`

```bash
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

    # Escape path: replace / with -, strip leading -
    local escaped
    escaped=$(echo "$working_dir" | sed 's/\//-/g' | sed 's/^-//')
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
```

---

## Task 1: Verify Frontmatter Hooks Fire for Subagent Tool Calls (#42)

**Depends on:** None
**Files:**
- Create: `tests/verification/test-frontmatter-hooks-subagent.sh`

**Purpose:** Determine whether PostToolUse hooks defined in an agent's frontmatter fire when that agent runs as a subagent via the Task tool. This is the single highest-leverage verification — it gates #25 (linter guards) and #3 (file ownership hooks).

**Not In Scope:**
- Global settings hooks (already known not to fire per Issue #21460)
- TeammateIdle / TaskCompleted hooks (already verified as working)

**Gotchas:**
- Must use `--agents` CLI flag (not `--add-dir`) to register the agent with hooks — per official docs, `--add-dir` only extends file access, not agent discovery
- `claude -p` runs in headless mode — hooks must produce observable side effects (file creation via `touch`)
- Hook `timeout` should be generous (30s) to avoid false negatives from slow startup
- The marker file path must be absolute (no `~` expansion in hook commands)
- If `mktemp -d` returns a path with spaces, the JSON will break. The `verify_no_spaces()` preflight guard (in test-helpers.sh) catches this automatically.
- Run 3 times per phase to handle flakiness in headless environments (Finding v3-#7)

**Step 1: Create the test script**

Create `tests/verification/test-frontmatter-hooks-subagent.sh`:

```bash
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
    # (follows established repo pattern from tests/claude-code/test-subagent-driven-development-integration.sh)
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
```

**Step 2: Run the test**

```bash
mkdir -p tests/verification
chmod +x tests/verification/test-helpers.sh tests/verification/test-frontmatter-hooks-subagent.sh
./tests/verification/test-frontmatter-hooks-subagent.sh
```

**Step 3: Interpret and record**

Gate on decision class first (per hard rule in Task 4), then act on verdict:

| Decision Class | Verdict | Implication for improvements doc |
|---------------|---------|----------------------------------|
| INCONCLUSIVE | (any) | Record as "tested, inconclusive (reason)". No priority change. Debug test setup, re-run. |
| VERIFIED | CONFIRMED | Remove "⚠️ VERIFY" from P1.3. Promote #25 (linter guards) to P2.2. #3 has viable path. |
| VERIFIED | DENIED | Mark P1.3 as "VERIFIED: Does NOT work." #25 and #3 both defer to P5+. |
| VERIFIED | PARTIAL | Record as "tested, inconsistent behavior." No priority promotion; investigate flakiness. |

---

## Task 2: Benchmark TaskCompleted Hook Latency (#5)

**Depends on:** None
**Files:**
- Create: `tests/verification/test-taskcompleted-latency.sh`

**Purpose:** Measure the overhead added by TaskCompleted hooks for each handler type (`command`, `prompt`, `agent`). This determines which types are practical for SDD workflows where many tasks complete per session.

**Not In Scope:**
- Testing hook blocking behavior (exit code 2) — already documented as working
- Testing with actual quality gate logic — measure baseline overhead only

**Gotchas:**
- Total session time includes model thinking + tool use + hook overhead. To isolate hook overhead, we compare sessions WITH hooks to baseline sessions WITHOUT hooks. The difference is the hook overhead.
- `type: "agent"` hooks can take up to 50 turns — use a trivial prompt that finishes in 1 turn
- `type: "prompt"` uses Haiku by default — latency depends on API response time
- Run each type 5 times to reduce variance. Hook type order is randomized per cycle to avoid systematic bias.
- TaskCompleted hooks live in `.claude/settings.json`, which Claude reads from the working directory. We `cd` to a temp project dir (with git init + `.claude/settings.json`) so each test variant has isolated hook config.
- Failed/timed-out runs are excluded from primary metrics and retried.
- Each hook variant uses ONLY its own type — no companion hooks that would contaminate the measurement. The `command` variant uses `touch marker` (directly observed proof it fired AND is the measured overhead). For `prompt`/`agent`, timing delta vs baseline is the only available signal — this is timing-inferred, not directly observed. Even with significant delta, these types are labeled "timing-inferred" and cannot reach VERIFIED (only OBSERVED). If delta is within baseline variance, report as INCONCLUSIVE for that type (Finding v3-#2, v3-#3, v5-#2).

**Step 1: Create the latency test script**

Create `tests/verification/test-taskcompleted-latency.sh`:

```bash
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
```

**Step 2: Run the test**

```bash
chmod +x tests/verification/test-taskcompleted-latency.sh
./tests/verification/test-taskcompleted-latency.sh
```

Expected: ~25 minutes (20 sessions × ~60-90s each, randomized order).

**Step 3: Interpret results**

| Hook Type Overhead | Recommendation |
|-------------------|----------------|
| `command` FAST (<5s) | Use for all quality gates in SDD |
| `prompt` FAST (<5s) | Use for lightweight LLM-based checks |
| `agent` MODERATE (5-15s) | Use only for epic verification, not per-task |
| `agent` SLOW/BLOCKING (>15s) | Document as impractical; recommend `prompt` instead |
| Any type within baseline variance | INCONCLUSIVE — cannot confirm hook executed |

---

## Task 3: Test Two-Phase Reflective Generalization (#1)

**Depends on:** None
**Files:**
- Create: `tests/verification/test-two-phase-reflective.sh`
- Create: `tests/verification/fixtures/known-buggy-spec.md`
- Create: `tests/verification/fixtures/known-buggy-impl.md`

**Purpose:** Test whether the Two-Phase Reflective review method (from arXiv 2508.12358, validated on HumanEval code) also catches issues in spec/implementation review — the actual use case for superpowers-bd reviewers.

**Not In Scope:**
- Benchmarking against behavioral comparison (too expensive for a verification test)
- Statistical significance (we need directional signal, not a paper)
- Testing on actual production reviews (use synthetic known-bad fixtures)

**Gotchas:**
- The test needs fixtures with KNOWN planted bugs so we can measure detection rate objectively
- Must test both the actual review prompt (from `skills/requesting-code-review/code-reviewer.md`, populated with fixture data) AND the Two-Phase Reflective prompt (treatment)
- LLM output is non-deterministic — run each 5 times and count detection rate
- Cost: each run is one API call. 5 runs × 2 methods = 10 calls
- Bug detection uses neutral area labels with 3 decoy areas to prevent answer leakage and catch false positives (Finding v3-#4). Score = true positives - false positives.
- Boolean values must be checked strictly (`is True`) to avoid string "false" counting as truthy (Finding v3-#5)
- Failed/timed-out runs are excluded and retried

**Step 1: Create test fixtures with known planted issues**

Create `tests/verification/fixtures/known-buggy-spec.md`:

```markdown
# Widget API Implementation Spec

## Requirements

1. Create a REST API endpoint `GET /api/widgets` that returns all widgets
2. Create `POST /api/widgets` that creates a new widget with `name` (required) and `color` (optional, default "blue")
3. Create `DELETE /api/widgets/:id` that deletes a widget by ID
4. All endpoints return JSON with `{ data: ..., error: null }` envelope
5. Input validation: name must be 1-100 characters, alphanumeric only
6. Rate limiting: max 100 requests per minute per IP
```

Create `tests/verification/fixtures/known-buggy-impl.md`:

```markdown
# Implementation Report

## What Was Built

Implemented the Widget API as specified.

### Files Created
- `src/routes/widgets.ts` — All three endpoints
- `src/middleware/rateLimit.ts` — Rate limiting middleware
- `tests/widgets.test.ts` — Test suite (12 tests, all passing)

### Implementation Details

**GET /api/widgets** — Returns all widgets from the database with pagination (page, limit params).

**POST /api/widgets** — Creates widget. Validates name is present. Color defaults to "blue".

**DELETE /api/widgets/:id** — Soft-deletes widget (sets `deleted_at` timestamp instead of removing).

**Rate Limiting** — Configured at 100 requests per minute using express-rate-limit.

**Tests** — All 12 tests pass. Covers happy paths and error cases.

### Known Issues
None. All requirements implemented.
```

**Planted bugs and decoys (8 areas total — ground truth in Python scorer, NOT in prompt):**

| Area ID | Label Given to Model | Ground Truth | Explanation |
|---------|---------------------|-------------|-------------|
| AREA_A | GET endpoint behavior | REAL BUG | Pagination added, spec says "returns all" |
| AREA_B | Rate limiting config | DECOY | Rate limiting is correct per spec |
| AREA_C | Input validation completeness | REAL BUG | Only checks "present", missing 1-100 + alphanumeric |
| AREA_D | Default value handling | DECOY | Color default "blue" is correct per spec |
| AREA_E | DELETE endpoint behavior | REAL BUG | Soft-delete vs actual delete |
| AREA_F | Response format compliance | REAL BUG | Missing { data, error } envelope |
| AREA_G | Endpoint coverage | DECOY | All three endpoints exist |
| AREA_H | Unrequested features | REAL BUG | deleted_at field added without spec requirement |

The model receives only the neutral labels (column 2), not the ground truth. It must independently determine whether each area has a real issue.

**Step 2: Create the test script**

Create `tests/verification/test-two-phase-reflective.sh`:

```bash
#!/usr/bin/env bash
# Test: Does Two-Phase Reflective catch more bugs than current review prompt?
#
# 8 areas evaluated (5 real bugs + 3 decoys):
#   AREA_A: GET endpoint behavior (REAL)
#   AREA_B: Rate limiting config (DECOY)
#   AREA_C: Input validation completeness (REAL)
#   AREA_D: Default value handling (DECOY)
#   AREA_E: DELETE endpoint behavior (REAL)
#   AREA_F: Response format compliance (REAL)
#   AREA_G: Endpoint coverage (DECOY)
#   AREA_H: Unrequested features (REAL)
#
# Score = true_positives - false_positives (penalizes shotgun marking)
#
# Verdict:
#   CONFIRMED — Two-Phase scores >= 1.0 higher on average
#   PARTIAL   — Same score (method works but no improvement)
#   DENIED    — Two-Phase scores lower
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
source "$SCRIPT_DIR/test-helpers.sh"

echo "========================================"
echo " Verification: Two-Phase Reflective (#1)"
echo "========================================"
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"
echo ""

# Load fixtures
SPEC=$(cat "$FIXTURES_DIR/known-buggy-spec.md")
IMPL=$(cat "$FIXTURES_DIR/known-buggy-impl.md")

TEST_DIR=$(mktemp -d)
verify_no_spaces "$TEST_DIR"
export TEST_DIR
RESULTS_FILE="$TEST_DIR/results.csv"
echo "label,run,duration_ms,status,attempt,pass_label" > "$RESULTS_FILE"
export RESULTS_FILE

NUM_RUNS=5

# Structured JSON output instructions (shared suffix for both prompts).
# Uses NEUTRAL area labels — no descriptions of what each bug is.
# Includes 3 decoy areas (correctly implemented features) to catch false positives.
JSON_SUFFIX='

## REQUIRED: Structured Output

After your analysis, evaluate each of the following areas. For each area, determine
whether you found a real issue (deviation from spec, missing requirement, or unrequested
behavior). Mark "found": true ONLY if your analysis above independently identified a
real problem in that area. Mark "found": false if the area is implemented correctly.

```json
{
  "areas": {
    "AREA_A": {"found": true, "evidence": "brief explanation"},
    "AREA_B": {"found": true, "evidence": "..."},
    "AREA_C": {"found": true, "evidence": "..."},
    "AREA_D": {"found": true, "evidence": "..."},
    "AREA_E": {"found": true, "evidence": "..."},
    "AREA_F": {"found": true, "evidence": "..."},
    "AREA_G": {"found": true, "evidence": "..."},
    "AREA_H": {"found": true, "evidence": "..."}
  }
}
```

Areas to evaluate:
- AREA_A: GET endpoint behavior
- AREA_B: Rate limiting configuration
- AREA_C: Input validation completeness
- AREA_D: Default value handling
- AREA_E: DELETE endpoint behavior
- AREA_F: Response format compliance
- AREA_G: Endpoint coverage
- AREA_H: Unrequested features

You MUST include this JSON block with all 8 areas evaluated.'

# --- Method A: Current review prompt (faithful to code-reviewer.md structure) ---
read -r -d '' CURRENT_PROMPT << 'CURRENT_EOF' || true
You are reviewing code changes for production readiness.

**Your task:**
1. Review Widget API implementation
2. Compare against the specification below
3. Check code quality, architecture, testing
4. Categorize issues by severity
5. Assess production readiness

## Requirements/Plan

CURRENT_EOF
CURRENT_PROMPT="$CURRENT_PROMPT
$SPEC

## Implementer's Report

$IMPL

## Review Checklist

**Code Quality:** Clean separation of concerns? Proper error handling? Edge cases handled?
**Architecture:** Sound design decisions? Scalability? Performance? Security?
**Testing:** Tests actually test logic? Edge cases covered? All tests passing?
**Requirements:** All plan requirements met? Implementation matches spec? No scope creep? Breaking changes documented?
**Production Readiness:** Migration strategy? Backward compatibility? Documentation complete? No obvious bugs?

## Output Format

### Issues

#### Critical (Must Fix)
[Bugs, security issues, data loss risks, broken functionality]

#### Important (Should Fix)
[Architecture problems, missing features, poor error handling, test gaps]

#### Minor (Nice to Have)
[Code style, optimization opportunities, documentation improvements]

For each issue: what's wrong, why it matters, how to fix.

### Assessment
**Ready to merge?** [Yes/No/With fixes]
$JSON_SUFFIX"

# --- Method B: Two-Phase Reflective prompt ---
read -r -d '' TWOPHASE_PROMPT << 'TWOPHASE_EOF' || true
You are reviewing whether an implementation matches its specification.

## Verification Method

Do NOT read the implementer's report first. Instead:

Step 1: Extract requirements from the spec below. Create a numbered checklist.
Step 2: Read the implementer's report. Audit each requirement against what they claim.
Step 3: Summarize unlisted behaviors not in the spec (scope creep check).
Step 4: Note discrepancies between your analysis and their claims.

## Specification

TWOPHASE_EOF
TWOPHASE_PROMPT="$TWOPHASE_PROMPT
$SPEC

## Implementer's Report

$IMPL

## Your Output

1. Requirements checklist (numbered, each marked PASS/FAIL/MISSING with evidence)
2. Unlisted behaviors (things built that weren't requested)
3. Discrepancies (claims vs evidence)
4. Overall verdict: PASS / FAIL with specific issues
$JSON_SUFFIX"

# Python scorer — extracts JSON and scores with decoy awareness
score_output() {
    local output_file="$1"
    local method="$2"
    local run_num="$3"

    python3 << PYEOF
import json, sys

with open("$output_file", "r") as f:
    content = f.read()

# Ground truth: which areas are real bugs vs decoys
REAL_BUGS = {"AREA_A", "AREA_C", "AREA_E", "AREA_F", "AREA_H"}
DECOYS = {"AREA_B", "AREA_D", "AREA_G"}
ALL_AREAS = sorted(REAL_BUGS | DECOYS)

# Extract JSON by finding balanced brace blocks containing "areas"
def find_json_objects(text):
    depth = 0
    start = None
    for i, ch in enumerate(text):
        if ch == '{':
            if depth == 0:
                start = i
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0 and start is not None:
                yield text[start:i+1]
                start = None

true_positives = 0
false_positives = 0
details = []
parsed = False

for block in find_json_objects(content):
    if "areas" not in block:
        continue
    try:
        data = json.loads(block)
        if "areas" not in data:
            continue
        areas = data["areas"]
        parsed = True
        for area_id in ALL_AREAS:
            entry = areas.get(area_id, {})
            # Strict boolean check — string "false" must not count as truthy
            found = entry.get("found", False) is True
            is_real = area_id in REAL_BUGS
            evidence = str(entry.get("evidence", ""))[:80]

            if found and is_real:
                true_positives += 1
                details.append(f"    [TP]    {area_id}: {evidence}")
            elif found and not is_real:
                false_positives += 1
                details.append(f"    [FP!!]  {area_id}: {evidence}")
            elif not found and is_real:
                details.append(f"    [MISS]  {area_id}")
            else:
                details.append(f"    [TN]    {area_id} (correctly marked clean)")
        break
    except (json.JSONDecodeError, AttributeError):
        continue

if not parsed:
    details.append("    [PARSE_FAIL] No valid areas JSON block in output — excluded from scoring")
    for d in details:
        print(d)
    # Record as parse failure — excluded from paired-cycle comparison
    with open("$TEST_DIR/scores.csv", "a") as f:
        f.write(f"$method,$run_num,0,0,0,true\n")
else:
    score = true_positives - false_positives
    for d in details:
        print(d)
    print(f"    TP: {true_positives}/5  FP: {false_positives}/3  Score: {score}")
    with open("$TEST_DIR/scores.csv", "a") as f:
        f.write(f"$method,$run_num,{true_positives},{false_positives},{score},false\n")
PYEOF
}

# Initialize scores file
echo "method,run,true_positives,false_positives,score,parse_failed" > "$TEST_DIR/scores.csv"

# Interleave methods to reduce order bias
METHODS=(current twophase)

for cycle in $(seq 1 $NUM_RUNS); do
    echo ""
    echo "=== Cycle $cycle / $NUM_RUNS ==="

    # Shuffle methods for this cycle
    shuffled=($(printf '%s\n' "${METHODS[@]}" | sort -R))

    for method in "${shuffled[@]}"; do
        echo "--- $method (run $cycle) ---"

        if [ "$method" = "current" ]; then
            prompt="$CURRENT_PROMPT"
        else
            prompt="$TWOPHASE_PROMPT"
        fi

        run_claude_session "$method" "$cycle" 2 180 \
            claude -p "$prompt" --permission-mode bypassPermissions --allowed-tools=all

        # Score only if run succeeded
        local_output="$TEST_DIR/output-${method}-run${cycle}.txt"
        if [ -f "$local_output" ]; then
            score_output "$local_output" "$method" "$cycle"
        else
            echo "    [SKIP] No output file (run failed)"
        fi
    done
done

# --- Summary ---
echo ""
echo "========================================"
echo " Results Summary"
echo "========================================"

SCORES_PATH="$TEST_DIR/scores.csv" RESULTS_PATH="$RESULTS_FILE" python3 << 'PYEOF'
import csv, os, math
from collections import defaultdict

scores_by_cycle = {}  # {(method, cycle): {score, tp, fp}}
parse_failures = 0
with open(os.environ['SCORES_PATH'], 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row.get('parse_failed', 'false') == 'true':
            parse_failures += 1
            continue  # Exclude parse failures from scoring entirely
        key = (row['method'], row['run'])
        scores_by_cycle[key] = {
            'score': int(row['score']),
            'tp': int(row['true_positives']),
            'fp': int(row['false_positives']),
        }

if parse_failures > 0:
    print(f"  [{parse_failures} run(s) excluded: JSON parse failure (output format, not analysis quality)]")

# Find paired cycles: both methods scored (non-parse-failed) in same cycle
all_cycles = set(c for _, c in scores_by_cycle.keys())
paired_cycles = sorted([c for c in all_cycles
    if ('current', c) in scores_by_cycle and ('twophase', c) in scores_by_cycle])

# Build per-method lists from paired cycles only
scores = defaultdict(list)
tp_scores = defaultdict(list)
fp_scores = defaultdict(list)
for c in paired_cycles:
    for m in ['current', 'twophase']:
        d = scores_by_cycle[(m, c)]
        scores[m].append(d['score'])
        tp_scores[m].append(d['tp'])
        fp_scores[m].append(d['fp'])

unpaired = len(all_cycles) - len(paired_cycles)
if unpaired > 0:
    print(f"  [{unpaired} unpaired cycle(s) excluded — method failed in one but not other]")

all_rows = []
with open(os.environ['RESULTS_PATH'], 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_rows.append(row)

def stdev(vals):
    if len(vals) < 2:
        return 0
    avg = sum(vals) / len(vals)
    return math.sqrt(sum((v - avg) ** 2 for v in vals) / (len(vals) - 1))

failed_count = sum(1 for r in all_rows if r['status'] != 'succeeded')
total_count = len(all_rows)
print(f"Runs: {total_count} total, {total_count - failed_count} succeeded, {failed_count} excluded")
print()

for method in ['current', 'twophase']:
    if method in scores and scores[method]:
        vals = scores[method]
        tp = tp_scores[method]
        fp = fp_scores[method]
        avg = sum(vals) / len(vals)
        sd = stdev(vals)
        tp_avg = sum(tp) / len(tp)
        fp_avg = sum(fp) / len(fp)
        print(f"{method:>10}: score {avg:.1f} (TP {tp_avg:.1f}/5, FP {fp_avg:.1f}/3, stdev {sd:.1f}, n={len(vals)}, runs: {vals})")
    else:
        print(f"{method:>10}: no successful runs")

MIN_PAIRED_CYCLES = 3
n_paired = len(paired_cycles)
print(f"Paired cycles: {n_paired} (from {len(all_cycles)} total cycles)")
print()

if n_paired >= MIN_PAIRED_CYCLES:
    current_vals = scores['current']
    twophase_vals = scores['twophase']

    current_avg = sum(current_vals) / n_paired
    twophase_avg = sum(twophase_vals) / n_paired
    diff = twophase_avg - current_avg

    print()
    if diff >= 1.0:
        print(f"VERDICT: CONFIRMED (Two-Phase scores {diff:.1f} higher on average)")
    elif diff > 0:
        print(f"VERDICT: PARTIAL (Two-Phase scores {diff:.1f} higher — marginal improvement)")
    elif diff == 0:
        print(f"VERDICT: PARTIAL (identical scores)")
    else:
        print(f"VERDICT: DENIED (Two-Phase scores {abs(diff):.1f} lower)")

    # Decision class with variance and FP checks (using paired data)
    retry_passes = sum(1 for r in all_rows if r.get('pass_label') == 'retry-pass')
    paired_stdevs = [stdev(scores[m]) for m in scores if len(scores[m]) >= 2]
    paired_avgs = [sum(scores[m]) / len(scores[m]) for m in scores if len(scores[m]) >= 2]
    high_variance = any(
        sd > 0.3 * abs(avg) for sd, avg in zip(paired_stdevs, paired_avgs) if avg != 0
    )

    # FP cap: avg FP > 1 for either method means scoring is unreliable
    high_fp = any(
        sum(fp_scores[m]) / len(fp_scores[m]) > 1.0
        for m in ['current', 'twophase'] if m in fp_scores and fp_scores[m]
    )

    # Parse failure gate: too many format failures → prompts aren't working
    # Denominator = all individual runs that produced output (parsed + parse-failed)
    total_runs_with_output = parse_failures + len(scores_by_cycle)
    if total_runs_with_output > 0 and parse_failures / total_runs_with_output > 0.3:
        print(f"Decision class: INCONCLUSIVE (parse failure rate {parse_failures}/{total_runs_with_output} > 30% — prompts not producing expected format)")
    elif failed_count > 0:
        print(f"Decision class: INCONCLUSIVE ({failed_count} runs failed — not all cycles succeeded)")
    elif retry_passes > 0:
        print(f"Decision class: INCONCLUSIVE ({retry_passes} retry-passes — results unstable)")
    elif high_fp:
        print("Decision class: INCONCLUSIVE (avg FP > 1 for a method — scoring unreliable)")
    elif high_variance:
        print("Decision class: INCONCLUSIVE (high variance — stdev > 30% of mean)")
    else:
        print("Decision class: VERIFIED (all first-pass successes, zero failures, low variance, FP controlled)")
else:
    print()
    print(f"VERDICT: INCONCLUSIVE (need >= {MIN_PAIRED_CYCLES} paired cycles; got {n_paired})")
    print(f"Decision class: INCONCLUSIVE (insufficient paired data)")
PYEOF

# Save results
cp "$TEST_DIR/scores.csv" "$SCRIPT_DIR/two-phase-reflective-results.csv" 2>/dev/null || true
rm -rf "$TEST_DIR"

echo ""
echo "Results saved to: tests/verification/two-phase-reflective-results.csv"
```

**Step 3: Run the test**

```bash
mkdir -p tests/verification/fixtures
chmod +x tests/verification/test-two-phase-reflective.sh
./tests/verification/test-two-phase-reflective.sh
```

Expected: ~15 minutes (10 API calls × ~90s each, interleaved).

**Step 4: Interpret results**

| Verdict | Action |
|---------|--------|
| CONFIRMED (>=1 higher score avg) | Proceed with P2.1. Two-Phase Reflective generalizes. |
| PARTIAL (same score) | Adopt for structural consistency but don't expect improvement. |
| DENIED (lower score) | Keep current prompts. Investigate why structured approach underperforms. |

---

## Task 4: Update Improvements Doc with Findings

**Depends on:** Task 1, Task 2, Task 3
**Files:**
- Modify: `SUPERPOWERS-BD-COMPREHENSIVE-IMPROVEMENTS.md`

**Purpose:** Update the improvements doc with verified findings so future decisions are based on evidence, not assumptions.

**Step 1: Update each item based on Decision class and verdict**

**Hard rule:** Only actionable decision classes (VERIFIED, OBSERVED) warrant priority changes. INCONCLUSIVE means record the finding as "tested, inconclusive" — no priority promotion/demotion.

**Terminology:**
- **Verdict** = what the experiment found (CONFIRMED, PARTIAL, DENIED, INCONCLUSIVE)
- **Decision class** = how confident we are in the verdict (VERIFIED, OBSERVED, INCONCLUSIVE)
- A CONFIRMED verdict with INCONCLUSIVE decision class means "probably works but evidence is weak"

**For #42 (frontmatter hooks):**
Task 1 emits both a verdict (CONFIRMED/DENIED/PARTIAL/INCONCLUSIVE) and a decision class (VERIFIED/INCONCLUSIVE). Gate on decision class first, then act on verdict.
- Decision class INCONCLUSIVE (any verdict): Record as "tested, inconclusive (reason)". No priority change.
- Decision class VERIFIED + verdict CONFIRMED: Remove "⚠️ VERIFY" from P1.3. Promote #25 to P2.2. Note tested Claude Code version.
- Decision class VERIFIED + verdict DENIED: Update P1.3 to "VERIFIED: Does NOT work." Move #25 to P5+. Add finding to Section 3.4.
- Decision class VERIFIED + verdict PARTIAL: Record as "tested, inconsistent behavior." No priority promotion; investigate flakiness before relying on feature.

**For #5 (TaskCompleted latency):**
Task 2 emits a decision class (VERIFIED, OBSERVED, INCONCLUSIVE).
- Decision class VERIFIED: Add measured overhead data to Section 3.4. Update P1.2 with recommended hook type. Add guidance table.
- Decision class OBSERVED: Add measured overhead data with caveat: "command type directly measured; prompt/agent overhead timing-inferred." No hook-type recommendations for timing-inferred types.
- Decision class INCONCLUSIVE: Record as "tested, inconclusive (reason)". No priority change.

**For #1 (Two-Phase Reflective):**
Task 3 emits both verdict and decision class.
- Decision class VERIFIED + verdict CONFIRMED: Update P2.1 to "Verified: generalizes to spec review." Include detection rates.
- Decision class VERIFIED + verdict PARTIAL/DENIED: Update with finding. Consider keeping only the requirements-extraction step.
- Decision class INCONCLUSIVE (any verdict): Record as "tested, inconclusive (reason)". No priority change.

**Step 2: Bump version to v5.1**

Add changelog entry in Document History table:

```markdown
| 5.1 | 2026-02-07 | **Empirical verification of top 3 assumptions.** #42 frontmatter hooks: [VERDICT]. #5 TaskCompleted latency: command +Xms, prompt +Xms, agent +Xms. #1 Two-Phase Reflective: [VERDICT] (current TP X.X/5 FP X.X/3 vs twophase TP X.X/5 FP X.X/3). |
```

**Note:** No git commit — test artifacts are throwaway. Only the doc updates in steps 1-2 are kept.

---

## Verification Record

### Plan Verification Checklist
| Check | Status | Notes |
|-------|--------|-------|
| Complete | ✓ | All 3 verification items + shared helper + doc update task |
| Accurate | ✓ | Paths verified. `--agents` flag confirmed in official docs (code.claude.com/docs/en/sub-agents). No `--project-dir` flag — use `cd` to temp dir instead. |
| Commands valid | ✓ | `claude -p`, `--permission-mode bypassPermissions`, `--allowed-tools=all`, `--agents`, `python3` all verified |
| YAGNI | ✓ | Shared helper is minimal (one function + one utility). No test framework. |
| Minimal | ✓ | 4 scripts + 2 fixtures + 1 doc update |
| Not over-engineered | ✓ | Bash + python for JSON/CSV. Retry logic is ~40 lines, justified by critical findings. |
| Key Decisions documented | ✓ | 9 decisions in header |
| Context sections present | ✓ | All tasks have Purpose, Not In Scope, Gotchas |

### Review v1 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| #1 Critical: Failure swallowing | Fixed | Shared `run_claude_session()` tracks exit codes, labels status |
| #2 Critical: No retry policy | Fixed | Shared helper retries up to max_retries, labels first-pass vs retry-pass |
| #3 Critical: Regex keyword matching | Fixed | Task 3 uses structured JSON output with area IDs, parsed by Python |
| #4 Critical: Double-counting bugs | Fixed | Area IDs are unique keys in JSON; decoy/real status in scorer only |
| #5 Important: No transcript parsing | Partial | Added `--allowed-tools=all` for reliability; transcript parsing deferred (stdout IS the data for review quality) |
| #6 Important: Missing --allowed-tools | Fixed | All `claude -p` invocations include `--allowed-tools=all` |
| #7 Important: Baseline isn't real prompt | Fixed | Task 3 baseline uses full code-reviewer.md structure |
| #8 Important: Run-order bias | Fixed | Task 2: randomized per cycle. Task 3: interleaved per cycle. |
| #9 Important: Git identity in temp repos | Fixed | `setup_git_identity()` in shared helper |
| #10 Important: Timeout as data | Fixed | Timed-out runs excluded from primary metrics, retried |

### Review v2 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v2-#1 Critical: setup_git_identity before git init | Fixed | Moved after `git init` |
| v2-#2 Critical: Prompt quoting breaks sh -c | Fixed | Env-var passing: `CLAUDE_PROMPT="$VAR" sh -c '... "$CLAUDE_PROMPT" ...'` |
| v2-#3 Critical: JSON regex truncates nested objects | Fixed | Balanced-brace parser iterates all `{...}` blocks |
| v2-#4 Critical: Decision class contradicts policy | Fixed | retry-pass → INCONCLUSIVE in all scripts |
| v2-#5 Critical: No proof hooks fired in Task 2 | Fixed | See v3 findings — redesigned approach |

### Review v3 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v3-#1 Critical: Double-row contaminates metrics | Fixed | Hook verification writes to separate CSV (`hook_verify.csv`), Python joins and excludes unverified command runs |
| v3-#2 Critical: Command hook contaminates prompt/agent overhead | Fixed | Each variant uses ONLY its own type. No companion hooks. |
| v3-#3 Critical: Marker proves wrong thing for prompt/agent | Fixed | Marker used only for command. Prompt/agent use timing delta: if overhead is within 2 stdev of baseline, flagged as unconfirmed. |
| v3-#4 Critical: Answer leakage + no false-positive guard | Fixed | Neutral area labels (no bug descriptions). 3 decoy areas. Score = TP - FP. |
| v3-#5 Critical: String boolean truthy | Fixed | `entry.get("found", False) is True` — strict identity check |
| v3-#6 Important: No variance metric | Fixed | Stdev computed per type. High variance (stdev > 30% of mean) → INCONCLUSIVE. |
| v3-#7 Important: Task 1 single runs | Fixed | 3 runs per phase. Verdict requires >= 2/3 positive control, aggregate experiment results. |
| v3-#8 Important: Commit step still present | Fixed (v4) | Removed commit step — test artifacts are throwaway per user clarification. |
| v3-#9 Minor: Stale overlap text | Fixed | Removed outdated "Bug patterns 3/5 overlap" reference. |

### Review v4 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v4-#1 Critical: CONFIRMED on too little evidence | Fixed | Added `EXPERIMENT_WROTE >= 2` gate before CONFIRMED verdict |
| v4-#2 Critical: VERIFIED despite unconfirmed prompt/agent | Fixed | `unconfirmed_types` list fed into decision class → INCONCLUSIVE |
| v4-#3 Critical: Unequal sample sizes bias verdict | Fixed | Minimum 3 runs per method required; imbalance warning when diff > 1 |
| v4-#4 Important: Retry artifacts contaminate evidence | Fixed | `PRE_ATTEMPT_CLEANUP` env var in retry loop clears markers/targets before each attempt |
| v4-#5 Important: Per-type sufficiency ignored in decision | Fixed | `insufficient_types` list fed into decision class → INCONCLUSIVE |
| v4-#6 Important: Commit steps in throwaway plan | Fixed | Removed commit step from Task 4; added throwaway note |

### Review v5 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v5-#1 Critical: Task 2 >=2 too low for decision-grade | Fixed | Raised `MIN_RUNS_PER_TYPE` to 3; shows actual/required count |
| v5-#2 Critical: Prompt/agent inferred not observed | Fixed | Labeled "timing-inferred" in output; cannot reach VERIFIED (only OBSERVED); updated header decision class definition |
| v5-#3 Important: VERIFIED with excluded failures | Fixed | Any `failed_count > 0` → INCONCLUSIVE in both Task 2 and Task 3 |
| v5-#4 Important: Task 3 imbalance warn-only | Fixed | Matched-N comparison: `min(n_current, n_twophase)` used for scoring and variance |
| v5-#5 Important: TP-FP rewards shotgun | Fixed | FP cap: avg FP > 1 for either method → INCONCLUSIVE |

### Review v6 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v6-#1 Critical: Unpaired samples in Task 3 | Fixed | Paired-by-cycle comparison: only cycles where both methods scored are used. Unpaired cycles excluded with count. |
| v6-#2 Important: Task 1 verdict ignores stability | Fixed | Checks results CSV for experiment failures/retries; any → INCONCLUSIVE before CONFIRMED |
| v6-#3 Important: VERIFIED emitted for timing-inferred | Fixed | Added OBSERVED decision class; VERIFIED only when all types directly observed |
| v6-#4 Important: Command hook-miss not instability | Fixed | `hook_miss_count` tracked; any misses → INCONCLUSIVE |

### Review v7 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v7-#1 Critical: Task 4 acts on VERDICT not Decision class | Fixed | Gated on Decision class: only VERIFIED/OBSERVED warrant priority changes; INCONCLUSIVE → record finding, no change |
| v7-#2 Important: Positive control stability unchecked | Fixed | Added POS_FAILURES/POS_RETRIES gates; any instability → POSITIVE_CONTROL_PASSED=false |
| v7-#3 Important: Parse failures scored as 0, bias comparison | Fixed | `parse_failed` column in CSV; excluded from paired-cycle scoring entirely |
| v7-#4 Important: OBSERVED has no downstream interpretation | Fixed | Task 4 defines OBSERVED rule: report data with timing-inferred caveat, no hook-type recommendations for inferred types |

### Review v8 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v8-#1 Critical: Task 4 mixes verdict/decision class labels | Fixed | Separated taxonomy: Decision class (VERIFIED/OBSERVED/INCONCLUSIVE) = confidence; Verdict (CONFIRMED/PARTIAL/DENIED/INCONCLUSIVE) = finding. Task 4 rules rewritten with correct labels per task. |
| v8-#2 Important: DENIED exits 1, aborts orchestration | Fixed | Exit 0 for all conclusive outcomes (CONFIRMED/PARTIAL/DENIED); exit 1 only for INCONCLUSIVE (harness failure) |
| v8-#3 Important: grep -c under pipefail produces "0\n0" | Fixed | Replaced with awk counters (`awk -F, '...' END {print n+0}`) — always outputs single integer |
| v8-Q: Parse failures and decision class | Implemented | Parse failure rate > 30% of total runs → INCONCLUSIVE (prompts not producing expected format) |

### Review v9 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v9-#1 Important: Parse-failure rate denominator wrong | Fixed | Changed to `parse_failures + len(scores_by_cycle)` (actual individual runs with output) |
| v9-#2 Important: Task 3 missing Decision class in insufficient-cycles branch | Fixed | Added `Decision class: INCONCLUSIVE (insufficient paired data)` line |
| v9-#3 Minor: Space-in-path not enforced | Fixed | Added `verify_no_spaces()` preflight in helper; called after every `mktemp -d` |

### Review v15 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v15-#1 Critical: Parser misses `event.message.content` (actual transcript shape) | Fixed | Extended block extraction to include `event.message.content[]` alongside existing top-level and `event.content[]` checks. Validated against real transcript at `.claude/projects/` session file. |
| v15-#2 Important: Missed events cause deterministic INCONCLUSIVE | Fixed | Same fix — parser now finds tool events at their actual location, so `SUBAGENT_INVOKED` increments correctly. |

### Review v14 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v14-#1 Critical: Regex proof can false-positive on text mentions | Fixed | Replaced grep with python3 structured JSON parsing: checks `type=="tool_use"`, `name=="Task"`, `input.subagent_type=="hooked-writer"` in the same event object. Authoritative proof. |
| v14-#2 Important: `sort -r` is lexicographic, not mtime | Fixed | Replaced with `find -print0 | xargs -0 ls -t | head -1` for true mtime ordering. |
| v14-Q: Task tool's agent key is `subagent_type` | Answered | Verified from repo codebase: `subagent_type` is the input parameter that selects which agent to spawn. Used in structured parser. |

### Review v13 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v13-#1 Critical: Two independent greps can false-positive | Fixed | Replaced with single-line grep `"name":"Task".*hooked-writer` requiring both in same JSON event. |
| v13-#2 Critical: `find` on missing dir aborts under pipefail | Fixed | Added `[ ! -d "$session_dir" ]` guard, returns empty string with exit 0. |
| v13-#3 Important: Stale transcript reuse across runs | Fixed | Per-run timestamp file (`touch` before run, `find -newer` after). `find_session_transcript()` accepts optional `newer_than` parameter. |
| v13-#4 Important: Secondary probe desynchronizes verdict/decision class | Fixed | Moved probe BEFORE decision class computation. Decision class now reflects final verdict state. |
| v13-#5 Minor: Architecture summary wrong about Task 2 output | Fixed | Clarified: Tasks 1/3 emit verdict+decision class, Task 2 emits decision class+latency bands. |

### Review v12 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v12-#1 Critical: Subagent proof via stdout grep is unreliable | Fixed | Replaced with `.jsonl` transcript parsing via `find_session_transcript()` + `verify_task_tool_used()`. Follows established repo pattern (`test-subagent-driven-development-integration.sh:164,199`). |
| v12-#2 Important: Task 1 local table acts on verdict without decision-class gate | Fixed | Rewrote "Interpret and record" table to gate on decision class first, consistent with Task 4 hard rule. |
| v12-#3 Minor: Architecture summary stale about Task 1 output | Fixed | Updated to "All three tasks emit both verdict and decision class." |

### Review v11 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v11-#1 Critical: No subagent invocation proof | Fixed | Added `SUBAGENT_INVOKED` counter — greps output for `hooked-writer` to prove Task tool was used. Gated in verdict logic: all runs must have proof or INCONCLUSIVE. |
| v11-#2 Critical: Task 1 exempt from decision-class gating | Fixed | Task 1 now emits formal `DECISION_CLASS` (VERIFIED/INCONCLUSIVE). Task 4 gates on decision class first, verdict second. Exit code based on decision class. |
| v11-#3 Important: PARTIAL comment says 1/3 but logic covers 1/3 or 2/3 | Fixed | Updated comment to "hook fires in some but not all experiment runs". |

### Review v10 Findings Applied
| Finding | Status | How Addressed |
|---------|--------|--------------|
| v10-#1 Important: Positive control too permissive at >= 2/3 | Fixed | Changed to require all runs (`POSITIVE_PASS -ne $NUM_RUNS`). One hook/harness failure blocks verdict. |
| v10-#2 Important: Conclusive verdict on 2/3 executed runs | Fixed | Changed `EXPERIMENT_WROTE -lt 2` to `EXPERIMENT_WROTE -ne $NUM_RUNS`. All runs must execute for conclusive claim. |
| v10-#3 Minor: Architecture summary stale (missing two-taxonomy model) | Fixed | Updated to describe verdict + decision class taxonomy. Notes Task 2 uses decision class output. |
| v10-#4 Minor: Stale manual space-check gotcha | Fixed | Replaced with reference to `verify_no_spaces()` preflight guard. |

### Rule-of-Five Passes
| Pass | Changes Made |
|------|--------------|
| Draft | Restructured: fixed --add-dir → --agents, fixed Python heredoc env var, fixed grep ERE syntax, improved latency isolation via per-variant settings |
| Correctness | Fixed --project-dir → cd to temp dir (flag doesn't exist). Added git commit --allow-empty for valid git state. |
| Clarity | Explained WHY cd to temp dir (Claude reads .claude/ from cwd). Removed jargon. |
| Edge Cases | Added space-in-path warning for Task 1 JSON. Added cold-start note for Task 2 timing. |
| Excellence | Removed `jq` from tech stack (unused). Verified all checklist items still accurate after edits. |
| Review v1 | Applied 10 findings: shared runner, JSON scoring, positive control, randomized order, git identity, --allowed-tools, real baseline prompt. |
| Review v2 | Fixed 5 execution bugs: git init ordering, shell quoting, JSON extraction, decision class logic. |
| Review v3 | Fixed 5 critical + 4 important: pure per-type measurement, separate hook verification, neutral labels with decoys, strict boolean check, stdev-based variance metric, multi-run Task 1. |
| Review v4 | Fixed 3 critical + 3 important: minimum evidence gates for verdicts, retry artifact cleanup, per-type sufficiency in decision class, removed commit steps for throwaway context. |
| Review v5 | Fixed 2 critical + 3 important: raised per-type min to 3, prompt/agent labeled timing-inferred (can't reach VERIFIED), any failures → INCONCLUSIVE, matched-N comparison, FP cap (avg > 1 → INCONCLUSIVE). |
| Review v6 | Fixed 1 critical + 3 important: paired-by-cycle comparison, Task 1 stability check from CSV, OBSERVED decision class for timing-inferred types, hook-miss as instability. |
| Review v7 | Fixed 1 critical + 3 important: Task 4 gated on Decision class (not VERDICT), positive control stability, parse-failure exclusion from scoring, OBSERVED downstream interpretation. |
| Review v8 | Fixed 1 critical + 2 important + 1 question: separated verdict/decision-class taxonomy, exit codes for conclusive outcomes, awk counters for pipefail safety, parse-failure rate gates decision class. |
| Review v9 | Fixed 2 important + 1 minor: parse-failure denominator, missing Decision class line in insufficient-cycles branch, space-in-path preflight guard. |
| Review v10 | Fixed 2 important + 2 minor: positive control requires all runs, experiment requires all runs for conclusive verdict, architecture summary reflects two-taxonomy model, stale space-check gotcha updated. |
| Review v11 | Fixed 2 critical + 1 important: subagent invocation proof per run (grep output for hooked-writer), Task 1 emits formal decision class (VERIFIED/INCONCLUSIVE) with Task 4 gating, PARTIAL comment aligned with logic. |
| Review v12 | Fixed 1 critical + 1 important + 1 minor: replaced stdout grep with `.jsonl` transcript parsing for authoritative subagent proof, Task 1 local table now gates on decision class, architecture summary updated. |
| Review v13 | Fixed 2 critical + 2 important + 1 minor: single-line grep for same-event proof, directory guard for pipefail safety, per-run timestamp isolation, probe-before-decision-class ordering, Task 2 output model in summary. |
| Review v14 | Fixed 1 critical + 1 important: replaced regex grep with python3 structured JSON parsing for authoritative subagent proof (`subagent_type` field), mtime-sorted transcript selection. |
| Review v15 | Fixed 1 critical + 1 important: extended JSON parser to check `event.message.content[]` (actual Claude transcript shape), preventing deterministic INCONCLUSIVE from missed tool events. |
