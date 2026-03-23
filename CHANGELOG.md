# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.5.7] - 2026-03-23

### Added

- Git bisect reference for systematic-debugging Phase 1 — regression pinpointing in multi-developer repos (`references/git-bisect.md`)

## [5.5.6] - 2026-03-21

### Changed

- Migrated release notes to Keep a Changelog format (`CHANGELOG.md`)

### Fixed

- Writing-plans skill now explicitly saves to `docs/plans/` instead of `~/.claude/plans/` default plan mode directory

## [5.5.5] - 2026-03-20

### Added

- Explicit `effort` frontmatter on all 20 skills and 5 commands (15 high, 10 medium) — deterministic effort regardless of session state

### Fixed

- Multi-reviewer report persistence (`/cr N`) — replaced `cat` heredoc with `tee` for `disallowedTools` enforcement compatibility

## [5.5.4] - 2026-03-19

### Added

- `effort: high` frontmatter to code-reviewer and epic-verifier agents for deeper reasoning

### Changed

- plan2beads auto-executes epic on 1M context instead of stopping with `/clear` instruction

### Fixed

- marketplace.json schema for `claude plugin validate` (moved `description` under `metadata`)

## [5.5.1] - 2026-03-13

### Changed

- Writing-plans skips `/compact` and `/clear` pauses on 1M context, eliminating two manual interventions per planning session

## [5.5.0] - 2026-03-13

### Added

- Context-aware wave cap for SDD: default 5 for 1M context, 3 for 200k (detected via `[1m]` model ID suffix)
- Always-aggregate rule in multi-review — no fast-path skip, preserves union of all findings
- Repo policy rule loading (`.claude/rules/*.md`) in code reviewer
- Stale reference checks in code reviewer for imports referencing deleted files
- SessionEnd hook for automatic `bd dolt commit` on session exit
- Mandatory fixes for Critical/Important findings (concrete fix required)
- Minimum Claude Code version documented as 2.1.73

### Changed

- Replaced all `bd sync` references with Dolt commands (`bd dolt commit`/`bd dolt push`/`bd dolt pull`)
- Simplified PR review flow in `/cr` command

## [5.4.0] - 2026-03-12

### Added

- Agent memory instructions — code-reviewer and epic-verifier read/write project memory
- Skills preloading via frontmatter for named agents (rule-of-five variants)
- Plugin settings file (`.claude-plugin/settings.json`) with `includeGitInstructions: false`
- SubagentStop verdict audit hook (`hooks/verdict-audit.sh`)
- ExitWorktree documentation as preferred worktree cleanup mechanism

## [5.3.0] - 2026-03-10

### Added

- 4-status implementer protocol: DONE, DONE_WITH_CONCERNS, BLOCKED, NEEDS_CONTEXT
- File structure mapping in writing-plans (file responsibility table before tasks)
- Escalation guidance for implementers ("Bad work is worse than no work")
- Status routing in SDD controller with re-dispatch and model upgrade paths

## [5.2.0] - 2026-03-06

### Added

- Configurable wave cap (1–10) for SDD via `wave-cap N` invocation option, default 3

## [5.1.0] - 2026-02-13

### Added

- `/cr` slash command for ad-hoc code reviews with optional multi-reviewer aggregation (`/cr N`, max 10)

### Fixed

- Plugin namespace consistency — renamed all runtime references from `superpowers:` to `superpowers-bd:`

## [5.0.2] - 2026-02-12

### Fixed

- Code reviewer methodology deduplication — agent body delegates to canonical file via self-read
- Lone finding downgrade scoped to Minor only — Critical/Important lone findings keep original severity
- Explicit `base_sha`/`head_sha` capture timing documented in SDD pipeline

## [5.0.1] - 2026-02-12

### Added

- `/compact` checkpoint between plan writing and verification to free research context before 6 verification passes

## [5.0.0] - 2026-02-11

### Added

- `rule-of-five-plans` variant with Feasibility, Completeness, Risk, Optimality passes
- `rule-of-five-tests` variant with Coverage, Independence, Speed, Maintainability passes
- Watch List for deferred improvement items with upstream triggers

### Changed

- `rule-of-five` renamed to `rule-of-five-code` (clean break, no backward compatibility shim)
- Roadmap marked complete (v6.9) — all 9 active items DONE

### Removed

- Improvement items #9 and #32 (obsolete after SQLite migration)

## [4.6.0] - 2026-02-11

### Added

- Checkpoint-based context window recovery for SDD — survives auto-compact, `/clear`, and session crashes
- Checkpoint schema with `epic_id`, `wave_completed`, `budget_tier`, `wave_receipts`, metrics

### Fixed

- Permission-triggering shell patterns removed from 19 skill files (heredocs, pipes, `$()`, `&&`, `||`)

## [4.5.0] - 2026-02-11

### Added

- Task complexity labels (simple/standard/complex) for per-task model selection at dispatch time
- Complexity heuristics: ≤1 file = simple, 2-3 files = standard, 4+ files = complex

### Changed

- Compressed 27 AI-consumed files (~30% token reduction) while preserving all enforcement content

### Fixed

- Removed audit logging from quality gate hook — `.claude/` is a protected directory

## [4.4.1] - 2026-02-10

### Fixed

- Unique temp filenames in plan2beads to prevent overwrite confirmation prompts
- Replaced `file-locks.json` with `{wave_file_map}` prompt template slot — eliminates file I/O for lock management
- Removed all `mkdir -p temp` instructions (7 locations across 6 files)

## [4.4.0] - 2026-02-10

### Added

- Beads-mediated stateless sub-agents — self-read context from beads, persist reports as tagged comments
- Code reviewer self-read (methodology loaded from disk via path resolution)
- Structured verdict format for all sub-agents (PASS/FAIL with REPORT_PERSISTED flag)

### Fixed

- Rule-of-five quality audit — 15 issues fixed across 16 qualifying files (placeholder mismatches, stale references, invalid examples)

## [4.3.0] - 2026-02-10

### Added

- 3-tier progressive disclosure for 14 skills — 67% token reduction (5,512 → 1,810 lines in SKILL.md files)
- Concise output directives for all agents ("final message must contain ONLY the structured report")
- Trivial change threshold — ≤10 diff lines overrides to single reviewer
- Wave size cap at 3 tasks (empirically determined from context exhaustion)

### Fixed

- SDD conflict task triggering quality gate — renamed to avoid verify/verification pattern match

## [4.2.0] - 2026-02-09

### Added

- Code reviewer rewrite — procedural 7-step methodology with precision gate and evidence protocol
- Multi-review aggregation skill — N independent reviewers with deduplication and severity voting
- Linter guards via PostToolUse hooks (shellcheck, jq, lizard, cognitive-complexity-ts)
- TaskCompleted quality gate hook — blocks task completion without evidence in interactive mode
- Completion evidence enforcement — three-layer audit trail (hook, template, `bd close --reason`)
- Advisory file ownership for parallel implementers (prompt-embedded wave file map)
- PostToolUse audit logging with `link-plugin-components.sh` workaround for #17688
- Cost metrics tracking in SDD (per-task, per-wave, per-epic token visibility)
- Code simplifier integration at 4 workflow points (TDD refactor, SDD post-wave, pre-merge, receiving review)
- Epic completion strategy — user declares once during planning, `finishing-a-development-branch` auto-executes

## [4.1.2] - 2026-01-31

### Added

- Visual verification for frontend code — automatic browser-based smoke tests when frontend files modified

## [4.1.1] - 2026-01-31

### Added

- Gap closure loop — automated 3-retry verification with fix task creation and human escalation
- Context loading for implementers — epic goals, key decisions, and wave conventions injected at dispatch

## [4.1.0] - 2026-01-30

### Added

- Epic verifier agent for post-implementation verification (engineering checklist + rule-of-five)
- SDD orchestrator state machine: INIT → LOADING → DISPATCH → MONITOR → REVIEW → CLOSE → COMPLETE
- Background execution with `run_in_background: true` for true parallelism
- Budget tier selection matrix (max-20x/max-5x/pro-api × role)
- Dispatch decision logic routing verification tasks to `epic-verifier` agent
- Failure recovery patterns (timeout, FAIL verdict, conflicts, context exceeded)
- Beads setup script (`scripts/setup-beads-local.sh`)

## [4.0.11] - 2026-01-28

### Changed

- Simplified epic verification from 4-task chain to single task with explicit step-by-step checklist

## [4.0.10] - 2026-01-27

### Fixed

- Verification chain always required regardless of plan content (distinguished engineering vs process verification)

## [4.0.9] - 2026-01-27

### Added

- Epic verification enforcement via beads dependencies — 4 verification tasks with dependency chain
- Defensive legacy epic check in `finishing-a-development-branch`

## [4.0.8] - 2026-01-26

### Added

- Key Decisions section in plan headers (3-5 architectural decisions with rationale)
- Task-level context sections: Purpose, Not In Scope, Gotchas
- Cross-wave summary comments in SDD for convention propagation

## [4.0.7] - 2026-01-23

### Added

- Native task tool integration (TaskCreate/TaskUpdate/TaskList/TaskGet) for 12 skills + 1 command
- Quality gate enforcement via `addBlockedBy` task dependencies

## [4.0.6] - 2026-01-19

### Added

- Plan verification enforcement — 7 mandatory todos at plan start, Plan Document Footer with Verification Record
- Beads skill — comprehensive bd CLI reference for AI agents

## [4.0.5] - 2026-01-19

### Fixed

- plan2beads acceptance criteria — semicolons trigger permission deny rules, replaced with commas or ANSI-C newlines

## [4.0.4] - 2026-01-18

### Added

- Rule-of-five skill (5-pass quality review for artifacts >50 lines)
- plan2beads command (converts markdown plans to beads epics with dependencies)
- Beads integration across writing-plans, executing-plans, and SDD

## [4.0.3] - 2025-12-26

### Changed

- Strengthened using-superpowers for explicit skill requests — "invoke" instead of "check", new red flag for "I know what that means"

## [4.0.2] - 2025-12-23

### Changed

- Slash commands now user-only (`disable-model-invocation: true`) — underlying skills remain available for autonomous invocation

## [4.0.1] - 2025-12-23

### Fixed

- Skill access clarification — Skill tool loads content directly, no need to Read files separately
- GitHub thread reply guidance added to receiving-code-review

## [4.0.0] - 2025-12-17

### Added

- Two-stage code review in SDD (spec compliance + code quality, each a loop)
- Debugging techniques consolidated in systematic-debugging (root-cause-tracing, defense-in-depth, condition-based-waiting, find-polluter.sh)
- Testing anti-patterns reference in test-driven-development
- Skill test infrastructure: triggering tests, Claude Code integration tests, end-to-end workflow tests
- DOT flowcharts as executable specifications for key skills
- Skill priority system (process skills before implementation skills)

### Changed

- Brainstorming trigger strengthened to imperative ("You MUST use this before any creative work")

### Removed

- Six standalone skills merged: root-cause-tracing, defense-in-depth, condition-based-waiting → systematic-debugging; testing-skills-with-subagents → writing-skills; testing-anti-patterns → test-driven-development; sharing-skills removed

## [3.6.2] - 2025-12-03

### Fixed

- Linux compatibility — polyglot hook wrapper uses POSIX-compliant `$0` instead of bash-specific `${BASH_SOURCE[0]:-$0}`

## [3.5.1] - 2025-11-24

### Changed

- OpenCode bootstrap refactored from `chat.message` hook to `session.created` event

## [3.5.0] - 2025-11-23

### Added

- OpenCode support — native JavaScript plugin with `use_skill` and `find_skills` tools

### Changed

- Codex implementation refactored to use shared `lib/skills-core.js` ES module

## [3.4.1] - 2025-10-31

### Changed

- Optimized superpowers bootstrap — eliminated redundant skill execution by providing content directly in session context

## [3.4.0] - 2025-10-30

### Changed

- Simplified brainstorming skill — removed heavyweight 6-phase process, returned to conversational dialogue

## [3.3.1] - 2025-10-28

### Changed

- Updated brainstorming for autonomous recon before questioning

### Fixed

- writing-skills guidance points to correct agent-specific personal skill directories

## [3.3.0] - 2025-10-28

### Added

- Experimental Codex support — unified `superpowers-codex` script with bootstrap/use-skill/find-skills
- Namespaced skills (`superpowers:skill-name`), personal skills override superpowers when names match

## [3.2.3] - 2025-10-23

### Changed

- using-superpowers now uses Skill tool instead of Read tool for invoking skills

## [3.2.2] - 2025-10-21

### Changed

- Strengthened using-superpowers against agent rationalization — EXTREMELY-IMPORTANT block, mandatory protocol, 8 counter-arguments

## [3.2.1] - 2025-10-20

### Added

- Code reviewer agent included in plugin (`agents/code-reviewer.md`)

## [3.2.0] - 2025-10-18

### Added

- Design documentation phase in brainstorming workflow (`docs/plans/YYYY-MM-DD-<topic>-design.md`)

### Changed

- Skill reference namespace standardization — all internal references use `superpowers:` prefix

## [3.1.1] - 2025-10-17

### Fixed

- Command syntax in README — updated to namespaced format (`/superpowers:brainstorm`)

## [3.1.0] - 2025-10-17

### Added

- Enhanced brainstorming skill (Quick Reference table, decision flowchart, AskUserQuestion guidance)
- Anthropic best practices integration (`skills/writing-skills/anthropic-best-practices.md`)

### Changed

- Skill names standardized to lowercase kebab-case matching directory names

### Fixed

- Re-added missing command redirects (`brainstorm.md`, `write-plan.md`) removed in v3.0
- Fixed name mismatches for defense-in-depth and receiving-code-review

## [3.0.1] - 2025-10-16

### Changed

- Migrated to Anthropic's first-party skills system

## [2.0.2] - 2025-10-12

### Fixed

- False warning when local skills repo is ahead of upstream

## [2.0.1] - 2025-10-12

### Fixed

- Session-start hook execution in plugin context — `BASH_SOURCE` fallback and empty grep handling

## [2.0.0] - 2025-10-12

### Added

- Skills repository separation — skills moved to dedicated `obra/superpowers-skills` repo
- Auto-clone, fork creation, and auto-update on session start
- 6 problem-solving skills (collision-zone-thinking, inversion-exercise, meta-pattern-recognition, scale-game, simplification-cascades, when-stuck)
- Research skill (tracing-knowledge-lineages)
- Architecture skill (preserving-productive-tensions)
- pulling-updates-from-skills-repository skill

### Changed

- using-skills rewritten with imperative tone (renamed from getting-started)
- find-skills outputs full paths with `/SKILL.md` suffix for direct Read tool usage

### Removed

- Personal superpowers overlay system — replaced with git branch workflow
- `setup-personal-superpowers` hook — replaced by `initialize-skills.sh`

[Unreleased]: https://github.com/schlenks/superpowers-bd/compare/v5.5.7...HEAD
[5.5.7]: https://github.com/schlenks/superpowers-bd/compare/v5.5.6...v5.5.7
[5.5.6]: https://github.com/schlenks/superpowers-bd/compare/v5.5.5...v5.5.6
[5.5.5]: https://github.com/schlenks/superpowers-bd/compare/v5.5.4...v5.5.5
[5.5.4]: https://github.com/schlenks/superpowers-bd/compare/v5.5.1...v5.5.4
[5.5.1]: https://github.com/schlenks/superpowers-bd/compare/v5.5.0...v5.5.1
[5.5.0]: https://github.com/schlenks/superpowers-bd/compare/v5.4.0...v5.5.0
[5.4.0]: https://github.com/schlenks/superpowers-bd/compare/v5.3.0...v5.4.0
[5.3.0]: https://github.com/schlenks/superpowers-bd/compare/v5.2.0...v5.3.0
[5.2.0]: https://github.com/schlenks/superpowers-bd/compare/v5.1.0...v5.2.0
[5.1.0]: https://github.com/schlenks/superpowers-bd/compare/v5.0.2...v5.1.0
[5.0.2]: https://github.com/schlenks/superpowers-bd/compare/v5.0.1...v5.0.2
[5.0.1]: https://github.com/schlenks/superpowers-bd/compare/v5.0.0...v5.0.1
[5.0.0]: https://github.com/schlenks/superpowers-bd/compare/v4.6.0...v5.0.0
[4.6.0]: https://github.com/schlenks/superpowers-bd/compare/v4.5.0...v4.6.0
[4.5.0]: https://github.com/schlenks/superpowers-bd/compare/v4.4.1...v4.5.0
[4.4.1]: https://github.com/schlenks/superpowers-bd/compare/v4.4.0...v4.4.1
[4.4.0]: https://github.com/schlenks/superpowers-bd/compare/v4.3.0...v4.4.0
[4.3.0]: https://github.com/schlenks/superpowers-bd/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/schlenks/superpowers-bd/compare/v4.1.2...v4.2.0
[4.1.2]: https://github.com/schlenks/superpowers-bd/compare/v4.1.1...v4.1.2
[4.1.1]: https://github.com/schlenks/superpowers-bd/compare/v4.1.0...v4.1.1
[4.1.0]: https://github.com/schlenks/superpowers-bd/compare/v4.0.11...v4.1.0
[4.0.11]: https://github.com/schlenks/superpowers-bd/compare/v4.0.10...v4.0.11
[4.0.10]: https://github.com/schlenks/superpowers-bd/compare/v4.0.9...v4.0.10
[4.0.9]: https://github.com/schlenks/superpowers-bd/compare/v4.0.8...v4.0.9
[4.0.8]: https://github.com/schlenks/superpowers-bd/compare/v4.0.7...v4.0.8
[4.0.7]: https://github.com/schlenks/superpowers-bd/compare/v4.0.6...v4.0.7
[4.0.6]: https://github.com/schlenks/superpowers-bd/compare/v4.0.5...v4.0.6
[4.0.5]: https://github.com/schlenks/superpowers-bd/compare/v4.0.4...v4.0.5
[4.0.4]: https://github.com/schlenks/superpowers-bd/compare/v4.0.3...v4.0.4
[4.0.3]: https://github.com/schlenks/superpowers-bd/compare/v4.0.2...v4.0.3
[4.0.2]: https://github.com/schlenks/superpowers-bd/compare/v4.0.1...v4.0.2
[4.0.1]: https://github.com/schlenks/superpowers-bd/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/schlenks/superpowers-bd/compare/v3.6.2...v4.0.0
[3.6.2]: https://github.com/schlenks/superpowers-bd/compare/v3.5.1...v3.6.2
[3.5.1]: https://github.com/schlenks/superpowers-bd/compare/v3.5.0...v3.5.1
[3.5.0]: https://github.com/schlenks/superpowers-bd/compare/v3.4.1...v3.5.0
[3.4.1]: https://github.com/schlenks/superpowers-bd/compare/v3.4.0...v3.4.1
[3.4.0]: https://github.com/schlenks/superpowers-bd/compare/v3.3.1...v3.4.0
[3.3.1]: https://github.com/schlenks/superpowers-bd/compare/v3.3.0...v3.3.1
[3.3.0]: https://github.com/schlenks/superpowers-bd/compare/v3.2.3...v3.3.0
[3.2.3]: https://github.com/schlenks/superpowers-bd/compare/v3.2.2...v3.2.3
[3.2.2]: https://github.com/schlenks/superpowers-bd/compare/v3.2.1...v3.2.2
[3.2.1]: https://github.com/schlenks/superpowers-bd/compare/v3.2.0...v3.2.1
[3.2.0]: https://github.com/schlenks/superpowers-bd/compare/v3.1.1...v3.2.0
[3.1.1]: https://github.com/schlenks/superpowers-bd/compare/v3.1.0...v3.1.1
[3.1.0]: https://github.com/schlenks/superpowers-bd/compare/v3.0.1...v3.1.0
[3.0.1]: https://github.com/schlenks/superpowers-bd/compare/v2.0.2...v3.0.1
[2.0.2]: https://github.com/schlenks/superpowers-bd/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/schlenks/superpowers-bd/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/schlenks/superpowers-bd/releases/tag/v2.0.0
