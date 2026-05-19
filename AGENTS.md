# AGENTS.md

This file provides guidance to agent tools when working with code in this repository. Claude Code-specific behavior is called out explicitly; Codex-specific behavior is first-class and should use native Codex tools.

## Project Overview

Superpowers-BD is a multi-agent-tool plugin providing workflow skills for TDD, debugging, and collaboration patterns. It has first-class Claude Code, Codex, and OpenCode support, and integrates with **beads** (git-backed issue tracker) for persistent task management and wave-based parallel execution across sessions.

**Plugin version:** 5.6.5

Codex reads this file as the project instruction source. Keep Claude Code minimum-version and release-tagging details in `CLAUDE.md`; keep Codex-native install, agent, hook, and `$skill` details in `docs/README.codex.md`.

## Platform Boundary

Shared skills describe workflow intent. Each supported agent tool executes that intent through its own native platform layer, with comparable outcomes implemented in platform-native terms.

| Shared intent | Claude Code implementation | Codex implementation |
|---------------|----------------------------|----------------------|
| Track progress | `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet` | `update_plan` |
| Delegate work | `Task` with background execution when appropriate | `spawn_agent`, then `wait_agent` when blocked on results |
| Ask questions | `AskUserQuestion` | Direct user question, or structured question tool when available |
| Verify completion | `Skill` plus verification commands and captured evidence | `$skill` plus verification commands and captured evidence |

Command-backed workflows must expose native entry points for each supported platform. Claude Code slash commands, Codex `$skill`/plugin entry points, OpenCode commands, and fallback CLIs may share shell scripts and skill content, but orchestration must remain native to the current platform.

## Development Commands

### Testing Skills

```bash
# Run all fast skill tests (2-5 min)
./tests/claude-code/run-skill-tests.sh

# Run integration tests (10-30 min, executes real subagent workflows)
./tests/claude-code/run-skill-tests.sh --integration

# Run specific test
./tests/claude-code/run-skill-tests.sh --test test-subagent-driven-development.sh

# Run with verbose output
./tests/claude-code/run-skill-tests.sh --verbose

# Run Codex plugin, agent, hook, and workflow-semantics tests
./tests/codex/run-tests.sh
```

### Token Usage Analysis

```bash
# Analyze session transcript for token costs
python3 tests/claude-code/analyze-token-usage.py ~/.claude/projects/<project-dir>/<session>.jsonl
```

### Beads Integration

```bash
bd ready                    # Find available work
bd show <id>                # Review issue details
bd close <id1> <id2> ...    # Close completed issues
bd dolt commit              # Commit pending Dolt changes (bd sync is deprecated)
```

## Architecture

### Directory Structure

```
skills/                     # Core skill definitions (SKILL.md files)
  brainstorming/           # Design refinement before coding
  writing-plans/           # Implementation plan creation
  subagent-driven-development/  # Wave-based parallel execution
  test-driven-development/     # RED-GREEN-REFACTOR cycle
  systematic-debugging/        # 4-phase root cause analysis
  verification-before-completion/  # Evidence before assertions
  epic-verifier/               # Post-implementation verification
  rule-of-five-code/            # 5-pass code quality review
  rule-of-five-plans/           # 5-pass plan/design doc review
  rule-of-five-tests/           # 5-pass test quality review
  ...

agents/                     # Claude Code subagent definitions for Task tool
  code-reviewer.md         # Code review subagent
  epic-verifier.md         # Epic verification subagent

.codex/agents/              # Codex native agent definitions
  code-reviewer.toml        # code_reviewer
  spec-reviewer.toml        # spec_reviewer
  review-aggregator.toml    # review_aggregator
  epic-verifier.toml        # epic_verifier

commands/                   # Claude Code user-invocable slash commands
  brainstorm.md            # /superpowers-bd:brainstorm
  write-plan.md            # /superpowers-bd:write-plan
  execute-plan.md          # /superpowers-bd:execute-plan
  plan2beads.md            # /superpowers-bd:plan2beads

hooks/                      # Claude Code session lifecycle hooks
  session-start.sh         # Runs on session start/resume/clear
  session-end.sh           # Commits pending Dolt changes on exit
  link-plugin-components.sh  # Copies hooked components to .claude/ (#17688 workaround)
  log-file-modification.sh   # PostToolUse audit logger for Write|Edit
  task-completed.sh        # Quality gate on task completion

.codex/
  hooks.json                # Codex project-local SessionStart and PostToolUse hooks
  model-profiles.toml       # Standard/premium Codex model routing profiles
  superpowers-bd-codex      # Manual fallback CLI for non-plugin Codex installs

plugins/superpowers-bd/     # Codex local marketplace wrapper
  agents/                   # Plugin-level Codex Markdown agents
  hooks.json                # Plugin-level Codex hook config
  hooks/                    # Plugin-bundled Codex hook scripts

tests/
  claude-code/             # Headless Claude Code integration tests
  codex/                   # Codex plugin and native-loading tests
  explicit-skill-requests/ # Skill invocation tests
  skill-triggering/        # Automatic skill triggering tests
  subagent-driven-dev/     # End-to-end workflow tests (go-fractals, svelte-todo)
```

### Two-Layer Task System

- **Beads tracks WHAT** (features/epics, 1-4 hours): `bd create`, `bd close`, `bd dep add`
- **Native platform progress tracks HOW** (quality gates, 5-30 min within skills): Claude Code uses `TaskCreate`/`TaskUpdate`, Codex uses `update_plan`

12 skills enforce quality gates via native progress dependencies. In Claude Code, skipped phases are visible in TaskList; in Codex, preserve the same ordering with `update_plan`.

### Skill Testing Methodology

Skills are tested like code via TDD:
1. **RED**: Run pressure scenarios WITHOUT skill, document baseline failures
2. **GREEN**: Write skill addressing specific failures, verify compliance
3. **REFACTOR**: Close loopholes by adding explicit counters for new rationalizations

Claude Code integration tests run headless Claude Code sessions and verify behavior by parsing `.jsonl` session transcripts. Codex tests live under the Codex test suite and should verify Codex-native plugin behavior.

### Key Workflows

1. **brainstorming** → **using-git-worktrees** → **writing-plans** → **plan2beads** → **subagent-driven-development** → **epic-verifier** → **finishing-a-development-branch**

2. **subagent-driven-development** uses state machine: `INIT → LOADING → DISPATCH → MONITOR → REVIEW → CLOSE → COMPLETE`

3. **epic-verifier** runs engineering checklist (YAGNI, drift, tests, docs, security) and variant-aware rule-of-five on files >50 lines changed

## Writing Skills

Skills live in `skills/<skill-name>/SKILL.md`. Key conventions:

- **Frontmatter**: Only `name` and `description` fields (max 1024 chars total)
- **Description**: Must start with "Use when..." describing triggering conditions only (never summarize workflow)
- **Testing required**: No skill without failing baseline test first
- **Apply rule-of-five variant**: Code >50 lines uses rule-of-five-code (Draft→Correctness→Clarity→Edge Cases→Excellence), plans/skills use rule-of-five-plans, tests use rule-of-five-tests

See `skills/writing-skills/SKILL.md` for complete guide.

## Plugin Configuration

- **Claude Code plugin manifest**: `.claude-plugin/plugin.json`
- **Codex plugin manifest**: `.codex-plugin/plugin.json`
- **Session hooks**: `hooks/hooks.json` (runs `session-start.sh` on startup, `link-plugin-components.sh` on first start, `session-end.sh` on exit)
- **Quality gates**: `hooks/task-completed.sh` (TaskCompleted hook, interactive mode only)
- **Audit logging**: `hooks/log-file-modification.sh` (PostToolUse hook via code-reviewer agent frontmatter)
- **Beads config**: `.beads/metadata.json`

## Known Workarounds

### Plugin Frontmatter Hooks (#17688)

Plugin-loaded frontmatter hook behavior has changed across Claude Code releases. The upstream changelog says plugin skill frontmatter hooks were fixed, but [#17688](https://github.com/anthropics/claude-code/issues/17688) remains open.
`hooks/link-plugin-components.sh` still copies hooked components to `.claude/` on SessionStart until this repo's integration test proves plugin-installed agent and skill hooks fire natively.

**When working on this codebase, check if #17688 has been resolved.** If fixed:
1. Remove the `link-plugin-components.sh` SessionStart entry from `hooks/hooks.json`
2. Delete `hooks/link-plugin-components.sh`
3. Keep `hooks:` blocks in agent/skill frontmatter (they'll fire natively)
4. Update `SUPERPOWERS-BD-COMPREHENSIVE-IMPROVEMENTS.md` — remove #17688 from Open Blockers
5. Update this section in AGENTS.md

## Testing Requirements for Integration Tests

- Must run FROM the superpowers plugin directory (not temp directories)
- Local dev marketplace must be enabled in `~/.claude/settings.json`
- Use `--permission-mode bypassPermissions` and `--add-dir` for test directories

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
