# Metrics Tracking Reference

## Usage Data Source

The Task tool returns a `<usage>` block with every result:
```
<usage>total_tokens: 81397
tool_uses: 20
duration_ms: 39153</usage>
```

## Per-Task Metrics

Keyed by `"{issue_id}.{role}"` (e.g., `"hub-abc.1.impl"`, `"hub-abc.1.spec"`, `"hub-abc.1.code"`). For multi-review (N>1), key each reviewer separately and add aggregation:

```python
# Single review (N=1):
task_metrics[f"{issue_id}.code"] = {...}

# Multi-review (N>1):
task_metrics[f"{issue_id}.code.1"] = {...}  # Reviewer 1
task_metrics[f"{issue_id}.code.2"] = {...}  # Reviewer 2
task_metrics[f"{issue_id}.code.3"] = {...}  # Reviewer 3
task_metrics[f"{issue_id}.agg"] = {...}     # Aggregation step (if not fast-pathed)
```

## Per-Wave Aggregates

Computed at wave end:
```python
wave_tokens = sum(m["total_tokens"] for m in wave_task_metrics)
wave_tool_uses = sum(m["tool_uses"] for m in wave_task_metrics)
wave_duration_ms = max(m["duration_ms"] for m in wave_task_metrics)  # parallel = wall clock is longest
wave_cost = wave_tokens * 9 / 1_000_000  # $9/M blended rate
```

## Epic Accumulator

Running totals across all waves:
```python
epic_tokens += wave_tokens
epic_tool_uses += wave_tool_uses
epic_cost += wave_cost
```

## Cost Formula

`$9/M tokens` (blended input/output rate). The Task `<usage>` block doesn't split input vs output tokens. For precise cost breakdown, use `analyze-token-usage.py` on the session JSONL post-hoc.

**Missing `<usage>` block:** If an agent crashes or no usage data is returned, default all metrics to 0. Don't let missing data block the workflow.

**Review retries:** Accumulate across attempts (sum, not overwrite). If a review fails and is re-dispatched, add the retry's metrics to the existing entry.

## Wave Summary Template

Post to epic comments after each wave:

```bash
bd comments add <epic-id> "Wave N complete:
- Closed: hub-abc.1, hub-abc.2
- Evidence:
  - hub-abc.1: commit=[hash], files=[count] changed, tests=[pass_count] pass
  - hub-abc.2: commit=[hash], files=[count] changed, tests=[pass_count] pass
- Simplification: [applied/skipped (reason)] [files touched, if applied]
- Cost: [wave_tokens] tokens (~$[cost]) | [tool_calls] tool calls | [duration]s
  - hub-abc.1: impl=[tok]/[calls]/[dur]s, spec=[tok], code=[tok]×N+agg=[tok]
  - hub-abc.2: impl=[tok]/[calls]/[dur]s, spec=[tok], code=[tok]×N+agg=[tok]
  - simplify: [tok]/[calls]/[dur]s (if applied)
- Running total: [epic_tokens] tokens (~$[epic_cost]) across [N] waves
- Conventions established:
  - [Pattern/convention implementers chose]
  - [Naming convention used]
  - [Library/approach selected when choice existed]
- Notes for future waves:
  - [Anything Wave N+1 should know]"
```

**Why this matters:**
- Wave 2 implementers can see what conventions Wave 1 established
- Prevents inconsistent naming, patterns, or style choices
- Creates audit trail of implementation decisions
- Cost visibility enables budget decisions mid-epic

**What to capture:**
- Cost data (always include — tokens, tool calls, duration, running total)
- File naming patterns chosen
- Code style decisions (async/await vs promises, etc.)
- Interface shapes that future tasks will consume
- Any surprises or deviations from the plan

**When to skip conventions (not cost):** If the wave established no new conventions (e.g., single-task wave, or tasks followed existing patterns without decisions), a minimal summary is fine — but always include cost: "Wave N complete: Closed hub-abc.1. Cost: 45,000 tokens (~$0.41). Running total: 120,000 tokens (~$1.08). No new conventions."

## Epic Completion Report Template

Print cost summary to user:
```
╔══════════════════════════════════════════════╗
║  Epic {epic_id} complete                     ║
╠══════════════════════════════════════════════╣
║  Waves:    {wave_count}                      ║
║  Tasks:    {task_count} ({impl} impl + {spec} spec + {code} code + {agg} agg) ║
║  Tokens:   {epic_tokens:,} total             ║
║  Cost:     ~${epic_cost:.2f} (blended $9/M)  ║
║  Duration: {wall_clock} wall clock           ║
╚══════════════════════════════════════════════╝
```

Post total to epic comments:
```bash
bd comments add <epic-id> "Epic complete:
- Total: {epic_tokens:,} tokens (~${epic_cost:.2f}) across {wave_count} waves
- Tasks: {task_count} ({impl} impl, {spec} spec reviews, {code} code reviews, {agg} aggregations)
- Wall clock: {wall_clock}
- Per-wave breakdown in wave summary comments above
- For precise input/output split: analyze-token-usage.py <session>.jsonl"
```

Reference post-hoc analysis: The blended $9/M rate is an estimate. For precise input vs output token costs, run `analyze-token-usage.py` on the session JSONL after completion.

Cleanup file-locks.json:
```bash
rm -f .claude/file-locks.json
```
Advisory locks removed — no agents active.
