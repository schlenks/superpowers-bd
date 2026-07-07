# Skill Structure & Directory Layout

## What is a Skill?

A **skill** is a reference guide for proven techniques, patterns, or tools. Skills help future Claude instances find and apply effective approaches.

**Skills are:** Reusable techniques, patterns, tools, reference guides

**Skills are NOT:** Narratives about how you solved a problem once

## Skill Types

### Technique
Concrete method with steps to follow (condition-based-waiting, root-cause-tracing)

### Pattern
Way of thinking about problems (flatten-with-flags, test-invariants)

### Reference
API docs, syntax guides, tool documentation (office docs)

### Discipline
Rules and requirements that must resist rationalization (TDD, verification-before-completion)

## Directory Layout

```
skills/
  skill-name/
    SKILL.md                    # Main reference (required, ≤150 body lines)
    render-graphs.js            # Executable utilities stay at root
    references/                 # Deep-dive content (loaded on demand)
      guide.md                  # Detailed how-to
      checklist.md              # Full checklists
      examples/                 # Worked examples
      heavy-reference.md        # API docs, syntax guides
```

**Key pattern:** `references/` is the standard location for Level 3 content. Everything an agent needs "right now" goes in SKILL.md body. Everything for "doing it well" goes in `references/`.

## Self-Contained Skill
```
defense-in-depth/
  SKILL.md    # Everything inline
```
When: All content fits within ≤150 body lines

## Skill with Reusable Tool
```
condition-based-waiting/
  SKILL.md    # Overview + patterns
  example.ts  # Working helpers to adapt
```
When: Tool is reusable code, not just narrative

## Skill with References
```
writing-skills/
  SKILL.md              # Quick Start + core principles + reference table
  render-graphs.js      # Executable utility
  references/           # Deep-dive content
    3-tier-model.md
    skill-structure.md
    tdd-for-skills.md
    ...
```
When: Content exceeds ≤150 line budget

## Component Frontmatter Reference

Claude Code plugins have three component types:

### Skills (`skills/*/SKILL.md`)

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Skill name (letters, numbers, hyphens only) |
| `description` | yes | "Use when..." triggering conditions (≤300 chars recommended) |
| `effort` | no | `low`/`medium`/`high`/`xhigh`/`max` — overrides model effort when the skill is invoked (since 2.1.80; `xhigh` from 2.1.111) |
| `paths` | no | YAML list of globs — activates the skill only for matching file paths (since 2.1.84) |
| `disallowed-tools` | no | Denylist of tools removed while the skill is active (since 2.1.152). Leaky via Bash (`tee`, `python3 -c`) — treat as discipline, not hard enforcement. |
| `display-name` | no | Human-friendly name shown in `/skills` listings |
| `default-enabled` | no | Set `false` to ship the skill disabled by default |
| `fallback` | no | Recognized optional key (see Claude Code docs for exact semantics) |
| `metadata.*` | no | Arbitrary namespaced metadata keys |

`display-name`, `default-enabled`, `fallback`, and `metadata.*` accept kebab-case, snake_case, or camelCase (since 2.1.186). Max 1024 characters total frontmatter.

### Agents (`agents/*.md`)

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Agent name |
| `description` | yes | When to dispatch this agent (with `<example>` blocks) |
| `model` | no | `inherit`, `opus`, `sonnet`, `haiku` |
| `memory` | no | `project` to load CLAUDE.md + memory files |
| `maxTurns` | no | Max API round-trips before stopping |
| `tools` | no | Restrict to specific tools (allowlist) |
| `disallowedTools` | no | Block specific tools (denylist) |
| `permissionMode` | no | `default`, `plan`, `bypassPermissions` |
| `skills` | no | Skills to load into agent context |
| `mcpServers` | no | MCP servers available to this agent |
| `hooks` | no | PostToolUse/PreToolUse hooks (requires #17688 workaround) |

### Commands (`commands/*.md`)

| Field | Required | Description |
|-------|----------|-------------|
| `description` | no | What the command does (shown in command list) |
| `disable-model-invocation` | no | `true` to inject text without model call |
