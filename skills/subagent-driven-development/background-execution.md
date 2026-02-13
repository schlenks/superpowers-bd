# Background Execution with Polling

## When to Use

For 2+ tasks per wave (up to the max of 3), background execution lets you monitor all tasks simultaneously and start reviews as soon as each completes—without waiting for all implementations to finish.

Use `run_in_background: true` with TaskOutput polling.

## Dispatch Phase

```python
pending_tasks = {}  # task_id -> {issue_id, complexity, base_sha, ...}
task_ids = []

# Capture pre-implementation SHA (see dispatch-and-conflict.md)
# Note: all tasks in wave share this base. If A commits before B, B's review
# diff will include A's files — non-overlapping by design, bounded noise.
wave_base_sha = run("git rev-parse HEAD")

for issue in parallelizable:
    bd update <issue.id> --status=in_progress
    # Read complexity label (set at plan time, see dispatch-and-conflict.md)
    impl_model = resolve_impl_model(issue.complexity, budget_tier)
    result = Task(
        subagent_type="general-purpose",
        model=impl_model,  # complexity-adjusted: see SKILL.md Budget Tier Selection
        run_in_background=True,
        description=f"Implement: {issue.id} {issue.title}",
        prompt=implementer_prompt
    )
    pending_tasks[result.task_id] = {
        "issue_id": issue.id,
        "complexity": issue.complexity,
        "base_sha": wave_base_sha  # stored for review dispatch
    }
    task_ids.append(result.task_id)
```

## Monitor Phase

Sub-agents persist full reports to beads comments. Only structured verdicts flow through TaskOutput.

```python
while task_ids:
    for task_id in list(task_ids):
        result = TaskOutput(task_id, block=False, timeout=5000)
        if result.status == "completed":
            # Parse structured verdict (5-6 lines, not full report)
            verdict = parse_verdict(result.output)
            # Expected fields: VERDICT, COMMIT, FILES, TESTS, SCOPE, REPORT_PERSISTED

            # Capture metrics per metrics-tracking.md keying scheme (accumulate on retry, don't overwrite)

            # Fallback: if REPORT_PERSISTED: NO, re-dispatch for full report
            if verdict.report_persisted == "NO":
                dispatch_full_report_fallback(task_id, issue_id)
            else:
                dispatch_review(task_id, verdict)
            task_ids.remove(task_id)

    # Also check review completions
    for review_id in list(pending_reviews):
        result = TaskOutput(review_id, block=False)
        if result.status == "completed":
            # Parse structured verdict (2-3 lines)
            verdict = parse_verdict(result.output)

            # Capture metrics per metrics-tracking.md keying scheme (accumulate on retry, don't overwrite)

            # Fallback: if REPORT_PERSISTED: NO, re-dispatch for full report
            if verdict.report_persisted == "NO":
                dispatch_full_report_fallback(review_id, issue_id)
            else:
                process_review(review_id, verdict)
```

## REPORT_PERSISTED Fallback

If a sub-agent returns `REPORT_PERSISTED: NO`, the full report was not saved to beads. The orchestrator re-dispatches a lightweight agent to retrieve it:

```python
def dispatch_full_report_fallback(task_id, issue_id):
    # One-time context cost — only triggers on bd write failure
    fallback = Task(
        subagent_type="general-purpose",
        model="haiku",
        description=f"Retrieve report: {issue_id}",
        prompt=f"The previous agent for {issue_id} failed to persist its report. "
               f"Run: bd comments {issue_id} --json "
               f"If the report is missing, report MISSING. Otherwise return the report."
    )
    # If still missing, orchestrator falls back to old pattern:
    # re-dispatch the original agent asking for full report via TaskOutput
```

## Review Pipeline Parallelism

Reviews for DIFFERENT tasks can run in parallel:

```
Timeline (3 tasks, N=3 reviews, max parallelism):
─────────────────────────────────────────────────────────────────────────
Task A: [implement]────[spec-A]────[code-A×3]────[agg-A]────→ close
Task B:    [implement]────[spec-B]────[code-B×3]────[agg-B]────→ close
Task C:       [implement]────[spec-C]────[code-C×3]──[agg-C]──→ close
                       ↑         ↑            ↑
                       └─parallel─┘    (agg skipped if fast path)
```

**Rules:**
- Spec review for A || Spec review for B ✅
- Code review A must wait for spec review A ❌ (sequential)
- Code review for A || Code review for B ✅

## Event-Driven Dispatch

```python
on_implementer_complete(task_id, result):
    # Extract head_sha from implementer's COMMIT verdict field
    head_sha = result.COMMIT  # e.g., "a7e2d4f" — from implementer-prompt.md structured verdict
    base_sha = pending_tasks[task_id]["base_sha"]  # captured before wave dispatch

    # Store SHAs for review pipeline (spec → code reviews use same range)
    pending_tasks[task_id]["head_sha"] = head_sha

    # Resolve spec model from stored complexity (sonnet for complex on non-pro; haiku otherwise)
    task_complexity = pending_tasks[task_id]["complexity"]  # stored at dispatch time
    spec_model = "sonnet" if task_complexity == "complex" and budget_tier != "pro/api" else "haiku"
    # Immediately dispatch spec review (background)
    spec_task = Task(
        model=spec_model,  # complexity-adjusted: see SKILL.md Budget Tier Selection
        run_in_background=True,
        description=f"Spec review: {task_id}",
        ...
    )
    pending_spec_reviews.add(spec_task)

on_spec_review_pass(task_id, result):
    base_sha = pending_tasks[task_id]["base_sha"]  # captured before wave dispatch
    head_sha = pending_tasks[task_id]["head_sha"]   # from implementer's COMMIT verdict
    n_reviews = tier_n_reviews  # 3 for max-20x/max-5x, 1 for pro/api

    # Trivial change override: skip multi-review for tiny diffs
    diff_stat = run(f"git diff --stat {base_sha}..{head_sha}")
    diff_lines = parse_insertions_plus_deletions(diff_stat)
    if diff_lines <= 10 and n_reviews > 1:
        n_reviews = 1  # Single reviewer sufficient for trivial changes

    if n_reviews > 1:
        # Dispatch N independent code reviews in parallel
        # See superpowers-bd:multi-review-aggregation for full algorithm
        reviewer_tasks = []
        for i in range(n_reviews):
            code_task = Task(
                subagent_type="general-purpose",
                model=tier_code_model,  # NEVER adjusted by complexity
                run_in_background=True,
                description=f"Code review {i+1}/{n_reviews}: {task_id}",
                prompt=code_reviewer_prompt.format(
                    code_reviewer_path=code_reviewer_path,
                    issue_id=issue_id,
                    base_sha=base_sha,
                    head_sha=head_sha,
                    wave_number=wave_n
                ) + f"\nYou are Reviewer {i+1} of {n_reviews}. "
                    "Review independently — do not reference other reviewers."
            )
            reviewer_tasks.append(code_task)

        # When all N complete: check fast path (all approve, 0 Critical/Important)
        # If fast path: skip aggregation, proceed to close
        # Otherwise: dispatch aggregator (haiku) per aggregator-prompt.md
        pending_multi_reviews[task_id] = reviewer_tasks
    else:
        # Single review (pro/api) — unchanged
        code_task = Task(
            subagent_type="general-purpose",
            model=tier_code_model,  # NEVER adjusted by complexity
            run_in_background=True,
            prompt=code_reviewer_prompt.format(
                code_reviewer_path=code_reviewer_path,
                issue_id=issue_id,
                base_sha=base_sha,
                head_sha=head_sha,
                wave_number=wave_n
            ),  # from ./code-quality-reviewer-prompt.md — sub-agent self-reads methodology
            ...
        )
        pending_code_reviews.add(code_task)
```
