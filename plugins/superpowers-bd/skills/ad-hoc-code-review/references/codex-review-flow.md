# Codex Ad-hoc Review Flow

Use this reference when `ad-hoc-code-review` is invoked from Codex. The workflow resolves a review scope, gathers requirements, runs one or more independent review passes, aggregates when needed, and reports findings without fixing them.

## Native Flow

1. Track progress with `update_plan`: resolve scope, gather requirements, select reviewer count, dispatch reviewers, aggregate when needed, present findings.
2. Ask what to review: local changes or a GitHub PR.
3. Resolve the exact diff scope.
4. Ask what requirements to check against: PR description, beads issue, commit messages, inline description, or general review.
5. Recommend a reviewer count based on diff size and security-sensitive files. Respect a user-provided count, capped at 10.
6. Generate a timestamp and persist reviewer outputs under `temp/`.
7. Dispatch independent reviewers in parallel when multiple reviewers are requested.
8. Wait for all reviewer outputs, aggregate if two or more succeeded, and present the review.
9. Do not edit code during this workflow.

## Scope Resolution

For local reviews:

- Uncommitted changes: use `git status --short` plus `git diff HEAD`; include untracked files in scope.
- Last commit: compare `HEAD~1` to `HEAD`.
- Since last push: prefer the push upstream, then fall back to the merge base with `origin/main` if available.
- Branch diff: use the merge base with the target branch.
- Custom: validate both refs before reviewing.

For PR reviews:

- Use `gh pr view` to capture metadata, changed file count, additions, deletions, body, base, head, URL, and state.
- Use `gh pr diff` for the review diff.
- Warn before reviewing a closed or merged PR.
- For very large PRs, ask whether to proceed or choose a smaller local scope.

## Reviewer Standard

Use Codex native agent `code_reviewer` when available. If it is unavailable, perform the review directly and follow `../../requesting-code-review/code-reviewer.md` exactly as the shared review standard.

Each reviewer must produce a structured report with changed files, rules consulted, requirement mapping, uncovered paths, not checked items, findings by severity, and readiness assessment.

For two or more successful reviewer reports, use Codex native agent `review_aggregator` when available. If it is unavailable, aggregate directly using `../../multi-review-aggregation/aggregator-prompt.md` as the shared aggregation standard.

## Output Rules

- Reviewer reports must follow the shared `code-reviewer.md` structure exactly. Use findings-first ordering only for the final human presentation after review reports are collected or aggregated.
- Every finding needs file and line evidence.
- Critical and Important findings need actionable fix guidance.
- Uncertainty belongs in Not Checked, not in speculative findings.
- Codex cross-model review is advisory unless the user explicitly changes that policy.
- Present findings and stop. Do not make fixes as part of ad-hoc review.
