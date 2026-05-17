# Superpowers-BD for Codex

Superpowers-BD supports Codex as a first-class plugin layer. Shared skills describe workflow intent; Codex executes that intent through native Codex skills, progress tracking, agent delegation, and verification commands.

Codex can use Superpowers-BD in two ways:

1. **Native Codex plugin** (preferred): Codex reads `.codex-plugin/plugin.json` and bundled skills directly.
2. **Manual bootstrap fallback**: Codex loads skills through `.codex/superpowers-bd-codex` from `~/.codex/AGENTS.md`.

Native plugin installation is the supported path for normal use. The fallback CLI remains for environments that cannot install Codex plugins yet; it is not the primary integration layer.

## Native Plugin Install

Register this repository as a Codex marketplace:

```bash
codex plugin marketplace add schlenks/superpowers-bd@main
```

For local development, clone the repository and register that checkout instead:

```bash
mkdir -p ~/.codex/plugins
git clone https://github.com/schlenks/superpowers-bd.git ~/.codex/plugins/superpowers-bd
codex plugin marketplace add ~/.codex/plugins/superpowers-bd
```

Then install or enable `superpowers-bd` from Codex's plugin UI/flow. Restart Codex after enabling the plugin so bundled skills are discovered.

The plugin manifest exposes `./skills/` directly and provides Codex UI metadata for core entry points. It deliberately does not declare bundled hooks yet; see [Project-Local Hooks](#project-local-hooks).

## Manual Bootstrap Install

Use this only when native plugin installation is unavailable.

```bash
mkdir -p ~/.codex
git clone https://github.com/schlenks/superpowers-bd.git ~/.codex/superpowers-bd
mkdir -p ~/.codex/skills
```

Add this section to `~/.codex/AGENTS.md`:

```markdown
## Superpowers-BD System

<EXTREMELY_IMPORTANT>
You have Superpowers-BD. RIGHT NOW run: `~/.codex/superpowers-bd/.codex/superpowers-bd-codex bootstrap` and follow the instructions it returns.
</EXTREMELY_IMPORTANT>
```

Verify:

```bash
~/.codex/superpowers-bd/.codex/superpowers-bd-codex find-skills
```

The fallback CLI supports `bootstrap`, `find-skills`, and `use-skill`. It uses the `superpowers-bd:` namespace for bundled skills and still honors personal skills in `~/.codex/skills`.

## Skill Usage

Native plugin install:

```text
Use $brainstorming before implementing this feature.
Use $plan2beads to import docs/plans/my-plan.md.
Use $ad-hoc-code-review to review my uncommitted changes.
```

Manual bootstrap install:

```bash
~/.codex/superpowers-bd/.codex/superpowers-bd-codex use-skill superpowers-bd:brainstorming
~/.codex/superpowers-bd/.codex/superpowers-bd-codex use-skill superpowers-bd:plan2beads
```

Prefer native `$skill` entry points when the plugin is installed. Use fallback CLI commands only from a manual bootstrap install.

## Codex Native Execution

Shared skills use platform-neutral workflow intent. Codex uses the native Codex surface for that intent:

| Shared intent | Claude Code implementation | Codex implementation |
|---------------|----------------------------|----------------------|
| Track progress | `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet` | `update_plan` |
| Delegate work | `Task` with background execution when appropriate | `spawn_agent`, then `wait_agent` when blocked on results |
| Ask questions | `AskUserQuestion` | Direct user question, or structured question tool when available |
| Verify completion | `Skill` plus verification commands and captured evidence | `$skill` plus verification commands and captured evidence |

Use native Codex file and shell tools for repository work. When a skill contains a Claude Code-specific task block, treat it as the Claude Code implementation of shared workflow intent and use the Codex implementation in the table.

For durable project tracking in repositories that use beads, keep `bd` as the source of truth for work items and dependencies. Use Codex progress tools for the execution checklist inside a skill.

## Codex-Specific Entry Points

- `$using-superpowers` - how to load and apply skills
- `$brainstorming` - design refinement before coding
- `$writing-plans` - implementation plan creation
- `$plan2beads` - convert a plan or Shortcut story into beads issues
- `$subagent-driven-development` - execute beads epics in parallel waves
- `$ad-hoc-code-review` - `/cr`-style local or PR review from Codex
- `$verification-before-completion` - evidence before completion claims

These are Codex-native entry points. Do not route Codex users through Claude Code slash commands unless a user explicitly asks to inspect the Claude command implementation.

## Native Agents

This repository includes project-scoped Codex agents in `.codex/agents/` and conservative execution limits in `.codex/config.toml`.

| Agent | Purpose |
|-------|---------|
| `code_reviewer` | Findings-first code review using the shared Superpowers-BD review standard |
| `spec_reviewer` | Spec-compliance review after SDD implementation tasks |
| `review_aggregator` | Provenance-preserving synthesis when multiple reviewer reports exist |
| `epic_verifier` | Final epic verification with PASS/FAIL evidence and no implementation edits |

Codex SDD uses these agents for review, aggregation, and verification stages. Implementation work currently uses the default Codex worker with explicit file ownership and scope instructions.

## Project-Local Hooks

This repository includes project-local Codex hooks in `.codex/hooks.json`. They add session context from `hooks/codex-session-start.sh` and PostToolUse audit/linter feedback from `hooks/codex-post-tool-use.sh`.

Review hook commands before trusting a checkout. In Codex, use the hooks review or trust flow for the project. If your Codex build gates plugin hooks behind `[features].plugin_hooks`, treat that as separate from this project-local development path. The plugin manifest deliberately does not declare bundled hook entries until plugin-bundled hook behavior is proven reliable for installed Codex plugins.

Current hook behavior is intentionally narrower than the Claude Code hook layer:

- SessionStart injects `superpowers-bd:using-superpowers` context and checkpoint reminders.
- PostToolUse records an audit log and returns linter feedback for edited files.
- There is no Codex Stop or TaskCompleted equivalent declared by this plugin.

## Feature Maturity Notes

- Codex plugin manifest and wrapper shape, core `$skill` metadata, Codex agent TOML, project-local hooks, and fallback CLI behavior are covered by `tests/codex/run-tests.sh`.
- Codex plugin-bundled hooks are not claimed yet. The local `.codex/hooks.json` path is the tested hook setup.
- Codex native agents are project-scoped in this repository. Plugin-wide distribution of `.codex/agents/*.toml` is not treated as proven by these docs.
- Codex review and SDD paths use native Codex agents. Cross-model Codex advisory review is only relevant when Claude Code is orchestrating and detects the separate OpenAI Codex plugin.

## Updating

Native plugin install:

```bash
cd ~/.codex/plugins/superpowers-bd
git pull
```

Manual bootstrap install:

```bash
cd ~/.codex/superpowers-bd
git pull
```

Restart Codex after updating.

## Troubleshooting

### Skills not found

1. Verify clone location: `ls ~/.codex/plugins/superpowers-bd/skills`
2. Verify plugin manifest: `jq . ~/.codex/plugins/superpowers-bd/.codex-plugin/plugin.json`
3. Restart Codex after enabling the plugin

### Manual fallback CLI script not executable

```bash
chmod +x ~/.codex/superpowers-bd/.codex/superpowers-bd-codex
```

### Node.js errors in manual mode

The manual fallback CLI is tested with modern Node.js. Use Node 20+.

## Development Tests

From the repository root:

```bash
./tests/codex/run-tests.sh
```
