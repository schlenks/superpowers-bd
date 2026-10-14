# Scoped Re-Reviewer Prompt Template

Dispatch one re-reviewer after each fix round (SKILL.md Review Rules; `background-execution.md` Fix Rounds). It checks only the findings sent to the implementer and the fix diff. It does not rerun spec review, the N code reviewers, or aggregation.

Placeholders: `{issue_id}`, `{epic_id}`, `{fix_round}` (1-3), `{reviewer_n}` (1 unless the security carve-out below dispatches several), `{test_command}` (the project's whole-suite command), `{fix_base_sha}` (the last reviewed commit), `{head_sha}` (COMMIT from the fix verdict), `{owned_paths}` (the issue's files; other implementers commit to the same branch), `{findings}` (numbered `F1`..`Fn`, consensus Critical/Important only, minus any a `[RULING]` dropped), `{wave_number}`.

## Claude Code Dispatch

```
Agent:
  subagent_type: "general-purpose"
  model: "haiku"   # "sonnet" for complexity:complex unless budget tier is pro/api, and always for the security carve-out
  run_in_background: true
  description: "Re-review R{fix_round}.{reviewer_n}: {issue_id}"
  prompt: |
    [Use the shared re-reviewer prompt below.]
```

## Codex Dispatch

```
spawn_agent:
  agent: "code_reviewer"
  description: "Re-review R{fix_round}.{reviewer_n}: {issue_id}"
  prompt: |
    [Use the shared re-reviewer prompt below.]
```

N re-reviewers per round follow `budget-and-wave-cap.md` Review Fan-Out by Complexity: one, or the tier-default N on sonnet when a finding is security or data loss. With several, each gets its own `{reviewer_n}` and report file, and the round FAILs if any reviewer reports a NOT_ADDRESSED finding or new breakage. A fresh, small reviewer is used instead of resuming the original reviewers: their cache is usually cold by the time the fix lands.

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
    3. The fix diff: `git diff {fix_base_sha}..{head_sha} -- {owned_paths}`.
    4. Scope check: `git diff --stat {fix_base_sha}..{head_sha}` with no path
       filter, plus `git log --format='%h %s' {fix_base_sha}..{head_sha}`.
       Other implementers' commits share the branch; a commit for
       {issue_id} that touches a file outside {owned_paths} is a scope
       violation (new breakage).

    ## Your Job

    - For each finding, locate the change that addresses it. ADDRESSED needs
      file:line evidence in the fix diff (or in the file at {head_sha} when the
      fix removed code). No located evidence is NOT_ADDRESSED.
    - Run the project's whole test suite on {head_sha}: `{test_command}`.
      Any failure the fix caused is new breakage; a failure that already
      existed at {fix_base_sha} goes in your report, not in NEW.
    - For every public symbol (function, type, exported name, documented
      format) the fix diff changes, grep its callers and readers across the
      repository and check they still match. A broken caller is new breakage,
      even though it lies outside the fix diff.
    - Check the fix diff for new breakage: a bug, a broken test, a scope
      violation, or a drifted `skills/` mirror introduced by the fix. A test
      the fix weakened is new breakage too: an assertion loosened, deleted or
      skipped, an input special-cased, or an expected output hardcoded (the
      implementer's Test Integrity rules). Report each as `N<k>` with
      file:line. New breakage fails the round.
    - Apart from those caller checks, do not re-review code outside the fix
      diff and do not raise new findings about it. An issue you notice outside the findings and outside the fix
      diff is out of scope: post it once and move on:
      `bd comments add {epic_id} "[DEFERRED] {issue_id}: <file:line> — <issue> — seen in re-review R{fix_round}"`
      A `[DEFERRED]` item never fails the round; the epic verifier still evaluates it. A security defect is the
      exception: report it as `N<k>`, wherever it is.
    - The implementer's notes are its self-assessment. Verify against the code.

    **Read-only:** Do not modify implementation files; only write the requested report artifact (`temp/{issue_id}-rereview-{fix_round}-{reviewer_n}.md`) and `[DEFERRED]` comments. Do not change the working tree or branch (`git checkout`, `git switch`, `git stash`, `git reset`, `git commit`); inspect other revisions with `git show <sha>:<path>` or `git diff`. Do not dispatch subagents.

    ## Write Report to Beads

    **Each step below MUST be a separate tool call. Never combine into one Bash command.**

    1. Create `temp/{issue_id}-rereview-{fix_round}-{reviewer_n}.md`:
       ```
       [RE-REVIEW-{fix_round}.{reviewer_n}] {issue_id} wave-{wave_number}
       Fix diff: {fix_base_sha}..{head_sha}
       Suite: {test_command} → <pass>/<total>, exit <code>
       Scope: CLEAN | VIOLATION <file>
       F1: ADDRESSED|NOT_ADDRESSED — file:line (evidence)
       ...
       New breakage: none | N1: file:line — issue
       Deferred: none | <count> [DEFERRED] comments posted
       ```
    2. Run: `bd comments add {issue_id} -f temp/{issue_id}-rereview-{fix_round}-{reviewer_n}.md`
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

With several re-reviewers, the orchestrator combines them first: any NOT_ADDRESSED or NEW line from any reviewer makes the round FAIL. It routes FAIL to the next fix round with the NOT_ADDRESSED findings and the `N<k>` lines as the new findings, or to adjudication after round 3 (`failure-recovery.md`).
