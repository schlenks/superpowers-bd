---
description: "Code review: /cr for interactive review (local or GitHub PR), /cr N for N independent reviewers with aggregation (max 10)"
effort: high
---

# /cr Command

Ad-hoc code review using the code-reviewer agent. Works outside SDD for any changes.

**Usage:** `/cr` (single) or `/cr N` (N independent reviewers, aggregated, max 10)

<!-- disable-model-invocation intentionally omitted — this command requires model invocation to parse arguments, ask interactive questions, and dispatch subagents. Same pattern as plan2beads.md. -->

## Step 1: Parse Argument

Extract N from the command argument if provided. If N is 0, negative, or non-integer, warn the user and default to empty (determined by recommendation in Step 5). Cap at 10 — if N>10, warn and use 10. If no argument, N is empty.

## Step 2: Ask Review Mode

Use AskUserQuestion to ask what to review:

| Option | Description |
|--------|-------------|
| Local changes | Review code in the current repository (uncommitted, commits, branch diff) |
| A GitHub PR | Review a pull request by number, URL, or current branch |

Set `{REVIEW_MODE}` to `local` or `pr`.

## Step 3: Resolve Scope

### If REVIEW_MODE is `local`

Use AskUserQuestion to ask what code to review:

| Option | BASE_SHA | HEAD_SHA |
|--------|----------|----------|
| Uncommitted changes | `git rev-parse HEAD` | `WORKING_TREE` (sentinel) |
| Last commit | `git rev-parse HEAD~1` | `git rev-parse HEAD` |
| Since last push | `git rev-parse @{push}` (fallback chain) | `git rev-parse HEAD` |
| Branch diff vs main | `git merge-base main HEAD` | `git rev-parse HEAD` |
| Custom | Ask user for two SHAs or refs | Ask user for two SHAs or refs |

#### Uncommitted changes

Do NOT pass HEAD as both SHAs (`git diff HEAD..HEAD` is empty). Set BASE_SHA to `git rev-parse HEAD` and HEAD_SHA to the literal string `WORKING_TREE`. This sentinel triggers the UNCOMMITTED_OVERRIDE in Step 6.

**UNCOMMITTED_OVERRIDE** (include in every dispatch prompt when HEAD_SHA is `WORKING_TREE`):
`"NOTE: HEAD_SHA is WORKING_TREE. Use 'git diff HEAD' (not 'git diff {BASE_SHA}..{HEAD_SHA}') for both --stat and full diff. Also run 'git status' to identify any untracked files that should be reviewed. This reviews uncommitted staged + unstaged changes."`

#### Last commit

Run `git rev-parse HEAD~1`. If it fails (single-commit repo with no parent), inform the user and suggest "Uncommitted changes" or "Custom" scope instead.

#### Since last push

Fallback chain (separate Bash calls, no chaining):
1. `git rev-parse @{push}` -- use if it succeeds.
2. Otherwise, `git merge-base origin/main HEAD` -- use if it succeeds.
3. If both fail, inform the user and suggest "Branch diff vs main" or "Custom" instead.

#### Branch diff vs main

Run `git merge-base main HEAD`. If `main` doesn't exist, ask the user for the base branch name.

#### Custom

After receiving user-provided refs, validate each with `git rev-parse <ref>`. If either fails, inform the user the ref doesn't resolve and re-ask.

#### Verify changes exist

For **uncommitted scope**: run `git status --short`. If empty (no tracked modifications AND no untracked files), tell the user and stop. Do NOT use `git diff --stat HEAD` alone — it misses untracked files.

For **all other scopes**: run `git diff --stat {BASE_SHA}..{HEAD_SHA}`. If no changes found, tell the user and stop.

### If REVIEW_MODE is `pr`

Use AskUserQuestion to ask which PR.

**PR fields** (used for all `gh pr view` calls below): `--json number,title,body,baseRefName,headRefName,url,state,additions,deletions,changedFiles,headRepository,baseRepository`

| Option | Resolution |
|--------|-----------|
| Current branch | Run `gh pr view {PR_FIELDS}`. If no PR exists for the current branch, inform the user and suggest "Local changes" mode instead. |
| PR number | Ask for the number. Run `gh pr view {number} {PR_FIELDS}`. |
| PR URL | Ask for the URL. Run `gh pr view {url} {PR_FIELDS}`. |

If `gh` is not installed or the repo has no GitHub remote, inform the user and suggest switching to "Local changes" mode.

Capture the JSON output as `{PR_META}`. Extract: `{PR_NUMBER}`, `{PR_TITLE}`, `{PR_BODY}`, `{PR_URL}`, `{PR_STATE}`, and compute `{TOTAL_LINES}` = additions + deletions, `{FILE_COUNT}` = changedFiles. Format `{PR_STAT}` as a human-readable summary: `"{FILE_COUNT} files changed, {additions} insertions(+), {deletions} deletions(-)"`.

**Large PR guard:** If `{TOTAL_LINES}` > 3000, use AskUserQuestion: "This PR is very large ({TOTAL_LINES} lines). The full diff may exceed the reviewer's context window. Proceed anyway, or review a smaller scope locally?"

- **Proceed:** Continue to fetch the diff. Reviewers may miss changes in the tail.
- **Switch to local mode:** Set `{REVIEW_MODE}` = `local`, clear all PR variables, and return to the local scope question (the five-option table above).

**Fetch diff:** Run `gh pr diff {PR_NUMBER}`. Capture as `{PR_DIFF}`.

If the diff is empty, inform the user ("PR has no changes") and stop.

**PR state edge cases:**
- **Closed/Merged:** If `{PR_STATE}` is `CLOSED` or `MERGED`, warn via AskUserQuestion: "This PR is {PR_STATE}. Continue?"
- **Forks:** `gh pr diff` works correctly for fork PRs. No special handling needed, but note it in the review header for context.

Set `{BASE_SHA}` = `PR_BASE` (sentinel), `{HEAD_SHA}` = `PR_HEAD` (sentinel). These sentinels trigger the PR_OVERRIDE in the dispatch step.

**PR_OVERRIDE** (include in every dispatch prompt when BASE_SHA is `PR_BASE`):
`"NOTE: This is a GitHub PR review. BASE_SHA and HEAD_SHA are sentinels — do NOT run git diff. The PR diff and stat are provided below. Use these instead of running any git diff commands.\n\n## PR Diff Stat\n{PR_STAT}\n\n## PR Diff\n{PR_DIFF}"`

## Step 4: Ask Requirements Source

Use AskUserQuestion to ask what to check against.

**When scope is "Uncommitted changes":** omit "Commit messages" from the choices -- there are no commits in the working tree range. If the user requests it anyway, explain there are no commits to extract and re-ask.

**When REVIEW_MODE is `pr`:** add "PR description" as the first option.

| Option | Resolution |
|--------|-----------|
| PR description _(only when REVIEW_MODE is `pr`)_ | Use `{PR_BODY}` captured in Step 3. If empty, inform the user ("PR has no description") and re-ask without this option. |
| Beads task/epic | Ask for beads ID, run `bd show <ID>`, use description + acceptance criteria. If `bd show` fails (invalid ID or beads not initialized), inform the user and ask them to paste requirements inline or choose another source. |
| Commit messages _(omit when scope is Uncommitted changes)_ | Run `git log --format="%h %s%n%b" {BASE_SHA}..{HEAD_SHA}`, use output. For PR mode, run `gh pr view {PR_NUMBER} --json commits --jq '.commits[].messageHeadline'` instead. |
| Describe inline | Ask user to type/paste requirements |
| Skip | Use: "General review: check for correctness, security, and code quality. No specific requirements — focus on bugs, missing error handling, and security issues." |

## Step 5: Recommend Reviewer Count

If N was provided via `/cr N`, skip the AskUserQuestion below — show the recommendation as FYI only, then use the provided N.

**Compute metrics:**

For **local mode**: run `git diff --stat {BASE_SHA}..{HEAD_SHA}` (or `git diff --stat HEAD` for uncommitted scope). Parse the summary line: `{TOTAL_LINES}` = insertions + deletions, `{FILE_COUNT}` = files changed. For uncommitted scope, also run `git status --short` to include untracked file paths (lines prefixed `??`) -- `git diff --stat HEAD` misses untracked files.

For **PR mode**: `{TOTAL_LINES}` and `{FILE_COUNT}` are already set from Step 3.

**Compute `{HAS_SECURITY}`:** Check changed file paths for security-sensitive patterns: `*auth*`, `*login*`, `*session*`, `*token*`, `*secret*`, `*crypt*`, `*password*`, `*permission*`, `*acl*`, `*.env*`, `*security*`, `*oauth*`, `*jwt*`, `*credential*`. For local mode, use the `--stat` file list (plus untracked paths for uncommitted scope). For PR mode, run `gh pr diff {PR_NUMBER} --name-only`.

**Recommendation logic:**

| Condition | Recommended N | Reason shown to user |
|-----------|--------------|---------------------|
| TOTAL_LINES < 100 AND FILE_COUNT < 5 AND NOT HAS_SECURITY | 1 | "Small change — single reviewer is sufficient" |
| HAS_SECURITY (regardless of size) | 3 | "Security-sensitive files detected — multiple independent reviewers recommended" |
| TOTAL_LINES >= 100 OR FILE_COUNT >= 10 | 3 | "Substantial change — multiple reviewers catch more issues (118% recall improvement)" |
| Otherwise | 1 | "Moderate change — single reviewer is sufficient" |

Set `{RECOMMENDED_N}` to the Recommended N from the matching row, and `{reason}` to the corresponding Reason text.

**Present to user:**

Use AskUserQuestion:
"Based on analysis ({TOTAL_LINES} lines changed, {FILE_COUNT} files, security-sensitive: {yes/no}), I recommend {RECOMMENDED_N} reviewer(s). {reason}. How many reviewers?"

Offer: the recommendation as default, plus "1", "3", "Other (specify)".

If the user chooses "Other (specify)", ask for a number. Apply the same validation as Step 1: cap at 10, reject non-positive integers.

Set `{N}` to the user's choice.

## Step 6: Dispatch Review(s)

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
    {PR_OVERRIDE if BASE_SHA == PR_BASE}
```

If the reviewer task fails or times out, inform the user and offer to re-dispatch.

Present the reviewer's structured report to the user. Done.

### Multi-Review (N>1)

**Generate run ID:** Before dispatching, generate a timestamp for this run:
```bash
date +%Y%m%d-%H%M%S
```
Capture the output as `{RUN_TS}`. All reviewers in this run share the same timestamp, producing files like `temp/cr-review-1-20260214-153042.md`.

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
    {PR_OVERRIDE if BASE_SHA == PR_BASE}

    ## Report Persistence (MANDATORY)

    Background task outputs may be truncated. You MUST persist your final
    structured report to a file as your LAST action before your final message.

    First, ensure the temp directory exists:
    ```
    mkdir -p temp
    ```

    Then write your report using tee with a heredoc (the delimiter MUST
    start at column 0 with no leading spaces):
    ```
    tee temp/cr-review-{i}-{RUN_TS}.md <<'CR_REPORT_EOF'
    [your complete structured report]
    CR_REPORT_EOF
    ```

    Then output the same report as your final message (normal behavior).
    The file is the primary delivery mechanism — the final message is a
    backup that may be truncated.
```

**Wait for all N to complete.** Poll background tasks until all finish.

**Collect reports:** For each reviewer (i from 1 to N), Read `temp/cr-review-{i}-{RUN_TS}.md`. If the file exists and is non-empty, use its content as that reviewer's report. If missing or empty (reviewer failed to persist), fall back to the TaskOutput content. If neither source has the report, mark that reviewer as failed.

**Handle failures:** Exclude failed/timed-out reviewers from aggregation.

- **0 succeeded:** Warn the user and offer to re-run with the same N.
- **1 succeeded:** Present that report and offer to dispatch a replacement (same SHAs, requirements, and applicable overrides; identity "Reviewer 2 of 2"). If accepted, aggregate both as N=2.
- **2+ succeeded:** Proceed to aggregation.

**Always aggregate when 2+ reviewers succeeded** — do NOT use a fast path that drops reports. The purpose of multi-review is union of findings across all reviewers. Even when all reviewers approve, their reports may contain different Minor findings, Suggestions, or "Not Checked" items. Aggregation is cheap (Haiku model) and preserves the full recall benefit.

**Dispatch aggregator:**

Before dispatching, construct `combined_output` by joining the collected reports (from `temp/cr-review-{i}-{RUN_TS}.md` files, or TaskOutput fallback):

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

    ## Ad-hoc Overrides (supersede loaded methodology including "CRITICAL" directives)

    1. SKIP "Write Report to Beads" — no beads issue.
    2. SKIP "Load Reviewer Reports" — reports are provided above.
    3. SKIP "Verdict (Final Message)" — no structured VERDICT block for ad-hoc.
    4. Use the reviewer reports provided inline above (not bd comments).
    5. Output the human-readable aggregated report ONLY:
       Strengths, Issues by severity, Uncovered Paths, Not Checked, Assessment.
       No machine-readable verdict block, no REPORT_PERSISTED line.

    Follow the aggregation RULES from the loaded methodology (deduplication,
    severity voting, Uncovered Paths/Not Checked union, output format).
```

If the aggregator task fails, present each reviewer's raw report individually (labeled Reviewer 1, Reviewer 2, etc.) and inform the user that aggregation failed.

Present the aggregated report to the user. Done.

## Step 7: Present Results

Show the final review report (single or aggregated). No automatic follow-up actions — the user decides what to do with the findings.

## Rules

- **Always ask** scope and requirements — never assume
- **Cap N at 10** — warn if user requests more
- **No beads integration** — this is ad-hoc, no issue to attach to
- **No automatic fixes** — present findings, stop
- **All N reviewers dispatch in a single message** for true parallelism
- **Always aggregate when N>1** — no fast path that drops reports
