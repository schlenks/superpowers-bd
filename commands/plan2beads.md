---
description: "Import a Superpowers plan (Markdown) or Shortcut story into Beads as an epic with dependency-aware child tasks"
effort: medium
---

# plan2beads

**REQUIRED BACKGROUND:** You MUST understand `superpowers-bd:beads` before using this command.

> **Permission Avoidance Rules:**
> - Use `--body-file temp/*.md` for multi-line descriptions (avoids newline issues)
> - Unique temp filenames: `temp/{title-slug}-epic.md`, `temp/{epic_id}-task-{n}.md`
> - **NEVER use `\n` or ANSI-C quoting** in `--acceptance` — use semicolons to separate
> - Do NOT delete temp files. `temp/` already exists — do NOT mkdir.

Usage: `/superpowers-bd:plan2beads <path-to-plan.md | SC-1234 | 1234>`

## Conversion Task Enforcement

Create native tasks (each blocked by previous):
```
TaskCreate: "Parse plan structure" → Extract epic title, context, phases, tasks, deps, complexity, files
TaskCreate: "Create epic" [blockedBy: parse] → Write temp file, bd create, capture epic ID
TaskCreate: "Create child tasks" [blockedBy: epic] → Build ID map, validate deps, bd create each
TaskCreate: "Dependency verification" [blockedBy: tasks] → bd ready, bd blocked, bd graph
TaskCreate: "Final validation gate" [blockedBy: verify] → Epic exists, children linked, no circular deps
```

## Instructions
### Step 1: Load and Parse

**Load:** Local markdown via Read tool. Shortcut story: `short story <numeric-id> -f=markdown` — first line `#XXXXX Title`, extract title, store ID for `--external-ref`.

**Parse elements:**
- Epic Title: First H1 or Shortcut first line
- Context: H2s like "Problem Statement", "Goals", "Architecture" -> epic description
- Phases: H2 "Phase N: ..." or "Stage N: ..." -> task labels
- Tasks: H3 (`### Task N:`) -> child tasks
- Dependencies: `**Depends on:**` line -> `--deps`
- Complexity: `**Complexity:**` line -> `-l "complexity:..."` label
- Files: `**Files:**` section -> preserved in description
- Interfaces (OPTIONAL): per-task `**Interfaces:**` line with `Consumes:` / `Produces:` -> preserved verbatim in that task's description (absent = task body unchanged)
- Success Criteria: H2 with `- [ ]` -> epic acceptance criteria
- Key Decisions: `## Key Decisions` -> epic description (placed first)
- Spec (OPTIONAL): header line `**Spec:** <path or URL>` -> copied verbatim into the epic description as a line `Spec: <value>` (absent = epic description unchanged)
- Global Constraints (OPTIONAL): `## Global Constraints` -> epic-wide rules; thread the block text into EVERY child task body and keep it on the epic (absent = no constraints, every task body unchanged)
- Review Focus (OPTIONAL for legacy plans): `## Review Focus` -> keep the full list on the epic; copy each `**Task N:**` item into its owning child task, alongside the task's test step

**Parsing Rules:**
- H2s NOT matching phases/stages/success-metrics are context
- Tasks inherit phase label from containing Phase H2
- Strip numbered prefixes ("1. Task Name" -> "Task Name")
- Parse `Depends on:` for task-level deps (see Step 3)
- Parse `Complexity:` for model selection label (simple/standard/complex, default: standard)
- Extract and preserve `Files:` section in task description
- **Global Constraints (OPTIONAL, backward-compatible):** If a `## Global Constraints` H2 exists, copy its text into each child task body (so every implementer carries the epic-wide rules) and retain it in the epic description. If absent, parse exactly as before — no constraints block, no change to any task body.
- **Interfaces (OPTIONAL, backward-compatible):** If a task has a `**Interfaces:**` line (with `Consumes:` / `Produces:`), preserve it verbatim in that task's description. If absent, the task body is unchanged. Regex: `\*\*Interfaces:\*\*` then capture the following `Consumes:` / `Produces:` lines.
- **Review Focus (OPTIONAL, backward-compatible):** If a `## Review Focus` H2 exists, retain the whole block in the epic description. For each bullet beginning `- **Task N:**`, copy that bullet verbatim under `Review Focus:` in the owning child task body only; verify the named test is present in that task's steps. A `None identified` bullet adds no child text. If a task number is missing or its test is absent, stop and correct the plan before creating issues. A legacy plan without this H2 imports unchanged.
- **Spec (OPTIONAL, backward-compatible):** If a `**Spec:**` header line exists in the plan header (before the first `## ` section or `### Task`; per-task `**Spec:**` lines are ignored) (regex `\*\*Spec:\*\*\s*(.+)$`), write `Spec: <value>` verbatim on its own line in the epic description, directly after Key Decisions. Do not resolve, fetch, or rewrite the path or URL. Subagent-driven-development reads this line at context loading so plan conflicts can be ruled against the spec. Absent means the epic description is unchanged.
- A plan with NEITHER `## Global Constraints` nor any `**Interfaces:**` imports identically to prior behavior.

**Local-plan gate:** Count H3 `### Task N:` headings before creating the epic. 0 H3 matches: stop before creating the epic and correct the local plan's task headings. Shortcut stories may still create an epic without implementation tasks.

### Step 1b: Completion Strategy (no ask by default)

Do NOT ask. Use the user's explicit choice if one was given in the request; otherwise default to `completion:commit-only` and say so in the Step 5 import summary ("Completion: commit-only (default; no choice given)").
Labels: commit only=`completion:commit-only`, push=`completion:push`, push+PR=`completion:push-pr`, merge local=`completion:merge-local`. Push and merge labels apply ONLY on an explicit user choice, never by default or inference.

### Step 2: Create the Epic

Write description to `temp/{title-slug}-epic.md` (Key Decisions first, then other context). Create:
```bash
bd create --silent --type epic "Title" --body-file temp/{slug}-epic.md --acceptance "C1; C2" -l "completion:commit-only" -p 1
```
Add `--external-ref "sc-1234"` for Shortcut. No H1 = use filename. Capture returned ID. Key Decisions missing = warn in summary but continue.

### Step 3: Create Child Tasks (Dependency-Aware)

> Without `--deps`, ALL tasks appear in `bd ready` simultaneously. Dependencies must be explicit.

**ID Map:** As created: Task 1 -> hub-abc.1, Task 2 -> hub-abc.2, etc.

**Parse deps:** `**Depends on:**` — `None` = no --deps. `Task 1` = `--deps "hub-abc.1"`. `Task 1, Task 3` = `--deps "hub-abc.1,hub-abc.3"`. Ignore parentheticals. Regex: `\*\*Depends on:\*\*\s*(.+)$` then `Task\s+(\d+)`.

**Parse complexity:** `**Complexity:**` — Regex: `\*\*Complexity:\*\*\s*(.+)$`. Extract value: `simple`, `standard`, or `complex`. If missing, default to `standard`. If unrecognized value, warn and default to `standard`.

**Dependency Validation:**
- Forward references (Task 2 depends on Task 5): warn and skip
- Self-references: warn and skip
- Non-existent tasks: warn and skip
- Continue without invalid deps; report in summary
- 0 H3 matches in a local implementation plan: stop at the Step 1 local-plan gate

**Create in order.** Write each description to `temp/{epic_id}-task-{n}.md`:
```bash
bd create --silent --parent hub-abc "User Model" --body-file temp/hub-abc-task-1.md -l "complexity:standard" -p 2
bd create --silent --parent hub-abc "Update Error Messages" --body-file temp/hub-abc-task-2.md -l "complexity:simple" -p 2
bd create --silent --parent hub-abc "Auth Service" --body-file temp/hub-abc-task-3.md -l "complexity:complex" --deps "hub-abc.1" -p 2
```
Same pattern for all. `## Files` section CRITICAL for parallel safety — if missing, warn. Phase labels combine with complexity: `-l "complexity:standard,phase:1"` if plan uses phases.

**Global Constraints + Interfaces + Review Focus (optional, additive):** When the plan has a `## Global Constraints` block, prepend its text to every child task body so each implementer carries the epic-wide rules. When a task carries an `**Interfaces:**` line, copy it verbatim into that task's body. Keep the entire `## Review Focus` block on the epic and copy each focus bullet to its owning child task only. Plans without these sections produce identical task bodies to before — the additions never alter the section-less path.

### Step 3f: Epic Verification Task (Required)

Every epic MUST have ONE final verification task. Write to `temp/{epic_id}-verification.md` with this template:

```markdown
## Epic Verification

**Complete each item. Do not close this task with any item unmarked.**

### Step 1: Review cumulative changes
Run: `git diff main...HEAD --stat`
Record: ___ files changed, ___ insertions, ___ deletions

### Step 2: Automated checks
- [ ] Tests pass: `pnpm test` -> Result: ___
- [ ] Build succeeds: `pnpm build` -> Result: ___
- [ ] Typecheck passes: `pnpm typecheck` -> Result: ___

### Step 3: Rule-of-five-code on significant code changes
For code files with >50 lines changed:
- [ ] Pass 1 (Draft): Structure correct?
- [ ] Pass 2 (Correctness): Any bugs?
- [ ] Pass 3 (Clarity): Understandable to newcomers?
- [ ] Pass 4 (Edge Cases): Failure modes handled?
- [ ] Pass 5 (Excellence): Would you sign your name to this?
Files reviewed: ___  Issues found and fixed: ___

### Step 4: Engineering checklist
Review cumulative diff against original plan:
- [ ] **Complete** — All requirements addressed
- [ ] **YAGNI** — No extra features beyond plan
- [ ] **Minimal** — Simplest solution
- [ ] **No drift** — Follows plan (or deviations documented)
- [ ] **Key Decisions followed** — Matches plan's Key Decisions
Deviations (if any): ___

### Step 5: Final confirmation
- [ ] All automated checks pass
- [ ] Rule-of-five-code completed on significant code changes
- [ ] Engineering checklist all items marked
- [ ] Ready for merge/PR
```

Create: `bd create --silent --parent hub-abc "Epic Verification" --body-file temp/hub-abc-verification.md --deps "hub-abc.1,hub-abc.2,..." --acceptance "All checks pass; Rule-of-five-code on >50 lines; Engineering checklist complete; No unmarked items" -p 1`
`--deps` must include ALL implementation task IDs.

### Step 4: Verify Dependencies
Run `bd ready`, `bd blocked`, `bd graph hub-abc`. Verify: independent tasks in ready, dependent tasks in blocked, graph shows expected flow.

### Step 5: Display Results and Execute
Show: epic ID/title, completion label (note when defaulted), Spec value (when present), N implementation + 1 verification task, ready/blocked lists. Then choose and record the execution mode per `skills/writing-plans/references/execution-handoff.md` (Step 3: `[EXECUTION-MODE]` epic comment; an already-recorded mode is preserved, not re-chosen), and immediately proceed to execute the epic with the matching skill: `superpowers-bd:subagent-driven-development` for SDD or `superpowers-bd:executing-plans` for Native — do NOT stop and tell the user to run it manually.

## bd CLI Quick Reference
`--silent`: ID only. `--type epic`: epic. `--parent <id>`: child. `--body-file <path>`: multi-line desc. `-d "text"`: single-line desc. `-l "label"`: labels. `-p N`: priority 0-4. `-e N`: estimate mins. `--deps "id1,id2"`: deps (affects `bd ready`). `--acceptance "text"`: criteria (semicolons, never `\n`). `--external-ref "ref"`: external link. `--defer "date"`: hide until date. `--claim`: assign+in_progress. `--suggest-next`: show unblocked after close.

## Backward Compatibility
Phase-based (old): Phase 0 = no deps, Phase N depends on ALL Phase N-1. Task-level deps (new): specific references, phase labels optional.

<!-- compressed: 2026-02-11, original: 2497 words, compressed: 1019 words -->
