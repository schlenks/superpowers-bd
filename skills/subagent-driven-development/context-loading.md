# Context Loading

Before dispatching implementers, load rich context to help them understand "why".

## Epic Context

Extract from epic description:

```bash
# Get epic details
bd show <epic-id>

# Parse Key Decisions section (between "Key Decisions:" and next heading or "---")
# Include epic goal (first paragraph of description)
```

**What to extract:**
- Epic goal (first sentence/paragraph)
- Key Decisions (3-5 decisions with rationale)
- Task purpose (from task's description or infer from title)

**Template slots to fill:**
- `[EPIC_GOAL]` - One sentence epic goal
- `[KEY_DECISIONS]` - Bullet list of decisions, or "None documented - refer to epic description"
- `[TASK_PURPOSE]` - Why this task matters

**Edge case:** If epic description lacks "Key Decisions:" section, use "Key Decisions not documented. Refer to epic description for context."

## Wave Conventions

Extract from epic comments:

```bash
# Get wave summary comments
bd comments <epic-id> --json | jq -r '
  .[] | select(.text | contains("Wave")) | .text
' | tail -3
```

**What to extract:**
- Naming conventions chosen
- Code patterns established
- Interface shapes implemented
- Any surprises or deviations

**Template slot to fill:**
- `[WAVE_CONVENTIONS]` - Bullet list or "None yet (first wave)"

## Prerequisites

- Beads epic exists (created via plan2beads)
- Dependencies are set (`bd blocked` shows expected blockers)
- Each issue has `## Files` section in description
- Epic has 2+ child issues (single-issue work doesn't need orchestration—just implement and use `superpowers:verification-before-completion`)
