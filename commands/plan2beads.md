---
description: "Import a Superpowers plan (Markdown) or Shortcut story into Beads as an epic with dependency-aware child tasks"
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
- Success Criteria: H2 with `- [ ]` -> epic acceptance criteria
- Key Decisions: `## Key Decisions` -> epic description (placed first)

**Parsing Rules:**
- H2s NOT matching phases/stages/success-metrics are context
- Tasks inherit phase label from containing Phase H2
- Strip numbered prefixes ("1. Task Name" -> "Task Name")
- Parse `Depends on:` for task-level deps (see Step 3)
- Parse `Complexity:` for model selection label (simple/standard/complex, default: standard)
- Extract and preserve `Files:` section in task description

### Step 1b: Ask Completion Strategy

```
How should this epic complete? 1. Commit only (default) 2. Push 3. Push+PR 4. Merge local
```
Labels: 1=`completion:commit-only`, 2=`completion:push`, 3=`completion:push-pr`, 4=`completion:merge-local`. Default 1 if skipped.

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
- 0 H3 matches: warn, create epic only

**Create in order.** Write each description to `temp/{epic_id}-task-{n}.md`:
```bash
bd create --silent --parent hub-abc "User Model" --body-file temp/hub-abc-task-1.md -l "complexity:standard" -p 2
bd create --silent --parent hub-abc "Update Error Messages" --body-file temp/hub-abc-task-2.md -l "complexity:simple" -p 2
bd create --silent --parent hub-abc "Auth Service" --body-file temp/hub-abc-task-3.md -l "complexity:complex" --deps "hub-abc.1" -p 2
```
Same pattern for all. `## Files` section CRITICAL for parallel safety — if missing, warn. Phase labels combine with complexity: `-l "complexity:standard,phase:1"` if plan uses phases.

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

### Step 5: Display Results
Show: epic ID/title, N implementation + 1 verification task, ready/blocked lists. End with: `Next: /clear then execute epic hub-abc`

## bd CLI Quick Reference
`--silent`: ID only. `--type epic`: epic. `--parent <id>`: child. `--body-file <path>`: multi-line desc. `-d "text"`: single-line desc. `-l "label"`: labels. `-p N`: priority 0-4. `-e N`: estimate mins. `--deps "id1,id2"`: deps (affects `bd ready`). `--acceptance "text"`: criteria (semicolons, never `\n`). `--external-ref "ref"`: external link. `--defer "date"`: hide until date. `--claim`: assign+in_progress. `--suggest-next`: show unblocked after close.

## Backward Compatibility
Phase-based (old): Phase 0 = no deps, Phase N depends on ALL Phase N-1. Task-level deps (new): specific references, phase labels optional.

<!-- compressed: 2026-02-11, original: 2497 words, compressed: 1019 words -->
