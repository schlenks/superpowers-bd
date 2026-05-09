# Worktree Native Detection + Inline Plan Self-Review Implementation Plan

> **For Claude:** After human approval, use plan2beads to convert this plan to a beads epic, then use `superpowers-bd:subagent-driven-development` for parallel execution.

**Goal:** Adopt two upstream superpowers patterns: (1) native worktree-tool detection across `using-git-worktrees` and `finishing-a-development-branch`; (2) inline orchestrator self-review for the Plan Verification Checklist in `writing-plans` (replacing sub-agent dispatch).

**Architecture:** Skill-document edits only. Three SKILL.md files plus six reference files. No code changes outside markdown. Changes take effect on next session start (skills are loaded from disk per session).

**Tech Stack:** Markdown skill files; bash snippets quoted in skill bodies; native task tooling for verification flow.

**Key Decisions:**
- **Plan Verification Checklist becomes inline, not dispatched.** The orchestrator already has full plan context; a sub-agent would re-read from disk. -- Why: aligns with upstream's fast-inline pattern, eliminates ~10–30s sonnet dispatch, preserves all checklist items intact.
- **Keep our 6-task git-worktree fallback flow.** Only the `EnterWorktree`-native path skips it (the harness owns directory placement and gitignore concerns). -- Why: our task-tracked safety verification (gitignore check, dependency install, baseline test) is unique value over upstream; only skip steps that no longer apply.
- **Adopt upstream's submodule guard verbatim.** `git rev-parse --show-superproject-working-tree` distinguishes worktrees from submodules. -- Why: cheap one-line check; without it, `GIT_DIR != GIT_COMMON` falsely triggers in submodule contexts and silently skips worktree creation.
- **Detached HEAD reduces menu to 3 options.** Drop "Merge locally" — it's invalid when not on a named branch. -- Why: harness-managed worktrees frequently present as detached HEAD; offering an invalid option produces user confusion or shell errors.
- **Provenance-based cleanup.** Only remove worktrees whose path is under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/`. Harness-owned workspaces are left alone. -- Why: upstream's pattern; removing harness-created worktrees creates phantom state in the harness's worktree registry.
- **No new tests for this change.** All edits are skill prose; behavior changes manifest on next session start. -- Why: rule-of-five-plans review + manual smoke test on next plan invocation is sufficient; planted-bug behavioral tests are a separate concern (deferred).

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `skills/using-git-worktrees/SKILL.md` | Worktree-creation entry point: env detection, consent, native-tool preference, fallback flow | Modify |
| `skills/using-git-worktrees/references/red-flags.md` | Never/Always lists | Modify |
| `skills/using-git-worktrees/references/creation-steps.md` | TaskCreate blocks for fallback flow (clarify scope) | Modify |
| `skills/finishing-a-development-branch/SKILL.md` | Branch completion: env detection, menu selection, provenance-based cleanup | Modify |
| `skills/finishing-a-development-branch/references/worktree-cleanup.md` | Provenance check + cleanup commands | Modify |
| `skills/writing-plans/SKILL.md` | Mandatory tasks 1–7 description: Task 2 is inline, dispatch is for tasks 3–7 only | Modify |
| `skills/writing-plans/references/task-enforcement-examples.md` | TaskCreate blocks + dispatch loop (Task 2 inline; loop covers tasks 3–7) | Modify |
| `skills/writing-plans/references/verification-dispatch.md` | Remove Checklist Pass template; note orchestrator handles checklist inline | Modify |
| `skills/writing-plans/references/announcements-protocol.md` | Update Task 2 announcement (inline, not dispatched) | Modify |
| `.claude-plugin/plugin.json` | Plugin version bump 5.6.4 → 5.6.5 | Modify |
| `.claude-plugin/marketplace.json` | Synced from plugin.json | Modify |
| `CHANGELOG.md` | New v5.6.5 entry | Modify |
| `RELEASE-NOTES.md` | New v5.6.5 release notes | Modify |

**No new files.** All work is incremental edits to existing skills and release artifacts.

---

## Tasks

### Task 1: Add Step 0 (env detection + submodule guard + consent) to using-git-worktrees
**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/using-git-worktrees/SKILL.md`

**Purpose:** Detect when we're already in an isolated workspace (skip creation) and gate creation on user consent when invoked from non-explicit contexts. Adopts upstream's Step 0 verbatim with our skill's announcement and our existing CLAUDE.md priority preserved.

**Not In Scope:** Native-tool detection (Task 2). Fallback flow restructuring (Task 3).

**Gotchas:**
- `GIT_DIR != GIT_COMMON` is also true inside submodules — the submodule guard line is load-bearing.
- Honor existing declared preference (CLAUDE.md, prior instructions) without asking again.

**Step 1: Insert Step 0 section after the "Announce at start" line in SKILL.md**

Add this content immediately after line 13 of the current SKILL.md (the "Announce at start" line):

```markdown
## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Submodule guard:** `GIT_DIR != GIT_COMMON` is also true inside git submodules. Before concluding "already in a worktree," verify you are not in a submodule:

```bash
# If this returns a path, you're in a submodule, not a worktree — treat as normal repo
git rev-parse --show-superproject-working-tree 2>/dev/null
```

**If `GIT_DIR != GIT_COMMON` (and not a submodule):** You are already in a linked worktree. Skip to Step 3 (Project Setup) below. Do NOT create another worktree.

Report with branch state:
- On a branch: "Already in isolated workspace at `<path>` on branch `<name>`."
- Detached HEAD: "Already in isolated workspace at `<path>` (detached HEAD, externally managed). Branch creation needed at finish time."

**If `GIT_DIR == GIT_COMMON` (or in a submodule):** You are in a normal repo checkout.

Has the user already indicated their worktree preference (CLAUDE.md, brainstorming spec, prior instructions)? If yes, honor it without asking. If no, ask for consent before creating a worktree:

> "Would you like me to set up an isolated worktree? It protects your current branch from changes."

If the user declines consent, work in place and skip to Step 3 (Project Setup).
```

**Step 2: Verify the insertion is well-formed**

Run: `head -60 skills/using-git-worktrees/SKILL.md`
Expected: Step 0 section appears after announcement, before Directory Selection Process.

**Step 3: Commit**

```bash
git add skills/using-git-worktrees/SKILL.md
git commit -m "feat(worktrees): add Step 0 environment detection and consent gating"
```

---

### Task 2: Add Step 1a native-tool detection to using-git-worktrees
**Depends on:** Task 1
**Complexity:** standard
**Files:**
- Modify: `skills/using-git-worktrees/SKILL.md`

**Purpose:** When the harness provides a native worktree tool (e.g., `EnterWorktree`, `WorktreeCreate`), prefer it over `git worktree add`. Native tools manage placement, branch creation, and lifecycle hooks (`WorktreeCreate`/`WorktreeRemove`). Using `git worktree add` when native tools exist creates phantom state.

**Not In Scope:** Restructuring the existing fallback flow (Task 3).

**Gotchas:**
- Claude Code provides `EnterWorktree`/`ExitWorktree` (deferred tools). Probe by tool-availability check at skill execution time.
- Native tools handle dependency install and baseline tests differently — they may delegate to the harness, not run our task-tracked flow.

**Step 1: Replace the "Directory Selection Process" section header with a "Step 1: Create Isolated Workspace" parent section, and insert Step 1a before the existing directory-selection content**

Restructure SKILL.md so that:
- Lines 15–46 (current Directory Selection Process + Safety Verification + Creation Steps headings) become "## Step 1: Create Isolated Workspace" with two subsections: Step 1a (native tool) and Step 1b (git fallback).
- Step 1a content (new):

```markdown
### Step 1a: Native Worktree Tool (preferred)

The user has consented to an isolated workspace (Step 0). Do you already have a way to create one? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip directly to Step 3 (Project Setup).

Native tools manage directory placement, branch creation, and harness lifecycle hooks (`WorktreeCreate`/`WorktreeRemove`). Using `git worktree add` when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native worktree tool available.
```

- Step 1b becomes the wrapper for our existing directory-selection + safety-verification + creation-steps flow:

```markdown
### Step 1b: Git Worktree Fallback

**Only use this if Step 1a does not apply** — you have no native worktree tool. Create a worktree manually using git via the task-tracked flow below.

Follow this priority order to select the directory:

1. **Check existing directories** -- Use `.worktrees/` or `worktrees/` if present (`.worktrees/` wins if both exist)
2. **Check CLAUDE.md** -- Use any worktree directory preference specified there
3. **Ask user** -- Offer `.worktrees/` (project-local) or `~/.config/superpowers/worktrees/<project>/` (global)

See `references/directory-selection.md` for full bash commands and ask-user flow.

**Safety verification (project-local only):**
1. **Check gitignore** -- `git check-ignore -q .worktrees` to verify directory is ignored
2. **Add if needed** -- Add to `.gitignore` if not ignored
3. **Commit** -- Commit the `.gitignore` change before proceeding

See `references/safety-verification.md` for full verification protocol.

**Creation Steps (Task-Tracked):** Create 6 native tasks, each blocked by the previous (non-skippable sequence):

1. **Select worktree directory location** -- Check existing dirs, CLAUDE.md, or ask user
2. **Verify gitignore for project-local directory** -- Run `git check-ignore`, add to `.gitignore` if needed
3. **Create worktree** -- `git worktree add <path> -b <branch>`
4. **Install dependencies** -- Auto-detect project type, run appropriate install command
5. **Run baseline tests** -- Capture output showing pass/fail; ask user if tests fail
6. **Worktree ready** -- Report location and test status; only complete if tests passed

See `references/creation-steps.md` for full TaskCreate blocks, bash commands, and setup detection.
```

**Step 2: Add Step 3 (Project Setup) and Step 4 (Verify Clean Baseline) inline summaries**

These already exist conceptually (referenced from creation-steps.md). Add a thin in-skill summary so the native-tool path knows what to do after using `EnterWorktree`:

```markdown
## Step 3: Project Setup

After workspace is established (whether via native tool or git fallback), auto-detect and run setup:

```bash
if [ -f package.json ]; then npm install; fi
if [ -f Cargo.toml ]; then cargo build; fi
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi
if [ -f go.mod ]; then go mod download; fi
```

## Step 4: Verify Clean Baseline

Run the project test suite. Report pass/fail. If failing, ask before proceeding.
```

**Step 3: Update Quick Reference table to include native-tool row**

Modify the Quick Reference table to add (at top):

```markdown
| Already in linked worktree (Step 0) | Skip creation, go to Step 3 |
| In a submodule | Treat as normal repo (Step 0 guard) |
| Native worktree tool available | Use it (Step 1a), skip fallback |
| No native tool | Git worktree fallback (Step 1b) |
```

**Step 4: Verify the rewrite is well-formed**

Run: `head -120 skills/using-git-worktrees/SKILL.md`
Expected: Step 0 → Step 1 (1a + 1b) → Step 3 → Step 4 → Quick Reference, all in order.

**Step 5: Commit**

```bash
git add skills/using-git-worktrees/SKILL.md
git commit -m "feat(worktrees): prefer native worktree tools over git fallback"
```

---

### Task 3: Update using-git-worktrees reference files (red-flags.md)
**Depends on:** Task 2
**Complexity:** simple
**Files:**
- Modify: `skills/using-git-worktrees/references/red-flags.md`

**Purpose:** Reflect new rules: never `git worktree add` when native tool available; always run Step 0 detection first.

**Not In Scope:** Other reference files (creation-steps.md and directory-selection.md describe the fallback path which still applies; no changes needed).

**Step 1: Rewrite red-flags.md content**

Replace existing content with:

```markdown
# Red Flags

## Never

- Create a worktree when Step 0 detects existing isolation
- Use `git worktree add` when you have a native worktree tool (`EnterWorktree`, `WorktreeCreate`, `/worktree`, `--worktree`). #1 mistake — if it exists, use it.
- Skip Step 1a by jumping straight to Step 1b's git commands
- Create worktree without verifying it's ignored (project-local fallback only)
- Skip baseline test verification
- Proceed with failing tests without asking
- Assume directory location when ambiguous
- Skip CLAUDE.md check

## Always

- Run Step 0 detection first
- Prefer native tools over git fallback (Step 1a beats Step 1b)
- Honor existing declared preference (CLAUDE.md, prior instructions) without re-asking
- Follow directory priority: existing > CLAUDE.md > ask
- Verify directory is ignored for project-local fallback
- Auto-detect and run project setup
- Verify clean test baseline
```

**Step 2: Verify**

Run: `cat skills/using-git-worktrees/references/red-flags.md`
Expected: Updated Never/Always lists with native-tool guidance at top of Never.

**Step 3: Commit**

```bash
git add skills/using-git-worktrees/references/red-flags.md
git commit -m "docs(worktrees): update red flags for native-tool preference"
```

---

### Task 4: Add environment detection + detached HEAD menu to finishing-a-development-branch
**Depends on:** None (parallel-safe with Tasks 1–3)
**Complexity:** standard
**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`

**Purpose:** Detect workspace state before presenting menu. Show 3 options instead of 4 when on detached HEAD (since "Merge locally" is invalid). Adopts upstream's environment-detection pattern while preserving our beads-aware Step 0 and pre-merge simplification (Step 1.5).

**Not In Scope:** Provenance-based cleanup (Task 5) — addressed separately.

**Gotchas:**
- Detached HEAD case must come AFTER our existing Step 0 (epic verification) and Step 1 (test verification) and Step 1.5 (pre-merge simplification) — those gates apply regardless of HEAD state.
- Our existing Step 2 ("Determine Base Branch") and Step 3 ("Present Options") need restructuring: insert env detection before Step 3, branch the menu by detection result.

**Step 1: Insert "Step 1.7: Detect Environment" section after Step 1.5 (Pre-Merge Simplification) in SKILL.md**

Add a new section after the Step 1.5 paragraph (currently ends at line 33):

```markdown
### Step 1.7: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

This determines which menu to show in Step 3:

| State | Menu | Cleanup behavior |
|-------|------|------------------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (Step 5) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |
```

**Step 2: Update Step 3 Manual ("Present Options") to branch by HEAD state**

Replace the current Step 3 Manual content (lines 57–66) with:

```markdown
### Step 3 Manual: Present Options

If no `completion:*` label, present options based on HEAD state from Step 1.7.

**On a named branch (normal repo or named-branch worktree) — present exactly these 4 choices:**

1. Merge back to \<base-branch\> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

**On detached HEAD (externally managed workspace) — present exactly these 3 choices:**

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Keep options concise. See `references/completion-strategies.md`.
```

**Step 3: Verify**

Run: `grep -n "Step 1.7\|Step 3 Manual\|detached HEAD" skills/finishing-a-development-branch/SKILL.md`
Expected: Step 1.7 detection block present; Step 3 Manual branches by HEAD state; detached HEAD case mentioned.

**Step 4: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(finishing): add env detection and detached HEAD menu"
```

---

### Task 5: Add provenance-based cleanup to finishing-a-development-branch
**Depends on:** Task 4
**Complexity:** standard
**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`
- Modify: `skills/finishing-a-development-branch/references/worktree-cleanup.md`

**Purpose:** Only remove worktrees we created (path under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/`). Harness-owned worktrees should be exited via the harness's tool, not removed by us.

**Not In Scope:** Logic for choosing native exit tool — keep as "use platform tool if available, else leave in place."

**Gotchas:**
- `cd` to main repo root before `git worktree remove` — running from inside the worktree fails silently.
- `git worktree prune` after removal handles stale registrations from squash-merged PRs.

**Step 1: Replace Step 5 in SKILL.md**

Replace lines 73–75 (current Step 5: Cleanup Worktree) with:

```markdown
### Step 5: Cleanup Workspace

**Only runs for Options 1 and 4** (Merge locally and Discard). Options 2 and 3 always preserve the worktree.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If worktree path is under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/`:** Superpowers-bd created this worktree — we own cleanup.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The harness owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool (e.g., `ExitWorktree`), use it. Otherwise, leave the workspace in place.

See `references/worktree-cleanup.md` for full provenance check.
```

**Step 2: Rewrite worktree-cleanup.md**

Replace existing content with:

```markdown
# Worktree Cleanup (Provenance-Based)

Step 5 detail: Only remove worktrees we created.

## Detect Provenance

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

## Decision Matrix

| Path under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/` | Action |
|-------|--------|
| Yes | We own it — `git worktree remove` (Options 1, 4) |
| No (harness-owned) | Use harness exit tool (`ExitWorktree`) if available; otherwise leave in place |
| `GIT_DIR == GIT_COMMON` | Normal repo — nothing to clean |

## Removal Commands

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune
```

## Common Mistakes

- **Running `git worktree remove` from inside the worktree** — fails silently. Always `cd` to main repo root first.
- **Removing harness-owned worktrees** — creates phantom state in the harness's worktree registry. Use the harness's exit tool instead.
- **Skipping `git worktree prune`** — leaves stale registrations from squash-merged PRs.

## Options 2 and 3

Keep worktree. Do not clean up.
```

**Step 3: Verify**

Run: `grep -n "provenance\|GIT_DIR\|harness-owned" skills/finishing-a-development-branch/SKILL.md`
Run: `cat skills/finishing-a-development-branch/references/worktree-cleanup.md`
Expected: Provenance language in SKILL.md Step 5; rewritten worktree-cleanup.md with decision matrix.

**Step 4: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md skills/finishing-a-development-branch/references/worktree-cleanup.md
git commit -m "feat(finishing): provenance-based worktree cleanup"
```

---

### Task 6: Convert Plan Verification Checklist to inline orchestrator self-review
**Depends on:** None (parallel-safe with Tasks 1–5)
**Complexity:** standard
**Files:**
- Modify: `skills/writing-plans/SKILL.md`
- Modify: `skills/writing-plans/references/task-enforcement-examples.md`
- Modify: `skills/writing-plans/references/verification-dispatch.md`
- Modify: `skills/writing-plans/references/announcements-protocol.md`

**Purpose:** The orchestrator just wrote the plan and has full context. Dispatching a sonnet sub-agent to read the plan from disk and run a 9-item checklist is wasted overhead. Run the checklist inline. The reference doc cleanup (removing the dispatched Checklist Pass template, updating announcements protocol) is the direct consequence of the same decision and belongs in the same commit.

**Not In Scope:** Removing the checklist itself (its 9 items are valuable). Changing rule-of-five-plans dispatch (Tasks 3–7 stay as sonnet sub-agents — they apply distinct lenses worth fresh context).

**Gotchas:**
- The dispatch loop "Tasks 2–7" wording must change to "Tasks 3–7" everywhere it appears.
- `verification-dispatch.md` has a Checklist Pass template (lines 56–95 of that file) that becomes vestigial — delete it.
- `announcements-protocol.md` has a "Before Each Verification Sub-Agent Dispatch" section that implicitly includes the checklist; clarify checklist is announced inline before dispatching tasks 3–7.

**Step 1: Update writing-plans/SKILL.md mandatory-tasks paragraph**

Replace the "Tasks 2-7: Sub-Agent Dispatch" paragraph (line 31 of SKILL.md) with:

```markdown
**Task 2: Inline Self-Review.** The orchestrator runs the Plan Verification Checklist directly — no sub-agent dispatch. The orchestrator just wrote the plan and has full context; a sub-agent would only re-read it from disk. Mark task 2 in_progress, run each checklist item against the plan, edit the plan to fix any issues, mark task 2 completed, then proceed to task 3.

**Tasks 3–7: Sub-Agent Dispatch.** After task 2 completes, dispatch each rule-of-five-plans pass sequentially as a **sonnet** sub-agent using the template in `references/verification-dispatch.md`. Mark each native task in_progress before dispatch, completed after collecting verdict. If any verdict is BLOCKED/FAIL, stop and report to user. After all 5 verdicts collected, assemble Verification Record (see `references/verification-footer.md`) and append to plan file.
```

**Step 2: Update task-enforcement-examples.md dispatch loop**

Replace lines 48–63 of `references/task-enforcement-examples.md` with:

```markdown
## Task 2: Inline Self-Review

After task 1 completes, the orchestrator runs the Plan Verification Checklist inline:

```
TaskUpdate(checklist-task-id, status: "in_progress")
→ Announce: "Running Plan Verification Checklist inline..."
→ Read the plan file
→ For each item (Complete, Accurate, Commands valid, YAGNI, Minimal, Not over-engineered, Key Decisions, Context sections, File Structure complete):
    - Evaluate against the plan
    - Use Glob/Grep to verify file paths and commands where needed
    - Edit the plan inline to fix any issues
→ Announce per-item results (see references/announcements-protocol.md)
→ If any item fails irrecoverably: stop, report to user
→ TaskUpdate(checklist-task-id, status: "completed")
```

## Sub-Agent Dispatch (Tasks 3–7)

After task 2 completes, drive this loop for tasks 3–7:

```
TaskUpdate(id, status: "in_progress")
→ Announce: "Dispatching verification sub-agent: {pass_name}..."
→ Task(subagent_type: "general-purpose", model: "sonnet",
       description: "Verify plan: {pass_name}",
       prompt: <verification template with pass definition inlined>)
→ Collect verdict
→ Announce: "{pass_name} verdict: {STATUS} — {SUMMARY}"
→ If BLOCKED/FAIL: stop, report to user
→ TaskUpdate(id, status: "completed")
→ Next task
```

See `references/verification-dispatch.md` for full prompt templates and pass definitions.
```

**Step 3: Remove Checklist Pass template from verification-dispatch.md**

In `references/verification-dispatch.md`:
1. Update the "Dispatch Flow" section's `for each pass in [...]` line: change `[checklist, draft, feasibility, completeness, risk, optimality]` to `[draft, feasibility, completeness, risk, optimality]`.
2. Update step counts in the dispatch flow: was "After all 6 passes", now "After all 5 passes".
3. Delete the "Prompt Template — Checklist Pass" section entirely (lines 56–95 of that file). The rule-of-five passes template remains.
4. Add a one-sentence note at the top of the file: "The Plan Verification Checklist (task 2) is run inline by the orchestrator, not dispatched. This file describes only the 5 rule-of-five passes (tasks 3–7)."
5. Update the "Error Handling" section's "FAIL on checklist" bullet — remove it (no checklist sub-agent any more).

**Step 4: Update announcements-protocol.md**

In `references/announcements-protocol.md`:
1. Add a new section between "After Draft Plan Saved" and "Before Each Verification Sub-Agent Dispatch" titled "Plan Verification Checklist (Inline)":

```markdown
## Plan Verification Checklist (Inline)

Mark task 2 in_progress, then announce:

```
Running Plan Verification Checklist inline...
```

After completing the checklist (and any inline fixes), announce per-item results:

```
Plan Verification Checklist results:
- Complete: {check/cross} {explanation}
- Accurate: {check/cross} {explanation}
- Commands valid: {check/cross} {explanation}
- YAGNI: {check/cross} {explanation}
- Minimal: {check/cross} {explanation}
- Not over-engineered: {check/cross} {explanation}
- Key Decisions documented: {check/cross} {explanation}
- Context sections present: {check/cross} {explanation}
- File Structure complete: {check/cross} {explanation}

{N} fixes applied inline. Proceeding to rule-of-five-plans dispatch.
```

Then mark task 2 completed and proceed to task 3.
```

2. Remove the "for the checklist pass, include the per-item results" sub-block from the existing "After Each Verdict Collected" section (lines 49–62), since the checklist is no longer a dispatched verdict.

**Step 5: Verify**

Run: `grep -n "inline\|Tasks 3" skills/writing-plans/SKILL.md skills/writing-plans/references/task-enforcement-examples.md`
Expected: Inline self-review language in both files; "Tasks 3–7" wording replaces "Tasks 2–7".

Run: `grep -n "checklist\|inline" skills/writing-plans/references/verification-dispatch.md skills/writing-plans/references/announcements-protocol.md`
Expected: verification-dispatch.md mentions checklist only in the "inline" disclaimer note; announcements-protocol.md has new "Plan Verification Checklist (Inline)" section with per-item announcement template.

**Step 6: Commit**

```bash
git add skills/writing-plans/SKILL.md skills/writing-plans/references/task-enforcement-examples.md skills/writing-plans/references/verification-dispatch.md skills/writing-plans/references/announcements-protocol.md
git commit -m "feat(writing-plans): convert Plan Verification Checklist to inline self-review"
```

---

### Task 7: Update creation-steps.md scope clarification
**Depends on:** Task 2
**Complexity:** simple
**Files:**
- Modify: `skills/using-git-worktrees/references/creation-steps.md`

**Purpose:** Clarify that the 6-task creation flow applies only to the git-worktree fallback path (Step 1b). Native-tool path skips this entirely.

**Step 1: Add a one-line scope note at the top of creation-steps.md**

Insert after line 1 (`# Creation Steps (Full Detail)`):

```markdown
> **Scope:** This file describes the **Step 1b git-worktree fallback** flow. If a native worktree tool (`EnterWorktree`, etc.) is available, Step 1a applies and the harness manages directory placement, branch creation, and lifecycle — the task-tracked flow below does NOT apply.
```

**Step 2: Verify**

Run: `head -10 skills/using-git-worktrees/references/creation-steps.md`
Expected: Scope note present at top.

**Step 3: Commit**

```bash
git add skills/using-git-worktrees/references/creation-steps.md
git commit -m "docs(worktrees): clarify creation-steps applies to git fallback only"
```

---

### Task 8: Bump plugin version to 5.6.5 and update release artifacts
**Depends on:** Tasks 1–7
**Complexity:** simple
**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json` (synced via script)
- Modify: `CHANGELOG.md`
- Modify: `RELEASE-NOTES.md`

**Purpose:** Cut a v5.6.5 release that ships these skill updates.

**Step 1: Bump version in plugin.json**

Edit `.claude-plugin/plugin.json` to change `"version": "5.6.4"` to `"version": "5.6.5"`.

**Step 2: Sync marketplace.json**

```bash
./scripts/sync-plugin-version.sh
```

Expected: `marketplace.json` updated to match `plugin.json`.

**Step 3: Add CHANGELOG.md entry**

Add a new entry at the top under a heading like:

```markdown
## v5.6.5 — 2026-05-09

**Worktree native-tool detection (using-git-worktrees):**
- Step 0: detect existing isolation via `GIT_DIR != GIT_COMMON` (with submodule guard)
- Consent gating before creation when no preference declared
- Step 1a: prefer native worktree tools (`EnterWorktree`, `WorktreeCreate`, `--worktree`) over `git worktree add`
- Step 1b: existing 6-task git fallback flow preserved

**Branch finishing (finishing-a-development-branch):**
- Environment detection chooses menu (4 options on named branch, 3 options on detached HEAD)
- Provenance-based cleanup: only remove worktrees under `.worktrees/`, `worktrees/`, or `~/.config/superpowers/worktrees/`; leave harness-owned workspaces alone

**Plan verification (writing-plans):**
- Plan Verification Checklist (task 2) is now inline orchestrator self-review, not a sonnet sub-agent dispatch
- Tasks 3–7 (rule-of-five-plans passes) continue to dispatch sub-agents as before
- ~10–30s saved per plan; same 9-item checklist coverage
```

**Step 4: Add RELEASE-NOTES.md entry**

Add a new section at the top mirroring the CHANGELOG entry but in narrative form.

**Step 5: Commit and tag**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md RELEASE-NOTES.md
git commit -m "Release v5.6.5"
claude plugin tag -m "Release %s" --push
```

**Expected:** Tag `superpowers-bd--v5.6.5` created and pushed; marketplace.json validates against plugin.json.

---

## Verification

Each task includes inline verification steps (grep/head checks). Cross-task acceptance:

- **using-git-worktrees:** Step 0 → Step 1a → Step 1b → Step 3 → Step 4 flow reads coherently; red-flags.md Never list leads with native-tool rule; creation-steps.md scope note present.
- **finishing-a-development-branch:** Step 1.7 detection present; Step 3 Manual branches on HEAD state; Step 5 contains provenance decision matrix; worktree-cleanup.md rewritten.
- **writing-plans:** SKILL.md says "inline" for task 2 and "Tasks 3–7" for sub-agent dispatch; verification-dispatch.md has top-of-file disclaimer and no Checklist Pass template; announcements-protocol.md has new inline checklist section.
- **Release (Task 8):** `plugin.json` and `marketplace.json` both show `5.6.5`; CHANGELOG.md has v5.6.5 entry; tag `superpowers-bd--v5.6.5` exists and `git push` succeeded.

---

## Execution Notes

- **Tasks 1–3 form one chain (worktree create flow).** Tasks 4–5 form another (worktree finish flow). These two chains are parallel-safe with each other — different files, no shared state.
- **Task 6 is the complete plan review flow** (SKILL.md + task-enforcement-examples.md + verification-dispatch.md + announcements-protocol.md in one commit). Parallel-safe with the worktree chains.
- **Task 7 depends on Task 2** but is otherwise standalone; can run after Task 2.
- **Task 8 depends on all of Tasks 1–7** (it's the release task).

For SDD: 3 parallel waves possible:
- Wave 1: Tasks 1, 4, 6 (independent starting points)
- Wave 2: Task 2 (after Task 1); Task 5 (after Task 4) — these run in parallel
- Wave 2b: Tasks 3 and 7 (both after Task 2, parallel with each other — different files); Task 5 may already be complete
- Wave 3: Task 8 (after all)

> **Note for SDD orchestrator:** Task 3 depends on Task 2 (sequential within the worktree-create chain). Do NOT dispatch Tasks 2 and 3 simultaneously. Tasks 3 and 7 are safe to run in parallel (red-flags.md vs creation-steps.md — no shared files).

## Rollback

These are markdown skill edits. Rollback is `git revert <commit-sha>` for the offending task's commit. The version bump (Task 8) can be reverted independently — drop the v5.6.5 tag (`git tag -d superpowers-bd--v5.6.5 && git push --delete origin superpowers-bd--v5.6.5`) before reverting the version commit.

---

## Verification Record

### Plan Verification Checklist (Inline)
| Check | Status | Notes |
|-------|--------|-------|
| Complete | ✓ | Both adoption items + release task; 9→8 tasks after Optimality merge |
| Accurate | ✓ | All 13 file paths verified to exist; line numbers correct vs live files |
| Commands valid | ✓ | sync-plugin-version.sh exists; claude plugin tag available (min 2.1.133) |
| YAGNI | ✓ | Each task traces to a stated requirement |
| Minimal | ✓ | Edits-only, no new files; tests deferred per Key Decision |
| Not over-engineered | ✓ | Reuses existing release tooling |
| Key Decisions documented | ✓ | 6 decisions with rationale |
| Context sections present | ✓ | Purpose on 9/9, Not In Scope on 7/9, Gotchas on 4/9 |
| File Structure complete | ✓ | Every Files: entry traces to File Structure table |

0 fixes applied inline.

### Rule-of-Five-Plans Passes
| Pass | Status | Changes | Summary |
|------|--------|---------|---------|
| Draft | EDITED | 1 | Added top-level Verification section with cross-task acceptance criteria |
| Feasibility | EDITED | 1 | Fixed `cat \| head` pipe violation in Task 2 verify step |
| Completeness | CLEAN | 0 | All adoption sub-requirements traced to tasks; every task has required sections |
| Risk | EDITED | 1 | Corrected Wave 2 execution note (Task 3 sequential, not parallel with Task 2) |
| Optimality | EDITED | 6 | Merged Tasks 6+7 into single Task 6 (writing-plans references for one decision); renumbered downstream tasks |
