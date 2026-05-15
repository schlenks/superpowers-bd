# Claude Code and Codex Parity Implementation Plan

> **For Claude Code and Codex:** After human approval, use `plan2beads` to convert this plan to a beads epic, then execute it with the platform-appropriate orchestration workflow.

**Goal:** Make Superpowers-BD a first-class plugin for both Claude Code and Codex, with neither platform treated as primary or as a compatibility shim.
**Architecture:** Keep workflow methodology shared where it is genuinely platform-neutral, then add native platform layers for Claude Code and Codex. Each platform gets its own packaging, agents, hooks, tests, and user-facing docs that use that platform's native terminology.
**Tech Stack:** Markdown skills and plans, Claude Code plugin manifest and YAML agents, Codex plugin manifest and TOML agents, shell hooks, Node-based fallback skill loader, beads issue tracking, existing shell test harnesses.
**Key Decisions:**
- **Equal native surfaces:** Claude Code and Codex both get first-class plugin layers; shared docs may describe both, but runtime instructions should not make one a mapping of the other.
- **Shared methodology, platform adapters:** Core workflows such as TDD, debugging, review, beads semantics, and rule-of-five stay shared. Tool invocation, agents, hooks, and model routing diverge by platform.
- **Codex agents are TOML, not Claude agent markdown:** Current Codex docs define custom agents under `.codex/agents/*.toml` for project scope or `~/.codex/agents/*.toml` for personal scope. Claude agents remain in `agents/*.md` and `.claude/agents/`.
- **Hooks are platform-specific:** Reuse shell scripts when possible, but hook event wiring must be separate for Claude Code and Codex because event sets and trust behavior differ.
- **Parity means comparable outcomes, not identical files:** Tests should prove both platforms expose the same workflows and quality gates, even when the implementation mechanics differ.
---

## Current Evidence

Official platform docs checked on 2026-05-15:
- OpenAI Codex skills: https://developers.openai.com/codex/skills
- OpenAI Codex plugin build docs: https://developers.openai.com/codex/plugins/build
- OpenAI Codex hooks: https://developers.openai.com/codex/hooks
- OpenAI Codex subagents: https://developers.openai.com/codex/subagents
- Claude Code skills: https://code.claude.com/docs/en/skills
- Claude Code subagents: https://code.claude.com/docs/en/sub-agents
- Claude Code hooks: https://code.claude.com/docs/en/hooks

Repository evidence:
- Codex plugin manifest exists at `.codex-plugin/plugin.json`, but it only points to `skills`.
- Codex local marketplace wrapper exists under `.agents/plugins/marketplace.json` and `plugins/superpowers-bd/`.
- Codex metadata exists only for four skills via `skills/*/agents/openai.yaml`.
- No `.codex/agents/` directory exists.
- No `.codex/hooks.json` or Codex hook manifest entry exists.
- Claude Code agent definitions exist at `agents/code-reviewer.md` and `agents/epic-verifier.md`.
- Claude Code hook wiring exists at `hooks/hooks.json` with Claude-specific events and `${CLAUDE_PLUGIN_ROOT}`.
- Existing Codex tests verify packaging and fallback loading, not semantic workflow execution.
- Existing Claude Code tests verify subagent-driven workflows and hook behavior more deeply.

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `docs/plans/2026-05-15-claude-codex-parity-plan.md` | This parity implementation plan | Create |
| `skills/using-superpowers/SKILL.md` | Shared skill-loading policy and platform-neutral routing guidance | Modify |
| `skills/subagent-driven-development/SKILL.md` | Shared SDD workflow with equal Claude Code and Codex paths | Modify |
| `skills/subagent-driven-development/background-execution.md` | Platform-specific dispatch and monitor mechanics for waves | Modify |
| `skills/subagent-driven-development/dispatch-and-conflict.md` | File conflict algorithm plus platform-native agent dispatch examples | Modify |
| `skills/subagent-driven-development/budget-and-wave-cap.md` | Split Claude model tiers from Codex model tiers | Modify |
| `skills/requesting-code-review/code-reviewer.md` | Platform-neutral review methodology | Modify |
| `skills/writing-plans/SKILL.md` | Plan authoring workflow with native Claude Code and Codex verification paths | Modify |
| `skills/writing-plans/references/codex-plan-verification.md` | Codex-native plan verification and rule-of-five-plans flow | Create |
| `skills/executing-plans/SKILL.md` | Plan execution workflow with native progress tracking per platform | Modify |
| `skills/executing-plans/references/codex-execution-checkpoints.md` | Codex-native execution checkpoint workflow | Create |
| `skills/plan2beads/SKILL.md` | Plan-to-beads workflow without Claude-command translation as the Codex path | Modify |
| `skills/plan2beads/references/codex-plan2beads-flow.md` | Codex-native plan-to-beads procedure | Create |
| `skills/ad-hoc-code-review/SKILL.md` | Codex-native and Claude-native ad-hoc review entry guidance | Modify |
| `commands/cr.md` | Claude Code slash command implementation | Modify |
| `skills/ad-hoc-code-review/references/codex-review-flow.md` | Codex-native ad-hoc review workflow | Create |
| `agents/code-reviewer.md` | Claude Code code reviewer agent | Keep, adjust only if parity docs require |
| `agents/epic-verifier.md` | Claude Code epic verifier agent | Keep, adjust only if parity docs require |
| `.codex/agents/code-reviewer.toml` | Codex-native code reviewer agent | Create |
| `.codex/agents/epic-verifier.toml` | Codex-native epic verifier agent | Create |
| `.codex/agents/spec-reviewer.toml` | Codex-native spec compliance reviewer | Create |
| `.codex/agents/review-aggregator.toml` | Codex-native multi-review aggregator | Create |
| `.codex/config.toml` | Project-level Codex agent concurrency and settings | Create |
| `.codex/hooks.json` | Codex project hooks for local development | Create |
| `hooks/codex-session-start.sh` | Codex-specific session/context hook wrapper | Create |
| `hooks/codex-post-tool-use.sh` | Codex-specific post-tool policy wrapper around shared lint/audit scripts | Create |
| `.codex-plugin/plugin.json` | Codex plugin manifest, including hooks when ready | Modify |
| `.claude-plugin/plugin.json` | Claude Code plugin manifest stays first-class | Keep in version lockstep |
| `docs/README.codex.md` | Codex install and usage docs | Modify |
| `README.md` | Platform-neutral top-level overview | Modify |
| `AGENTS.md` | Codex/project agent instructions, remove Claude-only framing where inappropriate | Modify |
| `CLAUDE.md` | Claude Code project instructions | Keep Claude-specific |
| `tests/codex/test-plugin-manifest.sh` | Codex packaging assertions | Modify |
| `tests/codex/test-codex-agents.sh` | Codex custom agent config assertions | Create |
| `tests/codex/test-codex-hooks.sh` | Codex hook config assertions | Create |
| `tests/codex/test-codex-workflow-semantics.sh` | Codex skill prose semantic checks | Create |
| `tests/claude-code/run-skill-tests.sh` | Claude Code regression suite | Keep |
| `tests/verification/test-plugin-config-drift.sh` | Cross-platform drift checks | Modify |

## Parity Gaps

| Area | Claude Code State | Codex State | Gap |
|------|-------------------|-------------|-----|
| Plugin manifest | `.claude-plugin/plugin.json` exists | `.codex-plugin/plugin.json` exists | Versions align, but Codex plugin layer does not yet expose hooks and the repo has no Codex agent layer |
| Skills | All workflows in `skills/` | Same skill files exposed | Shared prose still uses Claude-first Task/TaskCreate language in hot paths |
| Skill metadata | Claude frontmatter includes `effort`, model, hooks support | Codex expects `name`, `description`, optional `agents/openai.yaml` | Metadata is tolerated, not optimized per platform |
| Commands | Claude slash commands in `commands/` | Codex gets wrapper skills for some commands | `/cr`, plan, and execution flows are not fully Codex-native |
| Agents | Claude agents in `agents/*.md` | No `.codex/agents/*.toml` | Major parity gap |
| Hooks | Claude hooks configured and tested | No Codex hook config | Major parity gap |
| SDD model routing | Opus/Sonnet/Haiku tiers | No Codex model tier matrix | Codex orchestration lacks native routing |
| Review pipeline | Claude reviewer and aggregator flow exists | Codex is mostly advisory cross-model review from Claude sessions | Codex should have its own primary reviewer pipeline |
| Tests | Integration tests parse Claude transcripts | Codex tests cover manifests and fallback only | Codex semantic execution is under-tested |
| Docs | Claude-specific docs are mature | Codex docs are install/use oriented | Codex best-practice workflow docs are thin |

## Task 1: Establish Platform Layer Boundaries

**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/using-superpowers/SKILL.md`
- Modify: `docs/README.codex.md`
- Modify: `README.md`
- Modify: `AGENTS.md`

**Purpose:** Define the architecture rule that shared skills contain platform-neutral workflow intent, while each platform has a native execution layer.

**Not In Scope:** Creating Codex agents or hooks yet.

**Gotchas:**
- Do not rewrite Claude Code docs into Codex docs.
- Do not remove Claude-specific features such as `effort:` or scoped hooks where Claude supports them.
- Avoid saying Codex maps to Claude or Claude maps to Codex. Both map from shared workflow intent to native tools.

**Step 1: Update shared policy language**
Replace "Claude Task maps to Codex spawn_agent" style phrasing with a neutral table:
- Shared intent: track progress, delegate work, ask questions, verify completion.
- Claude Code implementation: `TaskCreate`, `Task`, `AskUserQuestion`, `Skill`.
- Codex implementation: `update_plan`, `spawn_agent`, direct question or structured question when available, `$skill`.

**Step 2: Update docs**
Make `README.md` describe Superpowers-BD as a multi-agent-tool plugin with first-class Claude Code, Codex, and OpenCode support. Keep platform-specific install details linked.

**Step 3: Adjust AGENTS.md framing**
`AGENTS.md` currently opens as guidance for Claude Code. Since Codex consumes `AGENTS.md`, either:
- make `AGENTS.md` platform-neutral, with Claude-specific material moved to `CLAUDE.md`, or
- add a top section that explicitly says Codex should use `AGENTS.md` and Claude Code should use `CLAUDE.md`.

**Step 4: Add a skill-boundary rule**
In `using-superpowers`, add a rule that command-backed workflows must provide a native path per platform. The actual planning, execution, and plan-to-beads rewrites happen in Task 4 so file ownership stays clear.

**Verification:**
- `rg -n "Codex.*maps to Claude|Claude.*maps to Codex|Claude Code plugin providing" README.md AGENTS.md docs/README.codex.md skills/using-superpowers/SKILL.md`
- `./tests/verification/test-plugin-config-drift.sh`

## Task 2: Add Codex-Native Agents

**Depends on:** Task 1
**Complexity:** complex
**Files:**
- Create: `.codex/agents/code-reviewer.toml`
- Create: `.codex/agents/epic-verifier.toml`
- Create: `.codex/agents/spec-reviewer.toml`
- Create: `.codex/agents/review-aggregator.toml`
- Create: `.codex/config.toml`
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/ad-hoc-code-review/SKILL.md`
- Create: `tests/codex/test-codex-agents.sh`
- Modify: `tests/codex/run-tests.sh`

**Purpose:** Give Codex its own custom agents using Codex TOML agent definitions instead of relying on Claude agent markdown or generic workers.

**Not In Scope:** Removing Claude agents.

**Gotchas:**
- Codex docs use TOML files under `.codex/agents/` with `name`, `description`, `model`, `model_reasoning_effort`, `sandbox_mode`, and `developer_instructions`.
- Agent names should use Codex-style identifiers such as `code_reviewer`, `epic_verifier`, `spec_reviewer`, and `review_aggregator`.
- Do not reference Claude tools such as `Read`, `Glob`, or `Task` inside Codex agent instructions unless framed generically as "use available file/search tools."

**Step 1: Create Codex code reviewer**
Use the existing methodology from `skills/requesting-code-review/code-reviewer.md`, but encode the role as Codex-native developer instructions:
- read diff and changed files,
- map requirements,
- trace data flow,
- report findings first,
- do not edit code,
- preserve `Not Checked`,
- lead with severity and concrete file references.

**Step 2: Create Codex spec reviewer**
Use SDD spec compliance prompt semantics:
- verify implementation against beads issue requirements,
- do not trust implementer report,
- emit PASS/FAIL with evidence.

**Step 3: Create Codex review aggregator**
Port `skills/multi-review-aggregation/aggregator-prompt.md` to a Codex agent that aggregates provided reviewer reports without beads coupling unless explicitly requested.

**Step 4: Create Codex epic verifier**
Port `skills/epic-verifier/verifier-prompt.md` to Codex-native instructions. Keep read-only by default unless a future task needs fixer behavior.

**Step 5: Configure agent concurrency**
Add `.codex/config.toml` with a conservative agent cap, for example:
```toml
[agents]
max_threads = 6
max_depth = 1
```

**Verification:**
- `test -f .codex/agents/code-reviewer.toml`
- `test -f .codex/agents/epic-verifier.toml`
- `test -f .codex/agents/spec-reviewer.toml`
- `test -f .codex/agents/review-aggregator.toml`
- `tests/codex/test-codex-agents.sh`

## Task 3: Split SDD Into Shared Logic Plus Native Dispatch Paths

**Depends on:** Task 2
**Complexity:** complex
**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/subagent-driven-development/background-execution.md`
- Modify: `skills/subagent-driven-development/dispatch-and-conflict.md`
- Modify: `skills/subagent-driven-development/budget-and-wave-cap.md`
- Modify: `skills/subagent-driven-development/implementer-prompt.md`
- Modify: `skills/subagent-driven-development/spec-reviewer-prompt.md`
- Modify: `skills/subagent-driven-development/code-quality-reviewer-prompt.md`

**Purpose:** Keep SDD as one workflow, but provide native dispatch paths for Claude Code and Codex.

**Not In Scope:** Changing beads issue structure.

**Gotchas:**
- Codex should not be described as a "cross-model review" inside native Codex sessions. It is the orchestrator.
- Claude Code can keep Opus/Sonnet/Haiku routing. Codex needs GPT model and reasoning effort routing.
- The current statement "Detect Codex cross-model review only in Claude sessions" is valid only for Claude sessions and should move into a Claude-specific subsection.

**Step 1: Refactor the SDD Quick Start**
Change the quick start to:
- shared steps: load epic, restore checkpoint, determine ready work, detect conflicts, dispatch wave, review, close, verify epic,
- Claude Code dispatch path,
- Codex dispatch path.

**Step 2: Add Codex model tier table**
Create a Codex model matrix using current available project defaults. Example starting point:
- simple implementer: fast coding model or inherited low/medium effort,
- standard implementer: inherited default or strong coding model,
- complex implementer/reviewer: stronger GPT model with high reasoning effort.

This should be confirmed against the team's actual Codex model policy before execution.

**Step 3: Replace pseudo-Task examples**
For each SDD helper file, include both:
- Claude Code example using `Task` and `run_in_background`,
- Codex example using `spawn_agent` semantics and custom agent names.

**Step 4: Update checkpoint schema**
Checkpoint should store:
- `platform`: `claude-code` or `codex`,
- `platform_agent_plan`: selected native agents and model settings,
- `codex_enabled` only for Claude cross-model advisory review, not native Codex runs.

**Verification:**
- `rg -n "Task tool:|subagent_type|model: \"opus\"|model=\"haiku\"|Claude reviewers|Codex cross-model" skills/subagent-driven-development`
- Manual check that every remaining match is in a platform-specific section.

## Task 4: Build Codex-Native User Entry Workflows

**Depends on:** Task 2
**Complexity:** standard
**Files:**
- Modify: `skills/writing-plans/SKILL.md`
- Create: `skills/writing-plans/references/codex-plan-verification.md`
- Modify: `skills/executing-plans/SKILL.md`
- Create: `skills/executing-plans/references/codex-execution-checkpoints.md`
- Modify: `skills/plan2beads/SKILL.md`
- Create: `skills/plan2beads/references/codex-plan2beads-flow.md`
- Modify: `skills/ad-hoc-code-review/SKILL.md`
- Create: `skills/ad-hoc-code-review/references/codex-review-flow.md`
- Modify: `commands/cr.md`
- Create: `tests/codex/test-codex-workflow-semantics.sh`

**Purpose:** Make command-backed workflows equal peers: Claude Code can use slash commands, while Codex uses native skill references and Codex agents without translation instructions.

**Not In Scope:** Removing the Claude slash command.

**Gotchas:**
- `commands/*.md` should remain Claude Code command implementations unless Codex explicitly supports the same command surface.
- Codex should not have to read a Claude command and mentally translate `AskUserQuestion`, `Task`, `TaskCreate`, `ExitPlanMode`, or Claude tool names.
- The beads semantics are shared; the orchestration and progress tracking instructions are platform-native.
- `skills/plan2beads/references/` and `skills/ad-hoc-code-review/references/` do not exist yet; create parent directories before adding their Codex reference files.

**Step 1: Create Codex planning reference**
Write `codex-plan-verification.md` with Codex-native plan authoring and verification:
1. create or update the plan file directly,
2. use `update_plan` for the live checklist,
3. run the plan verification checklist inline,
4. use Codex-native reviewer agents only when the user has approved agent delegation or the workflow explicitly requires it,
5. append a verification record with concrete evidence.

**Step 2: Create Codex execution checkpoint reference**
Write `codex-execution-checkpoints.md` with Codex-native execution rules:
1. use `bd show`, `bd ready`, and dependencies as the durable source of truth,
2. use `update_plan` for short-lived in-session state,
3. serialize file conflicts,
4. run rule-of-five variants before completion claims,
5. report batch checkpoints without Claude `TaskCreate` blocks.

**Step 3: Create Codex plan2beads reference**
Write `codex-plan2beads-flow.md` with the same beads output contract as `commands/plan2beads.md`, but expressed as Codex actions and shell commands rather than a Claude slash command.

**Step 4: Create Codex review flow reference**
Write `codex-review-flow.md` with Codex-native steps:
1. choose local or PR review,
2. resolve scope,
3. collect requirements,
4. recommend reviewer count,
5. spawn `code_reviewer` agents,
6. spawn `review_aggregator` when needed,
7. present findings,
8. do not auto-fix.

**Step 5: Update skill routing**
Make command-backed skills route by platform:
- Claude Code: use slash commands where they are the native implementation.
- Codex: read the relevant `references/codex-*.md` file and use Codex tools directly.
- Other platforms: use shared methodology with native agents and progress tracking if available.

For `skills/ad-hoc-code-review/SKILL.md` specifically:
- Claude Code: use `/superpowers-bd:cr`.
- Codex: read `references/codex-review-flow.md`.
- Other platforms: use shared review methodology with native agents if available.

**Step 6: Keep methodology shared**
`skills/requesting-code-review/code-reviewer.md` remains the review standard both platform agents implement.

**Verification:**
- `rg -n "AskUserQuestion|Task:|TaskCreate|ExitPlanMode|subagent_type|Claude .* maps|Codex: invoke this skill.*read ../../commands" skills/writing-plans skills/executing-plans skills/plan2beads skills/ad-hoc-code-review`
- `tests/codex/test-codex-workflow-semantics.sh`

## Task 5: Add Codex Hooks Without Weakening Claude Hooks

**Depends on:** Task 1
**Complexity:** complex
**Files:**
- Create: `.codex/hooks.json`
- Create: `hooks/codex-session-start.sh`
- Create: `hooks/codex-post-tool-use.sh`
- Modify: `.codex-plugin/plugin.json`
- Create: `tests/codex/test-codex-hooks.sh`
- Modify: `tests/verification/test-plugin-config-drift.sh`

**Purpose:** Give Codex deterministic quality gates comparable to Claude Code hooks where Codex supports them.

**Not In Scope:** Porting every Claude hook event one-for-one. Codex and Claude hook event sets differ.

**Gotchas:**
- Codex plugin-bundled hooks are opt-in according to current docs. Project-local `.codex/hooks.json` is a more reliable local development path.
- Hook shell scripts can share lint/audit implementation, but environment variables differ. Avoid relying on `${CLAUDE_PLUGIN_ROOT}` or `${CLAUDE_PROJECT_DIR}` in Codex wrappers.
- Do not break existing Claude hook behavior.

**Step 1: Add project-local Codex hooks**
Start with local `.codex/hooks.json`:
- `SessionStart`: inject Superpowers-BD session guidance if Codex does not already load skills through plugin metadata.
- `PostToolUse`: run shared linter/audit wrapper after file writes where Codex hook input exposes the path.
- `Stop`: optional quality reminder when verification evidence is missing.

**Step 2: Add plugin hook manifest only after testing**
Add `hooks` to `.codex-plugin/plugin.json` only if local hook tests show the bundled plugin path works reliably with `[features].plugin_hooks = true`.

**Step 3: Add trust docs**
Update `docs/README.codex.md` with `/hooks` review/trust instructions.

**Verification:**
- `tests/codex/test-codex-hooks.sh`
- `tests/verification/test-plugin-config-drift.sh`

## Task 6: Add Platform Parity Tests

**Depends on:** Tasks 1-5
**Complexity:** standard
**Files:**
- Modify: `tests/codex/run-tests.sh`
- Modify: `tests/codex/test-codex-agents.sh`
- Modify: `tests/codex/test-codex-hooks.sh`
- Modify: `tests/codex/test-codex-workflow-semantics.sh`
- Modify: `tests/verification/test-plugin-config-drift.sh`
- Modify: `tests/claude-code/run-skill-tests.sh` only if shared semantics change

**Purpose:** Prevent future drift where Claude Code regains richer behavior and Codex silently falls behind, or vice versa.

**Not In Scope:** Full headless Codex end-to-end execution unless the team approves cost/runtime budget.

**Gotchas:**
- Existing Codex tests prove packaging, not behavior.
- Semantic grep tests should be strict enough to catch regressions but not brittle about wording.

**Step 1: Agent tests**
Validate:
- `.codex/agents/*.toml` files exist,
- required fields exist,
- no Claude-only tool names in Codex developer instructions,
- reviewer agents are read-only where expected.

**Step 2: Hook tests**
Validate:
- `.codex/hooks.json` schema shape,
- wrappers are executable,
- no `${CLAUDE_...}` variables in Codex hook paths,
- `.codex-plugin/plugin.json` hook field is either absent with documented reason or points to existing files.

**Step 3: Workflow semantic tests**
Validate:
- SDD has both Claude Code and Codex dispatch sections,
- ad-hoc review has native Codex flow,
- no "Codex maps to Claude" framing,
- no "Claude reviewers" language outside Claude-specific sections.

**Step 4: Drift test update**
Add checks that:
- Claude and Codex manifests stay version-aligned,
- Codex native agent list includes the reviewer/verifier roles,
- Claude native agent list includes comparable roles,
- each platform docs mention its native path.

**Verification:**
- `./tests/codex/run-tests.sh`
- `tests/verification/test-plugin-config-drift.sh`
- `./tests/claude-code/run-skill-tests.sh --test test-subagent-driven-development.sh`

## Task 7: Documentation Parity Pass

**Depends on:** Tasks 1-6
**Complexity:** standard
**Files:**
- Modify: `README.md`
- Modify: `docs/README.codex.md`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `CHANGELOG.md`
- Modify: `RELEASE-NOTES.md`

**Purpose:** Make the public and project docs communicate equal first-class support.

**Not In Scope:** Marketing copy beyond technical truth.

**Gotchas:**
- Do not make `AGENTS.md` a clone of `CLAUDE.md`. Codex reads AGENTS.md.
- Keep Claude-specific minimum version details in Claude docs.
- Add Codex-specific feature maturity notes honestly if hooks or agents require optional feature flags.

**Step 1: Update top-level README**
Add a platform support matrix:
- skills,
- agents,
- hooks,
- review workflow,
- SDD,
- tests,
- known limitations.

**Step 2: Update Codex docs**
Document:
- native plugin install,
- native agents,
- hook trust/setup,
- `$skill` entry points,
- fallback CLI status,
- known feature flags.

**Step 3: Update release notes**
Record the parity initiative and the fact that it intentionally introduces platform-specific native layers rather than a single translated workflow.

**Verification:**
- `rg -n "Claude Code plugin providing|Codex.*fallback only|experimental Codex" README.md docs/README.codex.md AGENTS.md CHANGELOG.md RELEASE-NOTES.md`
- `./tests/codex/run-tests.sh`

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Codex plugin-bundled hooks require user opt-in | Codex hook parity may be incomplete for installed plugin users | Ship project-local hooks first, document `plugin_hooks`, gate manifest hook field behind tests |
| Codex agent packaging from plugins may differ from project `.codex/agents` | Agents may work locally but not as installed plugin components | Test project-scoped agents first, then research plugin distribution for agents before claiming plugin-wide support |
| Shared skill prose becomes too complex with dual paths | Agents may skip or misapply workflows | Move native execution details to platform-specific reference files and keep SKILL.md short |
| Model naming differs across environments | Hard-coded model tiers become stale | Centralize platform model matrices and prefer inherited model unless a role requires explicit strength |
| Tests become grep-only and miss behavior | False confidence | Add optional headless smoke tests for Codex when CLI/runtime support is stable and cost budget is approved |

## Plan Verification Checklist

- **Complete:** Addresses packaging, skills, commands, agents, hooks, SDD, code review, docs, and tests.
- **Accurate:** File paths checked against current repository inventory.
- **Commands valid:** Verification commands use existing scripts or explicitly call new tests created by tasks.
- **YAGNI:** Does not propose rewriting all skills; focuses on native execution gaps.
- **Minimal:** Seven tasks are enough to separate boundary decisions, native agents, SDD, review, hooks, tests, and docs.
- **Not over-engineered:** Uses shell tests and TOML/Markdown files already aligned with repo patterns.
- **Key Decisions documented:** Equal native surfaces, shared methodology, platform adapters, native agents, platform-specific hooks, outcome-based parity.
- **Context sections present:** Each task has purpose, scope, gotchas, and verification.
- **File Structure complete:** Every planned file appears in the file structure table.

## Verification Record

**Plan path:** `docs/plans/2026-05-15-claude-codex-parity-plan.md`
**Verification status:** Draft, checklist, rule-of-five-plans, and repository compatibility checks complete.
**External docs checked:** OpenAI Codex skills/plugins/hooks/subagents and Claude Code skills/subagents/hooks on 2026-05-15.
**Rule-of-five-plans results:**
- Draft pass: PASS. The plan has a clear goal, evidence, file structure, parity gaps, implementation tasks, risk register, and verification record.
- Feasibility pass: PASS after fix. The plan now calls out that `skills/plan2beads/references/` and `skills/ad-hoc-code-review/references/` must be created before adding new Codex references.
- Completeness pass: PASS after fix. The plan now covers planning, plan-to-beads, execution, and ad-hoc review entry workflows rather than only `/cr`.
- Risk pass: PASS. Main risks are documented: plugin hook opt-in, custom-agent distribution maturity, dual-path prose complexity, stale model names, and grep-only tests.
- Optimality pass: PASS. The plan keeps shared methodology and adds native platform layers instead of forking every skill.

**Local verification run:**
- `./tests/codex/run-tests.sh` -- PASS, 2 passed, 0 failed.
- `tests/verification/test-plugin-config-drift.sh` -- PASS, 15 passed, 0 failed.

**Remaining required review:** Human approval before converting this plan to a beads epic and implementing the parity tasks.
