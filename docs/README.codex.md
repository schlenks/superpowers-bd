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

The plugin manifest exposes `./skills/` directly and provides Codex UI metadata for core entry points. The marketplace wrapper also includes plugin-level Codex agents and hooks for installed-plugin use; project-local `.codex/` files remain the development fallback.

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
| Ask questions | `AskUserQuestion` | `request_user_input` when available for structured choices, otherwise direct user question |
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

The plugin wrapper bundles Markdown Codex agents under `plugins/superpowers-bd/agents/` so installed-plugin users get native agent roles outside this repository. Those agents omit `model` and inherit the active Codex model. This repository also keeps project-local `.codex/agents/` files as a development fallback.

| Agent | Purpose |
|-------|---------|
| `code_reviewer` | Findings-first code review using the shared Superpowers-BD review standard |
| `spec_reviewer` | Spec-compliance review after SDD implementation tasks |
| `review_aggregator` | Provenance-preserving synthesis when multiple reviewer reports exist |
| `epic_verifier` | Final epic verification with PASS/FAIL evidence and no implementation edits |

Codex SDD uses these agents for review, aggregation, and verification stages. Implementation work currently uses the default Codex worker with explicit file ownership and scope instructions.

## Codex Model Inheritance

Superpowers-BD does not use `.zshrc`, shell environment variables, or plugin metadata to guess a user's Codex plan tier. The installed-plugin Codex agents omit `model`, so Codex inherits the active model selected by the user.

The portable policy is documented in `skills/subagent-driven-development/budget-and-wave-cap.md`: inherit the active Codex model and route strength with `model_reasoning_effort`. If Codex later exposes a reliable authenticated plan-tier signal, this policy can add automatic paid-tier defaults. Until then, explicit inheritance is safer than stale model pins.

## Plugin Hooks

The installable plugin wrapper bundles Codex lifecycle hooks in both `plugins/superpowers-bd/hooks.json` and `plugins/superpowers-bd/hooks/hooks.json`. The second path is the current default plugin lifecycle location from Codex docs; the root wrapper file stays for compatibility with older local marketplace setups.

Review hook commands before trusting a checkout. In Codex, use `/hooks` to inspect hook sources, review new or changed hooks, trust hooks, or disable individual hooks.

Current installed-plugin hook behavior:

- SessionStart injects `superpowers-bd:using-superpowers` context and checkpoint reminders.
- UserPromptSubmit injects a terse active-work anchor only while SDD waves or beads work are in progress.
- PostToolUse records an audit log and returns linter feedback for edited files.
- SubagentStop blocks missing `VERDICT:` lines during active SDD waves.
- Stop blocks completion claims without verification evidence while live work is in progress.
- PreCompact blocks compaction during active SDD waves; PostCompact restores Superpowers-BD context after compaction.

The root plugin manifest still avoids a manifest-level `hooks` field; hooks live in the tested plugin wrapper lifecycle files.

## Feature Maturity Notes

- Codex plugin manifest and wrapper shape, all `$skill` metadata, plugin-level agents/hooks, workflow semantics, and fallback CLI behavior are covered by `tests/codex/run-tests.sh`.
- Codex plugin-bundled hooks are claimed through the local marketplace wrapper lifecycle files, not through a root `hooks` field in `.codex-plugin/plugin.json`.
- Codex native agents are available as project-local TOML agents for repository development and plugin-level Markdown agents for installed-plugin use.
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
