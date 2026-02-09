# Superpowers-BD

> A beads-integrated fork of [Superpowers](https://github.com/obra/superpowers) by [Jesse Vincent](https://github.com/obra)

Superpowers-BD extends the original Superpowers workflow with **[beads](https://github.com/steveyegge/beads)** by [Steve Yegge](https://github.com/steveyegge) - a git-backed issue tracker that enables persistent task management, dependency tracking, and wave-based parallel execution across coding sessions.

## What's Different from Upstream

| Feature | Superpowers | Superpowers-BD |
|---------|-------------|----------------|
| Task tracking | In-memory TodoWrite | Persistent beads issues |
| Dependencies | None | `bd dep add` with blocking |
| Parallel execution | Basic subagents | Wave orchestration with conflict detection |
| Session persistence | Lost on context clear | Survives compaction, resumable |
| Epic verification | Self-review | Dedicated epic-verifier agent |
| Plan conversion | Manual | `plan2beads` command |

## Prerequisites

**Required:** [beads](https://github.com/steveyegge/beads) - git-backed issue tracker

```bash
# Install beads (choose one)
brew install beads
npm install -g @beads/bd
go install github.com/steveyegge/beads/cmd/bd@latest
```

Without beads, the core workflow (`plan2beads`, `executing-plans`, `subagent-driven-development`) will not function.

### Optional Dependencies

These tools enhance linting and complexity checks but are **not required** — hooks gracefully degrade without them.

| Tool | Purpose | Install |
|------|---------|---------|
| [shellcheck](https://www.shellcheck.net/) | Shell script linting | `brew install shellcheck` |
| [lizard](https://github.com/terryyin/lizard) | Cyclomatic complexity checking | `pip install lizard` |
| [cognitive-complexity-ts](https://github.com/Deskbot/Cognitive-Complexity-TS) | Cognitive complexity for TS/TSX | `npm install -g cognitive-complexity-ts` |

## Key Features

### Two-Layer Task System (v4.0.7)

Beads tracks **WHAT** work to do (features/epics, 1-4 hours). Claude's native tasks track **HOW** progress is made within those items (quality gates, 5-30 min).

12 skills enforce quality gates with task dependencies:
- `systematic-debugging` - 4 phase tasks enforce "NO FIXES BEFORE ROOT CAUSE"
- `rule-of-five` - 5 sequential pass tasks with dependencies
- `test-driven-development` - RED/GREEN/REFACTOR per feature
- `writing-plans` - 7 tasks (draft + checklist + rule-of-five)

Skipping phases becomes visible in TaskList. Blocked tasks cannot be marked in_progress.

### Rule-of-Five Quality Review (v4.0.4)

5-pass review required for any artifact >50 lines:
1. **Draft** - Get it working
2. **Correctness** - Verify logic and edge cases
3. **Clarity** - Improve readability
4. **Edge Cases** - Handle failures gracefully
5. **Excellence** - Polish for production

Integrated into `writing-plans`, `executing-plans`, `writing-skills`, and implementer prompts.

### Context Preservation (v4.0.8)

**Key Decisions** - Plans require 3-5 architectural decisions with rationale. Copied to epic description so implementers understand WHY, not just WHAT.

**Task Context Sections** - Optional but recommended:
- `Purpose:` - Why this task exists
- `Not In Scope:` - Prevents overbuilding
- `Gotchas:` - Known quirks from planning

**Cross-Wave Summaries** - After each wave, orchestrator posts summary comment to epic with conventions established and notes for future waves.

### Epic Verification (v4.0.9 → v4.1.0)

**Problem:** Verification was documented but skippable. Implementers rubber-stamped their own work.

**Solution:** Dedicated `epic-verifier` agent runs AFTER all implementation tasks close:
- Engineering checklist: YAGNI, drift, test coverage, regressions, docs, security
- Rule-of-five on files with >50 lines changed
- Produces PASS/FAIL verdict with file:line evidence
- Does NOT fix issues - reports them for implementers to fix

### Orchestrator State Machine (v4.1.0)

7 explicit states with defined transitions:
```
INIT → LOADING → DISPATCH → MONITOR → REVIEW → CLOSE → COMPLETE
```

**Background Execution** - `run_in_background: true` enables true parallelism:
- Dispatch multiple implementations simultaneously
- Poll with TaskOutput for completion
- Immediately dispatch reviews as implementations finish

**Budget Tier Selection** - Model matrix based on subscription:

| Role | max-20x | max-5x | pro/api |
|------|---------|--------|---------|
| Orchestrator | opus | opus | sonnet |
| Implementer | opus | sonnet | haiku |
| Reviewer | opus | sonnet | sonnet |

**Failure Recovery** - Documented patterns for timeout, FAIL verdict, file conflicts, context exceeded.

### Stealth Mode for Company Codebases (v4.1.0)

Use beads for personal issue tracking without committing to repo:

```bash
curl -fsSL https://raw.githubusercontent.com/schlenks/superpowers-bd/main/scripts/setup-beads-local.sh | bash
```

Initializes beads in stealth mode (`.beads/` in `.git/info/exclude`) and adds worktree auto-exclude to shell config.

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it steps back and asks you what you're really trying to do.

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read and digest.

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI (You Aren't Gonna Need It), and DRY.

Next up, once you say "go", it converts the plan to a **beads epic** with tracked dependencies, then launches *subagent-driven-development* - an orchestrator dispatches implementers in parallel waves, reviews their work with dedicated spec and code reviewers, and continues forward. Work persists across sessions. It's not uncommon for Claude to work autonomously for hours without deviating from the plan.

When implementation completes, a dedicated **epic-verifier** agent runs systematic verification (YAGNI, drift, tests, security, rule-of-five) before the branch is finished.

## Sponsorship

If Superpowers has helped you, consider [sponsoring Jesse Vincent's opensource work](https://github.com/sponsors/obra) - he created the original system this fork builds upon.


## Installation

**Note:** Installation differs by platform. Claude Code has a built-in plugin system. Codex and OpenCode require manual setup.

### Claude Code (via Plugin Marketplace)

In Claude Code, register the marketplace first:

```bash
/plugin marketplace add schlenks/superpowers-bd
```

Then install the plugin from this marketplace:

```bash
/plugin install superpowers-bd@schlenks/superpowers-bd
```

### Verify Installation

Check that commands appear:

```bash
/help
```

```
# Should see:
# /superpowers-bd:brainstorm - Interactive design refinement
# /superpowers-bd:write-plan - Create implementation plan
# /superpowers-bd:execute-plan - Execute plan in batches
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

3. **writing-plans** - Activates with approved design. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, `Depends on:` sections, complete code, verification steps.

4. **plan2beads** - Converts markdown plan to beads epic with tracked dependencies. Creates parent epic and child tasks with proper blocking relationships.

5. **subagent-driven-development** - Orchestrator dispatches implementers in parallel waves based on dependency graph. Each wave:
   - Checks file conflicts between ready tasks
   - Dispatches implementations (optionally in background for true parallelism)
   - Runs spec review + code review (can be parallel)
   - Closes completed tasks, unlocking next wave

6. **test-driven-development** - Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit.

7. **epic-verifier** - Activates when all implementation tasks close. Dedicated verification agent runs engineering checklist (YAGNI, drift, tests, docs, security) and rule-of-five on significant files. Produces PASS/FAIL verdict with evidence.

8. **finishing-a-development-branch** - Activates after verification passes. Presents options (merge/PR/keep/discard), cleans up worktree.

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
- **writing-plans** - Detailed implementation plans with dependency tracking
- **executing-plans** - Batch execution with checkpoints (beads-aware)
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Pre-review checklist
- **receiving-code-review** - Responding to feedback
- **using-git-worktrees** - Parallel development branches
- **finishing-a-development-branch** - Merge/PR decision workflow
- **subagent-driven-development** - Wave-based orchestration with state machine, background execution, budget tier selection, and failure recovery

**Verification**
- **epic-verifier** - Dedicated agent for epic completion verification (YAGNI, drift, tests, docs, security, rule-of-five)
- **rule-of-five** - 5-pass review for significant artifacts (Draft, Correctness, Clarity, Edge Cases, Excellence)

**Beads Integration**
- **beads** - Git-backed issue tracking skill
- **plan2beads** - Convert markdown plans to beads epics with dependencies

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-superpowers** - Introduction to the skills system

## Customizing for Your Organization

Superpowers-BD is designed to be forked and customized. The skill system supports a **local > marketplace** priority:

1. **Local skills** in `~/.claude/skills/` take precedence
2. **Marketplace skills** are used as fallbacks

This means you can:
- Fork this repository to your organization
- Add custom skills or modify existing ones
- Install your fork as a plugin
- Your customizations override marketplace defaults

### Skill Resolution

When invoking skills, Claude checks for unprefixed local versions first:

| If you want... | Try first (local) | Fall back to (plugin) |
|----------------|-------------------|---------------------------|
| brainstorming | `brainstorming` | `superpowers-bd:brainstorming` |
| writing-plans | `writing-plans` | `superpowers-bd:writing-plans` |
| executing-plans | `executing-plans` | `superpowers-bd:executing-plans` |

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
/plugin update superpowers-bd
```

## License

MIT License - see LICENSE file for details

## Support

- **This fork**: https://github.com/schlenks/superpowers-bd/issues
- **Upstream Superpowers**: https://github.com/obra/superpowers
- **Beads**: https://github.com/steveyegge/beads
