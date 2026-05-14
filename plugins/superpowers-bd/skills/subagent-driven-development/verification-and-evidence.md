# Verification and Evidence Reference

## Verification Tasks

Verification tasks (like Rule-of-Five, Code Review, Plan Verification) are processed through the **same dispatch loop** as implementation tasks, but are routed to specialized agents based on task type (see "Dispatch Decision" in SKILL.md).

**Key points:**

1. **Appear in `bd ready`** - When an implementation task closes, its dependent verification task becomes ready
2. **Routed by title** - Tasks with "verification" or "verify" in title use the verifier prompt template, others use the implementer prompt
3. **Same review flow** - All tasks still go through spec compliance then code quality review
4. **Specific acceptance criteria** - The spec reviewer verifies the verification was actually performed, not just claimed

**Example:** A verification task (e.g., `superpowers-xyz.5`) depends on impl tasks 1-4. When all close, it appears in `bd ready`. The agent executing the verification task applies Rule-of-Five passes to all >50 line artifacts. The spec reviewer verifies each artifact was reviewed, confirms 5 passes were applied (not just claimed), and checks improvements were substantive. Then code review → `bd close`.

The existing dispatch → review → close flow works unchanged for verification tasks.

## Verification Gap Closure

After both reviews pass, apply `superpowers-bd:verification-before-completion` with gap closure:

```python
on_code_review_pass(task_id, result):
    # Create verification task for the implementation
    verify_task = TaskCreate(
        subject=f"Verify: {task_id} implementation",
        description=f"Run tests, check build. Max 3 attempts.",
        metadata={"attempt": 1, "max_attempts": 3}
    )

    # Run verification with gap closure loop
    verification_result = run_verification_with_gap_closure(
        task_id=task_id,
        verification_commands=["npm test", "npm run build"],  # run each separately
        max_attempts=3
    )

    if verification_result.passed:
        # Extract evidence and close with audit trail (see below)
        extract_evidence_and_close(task_id, implementer_result)
    elif verification_result.escalated:
        # Human intervention task created by gap closure
        pending_human_intervention.add(task_id)
```

**Gap closure flow within SDD:**
```
Code review passes → Create verification task (attempt 1) → Run verification
  → passes? → yes → bd close
  → no → Create gap-fix task → Fix completes → Re-verify (attempt N+1)
    → passes? → yes → bd close
    → no, attempt < 3 → loop
    → no, attempt >= 3 → Escalate to human
```

**Integration with state machine:**
- Gap closure happens in REVIEW → CLOSE transition
- If escalated, task moves to "pending human" (not closed, not dispatched)
- After human resolves, re-enter REVIEW state for that task

## Evidence Extraction Before Close

After verification passes but before `bd close`, extract evidence from the implementer's structured verdict. Full reports are in beads comments — the orchestrator only needs the verdict fields.

```python
on_verification_pass(task_id, implementer_verdict):
    # 1. Extract evidence from verdict fields (not full report)
    evidence = {
        "commit": implementer_verdict.COMMIT,      # e.g., "a7e2d4f"
        "files": implementer_verdict.FILES,         # e.g., "3 changed (120+/15-)"
        "tests": implementer_verdict.TESTS,         # e.g., "12/12 pass, exit 0"
        "scope": implementer_verdict.SCOPE,         # CLEAN or VIOLATION
    }

    # 2. Fallback: run git commands directly if verdict is malformed
    if not evidence["commit"]:
        evidence["commit"] = run("git rev-parse --short HEAD")
    if not evidence["files"]:
        evidence["files"] = run("git diff --stat")

    # 3. Create native "Close evidence" task → triggers TaskCompleted hook (interactive mode)
    evidence_task = TaskCreate(
        subject=f"Close evidence: {task_id}",
        description=f"Commit: {evidence['commit']}\n"
                    f"Files changed: {evidence['files']}\n"
                    f"Test results: {evidence['tests']}",
        activeForm=f"Recording evidence for {task_id}"
    )
    TaskUpdate(taskId=evidence_task.id, status="completed")

    # 4. Close with evidence in reason for beads audit trail
    bd_close(task_id, reason=f"Commit: {evidence['commit']} | Files: {evidence['files']} | Tests: {evidence['tests']}")
```

**Why two layers:**
- **Native task** (step 3) — triggers TaskCompleted hook in interactive mode, which blocks if evidence is missing
- **bd close --reason** (step 4) — persists evidence in beads for cross-session audit trail
- **Verdict-based** — implementer verdict provides structured fields; full report lives in beads comments for audit

**Full reports in beads:** If the orchestrator needs to drill into details (e.g., investigating a failure), it can read the full report: `bd comments <issue-id> --json` and look for `[IMPL-REPORT]` tagged entries.
