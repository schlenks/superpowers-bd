# Superpowers-BD for Codex

Superpowers-BD can be used from Codex in two ways:

1. **Native Codex plugin** (preferred): Codex reads `.codex-plugin/plugin.json` and bundled skills directly.
2. **Legacy bootstrap fallback**: Codex loads skills through `.codex/superpowers-codex` from `~/.codex/AGENTS.md`.

## Native Plugin Install

Clone this repository:

```bash
mkdir -p ~/.codex/plugins
git clone https://github.com/schlenks/superpowers-bd.git ~/.codex/plugins/superpowers-bd
```

Register the repository as a local Codex marketplace:

```bash
codex plugin marketplace add ~/.codex/plugins/superpowers-bd
```

Then install or enable `superpowers-bd` from Codex's plugin UI/flow. Restart Codex after enabling the plugin so bundled skills are discovered.

## Legacy Bootstrap Install

Use this only when native plugin installation is unavailable.

```bash
mkdir -p ~/.codex
git clone https://github.com/schlenks/superpowers-bd.git ~/.codex/superpowers
mkdir -p ~/.codex/skills
```

Add this section to `~/.codex/AGENTS.md`:

```markdown
## Superpowers System

<EXTREMELY_IMPORTANT>
You have superpowers. RIGHT NOW run: `~/.codex/superpowers/.codex/superpowers-codex bootstrap` and follow the instructions it returns.
</EXTREMELY_IMPORTANT>
```

Verify:

```bash
~/.codex/superpowers/.codex/superpowers-codex find-skills
```

## Skill Usage

Native plugin install:

```text
Use $brainstorming before implementing this feature.
Use $plan2beads to import docs/plans/my-plan.md.
Use $ad-hoc-code-review to review my uncommitted changes.
```

Legacy bootstrap install:

```bash
~/.codex/superpowers/.codex/superpowers-codex use-skill superpowers:brainstorming
~/.codex/superpowers/.codex/superpowers-codex use-skill superpowers:plan2beads
```

## Codex Tool Mapping

Skills were originally written for Claude Code and are adapted for Codex with these mappings:

- `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet` -> `update_plan`
- `Task` with `run_in_background: true` -> `spawn_agent`, then `wait_agent` only when blocked on results
- `AskUserQuestion` -> direct user question, or structured question tool when available
- `Skill` tool -> native `$skill-name` invocation, or the legacy `superpowers-codex use-skill` command
- File operations -> native Codex tools

For durable project tracking in repositories that use beads, keep `bd` as the source of truth for work items and dependencies. Use Codex progress tools for the execution checklist inside a skill.

## Codex-Specific Entry Points

- `$using-superpowers` - how to load and apply skills
- `$brainstorming` - design refinement before coding
- `$writing-plans` - implementation plan creation
- `$plan2beads` - convert a plan or Shortcut story into beads issues
- `$subagent-driven-development` - execute beads epics in parallel waves
- `$ad-hoc-code-review` - `/cr`-style local or PR review from Codex
- `$verification-before-completion` - evidence before completion claims

## Updating

Native plugin install:

```bash
cd ~/.codex/plugins/superpowers-bd
git pull
```

Legacy bootstrap install:

```bash
cd ~/.codex/superpowers
git pull
```

Restart Codex after updating.

## Troubleshooting

### Skills not found

1. Verify clone location: `ls ~/.codex/plugins/superpowers-bd/skills`
2. Verify plugin manifest: `jq . ~/.codex/plugins/superpowers-bd/.codex-plugin/plugin.json`
3. Restart Codex after enabling the plugin

### Legacy CLI script not executable

```bash
chmod +x ~/.codex/superpowers/.codex/superpowers-codex
```

### Node.js errors in legacy mode

The legacy CLI is tested with modern Node.js. Use Node 20+.

## Development Tests

From the repository root:

```bash
./tests/codex/run-tests.sh
```
