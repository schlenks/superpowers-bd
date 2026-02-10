# Parallel Dispatch Code

Full dispatch implementation for multi-review aggregation.

## On Spec Review Pass Handler

```python
on_spec_review_pass(issue_id, result):
    n_reviews = tier_n_reviews  # 3 for max-20x/max-5x, 1 for pro/api

    if n_reviews > 1:
        reviewer_tasks = []
        for i in range(n_reviews):
            task = Task(
                subagent_type="general-purpose",
                model=tier_code_model,
                run_in_background=True,
                description=f"Code review {i+1}/{n_reviews}: {issue_id}",
                prompt=code_reviewer_prompt + f"\nYou are Reviewer {i+1} of {n_reviews}. "
                    "Review independently — do not reference other reviewers."
            )
            reviewer_tasks.append(task)

        # Poll until all N complete
        results = wait_for_all(reviewer_tasks)

        # Check fast path
        if all_approve_no_issues(results):
            # Skip aggregation — unanimous clean approval
            record_metrics(results, role="code")
            proceed_to_close(issue_id)
        else:
            # Dispatch aggregator
            dispatch_aggregator(results, issue_id)
    else:
        # Single review (pro/api) — unchanged
        dispatch_single_code_review(issue_id)
```

## Aggregator Dispatch

```python
dispatch_aggregator(reviewer_results, task_id):
    combined_output = "\n---\n".join([
        f"## Reviewer {i+1} Output\n{result.output}"
        for i, result in enumerate(reviewer_results)
    ])

    aggregator = Task(
        subagent_type="general-purpose",
        model="haiku",  # Synthesis task, not deep analysis
        description=f"Aggregate reviews: {task_id}",
        prompt=aggregator_prompt.format(
            n_reviews=len(reviewer_results),
            reviewer_outputs=combined_output
        )
    )
```

Use the aggregator prompt template at `../aggregator-prompt.md`.
