# SDD Status Protocol, File Structure Mapping & Escalation Guidance Implementation Plan

> **For Claude:** After human approval, use plan2beads to convert this plan to a beads epic, then use `superpowers-bd:subagent-driven-development` for parallel execution.

**Goal:** Add structured implementer status reporting (DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT), file structure mapping to writing-plans, and escalation guidance to the implementer prompt — enabling the SDD controller to route by status instead of binary PASS/FAIL.

**Architecture:** Three coordinated changes to the SDD pipeline: (1) writing-plans gets a File Structure section that plans file responsibilities before task decomposition, (2) the implementer prompt gains Code Organization guidance, escalation permission, and a 4-status verdict format, (3) the SDD controller gains status-aware routing with model upgrades, re-dispatch, and human escalation paths.

**Tech Stack:** Markdown skill files (no executable code changes)

**Key Decisions:**
- **Verdict format:** Expand from PASS/FAIL to DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT — backward-compatible since DONE maps to old PASS behavior and all existing fields are preserved for DONE/DONE_WITH_CONCERNS statuses
- **BLOCKED/NEEDS_CONTEXT report format:** These verdicts omit COMMIT/FILES/TESTS/SCOPE fields (no meaningful work done) but still write a beads report describing what was attempted and what's needed — preserves audit trail
- **Re-dispatch ceiling:** Max 2 re-dispatches for NEEDS_CONTEXT before escalating to human — prevents infinite context-chasing loops while giving the controller two chances to fix the problem
- **File Structure placement:** Between Plan Document Header and Task Structure in writing-plans — establishes file architecture before task decomposition, which is the natural planning sequence
- **Architecture checks in code reviewer:** Add to existing code-quality-reviewer-prompt.md append block — the reviewer should verify implementations follow the planned file structure

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `skills/writing-plans/SKILL.md` | Plan writing skill definition | Modify: add File Structure section, update checklist and Remember list |
| `skills/writing-plans/references/file-lists.md` | File list format reference | Modify: reference File Structure table as authoritative source |
| `skills/writing-plans/references/verification-dispatch.md` | Verification pass definitions | Modify: add File Structure check to checklist and completeness passes |
| `skills/subagent-driven-development/implementer-prompt.md` | Implementer subagent template | Modify: add Code Organization, escalation guidance, 4-status verdict |
| `skills/subagent-driven-development/SKILL.md` | SDD skill definition | Modify: add status handling section, update state machine |
| `skills/subagent-driven-development/background-execution.md` | Background polling and routing | Modify: update on_implementer_complete with status routing |
| `skills/subagent-driven-development/code-quality-reviewer-prompt.md` | Code review dispatch template | Modify: add architecture checks to append block |
| `skills/subagent-driven-development/failure-recovery.md` | Failure playbooks | Modify: add BLOCKED/NEEDS_CONTEXT playbooks |
| `skills/subagent-driven-development/checkpoint-recovery.md` | Checkpoint schema and recovery | Modify: add escalated_tasks field to schema |

---

### Task 1: Add File Structure section to writing-plans
**Depends on:** None
**Complexity:** simple
**Files:**
- Modify: `skills/writing-plans/SKILL.md:34-56` (insert File Structure section between Plan Document Header and Task Structure)
- Modify: `skills/writing-plans/references/file-lists.md:1-5` (add reference to File Structure table)
- Modify: `skills/writing-plans/references/verification-dispatch.md:64-93` (add File Structure checks to checklist and completeness passes)

**Purpose:** Establish file responsibility mapping before task decomposition so tasks are decomposed along file boundaries, reducing wave file conflicts during SDD execution.

**Not In Scope:** Changing the plan document header format. Changing task structure format. Adding new reference files.

**Step 1: Add File Structure section to SKILL.md**

Insert the following between the "Plan Document Header" section (after `Key Decisions: 3-5 decisions implementers might question...`) and the "Task Structure" section:

```markdown
## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

```markdown
| File | Responsibility | Action |
|------|---------------|--------|
| `exact/path/to/file.py` | One clear responsibility | Create |
| `exact/path/to/existing.py` | One clear responsibility | Modify |
| `tests/exact/path/to/test.py` | Tests for file.py | Create |
```

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- Prefer smaller, focused files. Files that can be held in context at once produce more reliable edits.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If a file has grown unwieldy, including a split in the plan is reasonable.

This structure informs task decomposition. Each task's `Files:` section must reference entries from this table — no task should introduce files not listed here.
```

**Step 2: Add File Structure check to Plan Verification Checklist in SKILL.md**

Add this line to the checklist (after `Context sections present`):

```markdown
- **File Structure complete** -- Every file in task `Files:` sections appears in File Structure table? No undeclared files?
```

**Step 3: Add File Structure to Remember list in SKILL.md**

Add this line to the Remember list:

```markdown
- **File Structure table before tasks — tasks reference it, never introduce undeclared files**
```

**Step 4: Update references/file-lists.md**

Add the following paragraph after the existing "## Format" section heading, before the code block:

```markdown
The plan's **File Structure** table is the authoritative source for all files. Every file listed in a task's `Files:` section must appear in the File Structure table. The table is written before tasks are defined — task decomposition follows file boundaries.
```

**Step 5: Update references/verification-dispatch.md checklist pass**

Add this item to the checklist pass items (line ~73, after `Context sections present`):

```markdown
- **File Structure complete** — Every file in task `Files:` sections appears in File Structure table? No undeclared files?
```

**Step 6: Update references/verification-dispatch.md completeness pass**

Add this item to the Completeness pass checklist (line ~128, after `Depends on:, Complexity:, and Files: sections on every task`):

```markdown
- File Structure table present with all files mapped to responsibilities
- Every task `Files:` entry traceable to File Structure table
```

**Step 7: Commit**

```bash
git add skills/writing-plans/SKILL.md skills/writing-plans/references/file-lists.md skills/writing-plans/references/verification-dispatch.md
git commit -m "feat(writing-plans): add File Structure section for pre-task file responsibility mapping"
```

---

### Task 2: Add Code Organization, Escalation Guidance, and Status Protocol to implementer-prompt.md
**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/subagent-driven-development/implementer-prompt.md`

**Purpose:** Give implementers structured guidance on file organization and explicit permission to escalate, replacing the binary PASS/FAIL verdict with a 4-status protocol that enables smarter controller routing.

**Not In Scope:** Changing the beads report format. Changing the self-read pattern (bd show). Changing the wave file map structure.

**Gotchas:** The prompt is inside a markdown code fence (` ``` `) that starts at line 3 and ends at line 118. All edits must stay inside this fence. The verdict format must remain parseable by the orchestrator — keep the `KEY: VALUE` format with one field per line.

**Step 1: Add Code Organization section**

Insert the following after the "Your Job" section (after `**If you need files outside your allowed list:** STOP immediately and ask. Do not modify them.`) and before "Before Reporting Back: Self-Review":

```markdown
    ## Code Organization

    - Follow the file structure from the plan (see Key Decisions and File Structure sections in epic)
    - Each file should have one clear responsibility with a well-defined interface
    - If a file you're creating grows beyond the plan's intent, report DONE_WITH_CONCERNS — don't split files without plan guidance
    - If an existing file you're modifying is already large or tangled, note it as a concern in your report
    - In existing codebases, follow established patterns. Improve code you're touching, but don't restructure outside your task scope
```

**Step 2: Add escalation guidance section**

Insert the following after the Code Organization section and before "Before Reporting Back: Self-Review":

```markdown
    ## When You're in Over Your Head

    It is always OK to stop and escalate. Bad work is worse than no work.

    **STOP and report BLOCKED or NEEDS_CONTEXT when:**
    - The task requires architectural decisions with multiple valid approaches
    - You need to understand code beyond what was provided and can't find clarity
    - You feel uncertain about whether your approach is correct
    - The task involves restructuring existing code beyond what the plan anticipated
    - You've been reading file after file without making progress

    **How to escalate:** Use BLOCKED or NEEDS_CONTEXT verdict. Describe specifically
    what you're stuck on, what you've tried, and what kind of help you need. The
    controller can provide more context, re-dispatch with a more capable model, or
    break the task into smaller pieces.
```

**Step 3: Replace verdict format**

Replace the current verdict section (lines 95-117) with:

```markdown
    ## Verdict (Final Message)

    **CRITICAL: Your final message must contain ONLY this structured verdict. No preamble, no narrative, no explanation of your process.**

    **If you completed the work (DONE or DONE_WITH_CONCERNS):**
    ```
    VERDICT: DONE|DONE_WITH_CONCERNS
    COMMIT: <hash>
    FILES: <count> changed (<insertions>+/<deletions>-)
    TESTS: <pass>/<total> pass, exit <code>
    SCOPE: CLEAN|VIOLATION
    REPORT_PERSISTED: YES|NO
    CONCERNS: <1-2 sentences — only if DONE_WITH_CONCERNS>
    ```

    **If you cannot complete the work (BLOCKED or NEEDS_CONTEXT):**
    ```
    VERDICT: BLOCKED|NEEDS_CONTEXT
    BLOCKER: <what you're stuck on, what you tried, what help you need>
    REPORT_PERSISTED: YES|NO
    ```

    Status meanings:
    - **DONE:** Implementation complete and tests green
    - **DONE_WITH_CONCERNS:** Implementation complete but you have doubts about correctness, scope, or file growth. Include CONCERNS field.
    - **BLOCKED:** Cannot complete the task. Describe the blocker specifically.
    - **NEEDS_CONTEXT:** Need information not provided. Describe what's missing.
    - **SCOPE:** CLEAN if only allowed files modified; VIOLATION if others touched
    - **REPORT_PERSISTED:** YES if beads comment succeeded; NO if all retries failed

    **STOP after the verdict.** Do NOT:
    - Ask what to do next
    - Offer options (commit, push, merge, etc.)
    - Invoke workflow skills (finishing-a-development-branch, etc.)
    - Suggest follow-up actions
    The orchestrator manages all workflow decisions. Your only job is the verdict.
```

**Step 4: Update beads report template for BLOCKED/NEEDS_CONTEXT**

Add an alternative report template after the existing "Write Report to Beads" section, before the verdict section:

```markdown
    **If BLOCKED or NEEDS_CONTEXT**, write a shorter report:

    1. Use the **Write** tool to create `temp/{issue_id}-impl.md` with content:
       ```
       [IMPL-REPORT] {issue_id} wave-{wave_number}

       ### Status: BLOCKED|NEEDS_CONTEXT

       ### What Was Attempted
       - What you tried (1-3 sentences)
       - How far you got

       ### Blocker
       - Specific description of what's blocking progress
       - What information or decision is needed
       ```

    2. Bash: `bd comments add {issue_id} -f temp/{issue_id}-impl.md`
    3. Bash: `bd comments {issue_id} --json`
    4. If `bd comments add` fails, retry up to 3 times with `sleep 2` between attempts.
```

**Step 5: Commit**

```bash
git add skills/subagent-driven-development/implementer-prompt.md
git commit -m "feat(sdd): add code organization, escalation guidance, and 4-status verdict protocol to implementer"
```

---

### Task 3: Add status routing to SDD orchestration
**Depends on:** Task 2
**Complexity:** standard
**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:70-98` (add status handling section, update state machine)
- Modify: `skills/subagent-driven-development/background-execution.md:43-75` (update on_implementer_complete routing)
- Modify: `skills/subagent-driven-development/code-quality-reviewer-prompt.md:33-35` (add architecture checks)

**Purpose:** Enable the SDD controller to route implementer completions by status — proceeding to review for DONE/DONE_WITH_CONCERNS, re-dispatching for NEEDS_CONTEXT, and escalating for BLOCKED — instead of treating all completions as binary pass/fail.

**Not In Scope:** Changing budget tier tables. Changing wave cap logic. Changing the review pipeline (spec → code quality → aggregation). Changing the checkpoint write timing.

**Gotchas:** The background-execution.md pseudocode is illustrative, not executable. Keep it consistent with existing style (Python-like pseudocode with comments). The state machine in SKILL.md uses a compact text format — maintain that style.

**Step 1: Add "Handling Implementer Status" section to SKILL.md**

Insert the following after the "The Process" section (after the process code block, line ~79) and before "Key Rules (GUARDS)":

```markdown
## Handling Implementer Status

Implementers report one of four statuses. The controller routes each:

**DONE:** Proceed to spec review → code review pipeline (unchanged).

**DONE_WITH_CONCERNS:** Read CONCERNS field before dispatching spec reviewer. If concern is about correctness or scope, forward to spec reviewer for focused attention. If observational (e.g., "file is getting large"), note in wave summary and proceed to review.

**NEEDS_CONTEXT:** Re-dispatch same issue with additional context. Use same model. Increment `redispatch_count[issue_id]`. If redispatch_count > 2, escalate to human (see [failure-recovery.md](failure-recovery.md)).

**BLOCKED:** Assess the blocker:
1. If context problem → provide context, re-dispatch with same model
2. If reasoning capacity → re-dispatch with next model up (haiku→sonnet→opus per tier ceiling)
3. If task too large → break into sub-issues via `bd create`, add dependencies
4. If plan is wrong → escalate to human

**Never** ignore an escalation. If the implementer said it's stuck, something needs to change.
```

**Step 2: Update state machine in SKILL.md**

Replace the current state machine block (lines 93-98) with:

```markdown
## State Machine

```
INIT [checkpoint?] -> LOADING (resume at wave N+1)
INIT -> LOADING -> DISPATCH -> MONITOR -> STATUS_ROUTE
  STATUS_ROUTE [DONE|DONE_WITH_CONCERNS] -> REVIEW -> CLOSE [+checkpoint] -> LOADING (loop)
  STATUS_ROUTE [NEEDS_CONTEXT|BLOCKED]   -> RE_DISPATCH -> MONITOR
  RE_DISPATCH [redispatch > 2]           -> PENDING_HUMAN
                                                         LOADING -> COMPLETE [cleanup]
REVIEW -> PENDING_HUMAN (verification >3 attempts)
```
```

**Step 3: Update Quick Start step 8 in SKILL.md**

Replace line 23:
```
8. Each returns: spec review -> code review -> verification -> evidence -> `bd close`
```
With:
```
8. Each returns status: DONE/DONE_WITH_CONCERNS → review pipeline → `bd close`; NEEDS_CONTEXT/BLOCKED → re-dispatch or escalate
```

**Step 4: Update on_implementer_complete in background-execution.md**

Replace the current `on_implementer_complete` function (lines 118-136) with:

```python
on_implementer_complete(task_id, result):
    verdict = parse_verdict(result.output)
    # Expected: VERDICT, and conditionally COMMIT/FILES/TESTS/SCOPE/REPORT_PERSISTED/CONCERNS/BLOCKER

    if verdict.status in ("DONE", "DONE_WITH_CONCERNS"):
        head_sha = verdict.COMMIT
        base_sha = pending_tasks[task_id]["base_sha"]
        pending_tasks[task_id]["head_sha"] = head_sha

        if verdict.status == "DONE_WITH_CONCERNS":
            pending_tasks[task_id]["concerns"] = verdict.CONCERNS
            # Forward concerns to spec reviewer for focused attention

        # Dispatch spec review (unchanged from here)
        task_complexity = pending_tasks[task_id]["complexity"]
        spec_model = "sonnet" if task_complexity == "complex" and budget_tier != "pro/api" else "haiku"
        spec_task = Task(
            model=spec_model,
            run_in_background=True,
            description=f"Spec review: {task_id}",
            ...
        )
        pending_spec_reviews.add(spec_task)

    elif verdict.status == "NEEDS_CONTEXT":
        redispatch_count = pending_tasks[task_id].get("redispatch_count", 0) + 1
        pending_tasks[task_id]["redispatch_count"] = redispatch_count
        if redispatch_count > 2:
            escalated_tasks[task_id] = verdict.BLOCKER
            report_to_human(task_id, verdict.BLOCKER,
                note="Implementer asked for context 3 times. Human clarification needed.")
        else:
            # Re-dispatch with same model + additional context addressing the BLOCKER
            redispatch_with_context(task_id, verdict.BLOCKER, same_model=True)

    elif verdict.status == "BLOCKED":
        blocker = verdict.BLOCKER
        # Assess blocker — see failure-recovery.md for full playbook
        # Options: provide context, upgrade model, break task, escalate to human
        handle_blocked_implementer(task_id, blocker)
```

**Step 5: Update monitor phase comment in background-execution.md**

Update the verdict parsing comment (line 49-50) from:
```python
            # Expected fields: VERDICT, COMMIT, FILES, TESTS, SCOPE, REPORT_PERSISTED
```
To:
```python
            # Expected fields vary by status:
            # DONE/DONE_WITH_CONCERNS: VERDICT, COMMIT, FILES, TESTS, SCOPE, REPORT_PERSISTED, [CONCERNS]
            # BLOCKED/NEEDS_CONTEXT: VERDICT, BLOCKER, REPORT_PERSISTED
```

**Step 6: Add architecture checks to code-quality-reviewer-prompt.md**

Add the following after the existing "**Append to the prompt:**" section's beads report block (before the `**Multi-review mode**` line):

```markdown
**Architecture checks (append to reviewer prompt alongside the beads report block):**
```
In addition to standard code quality concerns, verify:
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this change create new files that are already large, or significantly grow existing files?
  (Don't flag pre-existing file sizes — focus on what this change contributed.)
```
```

**Step 7: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/background-execution.md skills/subagent-driven-development/code-quality-reviewer-prompt.md
git commit -m "feat(sdd): add status-aware routing to controller for DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT"
```

---

### Task 4: Add BLOCKED/NEEDS_CONTEXT recovery playbooks and update checkpoint schema
**Depends on:** Task 3
**Complexity:** simple
**Files:**
- Modify: `skills/subagent-driven-development/failure-recovery.md` (add two new playbook sections)
- Modify: `skills/subagent-driven-development/checkpoint-recovery.md:7-24` (add escalated_tasks to schema)

**Purpose:** Document recovery procedures for the two new failure modes (BLOCKED and NEEDS_CONTEXT) and ensure escalated tasks survive checkpoint recovery.

**Not In Scope:** Changing existing recovery playbooks. Changing checkpoint write timing. Changing the SessionStart hook.

**Step 1: Add Implementer BLOCKED playbook to failure-recovery.md**

Insert the following after the existing "## Review Rejection Loop" section:

```markdown
## Implementer BLOCKED

When an implementer returns BLOCKED:

```
blocker = verdict.BLOCKER

# 1. Assess blocker type
if blocker indicates missing context ("need to understand", "can't find"):
    # Context problem — provide more context, same model
    redispatch_with_context(task_id, blocker, same_model=True)

elif blocker indicates capacity limit ("architectural decision", "multiple approaches", "uncertain"):
    # Reasoning capacity — upgrade model
    current_model = pending_tasks[task_id]["model"]
    next_model = upgrade(current_model)  # haiku→sonnet→opus, capped by tier
    if next_model == current_model:
        # Already at tier ceiling — escalate to human
        escalated_tasks[task_id] = blocker
        report_to_human(task_id, blocker)
    else:
        redispatch(task_id, next_model, extra_context=blocker)

elif blocker indicates scope problem ("restructuring", "too large", "beyond plan"):
    # Task decomposition needed — escalate to human
    escalated_tasks[task_id] = blocker
    report_to_human(task_id, blocker,
        options=["Break task into sub-issues", "Revise plan", "Take over manually"])

else:
    # Unknown blocker — escalate to human
    escalated_tasks[task_id] = blocker
    report_to_human(task_id, blocker)
```
```

**Step 2: Add Implementer NEEDS_CONTEXT playbook to failure-recovery.md**

Insert the following after the Implementer BLOCKED section:

```markdown
## Implementer NEEDS_CONTEXT

When an implementer returns NEEDS_CONTEXT:

```
missing_context = verdict.BLOCKER
redispatch_count = pending_tasks[task_id].get("redispatch_count", 0) + 1
pending_tasks[task_id]["redispatch_count"] = redispatch_count

if redispatch_count > 2:
    # Tried 3 times — human must clarify
    escalated_tasks[task_id] = missing_context
    report_to_human(task_id, missing_context,
        note="Implementer asked for context 3 times. Human clarification needed.")
else:
    # Read the relevant files/code the implementer needs
    # Include them directly in the re-dispatch prompt
    redispatch_with_context(task_id, missing_context, same_model=True)
```

**Re-dispatch prompt addendum:**

```
The previous attempt returned NEEDS_CONTEXT:
"{blocker_description}"

Here is the additional context:
{additional_context_from_orchestrator}

All other instructions from your original dispatch still apply.
```
```

**Step 3: Update checkpoint schema in checkpoint-recovery.md**

Add `escalated_tasks` field to the JSON schema example (after `"closed_issues"` array):

```json
  "escalated_tasks": {
    "hub-abc.4": "BLOCKED: requires database migration strategy not in plan",
    "hub-abc.7": "NEEDS_CONTEXT: 3 re-dispatches exhausted, unclear auth pattern"
  },
```

**Step 4: Update recovery logic in checkpoint-recovery.md**

Add to the recovery logic list (after item 2, "Restore: budget_tier..."):

```markdown
3. Restore `escalated_tasks` — these need human resolution before dispatch. Skip them during LOADING filter (treat as not-ready even if `bd ready` lists them).
```

Renumber existing items 3-6 to 4-7.

**Step 5: Commit**

```bash
git add skills/subagent-driven-development/failure-recovery.md skills/subagent-driven-development/checkpoint-recovery.md
git commit -m "feat(sdd): add BLOCKED/NEEDS_CONTEXT recovery playbooks and checkpoint escalated_tasks"
```

---

## Verification

After all tasks complete:

1. **Consistency check:** Read each modified file end-to-end. Verify no broken cross-references between:
   - writing-plans File Structure → file-lists.md reference
   - implementer-prompt.md verdict format → background-execution.md parser comments
   - SKILL.md status handling → failure-recovery.md playbooks
   - checkpoint-recovery.md schema → SKILL.md checkpoint references

2. **Word count check:** Verify implementer-prompt.md stays under 600 words (current: 586, compressed). If over, apply compression following the existing `<!-- compressed: -->` pattern.

3. **Wave parallelism check:** Tasks 1 and 2 have no file overlap — verify they can execute in wave 1 together.
