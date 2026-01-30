# Superpowers

Superpowers is a complete software development workflow for your coding agents, built on top of a set of composable "skills" and some initial instructions that make sure your agent uses them.

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it steps back and asks you what you're really trying to do. 

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read and digest. 

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI (You Aren't Gonna Need It), and DRY. 

Next up, once you say "go", it launches a *subagent-driven-development* process, having agents work through each engineering task, inspecting and reviewing their work, and continuing forward. It's not uncommon for Claude to be able to work autonomously for a couple hours at a time without deviating from the plan you put together.

There's a bunch more to it, but that's the core of the system. And because the skills trigger automatically, you don't need to do anything special. Your coding agent just has Superpowers.


## Sponsorship

If Superpowers has helped you do stuff that makes money and you are so inclined, I'd greatly appreciate it if you'd consider [sponsoring my opensource work](https://github.com/sponsors/obra).

Thanks! 

- Jesse


## Installation

**Note:** Installation differs by platform. Claude Code has a built-in plugin system. Codex and OpenCode require manual setup.

### Claude Code (via Plugin Marketplace)

In Claude Code, register the marketplace first:

```bash
/plugin marketplace add obra/superpowers-marketplace
```

Then install the plugin from this marketplace:

```bash
/plugin install superpowers@superpowers-marketplace
```

### Verify Installation

Check that commands appear:

```bash
/help
```

```
# Should see:
# /superpowers:brainstorm - Interactive design refinement
# /superpowers:write-plan - Create implementation plan
# /superpowers:execute-plan - Execute plan in batches
```

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md
```

**Detailed docs:** [docs/README.codex.md](docs/README.codex.md)

### OpenCode

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

**Detailed docs:** [docs/README.opencode.md](docs/README.opencode.md)

## The Basic Workflow

1. **brainstorming** - Activates before writing code. Refines rough ideas through questions, explores alternatives, presents design in sections for validation. Saves design document.

2. **using-git-worktrees** - Activates after design approval. Creates isolated workspace on new branch, runs project setup, verifies clean test baseline.

3. **writing-plans** - Activates with approved design. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, verification steps.

4. **subagent-driven-development** or **executing-plans** - Activates with plan. Dispatches fresh subagent per task with two-stage review (spec compliance, then code quality), or executes in batches with human checkpoints.

5. **test-driven-development** - Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests.

6. **requesting-code-review** - Activates between tasks. Reviews against plan, reports issues by severity. Critical issues block progress.

7. **finishing-a-development-branch** - Activates when tasks complete. Verifies tests, presents options (merge/PR/keep/discard), cleans up worktree.

**The agent checks for relevant skills before any task.** Mandatory workflows, not suggestions.

## What's Inside

### Skills Library

**Testing**
- **test-driven-development** - RED-GREEN-REFACTOR cycle (includes testing anti-patterns reference)

**Debugging**
- **systematic-debugging** - 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)
- **verification-before-completion** - Ensure it's actually fixed

**Collaboration** 
- **brainstorming** - Socratic design refinement
- **writing-plans** - Detailed implementation plans
- **executing-plans** - Batch execution with checkpoints
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Pre-review checklist
- **receiving-code-review** - Responding to feedback
- **using-git-worktrees** - Parallel development branches
- **finishing-a-development-branch** - Merge/PR decision workflow
- **subagent-driven-development** - Fast iteration with two-stage review (spec compliance, then code quality)

**Quality**
- **rule-of-five** - 5-pass review for significant artifacts (Draft, Correctness, Clarity, Edge Cases, Excellence)

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-superpowers** - Introduction to the skills system

## Customizing for Your Organization

Superpowers is designed to be forked and customized. The skill system supports a **local > marketplace** priority:

1. **Local skills** in `~/.claude/skills/` take precedence
2. **Marketplace skills** are used as fallbacks

This means you can:
- Fork this repository to your organization
- Add custom skills or modify existing ones
- Install your fork as a plugin
- Your customizations override marketplace defaults

### TBL Customizations

This fork includes ToursByLocals-specific enhancements:

**Beads Integration** - Skills are updated to use [beads](https://github.com/obra/beads), a git-backed issue tracker:
- `writing-plans` - Tasks include `Depends on:` and `Files:` sections for dependency tracking
- `executing-plans` - Uses `bd ready`, `bd blocked`, `bd close` for dependency-aware batch execution
- `subagent-driven-development` - Wave-based parallel dispatch with file conflict detection
- `plan2beads` command - Converts markdown plans to beads epics

**Rule-of-Five** - 5-pass quality review for significant artifacts (>50 lines):
- Draft → Correctness → Clarity → Edge Cases → Excellence
- Integrated into `writing-plans`, `executing-plans`, `writing-skills`, and `implementer-prompt`

**Skill Resolution** - When invoking skills, Claude checks for unprefixed local versions first:
| If you want... | Try first (local) | Fall back to (marketplace) |
|----------------|-------------------|---------------------------|
| brainstorming | `brainstorming` | `superpowers:brainstorming` |
| writing-plans | `writing-plans` | `superpowers:writing-plans` |
| executing-plans | `executing-plans` | `superpowers:executing-plans` |

### Local-Only Beads Setup

If you want to use beads for personal issue tracking **without committing to the repo** (useful for company codebases):

```bash
# One-liner setup (installs beads, initializes stealth mode, adds worktree support)
curl -fsSL https://raw.githubusercontent.com/schlenks/superpowers/main/scripts/setup-beads-local.sh | bash
```

Or manually:

```bash
# 1. Install beads
brew install beads  # or: npm install -g @beads/bd

# 2. Initialize in stealth mode (adds to .git/info/exclude, not .gitignore)
bd init --stealth
```

**Git Worktree Support**: The setup script adds shell functions that automatically exclude `.beads/` in each worktree's local git exclude. This ensures beads works seamlessly across `git worktree` environments without polluting the repo.

## Philosophy

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success

Read more: [Superpowers for Claude Code](https://blog.fsck.com/2025/10/09/superpowers/)

## Contributing

Skills live directly in this repository. To contribute:

1. Fork the repository
2. Create a branch for your skill
3. Follow the `writing-skills` skill for creating and testing new skills
4. Submit a PR

See `skills/writing-skills/SKILL.md` for the complete guide.

## Updating

Skills update automatically when you update the plugin:

```bash
/plugin update superpowers
```

## License

MIT License - see LICENSE file for details

## Support

- **Issues**: https://github.com/schlenks/superpowers/issues
- **Upstream**: https://github.com/obra/superpowers
