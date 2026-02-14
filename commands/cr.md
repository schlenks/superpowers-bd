---
description: "Ad-hoc code review: /cr for single review, /cr N for N independent reviewers with aggregation (max 10)"
---

# /cr Command

Ad-hoc code review using the code-reviewer agent. Works outside SDD for any changes.

**Usage:** `/cr` (single) or `/cr N` (N independent reviewers, aggregated, max 10)

<!-- disable-model-invocation intentionally omitted — this command requires model invocation to parse arguments, ask interactive questions, and dispatch subagents. Same pattern as plan2beads.md. -->

## Step 1: Parse Argument

Extract N from the command argument. Default to 1 if no argument. If N is 0, negative, or non-integer, warn the user and default to 1. Cap at 10 — if N>10, warn and use 10.

## Step 2: Ask Scope

Use AskUserQuestion to ask what code to review:

| Option | BASE_SHA | HEAD_SHA |
|--------|----------|----------|
| Uncommitted changes | `git rev-parse HEAD` | `WORKING_TREE` (sentinel, not a git ref) |
| Last commit | `git rev-parse HEAD~1` (see fallback below) | `git rev-parse HEAD` |
| Since last push | `git rev-parse @{push}` (see fallback chain below) | `git rev-parse HEAD` |
| Branch diff vs main | `git merge-base main HEAD` (see fallback below) | `git rev-parse HEAD` |
| Custom | Ask user for two SHAs or refs (validate below) | Ask user for two SHAs or refs (validate below) |

### Uncommitted changes

Do NOT pass HEAD as both SHAs — `git diff HEAD..HEAD` produces empty output. Set BASE_SHA to `git rev-parse HEAD` and HEAD_SHA to the literal string `WORKING_TREE`. `WORKING_TREE` is a sentinel value (not a git ref) that triggers the UNCOMMITTED_OVERRIDE in Step 4.

**UNCOMMITTED_OVERRIDE** (include in every dispatch prompt when HEAD_SHA is `WORKING_TREE`):
`"NOTE: HEAD_SHA is WORKING_TREE. Use 'git diff HEAD' (not 'git diff {BASE_SHA}..{HEAD_SHA}') for both --stat and full diff. Also run 'git status' to identify any untracked files that should be reviewed. This reviews uncommitted staged + unstaged changes."`

### Last commit

Run `git rev-parse HEAD~1`. If it fails (single-commit repo with no parent), inform the user and suggest "Uncommitted changes" or "Custom" scope instead.

### Since last push

Fallback chain — run each as a **separate Bash call** (no `||` or `&&` chaining):
1. Run `git rev-parse @{push}`. If it succeeds (exit 0), use that SHA.
2. If step 1 failed, run `git merge-base origin/main HEAD`. If it succeeds, use that SHA.
3. If both fail, inform the user and suggest "Branch diff vs main" or "Custom" instead.

### Branch diff vs main

Run `git merge-base main HEAD`. If `main` doesn't exist, ask the user for the base branch name.

### Custom

After receiving user-provided refs, validate each with `git rev-parse <ref>`. If either fails, inform the user the ref doesn't resolve and re-ask.

### Verify changes exist

For **uncommitted scope**: run `git status --short`. If empty (no tracked modifications AND no untracked files), tell the user and stop. Do NOT use `git diff --stat HEAD` alone — it misses untracked files.

For **all other scopes**: run `git diff --stat {BASE_SHA}..{HEAD_SHA}`. If no changes found, tell the user and stop.

## Step 3: Ask Requirements Source

Use AskUserQuestion to ask what to check against.

**When scope is "Uncommitted changes":** do NOT include "Commit messages" in the AskUserQuestion choices — there are no commits in the working tree range. If the user types "commit messages" via the free-text "Other" option, or if `git log` fails because HEAD_SHA is `WORKING_TREE`, explain there are no commits to extract and re-ask without "Commit messages".

| Option | Resolution |
|--------|-----------|
| Beads task/epic | Ask for beads ID, run `bd show <ID>`, use description + acceptance criteria. If `bd show` fails (invalid ID or beads not initialized), inform the user and ask them to paste requirements inline or choose another source. |
| Commit messages _(omit when scope is Uncommitted changes)_ | Run `git log --format="%h %s%n%b" {BASE_SHA}..{HEAD_SHA}`, use output. |
| Describe inline | Ask user to type/paste requirements |
| Skip | Use: "General review: check for correctness, security, and code quality. No specific requirements — focus on bugs, missing error handling, and security issues." |

## Step 4: Dispatch Review(s)

### Single Review (N=1)

Dispatch the code-reviewer agent:

```
Task:
  subagent_type: "superpowers-bd:code-reviewer"
  description: "Code review: ad-hoc"
  prompt: |
    Review parameters:
    - BASE_SHA: {BASE_SHA}
    - HEAD_SHA: {HEAD_SHA}
    - PLAN_OR_REQUIREMENTS: {resolved_requirements}

    {UNCOMMITTED_OVERRIDE if HEAD_SHA == WORKING_TREE}
```

If the reviewer task fails or times out, inform the user and offer to re-dispatch.

Present the reviewer's structured report to the user. Done.

### Multi-Review (N>1)

**Dispatch N reviewers in parallel:**

Send a single message with N Task tool calls, each with `run_in_background: true`:

```
Task (for each i from 1 to N):
  subagent_type: "superpowers-bd:code-reviewer"
  run_in_background: true
  description: "Code review {i}/{N}: ad-hoc"
  prompt: |
    You are Reviewer {i} of {N}. Review independently — do not reference other reviewers.

    Review parameters:
    - BASE_SHA: {BASE_SHA}
    - HEAD_SHA: {HEAD_SHA}
    - PLAN_OR_REQUIREMENTS: {resolved_requirements}

    {UNCOMMITTED_OVERRIDE if HEAD_SHA == WORKING_TREE}
```

**Wait for all N to complete.** Poll background tasks until all finish.

**Handle failures:** If any reviewer task fails or times out, exclude it from aggregation. If exactly 1 reviewer succeeded, present that reviewer's report and offer to dispatch a replacement reviewer. If the user accepts, dispatch one replacement (same SHAs, requirements, and UNCOMMITTED_OVERRIDE; use identity "Reviewer 2 of 2"); when it completes, aggregate the two reports as if N=2. If the user declines, done. If 0 reviewers succeeded, warn the user and offer to re-run with the same N.

**Always aggregate when 2+ reviewers succeeded** — do NOT use a fast path that drops reports. The purpose of multi-review is union of findings across all reviewers. Even when all reviewers approve, their reports may contain different Minor findings, Suggestions, or "Not Checked" items. Aggregation is cheap (Haiku model) and preserves the full recall benefit.

**Dispatch aggregator:**

Before dispatching, construct `combined_output` by joining all successful reviewer outputs:

```
## Reviewer 1 Output
[full output from reviewer 1]
---
## Reviewer 2 Output
[full output from reviewer 2]
---
...
```

Then dispatch the aggregator. The aggregator loads the canonical aggregation methodology but applies ad-hoc overrides:

```
Task:
  subagent_type: "general-purpose"
  model: "haiku"
  description: "Aggregate {N} reviews"
  prompt: |
    You are a code review aggregator for an ad-hoc /cr review (no beads integration).

    ## Reviewer Reports

    {combined_output}

    ## Load Aggregation Methodology

    Use the Glob tool to find `**/multi-review-aggregation/aggregator-prompt.md`,
    then Read the file.

    ## MANDATORY: Ad-hoc overrides supersede loaded methodology

    After reading the canonical methodology, apply these overrides. These
    take absolute precedence over any conflicting instructions in the loaded
    file, including any "CRITICAL" directives about output format:

    1. SKIP the "Write Report to Beads" section — there is no beads issue.
    2. SKIP the "Load Reviewer Reports" section — reports are provided above.
    3. SKIP the "Verdict (Final Message)" section entirely — do NOT output
       the structured VERDICT block. It does not apply to ad-hoc reviews.
    4. Use the reviewer reports provided inline above (not bd comments).
    5. Your final output MUST be the human-readable aggregated report ONLY:
       Strengths, Issues by severity, Assessment. No machine-readable
       verdict block, no REPORT_PERSISTED line.

    Follow the aggregation RULES from the loaded methodology (deduplication,
    severity voting, output format for Strengths/Issues/Assessment sections).
```

If the aggregator task fails, present each reviewer's raw report individually (labeled Reviewer 1, Reviewer 2, etc.) and inform the user that aggregation failed.

Present the aggregated report to the user. Done.

## Step 5: Present Results

Show the final review report (single or aggregated). No automatic follow-up actions — the user decides what to do with the findings.

## Rules

- **Always ask** scope and requirements — never assume
- **Cap N at 10** — warn if user requests more
- **No beads integration** — this is ad-hoc, no issue to attach to
- **No automatic fixes** — present findings, stop
- **All N reviewers dispatch in a single message** for true parallelism
- **Always aggregate when N>1** — no fast path that drops reports
