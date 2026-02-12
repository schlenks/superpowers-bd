# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Superpowers-BD is a Claude Code plugin providing workflow skills for TDD, debugging, and collaboration patterns. It integrates with **beads** (git-backed issue tracker) for persistent task management and wave-based parallel execution across sessions.

**Plugin version:** 5.0.2

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
bd sync                     # Sync with git remote
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

agents/                     # Subagent definitions for Task tool
  code-reviewer.md         # Code review subagent
  epic-verifier.md         # Epic verification subagent

commands/                   # User-invocable slash commands
  brainstorm.md            # /superpowers-bd:brainstorm
  write-plan.md            # /superpowers-bd:write-plan
  execute-plan.md          # /superpowers-bd:execute-plan
  plan2beads.md            # /superpowers-bd:plan2beads

hooks/                      # Session lifecycle hooks
  session-start.sh         # Runs on session start/resume/clear
  link-plugin-components.sh  # Copies hooked components to .claude/ (#17688 workaround)
  log-file-modification.sh   # PostToolUse audit logger for Write|Edit
  task-completed.sh        # Quality gate on task completion

tests/
  claude-code/             # Headless Claude Code integration tests
  explicit-skill-requests/ # Skill invocation tests
  skill-triggering/        # Automatic skill triggering tests
  subagent-driven-dev/     # End-to-end workflow tests (go-fractals, svelte-todo)
```

### Two-Layer Task System

- **Beads tracks WHAT** (features/epics, 1-4 hours): `bd create`, `bd close`, `bd dep add`
- **Native TaskCreate/TaskUpdate tracks HOW** (quality gates, 5-30 min within skills)

12 skills enforce quality gates via native task dependencies. Skipping phases is visible in TaskList.

### Skill Testing Methodology

Skills are tested like code via TDD:
1. **RED**: Run pressure scenarios WITHOUT skill, document baseline failures
2. **GREEN**: Write skill addressing specific failures, verify compliance
3. **REFACTOR**: Close loopholes by adding explicit counters for new rationalizations

Integration tests run headless Claude Code sessions and verify behavior by parsing `.jsonl` session transcripts.

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
- **Session hooks**: `hooks/hooks.json` (runs `session-start.sh` on startup, `link-plugin-components.sh` on first start)
- **Quality gates**: `hooks/task-completed.sh` (TaskCompleted hook, interactive mode only)
- **Audit logging**: `hooks/log-file-modification.sh` (PostToolUse hook via code-reviewer agent frontmatter)
- **Beads config**: `.beads/metadata.json`
- **Note**: Plugin frontmatter hooks are broken ([#17688](https://github.com/anthropics/claude-code/issues/17688)). `link-plugin-components.sh` works around this.

## Testing Requirements for Integration Tests

- Must run FROM the superpowers plugin directory (not temp directories)
- Local dev marketplace must be enabled in `~/.claude/settings.json`
- Use `--permission-mode bypassPermissions` and `--add-dir` for test directories
