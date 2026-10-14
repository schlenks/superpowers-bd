# Scoped Re-Reviewer Prompt Template

Dispatch one re-reviewer after each fix round (SKILL.md Review Rules; `background-execution.md` Fix Rounds). It checks only the findings sent to the implementer and the fix diff. It does not rerun spec review, the N code reviewers, or aggregation.

Placeholders: `{issue_id}`, `{epic_id}`, `{fix_round}` (1-3), `{fix_base_sha}` (the last reviewed commit), `{head_sha}` (COMMIT from the fix verdict), `{owned_paths}` (the issue's files; other implementers commit to the same branch), `{findings}` (numbered `F1`..`Fn`, consensus Critical/Important only, minus any a `[RULING]` dropped), `{wave_number}`.

## Claude Code Dispatch

```
Agent:
  subagent_type: "general-purpose"
  model: "haiku"   # "sonnet" for complexity:complex unless budget tier is pro/api
  run_in_background: true
  description: "Re-review R{fix_round}: {issue_id}"
  prompt: |
    [Use the shared re-reviewer prompt below.]
```

## Codex Dispatch

```
spawn_agent:
  agent: "code_reviewer"
  description: "Re-review R{fix_round}: {issue_id}"
  prompt: |
    [Use the shared re-reviewer prompt below.]
```

One reviewer per round on both platforms, except when a finding is security or data loss: then dispatch the tier-default N reviewers with this prompt (`budget-and-wave-cap.md` Review Fan-Out by Complexity), each verdict judged the same way. A fresh, small reviewer is used instead of resuming the original reviewers: their cache is usually cold by the time the fix lands.

## Shared Re-Reviewer Prompt

```
    You are re-reviewing fix round {fix_round} for beads issue {issue_id}.
    Your job is narrow: decide whether each finding below was addressed, and
    whether the fix itself broke anything.

    ## Findings Sent to the Implementer

    {findings}

    ## Load Your Context

    1. `bd show {issue_id}`: the requirements the findings are judged against.
    2. `bd comments {issue_id} --json`: the latest `[IMPL-REPORT]` and its
       `### Fix round {fix_round}` section, plus any `[RULING]` comments.
       Also read `[RULING]` comments on the epic (`bd comments {epic_id} --json`).
       A ruling amends the requirement it names.
    3. The fix diff, and only the fix diff:
       `git diff {fix_base_sha}..{head_sha} -- {owned_paths}`

    ## Your Job

    - For each finding, locate the change that addresses it. ADDRESSED needs
      file:line evidence in the fix diff (or in the file at {head_sha} when the
      fix removed code). No located evidence is NOT_ADDRESSED.
    - Where a finding concerns behavior, run the narrowest test that covers it.
    - Check the fix diff for new breakage: a bug, a broken test, a scope
      violation, or a drifted `skills/` mirror introduced by the fix. Report each
      as `N<k>` with file:line. New breakage fails the round.
    - Do not re-review code outside the fix diff and do not raise new findings
      about it. An issue you notice outside the findings and outside the fix
      diff is out of scope: post it once and move on:
      `bd comments add {epic_id} "[DEFERRED] {issue_id}: <file:line> — <issue> — seen in re-review R{fix_round}"`
      A `[DEFERRED]` item never fails the round. A security defect is the
      exception: report it as `N<k>`, wherever it is.
    - The implementer's notes are its self-assessment. Verify against the code.

    **Read-only:** Do not modify implementation files; only write the requested report artifact (`temp/{issue_id}-rereview-{fix_round}.md`) and `[DEFERRED]` comments. Do not change the working tree or branch (`git checkout`, `git switch`, `git stash`, `git reset`, `git commit`); inspect other revisions with `git show <sha>:<path>` or `git diff`. Do not dispatch subagents.

    ## Write Report to Beads

    **Each step below MUST be a separate tool call. Never combine into one Bash command.**

    1. Create `temp/{issue_id}-rereview-{fix_round}.md`:
       ```
       [RE-REVIEW-{fix_round}] {issue_id} wave-{wave_number}
       Fix diff: {fix_base_sha}..{head_sha}
       F1: ADDRESSED|NOT_ADDRESSED — file:line (evidence)
       ...
       New breakage: none | N1: file:line — issue
       Deferred: none | <count> [DEFERRED] comments posted
       ```
    2. Run: `bd comments add {issue_id} -f temp/{issue_id}-rereview-{fix_round}.md`
    3. Run: `bd comments {issue_id} --json`
    4. If `bd comments add` fails, retry up to 3 times with `sleep 2` between attempts.

    ## Verdict (Final Message)

    **Your final message must contain ONLY these lines. No preamble or narrative.**

    ```
    F1: ADDRESSED|NOT_ADDRESSED — file:line
    F2: ADDRESSED|NOT_ADDRESSED — file:line
    NEW: none | N1: file:line — <issue>; ...
    REPORT_PERSISTED: YES|NO
    VERDICT: PASS|FAIL
    ```

    - One `F<n>` line per finding, in the order given.
    - PASS only when every finding is ADDRESSED and NEW is none. Otherwise FAIL.
```

The orchestrator routes FAIL to the next fix round with the NOT_ADDRESSED findings and the `N<k>` lines as the new findings, or to adjudication after round 3 (`failure-recovery.md`).
