# Superpowers Release Notes

## v4.1.1 (2026-01-31) - Beads Fork

### Feature: Gap Closure Loop

Automated verification retry mechanism that creates fix tasks and re-verifies up to 3 times before escalating to human.

**Problem:** When verification failed, agents would just report failure. Manual intervention was required to create fix tasks and re-verify.

**Solution:** Added gap closure loop to `verification-before-completion` skill that automatically:
1. Creates a "Fix: [failure]" task when verification fails
2. Creates a blocked "Re-verify" task
3. Loops up to 3 attempts
4. Escalates to human with full failure history after 3 failures

**Files Modified:**
- `skills/verification-before-completion/SKILL.md` - Gap Closure Loop section, attempt tracking metadata, Gap Closure Enforcement protocol
- `skills/verification-before-completion/SKILL.test.md` (NEW) - 4 manual test cases for gap closure behavior

---

### Feature: Context Loading for Implementers

Rich context injection so implementers understand "why" they're building something and what conventions previous waves established.

**Problem:** Implementers received task specs but lacked broader context—epic goals, key architectural decisions, and patterns established by earlier waves.

**Solution:** Added context loading instructions to SDD and context slots to implementer prompt template.

**New template slots in `implementer-prompt.md`:**
- `[EPIC_GOAL]` - One sentence describing what the epic achieves
- `[KEY_DECISIONS]` - 3-5 architectural decisions with rationale
- `[TASK_PURPOSE]` - How this task contributes to the epic goal
- `[WAVE_CONVENTIONS]` - Patterns and conventions from previous wave summaries

**Context extraction using bd CLI:**
```bash
# Epic context
bd show <epic-id>  # Extract goal and Key Decisions section

# Wave conventions
bd comments <epic-id> --json | jq -r '
  .[] | select(.text | contains("Wave")) | .text
' | tail -3
```

**Files Modified:**
- `skills/subagent-driven-development/SKILL.md` - Context Loading section, Verification Gap Closure integration, PENDING_HUMAN state in state machine
- `skills/subagent-driven-development/implementer-prompt.md` - Epic Context and Established Conventions slots
- `skills/subagent-driven-development/SKILL.test.md` (NEW) - 4 manual test cases for context loading behavior

---

### Key Decisions

- **Gap Closure in verification-before-completion** — Centralizes retry logic in one skill rather than duplicating across SDD, executing-plans, etc.
- **Context extraction via bd CLI** — Uses existing `bd show` and `bd comments` rather than parsing JSONL directly
- **Max 3 retry attempts** — Balances automated recovery against infinite loops
- **Wave conventions in epic comments** — Reuses existing wave summary pattern for convention propagation

### Files Changed (5)

**Modified (3):**
- `skills/verification-before-completion/SKILL.md` (+87 lines)
- `skills/subagent-driven-development/SKILL.md` (+114 lines)
- `skills/subagent-driven-development/implementer-prompt.md` (+40 lines)

**New (2):**
- `skills/verification-before-completion/SKILL.test.md` (68 lines)
- `skills/subagent-driven-development/SKILL.test.md` (67 lines)

---

## v4.1.0 (2026-01-30) - Beads Fork

### Major Feature: Epic Verifier Agent

New dedicated agent and skill for epic completion verification. Separates verification from implementation to prevent self-certification bias.

**Problem:** Implementer subagents were verifying their own work, leading to rubber-stamp approvals and missed issues. Verification steps were skippable.

**Solution:** Created a dedicated `epic-verifier` agent that runs systematically after all implementation tasks close.

**What it does:**
- Engineering Checklist: YAGNI, plan drift, test coverage, regressions, docs, security
- Rule-of-Five review on files with >50 lines changed
- Produces PASS/FAIL verdict with file:line evidence
- Does NOT fix issues - reports them for implementers

**Files Added (3):**
- agents/epic-verifier.md - Agent definition with full verification process
- skills/epic-verifier/SKILL.md - Skill documentation with dispatch guidance
- skills/epic-verifier/verifier-prompt.md - Prompt template with context slots

---

### Major Feature: Subagent-Driven Development Overhaul

Comprehensive documentation additions to `subagent-driven-development` skill, making orchestration patterns explicit and production-ready.

**Orchestrator State Machine**

Documented 7 explicit states with transitions:
- INIT → LOADING → DISPATCH → MONITOR → REVIEW → CLOSE → COMPLETE

Each state has defined entry conditions, actions, and exit conditions.

**Wave Orchestration with Native Task Tracking**

Shows how to use Claude Code's TaskCreate tool to track orchestrator state:
- Conflict check task
- Wave tasks with blocked dependencies
- Implementation and review sub-tasks
- Wave summary tasks

**Background Execution with Polling**

Documents the `run_in_background: true` pattern for true parallelism:
- Dispatch multiple implementations simultaneously
- Poll with TaskOutput for completion
- Immediately dispatch reviews as implementations finish
- Better throughput than sequential dispatch

**Budget Tier Selection**

Model selection matrix based on Claude Code subscription tier:

| Role | max-20x | max-5x | pro/api |
|------|---------|--------|---------|
| Orchestrator | opus | opus | sonnet |
| Implementer | opus | sonnet | haiku |
| Reviewer | opus | sonnet | sonnet |
| Verifier | opus | sonnet | sonnet |

**Dispatch Decision Logic**

Verification tasks route to `epic-verifier` agent instead of generic implementers:
- Detects "verification" or "verify" in task title
- Includes decision function example
- Flow diagram showing routing

**Review Pipeline Parallelism**

Documents parallel review dispatch:
- Spec review + code review can run simultaneously
- Both must pass before task closes
- Reduces latency compared to sequential

**Failure Recovery Patterns**

Documents how to handle common failures:
- Subagent timeout → retry with smaller scope
- Subagent FAIL verdict → orchestrator fixes or re-dispatches
- Conflicting file modifications → manual resolution
- Context exceeded → split task

---

### New: Beads Setup Script

Added `scripts/setup-beads-local.sh` for one-command beads setup with worktree support.

**What it does:**
1. Installs beads via brew/npm/go if not present
2. Initializes beads in stealth mode (`.beads/` stays local)
3. Adds worktree auto-exclude to shell config

**Worktree support features:**
- `bdwt` function - manually add `.beads/` to worktree's local exclude
- `bdwtauto` function - automatically runs on directory change
- Works with both bash and zsh
- Caches last repo root to avoid repeated checks

---

### Other Changes

**plan2beads updates:**
- Now routes Epic Verification tasks to `epic-verifier` agent in dispatch guidance

**Prompt template updates:**
- Added model parameters to implementer/reviewer prompt templates
- Minor clarifications to spec-reviewer and code-quality-reviewer prompts

**Skills updates:**
- beads skill: Added cross-reference to setup script
- writing-plans: Minor documentation fixes

**Cleanup:**
- Removed old design documents from docs/plans/ (2025 files)

### Files Changed (12)

**New Files (4):**
- agents/epic-verifier.md
- skills/epic-verifier/SKILL.md
- skills/epic-verifier/verifier-prompt.md
- scripts/setup-beads-local.sh

**Modified (8):**
- commands/plan2beads.md (+155 lines across multiple commits)
- skills/subagent-driven-development/SKILL.md (+359 lines)
- skills/subagent-driven-development/implementer-prompt.md
- skills/subagent-driven-development/spec-reviewer-prompt.md
- skills/subagent-driven-development/code-quality-reviewer-prompt.md
- skills/beads/SKILL.md
- skills/writing-plans/SKILL.md
- README.md (beads setup instructions)

---

## v4.0.11 (2026-01-28) - Beads Fork

### Simplify: Single Epic Verification Task with Explicit Checklist

Replaced the 4-task verification chain with a single "Epic Verification" task containing an explicit step-by-step checklist.

**Problem:** Despite v4.0.9-v4.0.10 adding a 4-task verification chain with "CRITICAL" callouts, agents still skipped creating the verification tasks when the plan already had a "Final Verification" task. More documentation didn't prevent rationalization.

**Solution:** Mirror the planning phase pattern. During planning, the Plan Verification Checklist works because it's explicit—the agent sees checkboxes and fills them in. Apply the same pattern to epic completion.

**Changes:**
- Replaced 4 verification tasks (rule-of-five, code review, spec verification, gate) with ONE task
- New task has explicit step-by-step checklist with checkboxes:
  1. Review cumulative changes (`git diff main...HEAD --stat`)
  2. Automated checks (tests, build, typecheck)
  3. Rule-of-five on files with >50 lines changed
  4. Engineering checklist (Complete, YAGNI, Minimal, No drift, Key Decisions)
  5. Final confirmation
- Updated Step 6 summary to reflect simplified structure

**Why this is better:**
- Same pattern as planning (explicit checklist works there)
- Agent sees exactly what to do, not vague "apply rule-of-five to artifacts"
- Single task is simpler than 4-task chain
- Checklist items are concrete: "Run `git diff main...HEAD --stat`" vs "Execute /rule-of-five"

**Files Changed (1):**
- commands/plan2beads.md (section 4f rewritten, Step 6 updated)

---

## v4.0.10 (2026-01-27) - Beads Fork

### Fix: Verification Chain Always Required

Fixed issue where `plan2beads` would skip creating the verification task chain if the plan already included a verification task (e.g., "Task 10: Verify Build and Tests").

**Root cause:** The verification chain creation logic didn't distinguish between:
- **Engineering verification** (typecheck, tests, build) — what plans often include
- **Process verification** (rule-of-five, code review, spec compliance) — what plan2beads should add

**Changes:**
- Added CRITICAL callout: verification chain must be added REGARDLESS of plan content
- Renamed "Plan Verification Checklist" → "Spec Verification" for clarity
- Added engineering verification checklist with 7 checks:
  - Complete — all requirements addressed
  - Accurate — file paths/commands match plan
  - YAGNI — no extra features added
  - Minimal — simplest solution
  - Not over-engineered — no unnecessary abstractions
  - Key Decisions followed — matches plan's decisions
  - No drift — didn't stray without documenting why
- Updated summary to clarify chain is "ALWAYS added, not from plan"

**Files Changed (1):**
- commands/plan2beads.md (+22 lines)

## v4.0.9 (2026-01-27) - Beads Fork

### Feature: Epic Verification Enforcement

Ensures epic completion verification steps (rule-of-five, code-review, plan verification checklist) are structurally enforced via beads dependencies, not just documented as text.

**Key Decisions:**
- **Separate verification issues over text criteria:** Beads dependencies provide structural sequencing; text criteria are easily skipped
- **Verifiable acceptance criteria over procedural instructions:** "Invoke /rule-of-five" is unverifiable; "Show TaskList with 5 completed passes" is verifiable
- **Two-layer enforcement:** Beads dependencies for sequencing + spec reviewer for verification within each issue
- **Defensive check in finishing-a-development-branch:** Catches legacy epics that predate this change

**plan2beads: 4 Verification Tasks**

Instead of a single "Verification Gate" task with text acceptance criteria, `plan2beads` now creates 4 verification tasks with explicit dependencies:

1. **Rule-of-Five (N+1)** — blocked by all implementation tasks
2. **Code Review (N+2)** — blocked by rule-of-five
3. **Plan Verification (N+3)** — blocked by code review
4. **Verification Gate (N+4)** — blocked by plan verification

Each task has:
- `## Required evidence for spec reviewer` section with specific verification criteria
- Explicit acceptance criteria the spec reviewer can objectively check
- Dependencies that enforce correct execution order

**finishing-a-development-branch: Legacy Epic Check**

Added Step 0 that checks for verification tasks before proceeding:
- **Verification tasks not closed** → STOP, list open tasks
- **No verification tasks (legacy epic)** → WARNING, proceed with caution
- **All verification tasks closed** → Proceed to Step 1

**subagent-driven-development: Updated Flow**

- Removed redundant "Final code review" node from flow diagram (now handled as verification task)
- Added `## Verification Tasks` section documenting that verification tasks flow through the same dispatch loop
- Includes example showing rule-of-five task dispatch/review cycle

### Files Changed (3)

**Commands (1):**
- commands/plan2beads.md (+98 lines across 3 commits)

**Skills (2):**
- skills/finishing-a-development-branch/SKILL.md (+44 lines)
- skills/subagent-driven-development/SKILL.md (+57 lines across 4 commits)

## v4.0.8 (2026-01-26) - Beads Fork

### Feature: Enhanced Context Preservation

Three improvements to preserve architectural context across the planning-to-execution workflow.

**Key Decisions in Plan Headers**

Plans now require a `## Key Decisions` section in the header template, documenting 3-5 architectural decisions with rationale. This ensures implementers understand WHY choices were made, not just WHAT to build.

- `writing-plans`: Added Key Decisions section to header template with guidance
- `plan2beads`: Copies Key Decisions to TOP of epic description for visibility via `bd show`
- Backward compatible: older plans without Key Decisions still convert with a warning

**Task-Level Context Sections**

Task templates now support optional but recommended context sections:
- `Purpose:` — Why this task exists (1 sentence)
- `Not In Scope:` — What this task should NOT do (prevents overbuilding)
- `Gotchas:` — Known issues or quirks discovered during planning

These are RECOMMENDED, not required, to avoid boilerplate when context is obvious.

**Cross-Wave Summary Comments**

`subagent-driven-development` now includes guidance to post wave summary comments after each wave completes:

```bash
bd comments add <epic-id> "Wave N complete:
- Closed: hub-abc.1, hub-abc.2
- Conventions established: [patterns, naming, style choices]
- Notes for future waves: [anything Wave N+1 should know]"
```

This propagates implementation conventions from earlier waves to later waves, preventing inconsistency across parallel subagents.

**Verification Checklist Updates**

Plan Verification Checklist now includes:
- `Key Decisions documented` — Are 3-5 key decisions captured with rationale?
- `Context sections present` — Do non-obvious tasks have Purpose? Scope-boundary tasks have Not In Scope?

### Files Changed (3)

**Skills (2):**
- skills/writing-plans/SKILL.md (+35 lines across 3 commits)
- skills/subagent-driven-development/SKILL.md (+34 lines)

**Commands (1):**
- commands/plan2beads.md (+11 lines)

## v4.0.7 (2026-01-23) - Beads Fork

### Major Feature: Native Task Tool Integration

Integrated Claude Code's native task tools (TaskCreate, TaskGet, TaskUpdate, TaskList) as a complementary layer to beads for fine-grained quality gate enforcement.

**Key insight:** Beads tracks WHAT work to do (features/tasks, 1-4 hours). Native tasks track HOW progress is made within those items (quality gates, 5-30 min).

**12 skills + 1 command now enforce quality gates with task dependencies:**

| Skill/Command | Tasks | Purpose |
|-------|-------|---------|
| systematic-debugging | 4 phase tasks | Enforce "NO FIXES BEFORE PHASE 1" iron law |
| writing-skills | 3 RED/GREEN/REFACTOR tasks | Enforce "NO SKILL WITHOUT FAILING TEST" |
| rule-of-five | 5 sequential pass tasks | Enforce all 5 passes with dependencies |
| receiving-code-review | 5 response tasks | VERIFY step blocks IMPLEMENT |
| verification-before-completion | 1 evidence task | Cannot claim done without verification |
| writing-plans | 7 tasks | Plan checklist + rule-of-five enforcement |
| finishing-a-development-branch | 4 tasks | Test verification gate before merge |
| plan2beads | 5 conversion tasks | Track multi-step conversion process |
| executing-plans | 3 batch tasks | Checkpoint + feedback between batches |
| subagent-driven-development | 3 wave tasks | File conflict verification |
| test-driven-development | 3 per-feature tasks | RED/GREEN/REFACTOR enforcement |
| using-git-worktrees | 6 setup tasks | Verification steps tracked |

**Pattern:** Each skill creates tasks with `addBlockedBy` dependencies. Skipping phases becomes visible in TaskList, and blocked tasks cannot be marked in_progress.

**Documentation:**
- Added "Native Task Integration" section to using-superpowers skill
- Documented task ID capture pattern for dependencies
- Listed all skills using this pattern with task counts

**Platform support:**
- OpenCode: TaskCreate/TaskUpdate/TaskList/TaskGet → `update_plan`
- Codex: TaskCreate/TaskUpdate/TaskList/TaskGet → `update_plan`

**Test updates:**
- Tests now accept both TaskCreate and legacy TodoWrite patterns
- Explicit skill request tests filter task tool calls

### Files Changed (23 total)

**Skills (12):**
- skills/systematic-debugging/SKILL.md
- skills/writing-skills/SKILL.md
- skills/rule-of-five/SKILL.md
- skills/receiving-code-review/SKILL.md
- skills/verification-before-completion/SKILL.md
- skills/writing-plans/SKILL.md
- skills/finishing-a-development-branch/SKILL.md
- skills/executing-plans/SKILL.md
- skills/subagent-driven-development/SKILL.md
- skills/test-driven-development/SKILL.md
- skills/using-git-worktrees/SKILL.md
- skills/using-superpowers/SKILL.md

**Commands (1):**
- commands/plan2beads.md

**Supporting files (10):**
- skills/writing-skills/persuasion-principles.md
- tests/claude-code/test-subagent-driven-development-integration.sh
- tests/explicit-skill-requests/run-test.sh
- tests/explicit-skill-requests/run-multiturn-test.sh
- docs/testing.md
- .opencode/plugin/superpowers.js
- .opencode/INSTALL.md
- .codex/superpowers-bootstrap.md
- docs/README.opencode.md
- docs/README.codex.md

## v4.0.6 (2026-01-19) - Beads Fork

### Improvements

**Enhanced plan verification enforcement**

Added enforcement mechanisms to ensure Plan Verification Checklist and rule-of-five are ALWAYS applied during plan writing and at epic completion.

**writing-plans skill:**
- Added "Mandatory Todos (Enforcement)" section - 7 todos created at plan start that must be completed before ExitPlanMode
- Added "Required Announcements" section - structured format for announcing verification phases with audit trail
- Added "Plan Document Footer (Required)" section - every plan must end with a Verification Record documenting checklist results and rule-of-five changes
- Fixed skill reference syntax (changed @ syntax to backtick format per writing-skills guidelines)

**plan2beads command:**
- Added "4f. Verification Gate Task (Required)" - every epic now gets a final gate task that depends on ALL other tasks
- Gate acceptance criteria enforces: tests pass, build succeeds, no TypeScript errors, invoke /rule-of-five, invoke /requesting-code-review, re-run Plan Verification Checklist, update docs
- Updated Step 6 results display to include gate task and completion workflow

**Why this matters:** Previously, verification was marked "REQUIRED" but nothing enforced it. Now:
1. TodoWrite tracks verification during planning (visible, can't skip)
2. Plan document embeds verification record (audit trail)
3. Gate task blocks epic completion until verification done

**New: beads skill**

Comprehensive reference for AI agents using the beads (bd) CLI:
- Permission avoidance rules (semicolons, multi-line content, temp files)
- Command quick reference (issue operations, queries, maintenance)
- Dependency management (types, validation, deadlock detection)
- Workflow patterns (autonomous work loop, session end protocol)
- Troubleshooting (sync, worktrees, daemon issues)

Cross-references added to:
- `plan2beads` - REQUIRED BACKGROUND
- `executing-plans` - REQUIRED BACKGROUND
- `subagent-driven-development` - REQUIRED BACKGROUND

## v4.0.5 (2026-01-19) - Beads Fork

### Fixes

**Fixed plan2beads acceptance criteria guidance**

The `--acceptance` flag documentation incorrectly recommended using semicolons as delimiters. Semicolons with surrounding spaces (` ; `) trigger Claude Code's permission system deny rules, causing approval prompts even when the semicolon is inside a quoted string argument.

**Corrected guidance:**
- Never use semicolons in `--acceptance`
- Use commas: `--acceptance "Criterion 1, Criterion 2, Criterion 3"`
- Or use ANSI-C quoting with newlines: `--acceptance $'Criterion 1\nCriterion 2\nCriterion 3'`

The newline syntax displays better in `bd show` output, with each criterion on its own line.

**Root cause:** Claude Code's permission pattern matching operates on the raw command string before shell parsing, so quoted semicolons still match the ` ; ` deny pattern.

## v4.0.4 (2026-01-18) - Beads Fork

### Fork Changes

This version represents the initial beads-integrated fork with customizations for persistent issue tracking and dependency-aware execution.

**New: rule-of-five skill**

5-pass quality review for significant artifacts (>50 lines):
1. Draft - Get it working
2. Correctness - Verify logic and edge cases
3. Clarity - Improve readability
4. Edge Cases - Handle failures gracefully
5. Excellence - Polish for production

**New: plan2beads command**

Converts markdown implementation plans to beads epics with proper dependencies. Parses `Depends on:` and `Files:` sections from plan tasks.

**Beads integration across skills**

- `writing-plans` - Tasks include `Depends on:` and `Files:` sections for dependency tracking
- `executing-plans` - Uses `bd ready`, `bd blocked`, `bd close` for dependency-aware batch execution
- `subagent-driven-development` - Wave-based parallel dispatch with file conflict detection

**Rule-of-five as required gate**

`executing-plans` now requires rule-of-five review before any commit with >50 lines changed. Not optional.

**Metadata updates**

- Repository references updated to `schlenks/superpowers-bd` fork
- README updated with Beads Customizations section

## v4.0.3 (2025-12-26)

### Improvements

**Strengthened using-superpowers skill for explicit skill requests**

Addressed a failure mode where Claude would skip invoking a skill even when the user explicitly requested it by name (e.g., "subagent-driven-development, please"). Claude would think "I know what that means" and start working directly instead of loading the skill.

Changes:
- Updated "The Rule" to say "Invoke relevant or requested skills" instead of "Check for skills" - emphasizing active invocation over passive checking
- Added "BEFORE any response or action" - the original wording only mentioned "response" but Claude would sometimes take action without responding first
- Added reassurance that invoking a wrong skill is okay - reduces hesitation
- Added new red flag: "I know what that means" → Knowing the concept ≠ using the skill

**Added explicit skill request tests**

New test suite in `tests/explicit-skill-requests/` that verifies Claude correctly invokes skills when users request them by name. Includes single-turn and multi-turn test scenarios.

## v4.0.2 (2025-12-23)

### Fixes

**Slash commands now user-only**

Added `disable-model-invocation: true` to all three slash commands (`/brainstorm`, `/execute-plan`, `/write-plan`). Claude can no longer invoke these commands via the Skill tool—they're restricted to manual user invocation only.

The underlying skills (`superpowers:brainstorming`, `superpowers:executing-plans`, `superpowers:writing-plans`) remain available for Claude to invoke autonomously. This change prevents confusion when Claude would invoke a command that just redirects to a skill anyway.

## v4.0.1 (2025-12-23)

### Fixes

**Clarified how to access skills in Claude Code**

Fixed a confusing pattern where Claude would invoke a skill via the Skill tool, then try to Read the skill file separately. The `using-superpowers` skill now explicitly states that the Skill tool loads skill content directly—no need to read files.

- Added "How to Access Skills" section to `using-superpowers`
- Changed "read the skill" → "invoke the skill" in instructions
- Updated slash commands to use fully qualified skill names (e.g., `superpowers:brainstorming`)

**Added GitHub thread reply guidance to receiving-code-review** (h/t @ralphbean)

Added a note about replying to inline review comments in the original thread rather than as top-level PR comments.

**Added automation-over-documentation guidance to writing-skills** (h/t @EthanJStark)

Added guidance that mechanical constraints should be automated, not documented—save skills for judgment calls.

## v4.0.0 (2025-12-17)

### New Features

**Two-stage code review in subagent-driven-development**

Subagent workflows now use two separate review stages after each task:

1. **Spec compliance review** - Skeptical reviewer verifies implementation matches spec exactly. Catches missing requirements AND over-building. Won't trust implementer's report—reads actual code.

2. **Code quality review** - Only runs after spec compliance passes. Reviews for clean code, test coverage, maintainability.

This catches the common failure mode where code is well-written but doesn't match what was requested. Reviews are loops, not one-shot: if reviewer finds issues, implementer fixes them, then reviewer checks again.

Other subagent workflow improvements:
- Controller provides full task text to workers (not file references)
- Workers can ask clarifying questions before AND during work
- Self-review checklist before reporting completion
- Plan read once at start, extracted to TodoWrite

New prompt templates in `skills/subagent-driven-development/`:
- `implementer-prompt.md` - Includes self-review checklist, encourages questions
- `spec-reviewer-prompt.md` - Skeptical verification against requirements
- `code-quality-reviewer-prompt.md` - Standard code review

**Debugging techniques consolidated with tools**

`systematic-debugging` now bundles supporting techniques and tools:
- `root-cause-tracing.md` - Trace bugs backward through call stack
- `defense-in-depth.md` - Add validation at multiple layers
- `condition-based-waiting.md` - Replace arbitrary timeouts with condition polling
- `find-polluter.sh` - Bisection script to find which test creates pollution
- `condition-based-waiting-example.ts` - Complete implementation from real debugging session

**Testing anti-patterns reference**

`test-driven-development` now includes `testing-anti-patterns.md` covering:
- Testing mock behavior instead of real behavior
- Adding test-only methods to production classes
- Mocking without understanding dependencies
- Incomplete mocks that hide structural assumptions

**Skill test infrastructure**

Three new test frameworks for validating skill behavior:

`tests/skill-triggering/` - Validates skills trigger from naive prompts without explicit naming. Tests 6 skills to ensure descriptions alone are sufficient.

`tests/claude-code/` - Integration tests using `claude -p` for headless testing. Verifies skill usage via session transcript (JSONL) analysis. Includes `analyze-token-usage.py` for cost tracking.

`tests/subagent-driven-dev/` - End-to-end workflow validation with two complete test projects:
- `go-fractals/` - CLI tool with Sierpinski/Mandelbrot (10 tasks)
- `svelte-todo/` - CRUD app with localStorage and Playwright (12 tasks)

### Major Changes

**DOT flowcharts as executable specifications**

Rewrote key skills using DOT/GraphViz flowcharts as the authoritative process definition. Prose becomes supporting content.

**The Description Trap** (documented in `writing-skills`): Discovered that skill descriptions override flowchart content when descriptions contain workflow summaries. Claude follows the short description instead of reading the detailed flowchart. Fix: descriptions must be trigger-only ("Use when X") with no process details.

**Skill priority in using-superpowers**

When multiple skills apply, process skills (brainstorming, debugging) now explicitly come before implementation skills. "Build X" triggers brainstorming first, then domain skills.

**brainstorming trigger strengthened**

Description changed to imperative: "You MUST use this before any creative work—creating features, building components, adding functionality, or modifying behavior."

### Breaking Changes

**Skill consolidation** - Six standalone skills merged:
- `root-cause-tracing`, `defense-in-depth`, `condition-based-waiting` → bundled in `systematic-debugging/`
- `testing-skills-with-subagents` → bundled in `writing-skills/`
- `testing-anti-patterns` → bundled in `test-driven-development/`
- `sharing-skills` removed (obsolete)

### Other Improvements

- **render-graphs.js** - Tool to extract DOT diagrams from skills and render to SVG
- **Rationalizations table** in using-superpowers - Scannable format including new entries: "I need more context first", "Let me explore first", "This feels productive"
- **docs/testing.md** - Guide to testing skills with Claude Code integration tests

---

## v3.6.2 (2025-12-03)

### Fixed

- **Linux Compatibility**: Fixed polyglot hook wrapper (`run-hook.cmd`) to use POSIX-compliant syntax
  - Replaced bash-specific `${BASH_SOURCE[0]:-$0}` with standard `$0` on line 16
  - Resolves "Bad substitution" error on Ubuntu/Debian systems where `/bin/sh` is dash
  - Fixes #141

---

## v3.5.1 (2025-11-24)

### Changed

- **OpenCode Bootstrap Refactor**: Switched from `chat.message` hook to `session.created` event for bootstrap injection
  - Bootstrap now injects at session creation via `session.prompt()` with `noReply: true`
  - Explicitly tells the model that using-superpowers is already loaded to prevent redundant skill loading
  - Consolidated bootstrap content generation into shared `getBootstrapContent()` helper
  - Cleaner single-implementation approach (removed fallback pattern)

---

## v3.5.0 (2025-11-23)

### Added

- **OpenCode Support**: Native JavaScript plugin for OpenCode.ai
  - Custom tools: `use_skill` and `find_skills`
  - Message insertion pattern for skill persistence across context compaction
  - Automatic context injection via chat.message hook
  - Auto re-injection on session.compacted events
  - Three-tier skill priority: project > personal > superpowers
  - Project-local skills support (`.opencode/skills/`)
  - Shared core module (`lib/skills-core.js`) for code reuse with Codex
  - Automated test suite with proper isolation (`tests/opencode/`)
  - Platform-specific documentation (`docs/README.opencode.md`, `docs/README.codex.md`)

### Changed

- **Refactored Codex Implementation**: Now uses shared `lib/skills-core.js` ES module
  - Eliminates code duplication between Codex and OpenCode
  - Single source of truth for skill discovery and parsing
  - Codex successfully loads ES modules via Node.js interop

- **Improved Documentation**: Rewrote README to explain problem/solution clearly
  - Removed duplicate sections and conflicting information
  - Added complete workflow description (brainstorm → plan → execute → finish)
  - Simplified platform installation instructions
  - Emphasized skill-checking protocol over automatic activation claims

---

## v3.4.1 (2025-10-31)

### Improvements

- Optimized superpowers bootstrap to eliminate redundant skill execution. The `using-superpowers` skill content is now provided directly in session context, with clear guidance to use the Skill tool only for other skills. This reduces overhead and prevents the confusing loop where agents would execute `using-superpowers` manually despite already having the content from session start.

## v3.4.0 (2025-10-30)

### Improvements

- Simplified `brainstorming` skill to return to original conversational vision. Removed heavyweight 6-phase process with formal checklists in favor of natural dialogue: ask questions one at a time, then present design in 200-300 word sections with validation. Keeps documentation and implementation handoff features.

## v3.3.1 (2025-10-28)

### Improvements

- Updated `brainstorming` skill to require autonomous recon before questioning, encourage recommendation-driven decisions, and prevent agents from delegating prioritization back to humans.
- Applied writing clarity improvements to `brainstorming` skill following Strunk's "Elements of Style" principles (omitted needless words, converted negative to positive form, improved parallel construction).

### Bug Fixes

- Clarified `writing-skills` guidance so it points to the correct agent-specific personal skill directories (`~/.claude/skills` for Claude Code, `~/.codex/skills` for Codex).

## v3.3.0 (2025-10-28)

### New Features

**Experimental Codex Support**
- Added unified `superpowers-codex` script with bootstrap/use-skill/find-skills commands
- Cross-platform Node.js implementation (works on Windows, macOS, Linux)
- Namespaced skills: `superpowers:skill-name` for superpowers skills, `skill-name` for personal
- Personal skills override superpowers skills when names match
- Clean skill display: shows name/description without raw frontmatter
- Helpful context: shows supporting files directory for each skill
- Tool mapping for Codex: TodoWrite→update_plan, subagents→manual fallback, etc.
- Bootstrap integration with minimal AGENTS.md for automatic startup
- Complete installation guide and bootstrap instructions specific to Codex

**Key differences from Claude Code integration:**
- Single unified script instead of separate tools
- Tool substitution system for Codex-specific equivalents
- Simplified subagent handling (manual work instead of delegation)
- Updated terminology: "Superpowers skills" instead of "Core skills"

### Files Added
- `.codex/INSTALL.md` - Installation guide for Codex users
- `.codex/superpowers-bootstrap.md` - Bootstrap instructions with Codex adaptations
- `.codex/superpowers-codex` - Unified Node.js executable with all functionality

**Note:** Codex support is experimental. The integration provides core superpowers functionality but may require refinement based on user feedback.

## v3.2.3 (2025-10-23)

### Improvements

**Updated using-superpowers skill to use Skill tool instead of Read tool**
- Changed skill invocation instructions from Read tool to Skill tool
- Updated description: "using Read tool" → "using Skill tool"
- Updated step 3: "Use the Read tool" → "Use the Skill tool to read and run"
- Updated rationalization list: "Read the current version" → "Run the current version"

The Skill tool is the proper mechanism for invoking skills in Claude Code. This update corrects the bootstrap instructions to guide agents toward the correct tool.

### Files Changed
- Updated: `skills/using-superpowers/SKILL.md` - Changed tool references from Read to Skill

## v3.2.2 (2025-10-21)

### Improvements

**Strengthened using-superpowers skill against agent rationalization**
- Added EXTREMELY-IMPORTANT block with absolute language about mandatory skill checking
  - "If even 1% chance a skill applies, you MUST read it"
  - "You do not have a choice. You cannot rationalize your way out."
- Added MANDATORY FIRST RESPONSE PROTOCOL checklist
  - 5-step process agents must complete before any response
  - Explicit "responding without this = failure" consequence
- Added Common Rationalizations section with 8 specific evasion patterns
  - "This is just a simple question" → WRONG
  - "I can check files quickly" → WRONG
  - "Let me gather information first" → WRONG
  - Plus 5 more common patterns observed in agent behavior

These changes address observed agent behavior where they rationalize around skill usage despite clear instructions. The forceful language and pre-emptive counter-arguments aim to make non-compliance harder.

### Files Changed
- Updated: `skills/using-superpowers/SKILL.md` - Added three layers of enforcement to prevent skill-skipping rationalization

## v3.2.1 (2025-10-20)

### New Features

**Code reviewer agent now included in plugin**
- Added `superpowers:code-reviewer` agent to plugin's `agents/` directory
- Agent provides systematic code review against plans and coding standards
- Previously required users to have personal agent configuration
- All skill references updated to use namespaced `superpowers:code-reviewer`
- Fixes #55

### Files Changed
- New: `agents/code-reviewer.md` - Agent definition with review checklist and output format
- Updated: `skills/requesting-code-review/SKILL.md` - References to `superpowers:code-reviewer`
- Updated: `skills/subagent-driven-development/SKILL.md` - References to `superpowers:code-reviewer`

## v3.2.0 (2025-10-18)

### New Features

**Design documentation in brainstorming workflow**
- Added Phase 4: Design Documentation to brainstorming skill
- Design documents now written to `docs/plans/YYYY-MM-DD-<topic>-design.md` before implementation
- Restores functionality from original brainstorming command that was lost during skill conversion
- Documents written before worktree setup and implementation planning
- Tested with subagent to verify compliance under time pressure

### Breaking Changes

**Skill reference namespace standardization**
- All internal skill references now use `superpowers:` namespace prefix
- Updated format: `superpowers:test-driven-development` (previously just `test-driven-development`)
- Affects all REQUIRED SUB-SKILL, RECOMMENDED SUB-SKILL, and REQUIRED BACKGROUND references
- Aligns with how skills are invoked using the Skill tool
- Files updated: brainstorming, executing-plans, subagent-driven-development, systematic-debugging, testing-skills-with-subagents, writing-plans, writing-skills

### Improvements

**Design vs implementation plan naming**
- Design documents use `-design.md` suffix to prevent filename collisions
- Implementation plans continue using existing `YYYY-MM-DD-<feature-name>.md` format
- Both stored in `docs/plans/` directory with clear naming distinction

## v3.1.1 (2025-10-17)

### Bug Fixes

- **Fixed command syntax in README** (#44) - Updated all command references to use correct namespaced syntax (`/superpowers:brainstorm` instead of `/brainstorm`). Plugin-provided commands are automatically namespaced by Claude Code to avoid conflicts between plugins.

## v3.1.0 (2025-10-17)

### Breaking Changes

**Skill names standardized to lowercase**
- All skill frontmatter `name:` fields now use lowercase kebab-case matching directory names
- Examples: `brainstorming`, `test-driven-development`, `using-git-worktrees`
- All skill announcements and cross-references updated to lowercase format
- This ensures consistent naming across directory names, frontmatter, and documentation

### New Features

**Enhanced brainstorming skill**
- Added Quick Reference table showing phases, activities, and tool usage
- Added copyable workflow checklist for tracking progress
- Added decision flowchart for when to revisit earlier phases
- Added comprehensive AskUserQuestion tool guidance with concrete examples
- Added "Question Patterns" section explaining when to use structured vs open-ended questions
- Restructured Key Principles as scannable table

**Anthropic best practices integration**
- Added `skills/writing-skills/anthropic-best-practices.md` - Official Anthropic skill authoring guide
- Referenced in writing-skills SKILL.md for comprehensive guidance
- Provides patterns for progressive disclosure, workflows, and evaluation

### Improvements

**Skill cross-reference clarity**
- All skill references now use explicit requirement markers:
  - `**REQUIRED BACKGROUND:**` - Prerequisites you must understand
  - `**REQUIRED SUB-SKILL:**` - Skills that must be used in workflow
  - `**Complementary skills:**` - Optional but helpful related skills
- Removed old path format (`skills/collaboration/X` → just `X`)
- Updated Integration sections with categorized relationships (Required vs Complementary)
- Updated cross-reference documentation with best practices

**Alignment with Anthropic best practices**
- Fixed description grammar and voice (fully third-person)
- Added Quick Reference tables for scanning
- Added workflow checklists Claude can copy and track
- Appropriate use of flowcharts for non-obvious decision points
- Improved scannable table formats
- All skills well under 500-line recommendation

### Bug Fixes

- **Re-added missing command redirects** - Restored `commands/brainstorm.md` and `commands/write-plan.md` that were accidentally removed in v3.0 migration
- Fixed `defense-in-depth` name mismatch (was `Defense-in-Depth-Validation`)
- Fixed `receiving-code-review` name mismatch (was `Code-Review-Reception`)
- Fixed `commands/brainstorm.md` reference to correct skill name
- Removed references to non-existent related skills

### Documentation

**writing-skills improvements**
- Updated cross-referencing guidance with explicit requirement markers
- Added reference to Anthropic's official best practices
- Improved examples showing proper skill reference format

## v3.0.1 (2025-10-16)

### Changes

We now use Anthropic's first-party skills system!

## v2.0.2 (2025-10-12)

### Bug Fixes

- **Fixed false warning when local skills repo is ahead of upstream** - The initialization script was incorrectly warning "New skills available from upstream" when the local repository had commits ahead of upstream. The logic now correctly distinguishes between three git states: local behind (should update), local ahead (no warning), and diverged (should warn).

## v2.0.1 (2025-10-12)

### Bug Fixes

- **Fixed session-start hook execution in plugin context** (#8, PR #9) - The hook was failing silently with "Plugin hook error" preventing skills context from loading. Fixed by:
  - Using `${BASH_SOURCE[0]:-$0}` fallback when BASH_SOURCE is unbound in Claude Code's execution context
  - Adding `|| true` to handle empty grep results gracefully when filtering status flags

---

# Superpowers v2.0.0 Release Notes

## Overview

Superpowers v2.0 makes skills more accessible, maintainable, and community-driven through a major architectural shift.

The headline change is **skills repository separation**: all skills, scripts, and documentation have moved from the plugin into a dedicated repository ([obra/superpowers-skills](https://github.com/obra/superpowers-skills)). This transforms superpowers from a monolithic plugin into a lightweight shim that manages a local clone of the skills repository. Skills auto-update on session start. Users fork and contribute improvements via standard git workflows. The skills library versions independently from the plugin.

Beyond infrastructure, this release adds nine new skills focused on problem-solving, research, and architecture. We rewrote the core **using-skills** documentation with imperative tone and clearer structure, making it easier for Claude to understand when and how to use skills. **find-skills** now outputs paths you can paste directly into the Read tool, eliminating friction in the skills discovery workflow.

Users experience seamless operation: the plugin handles cloning, forking, and updating automatically. Contributors find the new architecture makes improving and sharing skills trivial. This release lays the foundation for skills to evolve rapidly as a community resource.

## Breaking Changes

### Skills Repository Separation

**The biggest change:** Skills no longer live in the plugin. They've been moved to a separate repository at [obra/superpowers-skills](https://github.com/obra/superpowers-skills).

**What this means for you:**

- **First install:** Plugin automatically clones skills to `~/.config/superpowers/skills/`
- **Forking:** During setup, you'll be offered the option to fork the skills repo (if `gh` is installed)
- **Updates:** Skills auto-update on session start (fast-forward when possible)
- **Contributing:** Work on branches, commit locally, submit PRs to upstream
- **No more shadowing:** Old two-tier system (personal/core) replaced with single-repo branch workflow

**Migration:**

If you have an existing installation:
1. Your old `~/.config/superpowers/.git` will be backed up to `~/.config/superpowers/.git.bak`
2. Old skills will be backed up to `~/.config/superpowers/skills.bak`
3. Fresh clone of obra/superpowers-skills will be created at `~/.config/superpowers/skills/`

### Removed Features

- **Personal superpowers overlay system** - Replaced with git branch workflow
- **setup-personal-superpowers hook** - Replaced by initialize-skills.sh

## New Features

### Skills Repository Infrastructure

**Automatic Clone & Setup** (`lib/initialize-skills.sh`)
- Clones obra/superpowers-skills on first run
- Offers fork creation if GitHub CLI is installed
- Sets up upstream/origin remotes correctly
- Handles migration from old installation

**Auto-Update**
- Fetches from tracking remote on every session start
- Auto-merges with fast-forward when possible
- Notifies when manual sync needed (branch diverged)
- Uses pulling-updates-from-skills-repository skill for manual sync

### New Skills

**Problem-Solving Skills** (`skills/problem-solving/`)
- **collision-zone-thinking** - Force unrelated concepts together for emergent insights
- **inversion-exercise** - Flip assumptions to reveal hidden constraints
- **meta-pattern-recognition** - Spot universal principles across domains
- **scale-game** - Test at extremes to expose fundamental truths
- **simplification-cascades** - Find insights that eliminate multiple components
- **when-stuck** - Dispatch to right problem-solving technique

**Research Skills** (`skills/research/`)
- **tracing-knowledge-lineages** - Understand how ideas evolved over time

**Architecture Skills** (`skills/architecture/`)
- **preserving-productive-tensions** - Keep multiple valid approaches instead of forcing premature resolution

### Skills Improvements

**using-skills (formerly getting-started)**
- Renamed from getting-started to using-skills
- Complete rewrite with imperative tone (v4.0.0)
- Front-loaded critical rules
- Added "Why" explanations for all workflows
- Always includes /SKILL.md suffix in references
- Clearer distinction between rigid rules and flexible patterns

**writing-skills**
- Cross-referencing guidance moved from using-skills
- Added token efficiency section (word count targets)
- Improved CSO (Claude Search Optimization) guidance

**sharing-skills**
- Updated for new branch-and-PR workflow (v2.0.0)
- Removed personal/core split references

**pulling-updates-from-skills-repository** (new)
- Complete workflow for syncing with upstream
- Replaces old "updating-skills" skill

### Tools Improvements

**find-skills**
- Now outputs full paths with /SKILL.md suffix
- Makes paths directly usable with Read tool
- Updated help text

**skill-run**
- Moved from scripts/ to skills/using-skills/
- Improved documentation

### Plugin Infrastructure

**Session Start Hook**
- Now loads from skills repository location
- Shows full skills list at session start
- Prints skills location info
- Shows update status (updated successfully / behind upstream)
- Moved "skills behind" warning to end of output

**Environment Variables**
- `SUPERPOWERS_SKILLS_ROOT` set to `~/.config/superpowers/skills`
- Used consistently throughout all paths

## Bug Fixes

- Fixed duplicate upstream remote addition when forking
- Fixed find-skills double "skills/" prefix in output
- Removed obsolete setup-personal-superpowers call from session-start
- Fixed path references throughout hooks and commands

## Documentation

### README
- Updated for new skills repository architecture
- Prominent link to superpowers-skills repo
- Updated auto-update description
- Fixed skill names and references
- Updated Meta skills list

### Testing Documentation
- Added comprehensive testing checklist (`docs/TESTING-CHECKLIST.md`)
- Created local marketplace config for testing
- Documented manual testing scenarios

## Technical Details

### File Changes

**Added:**
- `lib/initialize-skills.sh` - Skills repo initialization and auto-update
- `docs/TESTING-CHECKLIST.md` - Manual testing scenarios
- `.claude-plugin/marketplace.json` - Local testing config

**Removed:**
- `skills/` directory (82 files) - Now in obra/superpowers-skills
- `scripts/` directory - Now in obra/superpowers-skills/skills/using-skills/
- `hooks/setup-personal-superpowers.sh` - Obsolete

**Modified:**
- `hooks/session-start.sh` - Use skills from ~/.config/superpowers/skills
- `commands/brainstorm.md` - Updated paths to SUPERPOWERS_SKILLS_ROOT
- `commands/write-plan.md` - Updated paths to SUPERPOWERS_SKILLS_ROOT
- `commands/execute-plan.md` - Updated paths to SUPERPOWERS_SKILLS_ROOT
- `README.md` - Complete rewrite for new architecture

### Commit History

This release includes:
- 20+ commits for skills repository separation
- PR #1: Amplifier-inspired problem-solving and research skills
- PR #2: Personal superpowers overlay system (later replaced)
- Multiple skill refinements and documentation improvements

## Upgrade Instructions

### Fresh Install

```bash
# In Claude Code
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

The plugin handles everything automatically.

### Upgrading from v1.x

1. **Backup your personal skills** (if you have any):
   ```bash
   cp -r ~/.config/superpowers/skills ~/superpowers-skills-backup
   ```

2. **Update the plugin:**
   ```bash
   /plugin update superpowers
   ```

3. **On next session start:**
   - Old installation will be backed up automatically
   - Fresh skills repo will be cloned
   - If you have GitHub CLI, you'll be offered the option to fork

4. **Migrate personal skills** (if you had any):
   - Create a branch in your local skills repo
   - Copy your personal skills from backup
   - Commit and push to your fork
   - Consider contributing back via PR

## What's Next

### For Users

- Explore the new problem-solving skills
- Try the branch-based workflow for skill improvements
- Contribute skills back to the community

### For Contributors

- Skills repository is now at https://github.com/obra/superpowers-skills
- Fork → Branch → PR workflow
- See skills/meta/writing-skills/SKILL.md for TDD approach to documentation

## Known Issues

None at this time.

## Credits

- Problem-solving skills inspired by Amplifier patterns
- Community contributions and feedback
- Extensive testing and iteration on skill effectiveness

---

**Full Changelog:** https://github.com/obra/superpowers/compare/dd013f6...main
**Skills Repository:** https://github.com/obra/superpowers-skills
**Issues:** https://github.com/obra/superpowers/issues
