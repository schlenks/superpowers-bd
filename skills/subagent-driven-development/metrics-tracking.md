# Metrics Tracking Reference

## Usage Data Source

Claude's `Agent` output is discriminated by `status`:

- `async_launched` includes `agentId` and `outputFile`, but no final usage.
- `completed` includes `agentId`, `totalTokens`, `totalToolUseCount`,
  `totalDurationMs`, and `usage.input_tokens` / `usage.output_tokens` plus cache
  token fields.

Capture structured metrics only from a `completed` result:

```python
def normalize_agent_metrics(result):
    if result.status != "completed":
        return {
            "metrics_available": False,
            "agent_id": result.agentId,
        }

    return {
        "metrics_available": True,
        "agent_id": result.agentId,
        "total_tokens": result.totalTokens,
        "input_tokens": result.usage.input_tokens,
        "output_tokens": result.usage.output_tokens,
        "cache_creation_input_tokens": result.usage.cache_creation_input_tokens,
        "cache_read_input_tokens": result.usage.cache_read_input_tokens,
        "tool_uses": result.totalToolUseCount,
        "duration_ms": result.totalDurationMs,
    }
```

For background agents, retain the launch result's `outputFile` for verdict
retrieval. If the later completion notification does not expose a structured
completed result, leave metrics unavailable and use transcript analysis after
the workflow. Never turn unavailable metrics into zeros; zero is a real
measurement.

Codex agent results may expose different fields. Normalize only fields returned
by the active Codex tool and mark the rest unavailable.

## Per-Task Metrics

Key by `"{issue_id}.{role}"` (for example, `"hub-abc.1.impl"`). For multiple
code reviewers, key each reviewer separately and include aggregation:

```python
task_metrics[f"{issue_id}.impl"] = normalize_agent_metrics(impl_result)
task_metrics[f"{issue_id}.spec"] = normalize_agent_metrics(spec_result)
task_metrics[f"{issue_id}.code.1"] = normalize_agent_metrics(code_result_1)
task_metrics[f"{issue_id}.code.2"] = normalize_agent_metrics(code_result_2)
task_metrics[f"{issue_id}.agg"] = normalize_agent_metrics(aggregation_result)
```

Retries append a unique attempt suffix rather than overwriting prior metrics.

## Per-Wave Aggregates

Aggregate only measured entries and retain an explicit missing count:

```python
measured = [m for m in wave_task_metrics if m["metrics_available"]]
missing_metrics = len(wave_task_metrics) - len(measured)

wave_tokens = sum(m["total_tokens"] for m in measured)
wave_input_tokens = sum(m["input_tokens"] for m in measured)
wave_output_tokens = sum(m["output_tokens"] for m in measured)
wave_tool_uses = sum(m["tool_uses"] for m in measured)
wave_longest_agent_ms = max(
    (m["duration_ms"] for m in measured),
    default=None,
)
```

When `missing_metrics > 0`, token and tool totals are known minimums, not epic
totals. The longest agent duration is not the same as wave wall-clock time.

## Cost Reporting

Do not estimate dollar cost from `totalTokens`. Pricing varies by resolved
model, input/output direction, cache reads/writes, service tier, and provider.
For a cost report, run `analyze-token-usage.py` on the session JSONL after
completion and report its model-aware result separately.

Cost analysis is observational and must never block task closure.

## Wave Summary Template

Post to epic comments after each wave with a `[WAVE-SUMMARY]` tag:

```bash
bd comments add <epic-id> "[WAVE-SUMMARY] Wave N complete:
- Closed: hub-abc.1, hub-abc.2
- Evidence:
  - hub-abc.1: commit=[hash], files=[count] changed, tests=[pass_count] pass
  - hub-abc.2: commit=[hash], files=[count] changed, tests=[pass_count] pass
- Simplification: [applied/skipped (reason)] [files touched, if applied]
- Metrics: [measured_count] measured, [missing_count] unavailable
  - Known minimum: [wave_tokens] tokens | [tool_calls] tool calls
  - Token split: [input_tokens] input | [output_tokens] output
  - Longest measured agent: [duration]s
- Conventions established:
  - [Pattern/convention implementers chose]
- Notes for future waves:
  - [Anything Wave N+1 should know]"
```

If every result lacks structured telemetry, say `Metrics: unavailable; run
analyze-token-usage.py on the session JSONL after completion.` Do not print a
synthetic zero total.

## Wave Receipt Compression

After posting the full summary, retain a two-line receipt:

```text
Wave 1: 2 tasks closed (hub-abc.1, hub-abc.2). Metrics: 168k known tokens; 1 result unavailable. Conventions: uuid-v4, camelCase.
Wave 2: 1 task closed (hub-abc.3). Metrics unavailable. No new conventions.
```

Full summaries live in beads. Future agents read them with
`bd comments <epic-id> --json`.

## Epic Completion Report

Report workflow results first, then telemetry quality:

```text
Epic {epic_id} complete
- Waves: {wave_count}
- Tasks: {task_count} ({impl} implementation, {spec} spec review, {code} code review, {agg} aggregation)
- Structured telemetry: {measured_count} measured, {missing_count} unavailable
- Known tokens: {known_tokens} (minimum when any result is unavailable)
- Tool calls: {known_tool_uses} (minimum when any result is unavailable)
- Wall clock: {wall_clock}
- Cost: run analyze-token-usage.py <session>.jsonl for model-aware analysis
```

## Disk Persistence

At wave end, write per-result metrics to disk and clear them from context:

```python
import json
import os

metrics_path = f"temp/metrics-{epic_id}.json"
existing = json.load(open(metrics_path)) if os.path.exists(metrics_path) else {}
existing.update(task_metrics)
json.dump(existing, open(metrics_path, "w"), indent=2)

# Retain only known totals and the unavailable-result count in context.
```

At epic completion, read the metrics file for the report, then remove ephemeral
state:

```bash
rm -f temp/sdd-checkpoint-{epic_id}.json temp/metrics-{epic_id}.json
```
