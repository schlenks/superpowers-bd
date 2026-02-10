# Background Execution with Polling

## When to Use

For 2+ tasks per wave (up to the max of 3), background execution lets you monitor all tasks simultaneously and start reviews as soon as each completes—without waiting for all implementations to finish.

Use `run_in_background: true` with TaskOutput polling.

## Dispatch Phase

```python
task_ids = []
for issue in parallelizable:
    bd update <issue.id> --status=in_progress
    result = Task(
        subagent_type="general-purpose",
        model=tier_model,
        run_in_background=True,
        description=f"Implement: {issue.id} {issue.title}",
        prompt=implementer_prompt
    )
    task_ids.append(result.task_id)
```

## Monitor Phase

```python
while task_ids:
    for task_id in list(task_ids):
        result = TaskOutput(task_id, block=False, timeout=5000)
        if result.status == "completed":
            # Capture metrics from <usage> block (default 0 if missing)
            # On retry: add to existing entry, don't overwrite (see metrics-tracking.md)
            key = f"{issue_id}.impl"
            new_metrics = {
                "total_tokens": getattr(result.usage, "total_tokens", 0),
                "tool_uses": getattr(result.usage, "tool_uses", 0),
                "duration_ms": getattr(result.usage, "duration_ms", 0)
            }
            if key in task_metrics:  # retry — accumulate
                for field in new_metrics:
                    task_metrics[key][field] += new_metrics[field]
            else:
                task_metrics[key] = new_metrics
            dispatch_review(task_id, result)
            task_ids.remove(task_id)

    # Also check review completions
    for review_id in list(pending_reviews):
        result = TaskOutput(review_id, block=False)
        if result.status == "completed":
            # Capture review metrics (role = "spec" or "code")
            # On retry: accumulate, don't overwrite
            key = f"{issue_id}.{review_role}"
            new_metrics = {
                "total_tokens": getattr(result.usage, "total_tokens", 0),
                "tool_uses": getattr(result.usage, "tool_uses", 0),
                "duration_ms": getattr(result.usage, "duration_ms", 0)
            }
            if key in task_metrics:
                for field in new_metrics:
                    task_metrics[key][field] += new_metrics[field]
            else:
                task_metrics[key] = new_metrics
            process_review(review_id, result)
```

## Benefits

- **True parallelism** - Tasks execute simultaneously, not just dispatched concurrently
- **Simultaneous monitoring** - Can poll multiple tasks without blocking on any single one
- **Immediate review dispatch** - Start reviews as soon as implementations complete, even while other implementations are running
- **Better throughput** - Wave N+1 reviews can overlap with Wave N implementations completing

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
    # Immediately dispatch spec review (background)
    spec_task = Task(
        model=tier_spec_model,
        run_in_background=True,
        description=f"Spec review: {task_id}",
        ...
    )
    pending_spec_reviews.add(spec_task)

on_spec_review_pass(task_id, result):
    n_reviews = tier_n_reviews  # 3 for max-20x/max-5x, 1 for pro/api

    # Trivial change override: skip multi-review for tiny diffs
    diff_stat = run(f"git diff --stat {base_sha}..{head_sha}")
    diff_lines = parse_insertions_plus_deletions(diff_stat)
    if diff_lines <= 10 and n_reviews > 1:
        n_reviews = 1  # Single reviewer sufficient for trivial changes

    if n_reviews > 1:
        # Dispatch N independent code reviews in parallel
        # See superpowers:multi-review-aggregation for full algorithm
        reviewer_tasks = []
        for i in range(n_reviews):
            code_task = Task(
                subagent_type="general-purpose",
                model=tier_code_model,
                run_in_background=True,
                description=f"Code review {i+1}/{n_reviews}: {task_id}",
                prompt=code_reviewer_prompt + f"\nYou are Reviewer {i+1} of {n_reviews}. "
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
            model=tier_code_model,
            run_in_background=True,
            prompt=code_reviewer_prompt,  # from ./code-quality-reviewer-prompt.md
            ...
        )
        pending_code_reviews.add(code_task)
```
