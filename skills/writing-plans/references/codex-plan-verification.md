# Codex Plan Verification

Use this reference when `writing-plans` is invoked from Codex. The goal is the same as the Claude workflow: create an implementation plan that is executable by a developer with limited prior context, then verify scope before polishing style.

## Native Flow

1. Announce that you are using `writing-plans`.
2. Track progress with `update_plan` using these phases: draft plan, verify plan, rule-of-five draft pass, rule-of-five feasibility pass, rule-of-five completeness pass, rule-of-five risk pass, rule-of-five optimality pass.
3. Read only the context needed to identify files, commands, dependencies, and existing patterns. Prefer `rg`, targeted file reads, and project tooling.
4. Save the plan to `docs/plans/YYYY-MM-DD-<feature-name>.md` unless the user specified a different repository-local path.
5. Run the verification checklist against the saved plan, edit the plan for any gaps, then apply all five rule-of-five-plans passes.
6. Append a verification record to the plan with the checks performed, findings, changes made, and remaining risks.
7. Present the plan path and ask for approval before implementation or conversion to beads.

## Plan Requirements

- Start with the standard implementation plan header from `writing-plans`.
- Include a file structure table before task definitions.
- Every task must include `Depends on:`, `Complexity:`, and `Files:`.
- Use exact file paths and exact verification commands with expected outcomes.
- Include TDD steps when the task changes behavior.
- Each step is one action with a checkable result, written as a decision, not a transcript: test steps give the test name and assertions with the spec's exact values; code steps give the exact signature, file and pinned values, with a body only for an algorithm the signature and tests do not determine; verification steps give the command and its passing output; cross-task references go through the other task's `**Interfaces:**` block. See `references/plan-step-content.md`.
- Do not build or run the product's code while planning.
- Keep tasks small enough for focused review and independent execution.
- Include `Purpose:`, `Not In Scope:`, and `Gotchas:` where they prevent ambiguity.

## Verification Checklist

Check the saved plan before applying rule-of-five-plans:

- All user requirements are represented by one or more tasks.
- Existing paths and referenced commands have been verified.
- New files are placed in directories that match repository conventions.
- Each task only touches files declared in the file structure table.
- Every implementation task uses an H3 `### Task N:` heading; a local plan with zero such headings is not ready for plan2beads.
- Dependencies describe real ordering constraints, not just narrative order.
- The plan avoids speculative infrastructure, broad refactors, and unrelated cleanup.
- Verification commands are feasible in the current repository.
- Step scan: every step lets the implementer write exactly one reasonable thing, with no line that decides nothing and no function body the signature and tests already determine.
- Proportion: compare plan length to the spec's. Several times longer, or mostly code blocks, is a transcript; replace bodies with signatures, test names and assertions.
- The final handoff explains whether the next step is approval, plan2beads, or direct execution.

## Rule-of-Five Evidence

For each pass, re-read the full plan through one lens only:

- Draft: structure and task shape.
- Feasibility: commands, paths, dependencies, and available tools; each step has one checkable result. Hand-trace; don't build or run the plan's code.
- Completeness: requirement coverage and missing edge cases.
- Risk: migration risk, parallel conflicts, data loss, auth/security concerns, and rollback.
- Optimality: simplest defensible plan with no unnecessary tasks, no bodies the signature and tests already determine, and not several times the spec's length.

Record the result of each pass in the plan's verification record. If a pass changes the plan materially, briefly state what changed and why. If a pass fails, fix the plan and re-run it once; if it still fails, record a ruling in the verification record and continue. With no human present, do not stop to ask.
