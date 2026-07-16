# Workflow Contract Review Fixes Implementation Plan

> **After approval:** execute directly in the current checkout because this is
> a review-correction pass on an already approved implementation.

**Goal:** Correct the verified review regressions without reversing the prompt
calibration or weakening deterministic workflow contracts.

**Architecture:** Strengthen the structural audit around behavior classes and
preserved invariants, then repair each affected authoring surface and its
installable mirror. Treat generated beads guidance as generated content, and
keep the active no-git-ops policy.

**Tech Stack:** Bash and Python structural tests, Markdown skills/prompts,
Claude/Codex agent definitions, beads.

**Key Decisions:**

- **Calibrated bright lines:** Keep TDD and verification invariants explicit,
  with scoped exceptions and calm recovery wording.
- **Every dispatch surface counts:** Test canonical prompts, Claude agents,
  Codex agents, commands, and plugin mirrors where the workflow can enter.
- **Defect-class tests:** Assert positive contracts and semantic failure
  classes, not only deleted phrases.
- **Portable fast tests:** Use repository-baseline tools and fail closed when a
  required command is unavailable.
- **Generated means generated:** Match the versioned `profile:minimal` fixture
  used by the managed block, carry a real content hash, and keep repository
  native-progress overrides outside generated content. The installed
  `bd setup --print` surface emits a different generic recipe.

---

## Global Constraints

- Preserve verdict schemas, beads persistence, checkpoint fields,
  `CANNOT_VERIFY`, retry ceilings, and file ownership.
- Keep every changed `skills/` file byte-identical to its
  `plugins/superpowers-bd/skills/` mirror.
- Keep the current stop-gate implementation unchanged; align the skill with its
  per-response-cycle evidence contract.
- Do not perform git operations.

## File Structure

| Area | Files | Responsibility |
|------|-------|----------------|
| Regression audit | `tests/verification/test-workflow-contract-audit.sh`, `tests/claude-code/run-skill-tests.sh` | Portable defect-class and invariant coverage |
| TDD | `skills/test-driven-development/SKILL.md`, `references/rationalizations-and-red-flags.md`, plugin mirrors | Bright line, recovery, four scoped exceptions |
| Epic verification | `agents/epic-verifier.md`, `skills/epic-verifier/verifier-prompt.md`, plugin mirrors | Read-only behavior on both Claude dispatch paths and valid persistence |
| Native semantics | SDD prompt templates, `commands/cr.md`, receiving-review, worktrees, writing-plans, plugin mirrors | Current Agent terminology and honest progress semantics |
| Completion evidence | `skills/verification-before-completion/SKILL.md`, plugin mirror | Same-cycle evidence and calibrated claim table |
| Preserved guidance | using-superpowers and writing-skills references plus mirrors | Codex ownership, measured evidence, valid references |
| Generated guidance | `AGENTS.md`, `CLAUDE.md`, versioned fixture, workflow audit | Managed profile body, content-integrity hash, and native-progress override |

### Task 1: Strengthen regression coverage

**Depends on:** None  
**Complexity:** complex  
**Files:** audit test and fast runner

1. Add assertions for the TDD bright line/recovery, bounded exception set,
   reference coherence, both verifier paths, valid heredoc shape, same-cycle
   verification evidence, ownership guidance, and generated-block integrity.
2. Scan `Task(`, YAML-style `Task:`/`Task tool:`, and prose forms such as
   `Task tool`, `Task calls`, and `both the Task` across root and plugin
   surfaces.
3. Replace optional `rg` execution with portable Python/grep scanning.
4. Wire the audit into `run-skill-tests.sh`.
5. Run the focused audit and confirm RED for the reviewed defects.

### Task 2: Restore calibrated workflow invariants

**Depends on:** Task 1  
**Complexity:** complex  
**Files:** TDD, VBC, receiving-review, worktrees, writing-plans, using-superpowers

1. Restore the production-behavior test-first bright line and the
   discard-and-restart recovery rule when no exception applies.
2. Limit autonomous exceptions to the four plan-authorized categories and make
   the rationalization reference exception-aware.
3. Restore conditional post-cycle simplification without imposing git actions.
4. Restore same-response-cycle completion evidence, `ONLY THEN`, and the
   `Not Sufficient` comparison column.
5. Replace remaining false “cannot/non-skippable” progress claims with visible
   ordering semantics.
6. Restore general Codex parallel-worker file-ownership guidance.

### Task 3: Repair all verifier and dispatch paths

**Depends on:** Task 1  
**Complexity:** complex  
**Files:** epic verifier agent/prompt, SDD prompt templates, `/cr`, aggregator

1. Remove editing rule-of-five skill auto-loads from the Claude epic-verifier
   agent and state that its five lenses are observations only.
2. Fix the tee heredoc with a column-zero delimiter and suppress duplicate
   transcript output.
3. Replace active Claude `Task:` forms with `Agent:` across prompt templates and
   `/cr`.
4. Express the first verifier lens as structural completeness rather than an
   authoring “Draft” action.
5. Align aggregation model wording with the platform policy.

### Task 4: Restore evidence and generated-content integrity

**Depends on:** Tasks 2 and 3  
**Complexity:** standard  
**Files:** bulletproofing, tdd-for-skills, example workflow, AGENTS/CLAUDE, drift test

1. Restore the measured “worse than no-guidance control” result.
2. Fix the renamed section pointer.
3. Replace the hook-blocked `bd show ... | head` example with bounded native
   output.
4. Capture the managed `profile:minimal` body in a versioned fixture, verify
   both instruction files against that fixture and their SHA-256 prefixes, and
   assert an external native-progress override reconciles the generated
   TaskCreate prohibition with the repository's two-layer architecture.

### Task 5: Verify and review

**Depends on:** Tasks 2–4  
**Complexity:** standard  
**Files:** tests only if gaps are discovered

Run the workflow audit after each behavior group, then run:

- `bash tests/claude-code/run-skill-tests.sh`
- `bash tests/codex/run-tests.sh`
- `bash tests/verification/test-plugin-config-drift.sh`
- `bash tests/verification/test-stop-gate.sh`
- `bash tests/verification/test-link-plugin-components.sh`
- `bash tests/shell-lint/test-lint-shell.sh`
- `claude plugin validate .`

Compare all mirrored skill files and close the beads issue only from fresh
evidence.

## Verification Record

| Pass | Result | Findings |
|------|--------|----------|
| Draft | PASS | Tasks follow the reviewer’s dependency structure and isolate tests before fixes. |
| Feasibility | PASS | All named paths and commands exist; generic and recipe-specific `bd setup --print` output were inspected and confirmed distinct from the managed minimal profile. |
| Completeness | PASS | Both Criticals, all six Important findings, and actionable Minors map to tasks. |
| Risk | PASS | No hook or git mutation; generated blocks and all dispatch surfaces receive direct coverage. |
| Optimality | PASS | One strengthened audit replaces several patch-shaped checks; no architecture experiments are pulled into scope. |
