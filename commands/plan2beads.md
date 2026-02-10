---
description: "Import a Superpowers plan (Markdown) or Shortcut story into Beads as an epic with dependency-aware child tasks"
---

# plan2beads

Import a Superpowers plan (Markdown) or a Shortcut story into Beads as an epic with child tasks. Supports both phase-based and task-level dependencies.

**REQUIRED BACKGROUND:** You MUST understand `superpowers:beads` before using this command. That skill covers bd CLI usage, permission avoidance, and dependency management.

> **Note:** This command uses `temp/*.md` files with `--body-file` for descriptions instead of inline `-d "..."` arguments. This avoids Claude Code permission prompts caused by newlines in bash commands breaking pattern matching. The `temp/` directory already exists at the repo root — do NOT run `mkdir` for it. Each file uses a unique name to avoid overwrite prompts across runs.
>
> **Permission Avoidance Rules:**
> - Use `--body-file temp/*.md` for multi-line descriptions (avoids newline issues)
> - Use unique temp filenames: `temp/{title-slug}-epic.md`, `temp/{epic_id}-task-{n}.md` (avoids overwrite prompts)
> - **NEVER use `\n` or ANSI-C quoting (`$'...'`)** in `--acceptance`—newlines trigger permission prompts
> - Use semicolons to separate acceptance criteria: `--acceptance "Criterion 1; Criterion 2; Criterion 3"`
> - Do NOT delete temp files (rm triggers permission prompts) - leave for human cleanup

## Usage

```
/superpowers-bd:plan2beads <path-to-plan.md>
/superpowers-bd:plan2beads SC-1234
/superpowers-bd:plan2beads 1234
```

## Conversion Task Enforcement

**When executing plan2beads, create native tasks to track each phase:**

```
TaskCreate: "Parse plan structure"
  description: "Extract: epic title, context sections, phases, task H3s, Depends on: lines, Files: sections."
  activeForm: "Parsing plan"

TaskCreate: "Create epic"
  description: "Write epic description to temp file. Run bd create. Capture epic ID."
  activeForm: "Creating epic"
  addBlockedBy: [parse-task-id]

TaskCreate: "Create child tasks"
  description: "Build task ID map. Validate dependencies (no forward refs, self-refs). Run bd create for each."
  activeForm: "Creating tasks"
  addBlockedBy: [create-epic-task-id]

TaskCreate: "Dependency verification"
  description: "Run: bd ready (verify independent tasks), bd blocked (verify expected blockers), bd graph (visual check)."
  activeForm: "Verifying dependencies"
  addBlockedBy: [create-tasks-id]

TaskCreate: "Final validation gate"
  description: "Verify: epic exists, all children linked, no circular deps, display summary."
  activeForm: "Running final validation"
  addBlockedBy: [dep-verify-task-id]
```

**ENFORCEMENT:**
- Each phase blocked by previous - cannot skip ahead
- Create child tasks cannot start until epic ID is captured
- Dependency verification cannot start until all tasks created
- Final validation exposes any issues before completing

**Why this matters:** plan2beads is the most complex multi-step process. Without task tracking, dependency misconfiguration is silent.

## Instructions

### Step 1: Load the Plan

**For local markdown files:**
- Use the Read tool to load the file content

**For Shortcut story IDs (SC-1234 or just 1234):**
- Run: `short story <numeric-id> -f=markdown`
- Note: Output starts with `#36578 Title` (no space after #, not valid H1)
- Extract epic title: everything after `#XXXXX ` on the first line
- Store the numeric ID for `--external-ref`

### Step 2: Parse the Plan Structure

| Element | How to Identify | Maps To |
|---------|----------------|---------|
| **Epic Title** | First H1 (`# Title`) OR first line of Shortcut output | Epic issue |
| **Context Sections** | H2 like "Problem Statement", "Executive Summary", "Goals", "Architecture" | Epic description |
| **Phase Groupings** | H2 matching "Phase N: ..." or "Stage N: ..." | Label for child tasks |
| **Individual Tasks** | H3 (`### Task N:`) with or without numbered prefix | Child tasks |
| **Task Dependencies** | `**Depends on:**` line within task | `--deps` flag |
| **Task Files** | `**Files:**` section within task | Preserved in description |
| **Success Criteria** | H2 "Success Metrics/Criteria" with checkboxes `- [ ]` | Epic acceptance criteria |
| **Key Decisions** | `## Key Decisions` section with bullet points | Epic description (prominently placed) |

**Parsing Rules:**
- H2s that are NOT phases/stages/success-metrics are context (epic description)
- Tasks inherit phase label from their containing Phase H2 (if any)
- Strip numbered prefixes ("1. Task Name" → "Task Name")
- **Parse `Depends on:` line for task-level dependencies** (see Step 4)
- **Extract `Files:` section and preserve in task description**

### Step 2b: Ask Completion Strategy

**Before creating the epic**, ask the user how they want the epic to complete:

```
How should this epic complete when all tasks are done?

1. Commit only — I'll review and push manually (Recommended)
2. Push to remote
3. Push and create a Pull Request
4. Merge to main locally (worktree workflows)
```

Map the choice to a label:

| Choice | Label |
|--------|-------|
| 1 | `completion:commit-only` |
| 2 | `completion:push` |
| 3 | `completion:push-pr` |
| 4 | `completion:merge-local` |

Store this label on the epic in Step 3. This enables `finishing-a-development-branch` to execute automatically at epic completion without prompting.

**If the user skips or doesn't choose:** Default to `completion:commit-only` (safest — no destructive actions).

### Step 3: Create the Epic

**IMPORTANT:** Use `temp/*.md` files for descriptions to avoid permission prompts from multi-line bash commands.

1. Write the epic description to a temp file using the Write tool (derive a short slug from the epic title — lowercase, hyphens for spaces — to avoid overwriting files from previous runs):
```
Write tool → temp/{title-slug}-epic.md
Content: Concatenated context sections (Problem Statement, Goals, Architecture, etc.)
Example: "Authentication System" → temp/authentication-system-epic.md
```

2. Create the epic using `--body-file` and the completion strategy label:
```bash
bd create --silent --type epic "Epic Title" --body-file temp/{title-slug}-epic.md --acceptance "Criterion 1; Criterion 2; Criterion 3" -l "completion:commit-only" -p 1
```

**IMPORTANT:** Never use `\n` or ANSI-C quoting (`$'...'`) in `--acceptance`—newlines trigger permission prompts. Use semicolons to separate criteria instead.

- Add `--external-ref "sc-1234"` for Shortcut stories
- If no H1 found, use the filename (without extension) as title

**Capture the returned ID** (e.g., `hub-abc`) - you'll need it for child tasks.

**Epic description structure:**
1. **Key Decisions** (first, for visibility when running `bd show`)
2. Problem Statement / Goals
3. Architecture / Technical approach
4. Other context sections

This ensures implementers see the "why" immediately when they check the epic.

**If Key Decisions is missing:** Warn in Step 6 summary ("Plan missing Key Decisions section") but continue - older plans should still convert successfully.

### Step 4: Create Child Tasks (Dependency-Aware)

**IMPORTANT:** Parse `**Depends on:**` line from each task to determine dependencies.

> ⚠️ **Common Mistake:** If you create tasks without `--deps`, they ALL appear in `bd ready` simultaneously. Tasks are NOT sequential by default—dependencies must be explicit.

#### 4a. Build Task ID Map

As you create tasks, maintain a mapping:
```
Task 1 → hub-abc.1
Task 2 → hub-abc.2
Task 3 → hub-abc.3
...
```

#### 4b. Parse Dependencies

For each task, look for `**Depends on:**` line:

| Depends on Value | Beads --deps |
|------------------|--------------|
| `None` | (no --deps flag) |
| `Task 1` | `--deps "hub-abc.1"` |
| `Task 1, Task 3` | `--deps "hub-abc.1,hub-abc.3"` |
| `Task 2 (User model)` | `--deps "hub-abc.2"` (ignore parenthetical) |

**Parsing regex:** `\*\*Depends on:\*\*\s*(.+)$`
- If value is "None", no dependencies
- Otherwise, extract task numbers: `Task\s+(\d+)` → map to beads IDs

**Validation:**
- **Forward references:** If Task 2 says "Depends on: Task 5" (higher number), warn and skip—forward dependencies indicate a plan ordering issue
- **Self-references:** If Task 3 says "Depends on: Task 3", warn and skip—task cannot depend on itself
- **Non-existent tasks:** If "Depends on: Task 10" when only 4 tasks exist, warn and skip
- Continue creating the task without invalid dependencies
- Report all warnings in Step 6 summary

**Edge case - No tasks found:**
If parsing finds 0 tasks (no H3 headings matching `### Task N:`):
- Warn: "No tasks found in plan - check format"
- Create epic only, no children
- Human should review and fix plan format

#### 4c. Create Tasks in Order

Create tasks **in numeric order** so dependencies can reference earlier IDs.

**IMPORTANT:** Use `temp/*.md` files for task descriptions to avoid permission prompts from multi-line bash commands.

For each task:
1. Write task description to `temp/{epic_id}-task-{n}.md` using the Write tool (where `{epic_id}` is from Step 3 and `{n}` is the task number)
2. Create the task with `--body-file temp/{epic_id}-task-{n}.md`

Each task gets its own file, prefixed by epic ID — unique across runs and avoids permission prompts.

```bash
# Task 1: No dependencies
# (Write tool creates temp/hub-abc-task-1.md)
bd create --silent --parent hub-abc "User Model" --body-file temp/hub-abc-task-1.md -p 2
# Returns: hub-abc.1

# Task 2: No dependencies (can be parallel with Task 1 at execution time)
# (Write tool creates temp/hub-abc-task-2.md)
bd create --silent --parent hub-abc "JWT Utils" --body-file temp/hub-abc-task-2.md -p 2
# Returns: hub-abc.2

# Task 3: Depends on Task 1
# (Write tool creates temp/hub-abc-task-3.md)
bd create --silent --parent hub-abc "Auth Service" --body-file temp/hub-abc-task-3.md --deps "hub-abc.1" -p 2
# Returns: hub-abc.3

# Task 4: Depends on Task 2 and Task 3
# (Write tool creates temp/hub-abc-task-4.md)
bd create --silent --parent hub-abc "Login Endpoint" --body-file temp/hub-abc-task-4.md --deps "hub-abc.2,hub-abc.3" -p 2
# Returns: hub-abc.4
```

#### 4d. Task Description Format

Include the full task content in the description, preserving structure:

```markdown
## Files
- Create: `apps/api/src/models/user.model.ts`
- Modify: `apps/api/src/models/index.ts`
- Test: `apps/api/src/__tests__/models/user.test.ts`

## Implementation Steps
**Step 1: Write the failing test**
...

**Step 2: Run test to verify it fails**
Run: `pnpm test -- --grep "user model"`
Expected: FAIL
...
```

**CRITICAL:** The `## Files` section MUST be preserved - it enables parallel execution safety.

**If `## Files` section is missing:**
- Warn: "Task N missing Files section - cannot parallelize safely"
- Still create the issue, but execution will treat it as conflicting with all others

#### 4e. Phase Labels (Optional)

If the plan uses Phase groupings, add phase labels:
```bash
bd create --silent --parent hub-abc "Task Name" -d "..." -l "phase:1" --deps "hub-abc.1" -p 2
```

If no phases, omit the `-l` flag.

#### 4f. Epic Verification Task (Required)

**Every epic MUST have ONE final verification task** that combines automated checks AND process verification in a single explicit checklist.

> **Why a single task with explicit checklist?** The planning phase succeeds because it has an explicit checklist (Plan Verification Checklist). Epic completion needs the same pattern—tell the agent exactly what to do, step by step.

Write description to temp file:
```markdown
## Epic Verification

**Complete each item. Do not close this task with any item unmarked.**

### Step 1: Review cumulative changes

Run: `git diff main...HEAD --stat`

Record: ___ files changed, ___ insertions, ___ deletions

### Step 2: Automated checks

- [ ] Tests pass: `pnpm test` → Result: ___
- [ ] Build succeeds: `pnpm build` → Result: ___
- [ ] Typecheck passes: `pnpm typecheck` → Result: ___

### Step 3: Rule-of-five on significant changes

For files with >50 lines changed (from Step 1 diff):

- [ ] Pass 1 (Draft): Structure correct?
- [ ] Pass 2 (Correctness): Any bugs?
- [ ] Pass 3 (Clarity): Understandable to newcomers?
- [ ] Pass 4 (Edge Cases): Failure modes handled?
- [ ] Pass 5 (Excellence): Would you sign your name to this?

Files reviewed: ___
Issues found and fixed: ___

### Step 4: Engineering checklist

Review the cumulative diff against the original plan:

- [ ] **Complete** — All requirements from plan addressed
- [ ] **YAGNI** — No extra features added beyond plan scope
- [ ] **Minimal** — Simplest solution that meets requirements
- [ ] **No drift** — Implementation follows plan (or deviations documented)
- [ ] **Key Decisions followed** — Matches plan's Key Decisions section

Deviations from plan (if any): ___

### Step 5: Final confirmation

- [ ] All automated checks pass
- [ ] Rule-of-five completed on significant changes
- [ ] Engineering checklist all items marked
- [ ] Ready for merge/PR
```

Create the task:
```bash
bd create --silent --parent hub-abc "Epic Verification" --body-file temp/hub-abc-verification.md --deps "hub-abc.1,hub-abc.2,..." --acceptance "All automated checks pass; Rule-of-five applied to changes >50 lines; Engineering checklist complete; No unmarked items" -p 1
```

**Note:** The `--deps` should include ALL implementation task IDs so this task only unblocks after all work is done.

**Why this works:** The checklist tells the agent exactly what to do—same pattern as the Plan Verification Checklist during planning. No ambiguity about "artifacts" or "implementation files."

### Step 5: Verify Dependency Structure

**REQUIRED:** After creating all tasks, verify the dependency structure:

```bash
# Show tasks that are ready (no blockers)
bd ready

# Show tasks that are blocked
bd blocked

# Visual dependency graph
bd graph hub-abc
```

**Check for issues:**
- Tasks with `Depends on: None` should appear in `bd ready`
- Tasks with dependencies should appear in `bd blocked`
- Graph should show expected dependency flow

### Step 6: Display Results

Show summary:
```
Created epic: hub-abc "Epic Title"

Created N implementation tasks + 1 verification task:
  Implementation tasks: hub-abc.1 through hub-abc.N
  Epic Verification: hub-abc.N+1 (blocked by all implementation tasks)

Ready (no blockers): hub-abc.1, hub-abc.2
Blocked: hub-abc.3 through hub-abc.N+1

Dependency verification:
  bd ready shows: 2 tasks ready
  bd blocked shows: N-1 tasks blocked (including verification)

Execution flow:
  1. Complete all N implementation tasks (respecting dependencies)
  2. Epic Verification task unblocks automatically
  3. Complete verification checklist (automated + rule-of-five + engineering)
  4. Close Epic Verification to complete the epic

Epic Verification task includes explicit checklist:
  - Automated checks (tests, build, typecheck)
  - Rule-of-five on changes >50 lines
  - Engineering checklist (Complete, YAGNI, Minimal, No drift, Key Decisions)

Next commands:
  bd show hub-abc        # View epic details
  bd graph hub-abc       # Visual dependency graph

═══════════════════════════════════════════════════════════════
  TO EXECUTE WITH PARALLEL SUBAGENTS:

  /clear
  execute epic hub-abc
═══════════════════════════════════════════════════════════════

Why /clear first? Maximizes context for subagents. Planning
conversation is no longer needed - beads preserves all task details.
```

## bd CLI Quick Reference

### Create Flags

| Flag | Purpose |
|------|---------|
| `--silent` | Output only ID (for capturing) |
| `--type epic` | Create epic instead of task |
| `--parent <id>` | Create as child of epic |
| `--body-file <path>` | Read description from file (use for multi-line content) |
| `-d "text"` | Description (single-line only, prefer --body-file) |
| `-l "label"` | Labels (comma-separated for multiple) |
| `-p N` | Priority (0-4, where 0=critical, 4=backlog) |
| `-e N` | Estimate in minutes (e.g., `-e 60` for 1 hour) |
| `--deps "id1,id2"` | Dependencies (blocked by these—only `blocks` type affects `bd ready`) |
| `--acceptance "text"` | Acceptance criteria (use semicolons to separate, never `\n`) |
| `--external-ref "ref"` | External link (e.g., "sc-1234") |
| `--defer "date"` | Hide from `bd ready` until date (e.g., `+1d`, `tomorrow`, `2025-01-20`) |

### Execution Flags

| Flag | Purpose |
|------|---------|
| `--claim` | Atomically set assignee + status to in_progress |
| `--suggest-next` | After close, show newly unblocked issues |

## Backward Compatibility

**Phase-based plans (old format):**
If the plan uses Phase H2 groupings WITHOUT `**Depends on:**` lines:
- Phase 0 tasks: no dependencies
- Phase N tasks: depend on ALL Phase N-1 tasks

**Task-level dependencies (new format):**
If tasks have `**Depends on:**` lines:
- Use specific task references
- Phase labels are optional (for filtering)
- This enables finer-grained parallelism
