# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Superpowers-BD is a multi-agent-tool plugin providing workflow skills for TDD, debugging, code review, and beads-based collaboration patterns. This file documents the Claude Code platform layer: Claude plugin metadata, slash commands, Claude Code agents, Claude hooks, and Claude-specific version requirements. Codex has its own first-class project instructions in `AGENTS.md` and native Codex plugin docs in `docs/README.codex.md`.

**Plugin version:** 5.10.0
**Minimum Claude Code:** 2.1.144 (2.1.141–143 shipped a Skill-tool headless-permission regression fixed in 2.1.144 — the exact subagent skill discovery SDD depends on; also `effort.level` in hook input JSON; `effort` frontmatter on review agents from 2.1.78; `claude plugin tag` from 2.1.118; PostToolUse `duration_ms` from 2.1.119; PostToolUse `continueOnBlock` from 2.1.139). Optional newer features degrade gracefully on older builds: `disallowed-tools` skill frontmatter (2.1.152), Notification stall hook (2.1.198).

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

agents/                     # Claude Code subagent definitions for Agent tool
  code-reviewer.md         # Code review subagent
  epic-verifier.md         # Epic verification subagent

commands/                   # Claude Code user-invocable slash commands
  brainstorm.md            # /superpowers-bd:brainstorm
  write-plan.md            # /superpowers-bd:write-plan
  execute-plan.md          # /superpowers-bd:execute-plan
  plan2beads.md            # /superpowers-bd:plan2beads

hooks/                      # Claude Code session lifecycle hooks
  session-start.sh         # Runs on session start/resume/clear; injects skills + live SDD checkpoint
  session-end.sh           # Commits pending Dolt changes on exit (requires >= 2.1.74)
  link-plugin-components.sh  # Copies hooked components to .claude/ (#17688 workaround)
  log-file-modification.sh   # PostToolUse audit logger for Write|Edit
  task-completed.sh        # Quality gate on task completion
  work-state-anchor.sh     # UserPromptSubmit: terse work-state anchor when work is live
  verdict-audit.sh         # SubagentStop: audits + gates NO_VERDICT during active SDD waves
  notification.sh          # Notification: wave-gated observability log (agent_needs_input/agent_completed)
  stop-gate.sh             # Stop: re-asserts verification-before-completion on unevidenced claims

tests/
  claude-code/             # Headless Claude Code integration tests
  explicit-skill-requests/ # Skill invocation tests
  skill-triggering/        # Automatic skill triggering tests
  subagent-driven-dev/     # End-to-end workflow tests (go-fractals, svelte-todo)
```

### Two-Layer Task System

- **Beads tracks WHAT** (features/epics, 1-4 hours): `bd create`, `bd close`, `bd dep add`
- **Claude Code TaskCreate/TaskUpdate tracks HOW** (quality gates, 5-30 min within skills)

12 skills enforce quality gates via native task dependencies. Skipping phases is visible in TaskList.

### Skill Testing Methodology

Skills are tested like code via TDD:
1. **RED**: Run pressure scenarios WITHOUT skill, document baseline failures
2. **GREEN**: Write skill addressing specific failures, verify compliance
3. **REFACTOR**: Close loopholes by adding explicit counters for new rationalizations

Claude Code integration tests run headless Claude Code sessions and verify behavior by parsing `.jsonl` session transcripts. Codex has a separate native test suite under `tests/codex/`.

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

- **Plugin manifest**: `.claude-plugin/plugin.json`
- **Session hooks**: `hooks/hooks.json` (runs `session-start.sh` on startup, `link-plugin-components.sh` on first start, `session-end.sh` on exit)
- **Dynamic-context injection**: `hooks/work-state-anchor.sh` (UserPromptSubmit — injects a one-line work-state anchor only when an SDD wave flag exists or beads has in_progress work; silent when idle)
- **Quality gates**: `hooks/task-completed.sh` (TaskCompleted hook, interactive mode only); `hooks/stop-gate.sh` (Stop hook — re-asserts verification-before-completion when a completion claim lacks evidence and work is live; guarded by `stop_hook_active`, a per-session counter, and `SDD_ALLOW_STOP=1`); `hooks/verdict-audit.sh` (SubagentStop — blocks `NO_VERDICT` during an active wave, gated by the wave flag with a 2-retry cap and `SDD_ALLOW_NO_VERDICT=1`)
- **Audit logging**: `hooks/log-file-modification.sh` (PostToolUse hook via code-reviewer agent frontmatter); `hooks/verdict-audit.sh` also appends every subagent verdict to `temp/verdict-audit.log`
- **Wave observability**: `hooks/notification.sh` (Notification hook — during an active SDD wave, logs `agent_needs_input`/`agent_completed` notifications to `temp/sdd-notifications.log`; silent no-op otherwise, never blocks). Whether the 2.1.198 `agent_needs_input`/`agent_completed` payloads fire for SDD's in-session Agent-tool subagents (vs only `claude agents` background sessions) is UNVERIFIED — this hook gathers the evidence before any reactive-MONITOR gate is built on top of it.
- **Beads config**: `.beads/metadata.json`
- **Note**: Plugin frontmatter hook behavior has changed across Claude Code releases. Keep `link-plugin-components.sh` until this repo's integration test proves plugin-installed agent and skill hooks fire natively.

## Releasing

`.claude-plugin/plugin.json` is the source of truth for the plugin version. `.claude-plugin/marketplace.json` must agree or `claude plugin tag` refuses to tag. The helper below keeps them in lockstep.

```bash
# 1. Bump the version in .claude-plugin/plugin.json
# 2. Sync marketplace.json from plugin.json
./scripts/sync-plugin-version.sh

# 3. Validate the manifests + hooks.json before tagging (2.1.196 covers local source="." plugins)
claude plugin validate .

# 4. Commit the version + release notes
git commit -am "Release vX.Y.Z"

# 5. Tag (validates plugin.json and marketplace.json agree) and push
claude plugin tag -m "Release %s" --push
```

`claude plugin validate .` catches YAML/JSON parse errors and hooks.json schema violations; since 2.1.196 it also inspects local `source="."` plugins instead of silently skipping them. `claude plugin tag` requires Claude Code 2.1.118+. Creates a `superpowers-bd--v{version}` annotated tag. Users with semver-pinned marketplace entries auto-update to the latest matching tag on their side.

## Bash Safety

- Never chain commands (`&&`, `||`, `;`) — use separate Bash tool calls
- Never use command substitution (`$()`, backticks) — run the inner command first
- Never use shell redirects (`>`, `>>`) — use Write tool instead
- Never use `2>&1` — Bash tool captures both streams; merging interferes with RTK
- Never use glob patterns in `rm` (`*`, `?`) — resolve exact paths with Glob tool first

## Testing Requirements for Integration Tests

- Must run FROM the superpowers plugin directory (not temp directories)
- Local dev marketplace must be enabled in `~/.claude/settings.json`
- Use `--permission-mode bypassPermissions` and `--add-dir` for test directories

The managed Beads block below governs durable issue tracking only. It does not
prohibit native workflow progress: Claude Code still uses
`TaskCreate`/`TaskUpdate` for execution phases and quality gates.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
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

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
