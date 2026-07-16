# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.10.0] - 2026-07-16

Workflow contract calibration for modern SOTA models (Fable 5, GPT-5.x Codex): fixes verified platform-API defects, replaces fictional enforcement rhetoric with honest progress semantics, and retunes prompt pressure to calibrated contracts — without weakening the TDD, verification, or review invariants. All skill edits are mirrored into the bundled `plugins/superpowers-bd/` wrapper. Plans: `docs/plans/2026-07-16-workflow-contract-calibration.md` and `...-review-fixes.md`.

### Added

- **Workflow contract audit (`tests/verification/test-workflow-contract-audit.sh`)**: 33 structural checks encoding the cross-file contracts (verdict vocabulary, read-only verifier paths, Agent terminology, TaskUpdate dependency semantics, calibrated framing, mirror identity, managed-block integrity via the versioned `beads-integration-v1-minimal.md` fixture). Wired into the fast Claude suite; the runner now fails closed on missing configured tests.
- **Bounded TDD exceptions**: agents may self-select exactly four exception categories (documentation-only, declarative configuration, generated code, throwaway prototypes), each requiring a `TDD_EXCEPTION` verification receipt with alternative-verification evidence. The bright line and discard-and-restart rule remain for production behavior.
- **Proportional triage**: `systematic-debugging` gains a quick-trace/full-investigation gate (risk-sensitive areas always full); `verification-before-completion` scales verification breadth to risk while keeping same-response-cycle evidence — matching the stop-gate contract exactly.
- **Epic-verifier fail-closed persistence**: idempotent `[EPIC-VERIFICATION] <epic-id> <head-sha> <run-id>` marker, query-confirmed retries (never trust the add's exit status), a Report Persistence summary row, and a `FAIL (CANNOT_VERIFY)` verdict that blocks epic completion — on all three dispatch paths (Claude agent, prompt template, Codex TOML).

### Changed

- **Valid native-progress API usage**: `addBlockedBy` is a `TaskUpdate` field, not a `TaskCreate` parameter — every dependency example (~15 files) now creates the task, captures its ID, then records dependencies via `TaskUpdate`. Verified against the live tool schemas.
- **Honest enforcement semantics**: "blocked tasks cannot be marked in_progress"/"cannot commit until" claims replaced with progress-contract wording — task state exposes ordering and skipped phases; it does not technically prevent unrelated actions.
- **Current dispatch terminology**: active Claude examples use `Agent` (the current tool name) instead of `Task` across SDD prompt templates, `/cr`, and skill references; implementer verdict examples use the declared `DONE` vocabulary.
- **Calibrated prompt pressure**: `using-superpowers` rewritten as concise routing (1% rule, rationalization table, and `<EXTREMELY-IMPORTANT>` framing removed); session-start injection on all three hook surfaces (Claude, Codex, bundled Codex) now uses a plain `<superpowers-bd-session-context>` wrapper; `writing-skills` bulletproofing reoriented from persuasion doctrine to evidence-matched guidance (retains the measured "prohibition list worse than no-guidance control" result).
- **Family-aware 1M detection**: `writing-plans` and loaded references recognize 1M-native families (`sonnet-5`, `fable-5`) in addition to the `[1m]` suffix, so extended-context routing survives the suffix auto-strip.
- **Read-only epic verification**: rule-of-five applied as five review lenses without invoking editing workflows; editing skill auto-loads removed from the Claude agent; `tee` heredoc report persistence with output suppression (`> /dev/null`) on every surface.
- **Claude Agent bookkeeping**: metrics tracking uses the current Agent output schema (`agentId`, `outputFile`, `totalTokens`, `totalToolUseCount`, `totalDurationMs`, input/output usage); missing telemetry stays unknown instead of fake zeroes; the inaccurate `$9/M` blended-cost estimate is removed.
- **Managed beads blocks (CLAUDE.md/AGENTS.md)**: replaced the push-mandating session-close protocol with the policy-controlled profile template (conservative default: no commit/push without explicit authority), guarded by a content-hash drift check against the versioned fixture.
- **Aggregation model policy**: hardcoded `haiku` replaced with a caller-resolved `{low_cost_synthesis_model}` placeholder (omit `model` when no low-cost alias exists); SDD tier tables keep literal model names by design.
- **Safer wave cleanup**: exact per-wave report-file removal replaces the broad `rm -f temp/<epic-prefix>*` glob that could delete checkpoints and flags.
- **Integration harness rework**: separate 300s fast / 1860s integration budgets, a real Beads epic fixture, current Agent assertions, exact session IDs, `--plugin-dir` source loading, and exit-77 skip semantics for environments that cannot run nested Claude.

### Removed

- Obsolete references after de-linking: `persuasion-principles.md`, `why-this-matters.md` (threat register), `systematic-debugging` `CREATION-LOG.md` and `real-world-impact.md`, `dispatching-parallel-agents` `real-world-impact.md`, `multi-review-aggregation` `dispatch-code.md` (nonexistent API pseudocode) and `metrics-and-cost.md` (stale pricing).

### Fixed

- Hook-blocked `bd show ... | head` truncation example in the SDD worked example; renamed-section pointer in `tdd-for-skills.md`; `✅/❌` verdict vocabulary normalized to `PASS/FAIL`; version drift ruled out by bumping all four manifests plus CLAUDE.md/AGENTS.md together.

## [5.9.1] - 2026-07-08

Fixes false-positive blocks in the `Stop` verification gate that fired on ordinary SDD status turns, and reconciles version drift left over from the 5.9.0 release. Mirrored across the Claude Code and Codex hook surfaces.

### Fixed

- **Stop-gate false positives during SDD review (`stop-gate.sh` + `codex-stop-gate.sh`)**: the completion-claim detector blocked turns that were not sign-offs. Two classes are now handled: (1) removed `ready to merge`/`ready for review` from `claim_re` — reviewer-verdict vocabulary the orchestrator *relays* during MONITOR/REVIEW, not its own completion claim; (2) added a not-a-sign-off suppressor that exits silently when a matched claim turn also reports work in flight (`still working`, `waiting on`, `N of M`, `holding`) or solicits user direction (trailing `?`, `want me to`, `awaiting your go-ahead`). Declarative terminal claims still block. Precision-over-recall by design: a false block harms the workflow, a false silence reverts to pre-hook behavior; the per-session counter cap and `SDD_ALLOW_STOP=1` remain as backstops.
- **Dead `all tests pass` claim entry**: `evidence_re` matched `all .*pass`, which self-exempted the bare `all tests pass` claim it collided with (an unevidenced assertion that should block). Removed `all .*pass` from `evidence_re` in both hooks; real evidence (`42 passed`, `ran pytest`, `exit code 0`) still exempts. Regression-tested.
- **Version drift from the 5.9.0 release**: `.codex-plugin/plugin.json` (5.8.0) and `AGENTS.md` (5.8.0) were never bumped alongside the Claude manifest. All four manifests plus `CLAUDE.md`/`AGENTS.md` now agree at 5.9.1, restoring the `test-plugin-config-drift.sh` version checks to green.

## [5.9.0] - 2026-07-07

Adopts the 2026-07-07 changelog audit (Claude Code 2.1.108–202) and retunes model-effort policy across both surfaces. All skill edits are mirrored into the bundled `plugins/superpowers-bd/skills/` wrapper.

### Added

- **Notification wave-observability hook (2.1.198)**: new `hooks/notification.sh` and a `Notification` entry in `hooks/hooks.json`. During an active SDD wave it logs `agent_needs_input`/`agent_completed` notifications to `temp/sdd-notifications.log`; silent no-op otherwise, never blocks. Gathers evidence on whether the 2.1.198 payloads fire for in-session Task-tool subagents (UNVERIFIED) before any reactive-MONITOR gate is built on top of it. Covered by `tests/codex/test-codex-hooks.sh`.
- **Expanded skill frontmatter reference**: `writing-skills/references/skill-structure.md` now documents `disallowed-tools` (2.1.152), `display-name`, `default-enabled`, `fallback`, `metadata.*`, the full `effort` value range (`low`–`max`; `xhigh` from 2.1.111), and case-insensitivity of the optional keys (2.1.186).

### Changed

- **Model-effort policy retune**: retired `xhigh` from static Claude Code skill/agent/command frontmatter in favor of a two-tier split — review/analysis gates at `effort: high`, workflow/orchestration at `effort: medium`. On Opus `medium ≈ high ≈ xhigh` sits within benchmark error bars (only `max` is a distinguishable gain), so `xhigh` cost ~2× `high` for no measurable benefit. On the Codex/GPT path — where `high`→`xhigh` is a real gain and Fable never runs — the SDD reviewer/verifier dispatch (`spec_reviewer`, `code_reviewer`, `epic_verifier`) is raised to `xhigh`; `review_aggregator` stays `medium`; implementers stay `medium`/`high`. Frontmatter now tops out at `high`, satisfying the Fable ceiling (never `xhigh`/`max` on Fable) by construction.
- **Context-tier detection by model family (2.1.173/2.1.197)**: the `[1m]` suffix is auto-stripped for 1M-native models (Sonnet 5, Fable 5), so wave-cap detection no longer relies on a bare `[1m]` substring — it also recognizes `sonnet-5`/`fable-5` as extended-context, preventing a silent drop to the 3-wave/9-budget tier.
- **Scoped simplifier revert (2.1.183)**: post-wave and pre-merge simplification recovery uses `git restore -- <files passed to the simplifier>` instead of `git checkout -- .`, which auto mode now blocks as a destructive bulk revert.
- **Minimum Claude Code raised to 2.1.144**: 2.1.141–143 shipped a Skill-tool headless-permission regression (the subagent skill discovery SDD depends on) fixed in 2.1.144. Newer optional features degrade gracefully.
- **Release process**: documents `claude plugin validate .` (inspects local `source="."` plugins since 2.1.196) as a pre-tag validation step.

### Docs

- **Worktree `baseRef` gotcha (2.1.133)**: `using-git-worktrees` warns that native/agent-isolation worktrees default to `baseRef: "fresh"` (branch from `origin/<default>`, not local `HEAD`), so unpushed plan/feature commits won't appear — set `worktree.baseRef: "head"` or push the base first.

### Fixed

- **SDD skill-test redesign (`superpowers_bd-ei5`/`ajn`)**: `tests/claude-code/test-subagent-driven-development.sh` was rewritten from six sequential live-model `claude -p` probes to deterministic structural assertions that grep the skill source for each documented property (spec-before-code ordering, self-review/completeness, checkpoint restore, reviewer skepticism, review loop, context/ownership). The old file used a positional phrase-order probe (`assert_order` on `spec compliance` → `code quality` in free text) that failed on *correct* answers phrased differently; fixing that unmasked further latent brittleness (a probe asserting "completeness" where the skill says "Complete") and pushed the full run past the runner's 300s timeout — its `exit 1`-on-first-failure had been masking the downstream probes. The suite is now fast and reliably green (2/2). Behavioral skill-invocation coverage remains in the `skill-triggering/` and `explicit-skill-requests/` suites.

## [5.8.0] - 2026-06-25

Ports a batch of "Superpowers-6" learnings into the plugin, hardening reviewer rigor, plan authoring contracts, plan2beads metadata propagation, and SDD guardrails. Every change keeps both the Claude Code and Codex surfaces first-class; all skill edits are mirrored into the bundled `plugins/superpowers-bd/skills/` wrapper.

### Added

- **Reviewer `CANNOT_VERIFY` channel (B1)**: spec reviewers can now return `VERDICT: CANNOT_VERIFY` when a requirement cannot be confirmed from the diff alone (e.g. an out-of-diff dependency), with an over-emission guardrail; the SDD orchestrator resolves it in Review Rules. Added to all spec-reviewer surfaces (Claude skill, Codex Markdown agent, Codex TOML fallback). `verdict-audit` gates only `NO_VERDICT`, so no hook change was needed.
- **Plan Global Constraints + per-task Interfaces (B5, B6)**: writing-plans now authors an optional `## Global Constraints` block and a per-task `Interfaces:` (Consumes/Produces) field in the task template.
- **plan2beads propagates plan metadata (B7)**: both parsers — Claude `commands/plan2beads.md` and Codex `skills/plan2beads/references/codex-plan2beads-flow.md` — recognize and propagate the optional `## Global Constraints` block (into every child body) and per-task `Interfaces:` field. Backward-compatible: section-less plans import unchanged.
- **rule-of-five-plans structural checks (B8)**: Interfaces routed to the Feasibility pass, Global Constraints routed to the Completeness pass.
- **SDD pre-flight requirement-conflict scan (B4)**: before dispatch, the orchestrator scans ready issues for conflicting requirements; silent when clean, distinct from the wave file map.
- **SDD no-prejudge review guardrail (B2)**: a review re-dispatch must not prejudge the outcome (names `Task` and `spawn_agent`).
- **Instruction-priority hierarchy (B10)**: using-superpowers documents the priority order on conflict, naming `CLAUDE.md` and `AGENTS.md`.
- **Task right-sizing heuristic (B11)**: writing-plans guidance — split a task only where a reviewer could reject one half while approving its neighbor.
- **Match-the-Form-to-the-Failure (A2)**: new bulletproofing.md section on choosing the enforcement shape that fits the failure mode.
- **Micro-Test Wording pre-step (A3)**: tdd-for-skills.md guidance on wording skill micro-tests before writing them.
- **`scripts/lint-shell.sh` + test (B9)**: shellcheck wrapper that lints tracked shell scripts at `--severity=warning`, with `tests/shell-lint/test-lint-shell.sh`.

### Changed

- **Reviewer rationale-skepticism + read-only (A1)**: all six reviewer surfaces now treat an in-diff justification as the author's self-assessment — a stated rationale never downgrades or suppresses a finding — and reaffirm that reviewers are read-only.
- **Plan-mandated-defect tripwire (B3)**: code reviewers surface a plan-mandated defect as a finding and route it to a human decision (`bd human` / PENDING_HUMAN) rather than silently approving or auto-fixing against the plan.

### Fixed

- **"Ultra-think" trigger keyword (A4)**: corrected `Ultrathink` → `Ultra-think` in systematic-debugging rationalizations so the trigger phrase matches.
- **shellcheck SC2034 (B9)**: removed unused variables from `hooks/task-completed.sh`; `scripts/lint-shell.sh` resolves shellcheck via `command -v` instead of a hardcoded Homebrew path (CI portability).

## [5.7.0] - 2026-06-18

### Added

- **Per-skill Codex UI metadata**: every skill now ships an `agents/openai.yaml` (display name, short description, brand color, default `$skill` prompt, implicit-invocation policy) in both the source tree and the bundled marketplace wrapper
- **Expanded Codex hook lifecycle**: `.codex/hooks.json` and `plugins/superpowers-bd/hooks.json` now carry `UserPromptSubmit`, `SubagentStop`, `Stop`, `PreCompact`, and `PostCompact` on top of `SessionStart`/`PostToolUse`, backed by new `codex-work-state-anchor.sh`, `codex-verdict-audit.sh`, `codex-stop-gate.sh`, and `codex-pre-compact.sh` wrappers (project-local resolves from the git root; the plugin uses plugin-relative paths)

### Changed

- Codex agents now inherit the user's active Codex model instead of pinning one, matching the plugin-bundled agents that already omitted model pins

### Removed

- `gpt-5.3-codex` model pins from `.codex/agents/*.toml`, the `.codex/model-profiles.toml` profile file, and the `[superpowers_bd] codex_model_profile` project config — README, Codex docs, and SDD model policy updated to document inheritance

## [5.6.8] - 2026-06-17

### Added

- **Claude Code SDD lifecycle gates**: `UserPromptSubmit` injects a terse work-state anchor only while an SDD wave or beads work is in flight; `Stop` blocks completion claims without fresh verification evidence during live work (with loop guards and override); `SubagentStop` blocks missing `VERDICT:` lines during active SDD waves, failing open when hook payload parsing is unavailable

### Changed

- `SessionStart` suppresses and removes stale SDD checkpoints when the epic has no open or in-progress children
- Codex `SessionStart` wrappers use the same stale-checkpoint liveness check; the SDD background-execution reference documents Codex-native `wait_agent` verdict validation, since Codex lacks the Claude `SubagentStop` enforcement surface

## [5.6.7] - 2026-05-19

### Fixed

- `hooks/hooks.json` runs the cross-platform `run-hook.cmd` wrapper in shell form again, fixing a 5.6.6 startup regression. Claude Code's hook `args` field switches command hooks into exec form, which spawned the polyglot `.cmd` wrapper directly with no shell — on macOS/Linux it has no shebang, so direct spawn failed with `ENOEXEC`. The PostToolUse linter keeps `continueOnBlock: true`; only the launcher form changed.

## [5.6.6] - 2026-05-19

### Added

- **Codex installed-plugin native surfaces**:
  - Added plugin-level Codex Markdown agents under `plugins/superpowers-bd/agents/` for `code_reviewer`, `spec_reviewer`, `review_aggregator`, and `epic_verifier`
  - Added plugin-level Codex hooks under `plugins/superpowers-bd/hooks.json` and `plugins/superpowers-bd/hooks/`
  - Added tests that verify the marketplace wrapper bundles native agents/hooks and executes bundled hook scripts with plugin-relative paths

- **Codex model profiles**:
  - Added `.codex/model-profiles.toml` and `[superpowers_bd] codex_model_profile = "standard"` project config
  - Documented `standard` (`gpt-5.3-codex`) and `premium` (`gpt-5.5`) Codex routing in README, Codex docs, and SDD model policy
  - Plugin-bundled Codex agents intentionally omit model pins so installed-plugin users inherit their active Codex model

### Changed

- **Claude hook compatibility**:
  - Updated `hooks/hooks.json` to use Claude Code hook `command` plus `args` exec form instead of shell-quoted command strings
  - Added `continueOnBlock: true` to the Claude PostToolUse linter hook
  - Bumped documented minimum Claude Code version to 2.1.139
  - Added drift tests for hook exec args and PostToolUse blocking semantics

- **Claude Code and Codex parity docs**:
  - README platform support matrix now describes skills, agents, hooks, review workflow, SDD, tests, fallbacks, and current limitations by native platform layer
  - Codex docs now cover native plugin install, `$skill` entry points, `.codex/agents/*.toml`, hook trust/setup, fallback CLI scope, and feature maturity notes
  - `CLAUDE.md` remains Claude-specific and keeps minimum Claude Code version details; `AGENTS.md` remains Codex/project-agent-specific and points to Codex-native docs instead of cloning Claude release requirements

- **OpenCode plugin packaging**:
  - OpenCode install docs now clone `schlenks/superpowers-bd` into `~/.config/opencode/superpowers-bd`
  - OpenCode plugin file moved to `.opencode/plugins/superpowers-bd.js`, with `.opencode/plugin/superpowers-bd.js` kept as a compatibility wrapper
  - `.opencode/package.json` is now tracked so local installs keep the `@opencode-ai/plugin` dependency metadata and Node loads the plugin as ESM without reparsing
  - OpenCode forced skill namespace changed from `superpowers:` to `superpowers-bd:`
  - OpenCode tests updated for the current install path, plugin filename, dependency metadata, and namespace

- **Cross-agent setup drift checks**:
  - Added `tests/verification/test-plugin-config-drift.sh` to keep Claude Code, Codex, and OpenCode plugin metadata/docs in sync
  - Root `settings.json` disables Codex git-instruction import so Codex uses `AGENTS.md` as the single project instruction source
  - Claude Code linter hook blocking paths now return PostToolUse decision JSON instead of relying on exit-code blocking semantics

## [5.6.5] - 2026-05-09

### Added

- **Codex plugin packaging addendum** (2026-05-14):
  - Added `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` for native Codex plugin discovery
  - Added `.codex/superpowers-bd-codex` as the manual Codex fallback CLI using the `superpowers-bd:` namespace
  - Added a local marketplace wrapper under `plugins/superpowers-bd/` with real manifest and skill files instead of symlinks
  - Added `tests/codex/run-tests.sh` coverage for the manifest, marketplace wrapper, fallback CLI, and frontmatter parsing

### Changed

- **Codex docs and naming**:
  - Codex install docs now prefer native plugin installation and describe the manual fallback under `~/.codex/superpowers-bd`
  - Codex UI metadata and fallback examples use Superpowers-BD naming consistently

- **Worktree native-tool detection** (`using-git-worktrees`):
  - Step 0: detect existing isolation via `GIT_DIR != GIT_COMMON` (with submodule guard via `git rev-parse --show-superproject-working-tree`)
  - Consent gating before creation when no preference declared
  - Step 1a: prefer native worktree tools (`EnterWorktree`, `WorktreeCreate`, `--worktree`) over `git worktree add`
  - Step 1b: fallback flow simplified to 4 task-tracked steps (select dir, gitignore check, create worktree, proceed to Step 3)
  - Reference files: red-flags.md updated; creation-steps.md scoped to fallback path

- **Branch finishing** (`finishing-a-development-branch`):
  - Step 1.7: environment detection chooses menu (4 options on named branch, 3 options on detached HEAD; submodule guard present)
  - Step 3 Auto: detached-HEAD env-state guard rejects `completion:merge-local`
  - Step 5 cleanup: provenance-based with prefix-anchored path matching against `$MAIN_ROOT/.worktrees/`, `$MAIN_ROOT/worktrees/`, `$HOME/.config/superpowers/worktrees/`. Harness-owned workspaces use ExitWorktree if available
  - Quick Reference includes both 4-option and 3-option tables

- **Plan verification** (`writing-plans`):
  - Plan Verification Checklist (task 2) is now inline orchestrator self-review, not a sonnet sub-agent dispatch
  - Tasks 3–7 (rule-of-five-plans passes) continue to dispatch sub-agents as before
  - ~10–30s saved per plan; same 9-item checklist coverage
  - verification-footer.md updated to "5 sub-agent verdicts + 1 inline checklist" contract

### Removed

- Removed the old `.codex/superpowers-codex` fallback script and the `superpowers:` fallback namespace from Codex packaging.

## [5.6.4] - 2026-05-09

### Changed

- All 15 skills and commands previously pinned to `effort: high` bumped to `effort: xhigh` to match Anthropic's recommended floor for Opus 4.7 coding/agentic work. Claude Code 2.1.117 made `xhigh` the default effort on Opus 4.7, and skill `effort:` frontmatter is a strict override (not a floor) — so every `effort: high` pin was silently downgrading Opus 4.7 sessions below the recommended depth, including capping rule-of-five passes inside the `xhigh` review agents back to `high`. `xhigh` falls back to the highest supported level (`high`) on Opus 4.6 and Sonnet 4.6, so no behavior change on those models. Files: `skills/{rule-of-five-code,rule-of-five-tests,rule-of-five-plans,test-driven-development,systematic-debugging,finishing-a-development-branch,epic-verifier,brainstorming,writing-plans,receiving-code-review,writing-skills,verification-before-completion,subagent-driven-development,multi-review-aggregation}/SKILL.md`, `commands/cr.md`. The 10 `effort: medium` skills and commands stay at `medium` — intentional downgrade for routing/mechanical work.
- Minimum Claude Code bumped from 2.1.111 to 2.1.133. Claude Code 2.1.133 fixes a bug where subagents could not discover project, user, or plugin skills via the `Skill` tool, so the `skills:` frontmatter on `agents/code-reviewer.md` and `agents/epic-verifier.md` (`rule-of-five-code`, `rule-of-five-tests`) is now actually loadable from inside those agents instead of being silently ignored.
- `hooks/log-file-modification.sh` records the active effort level alongside `duration_ms` in `temp/file-modifications.log`. Hook input gained the `effort.level` JSON field in Claude Code 2.1.133. Older versions log `effort=-`.

## [5.6.3] - 2026-04-24

### Added

- `scripts/sync-plugin-version.sh` — reads version from `plugin.json` and writes it into `marketplace.json` so `claude plugin tag` validation passes without a manual double-bump
- Releasing workflow documented in `CLAUDE.md` — `bump → sync → commit → tag` loop using `claude plugin tag` (requires Claude Code 2.1.118+)
- `duration_ms` logged in `temp/file-modifications.log` by the PostToolUse audit hook (requires Claude Code 2.1.119+; older versions record `-ms`)

### Changed

- `code-reviewer` and `epic-verifier` agents bumped from `effort: high` to `effort: xhigh` — Opus 4.7 effort tier introduced in Claude Code 2.1.111. Review agents have no feedback loop, so reasoning depth is the quality lever. Degrades to the model's highest supported effort when invoked on models without `xhigh`.
- `CLAUDE.md` plugin version documented as 5.6.3 (was 5.6.0); minimum Claude Code bumped from 2.1.73 to 2.1.111
- `AGENTS.md` plugin version and minimum Claude Code version brought in line with `CLAUDE.md`
- `.claude-plugin/marketplace.json` version synced to 5.6.3 (was stale at 5.6.2)

## [5.6.2] - 2026-04-14

### Added

- `hooks/pre-compact.sh` returns `{"decision":"block","reason":"..."}` when any `temp/sdd-wave-active-{epic_id}.flag` exists, preventing mid-wave compaction from truncating orchestrator state. Adopts the `PreCompact` hook decision-block capability introduced in Claude Code 2.1.105.
- `SDD_ALLOW_COMPACT=1` environment variable bypass for stale flag files or explicit user override

### Changed

- `skills/subagent-driven-development/wave-orchestration.md` writes the wave-active flag at dispatch start and removes it during wave cleanup and COMPLETE cleanup — between waves the flag is absent so checkpoint-based recovery still works

## [5.6.0] - 2026-04-06

### Added

- Codex cross-model review integration — OpenAI's Codex plugin as a structurally distinct "second opinion" reviewer
- Session-start codex detection (`hooks/session-start.sh`) — sets `CODEX_REVIEW_AVAILABLE` and `CODEX_INSTALL_PATH` env vars with timeout guard and graceful degradation
- `/cr` parallel Codex adversarial review dispatch with scope mapping for all 6 review modes (uncommitted, last commit, since push, branch diff, custom, PR)
- Rule-of-five parallel Codex review for all 3 variants (code, plans, tests) — dispatches at pass 1, waits synchronously after pass 5
- Unified Step 7 in `/cr` — waits for ALL reviews (Claude + Codex) before presenting, fixing N=1 early exit

## [5.5.8] - 2026-03-30

### Changed

- Migrated all `TaskOutput` references to `Read` on agent output files (TaskOutput deprecated in Claude Code 2.1.83) — SDD skill, `/cr` command, README, release notes

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

[Unreleased]: https://github.com/schlenks/superpowers-bd/compare/v5.8.0...HEAD
[5.8.0]: https://github.com/schlenks/superpowers-bd/compare/v5.7.0...v5.8.0
[5.7.0]: https://github.com/schlenks/superpowers-bd/compare/v5.6.8...v5.7.0
[5.6.8]: https://github.com/schlenks/superpowers-bd/compare/v5.6.7...v5.6.8
[5.6.7]: https://github.com/schlenks/superpowers-bd/compare/v5.6.6...v5.6.7
[5.6.6]: https://github.com/schlenks/superpowers-bd/compare/v5.6.5...v5.6.6
[5.6.5]: https://github.com/schlenks/superpowers-bd/compare/v5.6.4...v5.6.5
[5.6.4]: https://github.com/schlenks/superpowers-bd/compare/v5.6.3...v5.6.4
[5.6.3]: https://github.com/schlenks/superpowers-bd/compare/v5.6.2...v5.6.3
[5.6.2]: https://github.com/schlenks/superpowers-bd/compare/v5.6.0...v5.6.2
[5.6.0]: https://github.com/schlenks/superpowers-bd/compare/v5.5.8...v5.6.0
[5.5.8]: https://github.com/schlenks/superpowers-bd/compare/v5.5.7...v5.5.8
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
