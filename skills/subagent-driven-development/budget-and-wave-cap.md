# Budget and Wave Cap

## Claude Code Model Policy

Claude Code routes work by Opus/Sonnet/Haiku model families. Complexity selects the desired model and the budget tier caps it.

### Implementer Models

| Tier | simple | standard | complex |
|------|--------|----------|---------|
| max-20x | haiku | sonnet | opus |
| max-5x | haiku | sonnet | opus |
| pro/api | haiku | sonnet | sonnet |

### Spec Reviewer Models

| Tier | simple | standard | complex |
|------|--------|----------|---------|
| max-20x | haiku | haiku | sonnet |
| max-5x | haiku | haiku | sonnet |
| pro/api | haiku | haiku | haiku |

### Other Roles

| Tier | Code Reviewer | N Reviews | Claude-only Codex advisory review | Verifier | Simplify |
|------|---------------|-----------|--------------|----------|----------|
| max-20x | sonnet | 3 | If available | opus | Yes |
| max-5x | sonnet | 3 | If available | opus | Yes |
| pro/api | haiku | 1 | Skip | sonnet | Skip |

`codex_enabled` applies only to this Claude Code advisory path. It does not apply to native Codex orchestration.

## Codex Project Model Policy

Codex plugin agents inherit the active Codex model. Do not pin a model in plugin-bundled agents or `spawn_agent` calls unless the user explicitly asks for a specific model. Codex does not currently expose a reliable authenticated plan-tier signal to this plugin, so Superpowers-BD does not auto-switch between paid-plan models.

Route strength by `model_reasoning_effort`, not by Claude Opus/Sonnet/Haiku names. If a future Codex runtime provides a reliable plan-tier signal, max-20x and max-5x sessions may default complex work to `xhigh` effort; without that signal, keep the active model and use the effort tables below.

### Implementer Reasoning Effort

| Tier | simple | standard | complex |
|------|--------|----------|---------|
| max-20x | medium | high | xhigh |
| max-5x | medium | high | xhigh |
| pro/api | medium | medium | high |

Implementers may use the default Codex worker with the active profile model and requested effort because there is no dedicated implementer agent in the current project policy.

### Native Reviewer and Verifier Agents

| Role | Codex agent | Model | Reasoning effort | Use |
|------|-------------|-------|------------------|-----|
| Spec compliance | `spec_reviewer` | inherit active Codex model | high | After implementer reports `DONE` or `DONE_WITH_CONCERNS` |
| Code quality | `code_reviewer` | inherit active Codex model | high | N independent reviews by budget tier |
| Review aggregation | `review_aggregator` | inherit active Codex model | medium | Required when N > 1 |
| Epic verification | `epic_verifier` | inherit active Codex model | xhigh | After all implementation tasks close |

| Tier | N Code Reviews | Aggregator | Simplify |
|------|----------------|------------|----------|
| max-20x | 3 | yes | yes |
| max-5x | 3 | yes | yes |
| pro/api | 1 | no | no |

Default issue complexity is `standard`.

## Context Tier

- Extended context: model ID contains `[1m]`; default wave cap 5; budget per wave 15.
- Standard context: no `[1m]` suffix or unknown; default wave cap 3; budget per wave 9.
- Codex: use visible context info if available; otherwise standard.

Store `context_tier`, `platform`, `platform_agent_plan`, and Codex-only `codex_model_policy: "inherit_active_model"` in the checkpoint. In Claude Code only, also store `codex_enabled` and `codex_install_path` when a separate Codex advisory integration is detected.

## Setting Priority

1. Explicit invocation wins: `execute epic hub-abc wave-cap 7`.
2. Smart recommendation: query complexity labels and calculate recommended cap.
3. Fallback: `min(DEFAULT_CAP, max_parallel)`.

## Smart Recommendation

Query:

```bash
bd sql "SELECT label, COUNT(*) FROM labels WHERE issue_id LIKE '{epic_id}.%' AND label LIKE 'complexity:%' GROUP BY label"
```

Formula:

```python
WEIGHTS = {"simple": 1, "standard": 2, "complex": 3}
BUDGET_PER_WAVE = 15 if context_tier == "extended" else 9
DEFAULT_CAP = 5 if context_tier == "extended" else 3

total_tasks = sum(counts.values())
total_weight = sum(WEIGHTS[c] * n for c, n in counts.items())
avg_weight = total_weight / total_tasks if total_tasks > 0 else 2.0
max_parallel = len(ready_epic_children)

recommended = min(floor(BUDGET_PER_WAVE / avg_weight), max_parallel, 10)
recommended = max(recommended, 1)
if budget_tier == "pro/api":
    recommended = min(recommended, 3)
```

Ask the user to confirm unless the recommendation is at or below the context default or only one issue is ready.

## Effective Wave Sizes

| Complexity Mix | Standard (200k) | Extended (1M) |
|----------------|-----------------|---------------|
| All simple | min(9, parallel, 10) | 10 |
| Mixed simple/standard | 6 | 10 |
| All standard | 4 | 7 |
| Mixed standard/complex | 3 | 6 |
| All complex | 3 | 5 |

## Edge Cases

- `bd sql` fails: print a warning and use `min(DEFAULT_CAP, max_parallel)`.
- No complexity labels: use average weight 2.0.
- Recommended <= default: skip question and use recommended.
- `max_parallel = 1`: wave cap is 1.
- Old checkpoint without `context_tier`: default to standard.
- Old checkpoint without `platform`: infer current platform and store it at the next checkpoint write.
- Old checkpoint without `platform_agent_plan`: rebuild it from the active platform dispatch path.
- Old Codex checkpoint with model profile fields: ignore them and continue with active model inheritance.
- Old checkpoint with `codex_enabled` in a Codex session: ignore it; native Codex sessions are the orchestrator, not a cross-model advisory review.
- Out-of-range explicit cap: warn, clamp to 1-10, and store clamped value.
