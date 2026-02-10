# Verification and Evidence Reference

## Verification Tasks

Verification tasks (like Rule-of-Five, Code Review, Plan Verification) are processed through the **same dispatch loop** as implementation tasks, but are routed to specialized agents based on task type (see "Dispatch Decision" in SKILL.md).

**Key points:**

1. **Appear in `bd ready`** - When an implementation task closes, its dependent verification task becomes ready
2. **Routed by title** - Tasks with "verification" or "verify" in title use the verifier prompt template, others use the implementer prompt
3. **Same review flow** - All tasks still go through spec compliance then code quality review
4. **Specific acceptance criteria** - The spec reviewer verifies the verification was actually performed, not just claimed

**Example: Rule-of-Five verification task**

```
Task superpowers-xyz.5 (Rule-of-Five verification)
  Dependencies: [superpowers-xyz.1, superpowers-xyz.2, superpowers-xyz.3, superpowers-xyz.4]
  Files: [docs/plans/implementation-plan.md]
  Acceptance: Apply 5-pass review to all artifacts >50 lines created in tasks 1-4
```

**Dispatch flow:**
```
[Tasks 1-4 all closed]
[bd ready now shows superpowers-xyz.5]

[bd update superpowers-xyz.5 --status=in_progress]
[Dispatch implementer for superpowers-xyz.5]

Implementer:
  - Reviews artifacts from tasks 1-4
  - Applies Rule-of-Five passes
  - Documents changes made in each pass
  - Committed

[Dispatch spec reviewer]
Spec reviewer:
  - Verifies each required artifact was reviewed
  - Confirms 5 passes were applied (not just claimed)
  - Checks that improvements were substantive
  ✅ Passes

[Dispatch code quality reviewer]
Code reviewer: ✅ Approved

[bd close superpowers-xyz.5]
```

**Why no special handling?** Verification tasks have:
- Clear acceptance criteria (verifiable by spec reviewer)
- Defined file scope (what to review)
- Dependencies (run after implementation completes)

This means the existing dispatch → review → close flow works unchanged.

## Verification Gap Closure

After both reviews pass, apply `superpowers:verification-before-completion` with gap closure:

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
        verification_command="npm test && npm run build",
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

After verification passes but before `bd close`, capture structured evidence for audit trail:

```python
on_verification_pass(task_id, implementer_result):
    # 1. Parse ### Evidence section from implementer's report
    evidence = parse_evidence_section(implementer_result)

    # 2. Fallback: run git commands directly if report is malformed
    if not evidence.commit:
        evidence.commit = run("git rev-parse --short HEAD")
    if not evidence.files:
        evidence.files = run("git diff --stat")

    # 3. Create native "Close evidence" task → triggers TaskCompleted hook (interactive mode)
    evidence_task = TaskCreate(
        subject=f"Close evidence: {task_id}",
        description=f"Commit: {evidence.commit}\n"
                    f"Files changed: {evidence.files}\n"
                    f"Test results: {evidence.test_results}",
        activeForm=f"Recording evidence for {task_id}"
    )
    TaskUpdate(taskId=evidence_task.id, status="completed")

    # 4. Close with evidence in reason for beads audit trail
    bd_close(task_id, reason=f"Commit: {evidence.commit} | Files: {evidence.files} | Tests: {evidence.test_results}")
```

**Why two layers:**
- **Native task** (step 3) — triggers TaskCompleted hook in interactive mode, which blocks if evidence is missing
- **bd close --reason** (step 4) — persists evidence in beads for cross-session audit trail
- **Prompt-based** — implementer report template ensures evidence is generated in all modes (including headless)
