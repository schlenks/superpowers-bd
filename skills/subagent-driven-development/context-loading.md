# Context Loading

Sub-agents load their own context directly from beads. The orchestrator only provides safety-critical fields that must be immediately visible (file ownership, dependency IDs, SHAs).

## Self-Read Pattern (Sub-Agents)

Sub-agents run these commands at the start of their task:

```bash
# 1. Task details — requirements, files, implementation steps
bd show <issue-id>

# 2. Epic context — goal and Key Decisions (read first ~30 lines of output)
bd show <epic-id>

# 3. Wave conventions — patterns from previous waves
bd comments <epic-id> --json
# Look for [WAVE-SUMMARY] tagged entries
```

**Why self-read?** Shifting context loading from orchestrator to sub-agent eliminates ~450-750 lines/wave of pasted content from the orchestrator's context window. Sub-agents have fresh, disposable context windows.

## What the Orchestrator Still Provides

These fields stay in the dispatch prompt (small, safety-critical):

| Field | Why in prompt | Size |
|-------|---------------|------|
| `{issue_id}` | Sub-agent needs to know which issue to `bd show` | 1 line |
| `{epic_id}` | Sub-agent needs to know which epic for context | 1 line |
| `{file_ownership_list}` | Must be immediately visible for scope guard | 3-10 lines |
| `{wave_file_map}` | Shows all agents' file assignments for conflict awareness | 5-15 lines |
| `{dependency_ids}` | Tells sub-agent which issues are already done | 1-3 lines |
| `{base_sha}`, `{head_sha}` | Reviewers need these for diff (not in beads) | 2 lines |
| `{code_reviewer_path}` | Code reviewers read methodology from disk (119 lines not in prompt) | 1 line |
| `{wave_number}` | For tagging beads comments | 1 line |

Everything else — requirements, implementation steps, epic goal, Key Decisions, wave conventions — the sub-agent reads from beads.

## Wave Summary Tags

Wave summaries posted to epic comments use a machine-parseable tag:

```
[WAVE-SUMMARY] Wave N complete:
- Closed: hub-abc.1, hub-abc.2
- Conventions: uuid-v4, camelCase
...
```

Sub-agents search for `[WAVE-SUMMARY]` entries to discover conventions.

## Report Tags

Sub-agent reports posted to issue comments use these tags:

| Tag | Written by | Content |
|-----|-----------|---------|
| `[IMPL-REPORT]` | Implementer | Full implementation report with evidence |
| `[SPEC-REVIEW]` | Spec reviewer | Spec compliance findings |
| `[CODE-REVIEW-N/M]` | Code reviewer N | Full code review report |
| `[CODE-REVIEW-AGG]` | Aggregator | Aggregated review report |

Downstream sub-agents search for these tags to load prior reports. Example: spec reviewer reads `[IMPL-REPORT]` to see what the implementer claims.

## Prerequisites

- Beads epic exists (created via plan2beads)
- Dependencies are set (`bd blocked` shows expected blockers)
- Each issue has `## Files` section in description
- Epic has 2+ child issues (single-issue work doesn't need orchestration—just implement and use `superpowers:verification-before-completion`)
- `temp/` directory exists in working directory (already present — do NOT run `mkdir`)
