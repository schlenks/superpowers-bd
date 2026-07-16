# Workflow Contract Calibration Implementation Plan

> **After approval:** convert this plan to a beads epic with plan2beads, then execute it with subagent-driven-development unless a different execution path is explicitly chosen.

**Goal:** Fix the verified Claude Code and Codex workflow defects, remove misleading enforcement rhetoric, and retain the evidence and orchestration contracts that still provide measurable value.

**Architecture:** Add one fast structural audit that encodes the cross-file contracts, then make narrowly scoped prose and prompt changes behind that test. Keep shared workflow intent in root skills, mirror installable Codex skill copies, and leave model-dependent experiments as separately tracked work rather than silently changing architecture.

**Tech Stack:** Bash structural tests, Markdown skills/prompts, beads issue tracking, Claude Code and Codex plugin manifests/tests.

**Key Decisions:**
- **Correctness before compression:** Fix broken paths, schemas, verdicts, and read-only verifier behavior before removing duplication.
- **Exact platform semantics:** Describe native tasks as visibility and ordering mechanisms, not as commit prevention or unskippable enforcement.
- **Capability-based verification:** Trigger browser verification from available browser capabilities and report relevant skips only when frontend files changed.
- **Preserve tested controls:** Keep the current stop gate and #17688 workaround. Track shadow evaluation and Workflow adoption as experiments.
- **No git mutation:** The active beads profile has `no-git-ops = true`, so this execution edits and verifies in place without branch, commit, sync, or push operations.

---

## Global Constraints

- Keep root skills and `plugins/superpowers-bd/skills/` mirrors byte-identical for every mirrored file changed.
- Do not remove verdict schemas, beads persistence, checkpoint fields, file ownership, retry ceilings, or `CANNOT_VERIFY`.
- Do not alter `hooks/stop-gate.sh` or remove `hooks/link-plugin-components.sh` in this implementation.
- Leave the unrelated untracked `mise.toml` untouched.

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `tests/verification/test-workflow-contract-audit.sh` | Fast regression test for the verified workflow defects and calibrated wording | Create |
| `tests/claude-code/test-subagent-driven-development.sh` | SDD discoverability and wave-flag lifecycle contract | Modify |
| `tests/codex/test-codex-workflow-semantics.sh` | Codex-native terminology and mirror assertions | Modify |
| `tests/verification/test-plugin-config-drift.sh` | Current beads instruction block and root/plugin mirror checks | Modify |
| `skills/subagent-driven-development/SKILL.md` | Document wave orchestration as a required companion and use current Agent terminology | Modify |
| `skills/subagent-driven-development/example-workflow.md` | Correct implementer verdict examples | Modify |
| `skills/subagent-driven-development/wave-orchestration.md` | Clarify flag lifecycle and native task dependency updates | Modify |
| `skills/subagent-driven-development/background-execution.md` | Replace stale Claude Task invocation terminology | Modify |
| `skills/subagent-driven-development/dispatch-and-conflict.md` | Replace stale Claude Task invocation terminology and exact enforcement wording | Modify |
| `skills/writing-plans/SKILL.md` | Reuse family-aware 1M detection and exact TaskUpdate dependency semantics | Modify |
| `skills/epic-verifier/verifier-prompt.md` | Make final verification read-only and persist via `tee` | Modify |
| `skills/epic-verifier/SKILL.md` | Align verifier description with read-only lens checks | Modify |
| `skills/using-superpowers/SKILL.md` | Replace pressure prose with concise routing and correct TaskUpdate example | Modify |
| `skills/systematic-debugging/SKILL.md` | Add proportional triage and replace fictional task enforcement | Modify |
| `skills/test-driven-development/SKILL.md` | Add bounded autonomous exceptions with alternative-verification receipts | Modify |
| `skills/verification-before-completion/SKILL.md` | Add proportional verification and remove threat language | Modify |
| `skills/verification-before-completion/references/visual-verification.md` | Capability-based browser detection and relevant skip reporting | Modify |
| `skills/writing-skills/SKILL.md` | Retire persuasion doctrine from active references | Modify |
| `skills/writing-skills/references/bulletproofing.md` | Remove persuasion framing while retaining failure-shape guidance | Modify |
| `skills/writing-skills/references/testing-skills-with-subagents.md` | Remove persuasion cross-reference | Modify |
| `skills/writing-skills/references/persuasion-principles.md` | Remove obsolete active doctrine | Delete |
| `skills/verification-before-completion/references/why-this-matters.md` | Remove threat-register reference | Delete |
| `skills/systematic-debugging/references/CREATION-LOG.md` | Remove obsolete creation history | Delete |
| `skills/systematic-debugging/references/real-world-impact.md` | Remove stale impact claims | Delete |
| `skills/dispatching-parallel-agents/references/real-world-impact.md` | Remove stale impact claims | Delete |
| `skills/multi-review-aggregation/references/dispatch-code.md` | Remove pseudocode for a nonexistent API | Delete |
| `skills/multi-review-aggregation/references/metrics-and-cost.md` | Remove stale pricing | Delete |
| `skills/multi-review-aggregation/SKILL.md` | Remove deleted reference links and use native dispatch descriptions | Modify |
| `skills/dispatching-parallel-agents/SKILL.md` | Use current Agent terminology and remove stale impact link | Modify |
| `skills/rule-of-five-code/SKILL.md` | Replace false enforcement statements with progress visibility semantics | Modify |
| `skills/rule-of-five-plans/SKILL.md` | Replace false enforcement statements with progress visibility semantics | Modify |
| `skills/rule-of-five-tests/SKILL.md` | Replace false enforcement statements with progress visibility semantics | Modify |
| `skills/receiving-code-review/SKILL.md` | Replace false enforcement statements with progress visibility semantics | Modify |
| `skills/using-git-worktrees/references/creation-steps.md` | Correct TaskCreate/TaskUpdate dependency examples | Modify |
| `skills/receiving-code-review/references/task-enforcement-blocks.md` | Correct TaskCreate/TaskUpdate dependency examples | Modify |
| `skills/writing-plans/references/task-enforcement-examples.md` | Correct dependency and Agent dispatch examples | Modify |
| `skills/verification-before-completion/references/gap-closure-protocol.md` | Correct dependency field usage | Modify |
| `skills/executing-plans/references/report-and-feedback.md` | Correct dependency field usage and enforcement semantics | Modify |
| `skills/finishing-a-development-branch/references/completion-strategies.md` | Correct dependency field usage | Modify |
| `skills/finishing-a-development-branch/references/pre-merge-simplification.md` | Correct dependency and Agent examples | Modify |
| `skills/writing-skills/references/tdd-for-skills.md` | Correct dependency field usage | Modify |
| `CLAUDE.md` | Replace stale generated beads block with current policy-controlled template | Modify |
| `AGENTS.md` | Replace stale generated beads block with current policy-controlled template | Modify |
| `plugins/superpowers-bd/skills/**` | Mirror each changed installable Codex skill/reference | Modify/Delete |

### Task 1: Add the workflow contract regression test

**Depends on:** None  
**Complexity:** standard  
**Files:**
- Create: `tests/verification/test-workflow-contract-audit.sh`
- Modify: `tests/claude-code/test-subagent-driven-development.sh`
- Modify: `tests/codex/test-codex-workflow-semantics.sh`
- Modify: `tests/verification/test-plugin-config-drift.sh`

**Purpose:** Convert the audit’s confirmed claims into deterministic failures before changing production skill content.

**Step 1: Write failing structural assertions**

Cover wave-orchestration discoverability, implementer verdict vocabulary, family-aware context detection, read-only epic verification, current Agent terminology, TaskUpdate dependency fields, current beads handoff policy, and absence of threat phrases.

**Step 2: Run tests to verify RED**

Run: `bash tests/verification/test-workflow-contract-audit.sh`  
Expected: FAIL on the current confirmed defects.

**Step 3: Keep focused tests independently runnable**

Run the existing SDD, Codex semantics, and plugin drift tests. Record existing baseline separately from the new intentional RED test.

### Task 2: Repair SDD and epic-verifier contracts

**Depends on:** Task 1  
**Complexity:** complex  
**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/subagent-driven-development/example-workflow.md`
- Modify: `skills/subagent-driven-development/wave-orchestration.md`
- Modify: `skills/subagent-driven-development/background-execution.md`
- Modify: `skills/subagent-driven-development/dispatch-and-conflict.md`
- Modify: `skills/writing-plans/SKILL.md`
- Modify: `skills/epic-verifier/verifier-prompt.md`
- Modify: `skills/epic-verifier/SKILL.md`
- Modify: matching files under `plugins/superpowers-bd/skills/`

**Purpose:** Restore live hook orchestration and remove prompt contradictions without changing external evidence formats.

**Not In Scope:** Replacing SDD with Claude Workflow or altering verdict/beads/checkpoint schemas.

**Step 1: Make wave orchestration load-bearing**

Add `wave-orchestration.md` to the companion list and explicitly require loading it before DISPATCH. Preserve flag creation, cleanup, and recovery behavior.

**Step 2: Correct verdict and context routing**

Use `DONE`/`DONE_WITH_CONCERNS` for implementers and family-aware 1M detection in writing-plans.

**Step 3: Make epic verification read-only**

Apply rule-of-five lenses as review checklists without editing files. Persist the report with a separate Bash `tee` call.

**Step 4: Modernize Claude dispatch terminology**

Use `Agent` in active examples while noting `Task` only where historical compatibility matters.

### Task 3: Correct native progress and generated instruction semantics

**Depends on:** Task 1  
**Complexity:** complex  
**Files:**
- Modify: all dependency-example and rule-of-five files listed in File Structure
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: matching files under `plugins/superpowers-bd/skills/`

**Purpose:** Ensure documentation teaches valid TaskCreate/TaskUpdate usage and accurately describes what progress dependencies enforce.

**Step 1: Split creation from dependency updates**

Teach `TaskCreate` first, capture the ID, then call `TaskUpdate(addBlockedBy=[...])`.

**Step 2: Replace fictional enforcement claims**

State that task state exposes ordering and skipped phases. Do not claim task state prevents commits or every out-of-order action.

**Step 3: Refresh generated beads blocks**

Replace the stale blocks with the current `bd setup ... --print` policy-controlled handoff template.

### Task 4: Calibrate prompt pressure and add proportionality

**Depends on:** Tasks 2 and 3  
**Complexity:** complex  
**Files:**
- Modify/Delete: calibration files listed in File Structure
- Modify: matching files under `plugins/superpowers-bd/skills/`

**Purpose:** Remove counterproductive threats and blanket ceremony while retaining concise quality contracts.

**Step 1: Rewrite using-superpowers**

Keep skill discovery, platform boundaries, conflict hierarchy, and native tool routing. Remove the 1% rule and rationalization table.

**Step 2: Add triage floors**

Allow systematic-debugging and verification depth to scale with risk while preserving fresh evidence for completion claims.

**Step 3: Add bounded TDD exceptions**

Permit generated code, declarative configuration, documentation-only changes, and throwaway prototypes when the agent records the reason and runs an appropriate alternative verification.

**Step 4: Retire obsolete references**

Delete threat, persuasion, stale-impact, stale-pricing, creation-history, and nonexistent-API pseudocode references after removing all live links.

**Step 5: Add load triggers**

Add concise load conditions to retained references touched by this work. File a follow-up for the remaining corpus if a safe mechanical pass would exceed this task’s scope.

### Task 5: Verify mirrors and behavior

**Depends on:** Tasks 2, 3, and 4  
**Complexity:** standard  
**Files:**
- Modify: tests if verification uncovers missing coverage

**Purpose:** Prove the edited corpus remains packageable and platform-native.

**Step 1: Run focused RED-to-GREEN test**

Run: `bash tests/verification/test-workflow-contract-audit.sh`  
Expected: PASS.

**Step 2: Run platform suites**

Run:
- `bash tests/claude-code/test-subagent-driven-development.sh`
- `bash tests/codex/run-tests.sh`
- `bash tests/verification/test-plugin-config-drift.sh`
- `bash tests/verification/test-stop-gate.sh`
- `bash tests/verification/test-link-plugin-components.sh`

Expected: all exit 0.

**Step 3: Run full fast skill suite**

Run: `bash tests/claude-code/run-skill-tests.sh`  
Expected: all fast tests pass.

**Step 4: Review the complete diff**

Run whitespace and mirror checks permitted by the no-git-ops profile using direct file comparisons and repository tests. Do not stage, commit, or push.

### Task 6: Track experiments and remaining mechanical cleanup

**Depends on:** Task 5  
**Complexity:** simple  
**Files:** None

**Purpose:** Prevent unvalidated architecture changes from being smuggled into a correctness batch.

Create separate beads issues for:
- stop-gate shadow evaluation against concise evidence-audit prompting,
- Claude Workflow `/cr N` adapter spike with preserved external contracts,
- rule-of-five ceremony versus checklist-only A/B,
- complete reference load-trigger census,
- measured token census and deduplication.

## Verification Record

| Pass | Result | Findings and changes |
|------|--------|----------------------|
| Draft | PASS | Tasks are grouped by reviewable contract boundaries and include exact files and commands. |
| Feasibility | PASS | Existing test entry points and mirror layout were verified. Git mutation was removed because the active beads profile forbids it. |
| Completeness | PASS | All confirmed defects, prompt calibration, proportionality, TDD exceptions, load triggers, and deferred experiments are represented. |
| Risk | PASS | Preserves stop-gate and #17688 controls, external SDD contracts, user files, and platform-specific adapters. |
| Optimality | PASS | Workflow replacement, broad deduplication, and behavioral experiments are separated from the correctness patch. |

