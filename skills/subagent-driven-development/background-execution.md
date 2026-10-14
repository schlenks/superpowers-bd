# Background Execution

## When to Use

For 2+ tasks per wave (up to the configured wave cap, default 5 for extended context and 3 for standard context), background execution lets you monitor all tasks simultaneously and start reviews as soon as each completes.

Use platform-native background dispatch. Claude Code uses `Agent(..., run_in_background=True)` and notifies when each agent completes. Codex uses `spawn_agent` and `wait_agent` only when the orchestrator is blocked on a result.

Claude Code model names in this document are literal SDD dispatch-tier choices governed by the complexity and budget tables. They are intentionally distinct from the `{low_cost_synthesis_model}` placeholder used for aggregation synthesis.

## Dispatch Phase

### Claude Code

```python
pending_tasks = {}  # agent_id -> {issue_id, complexity, base_sha, output_file, ...}
pending_reviews = {}  # review_id -> {issue_id, phase, base_sha, head_sha, ...}
agent_ids = []

wave_base_sha = run("git rev-parse HEAD")

for issue in parallelizable:
    bd update <issue.id> --status=in_progress
    impl_model = resolve_impl_model(issue.complexity, budget_tier)
    result = Agent(  # never pass a name: teammate mode breaks resume
        subagent_type="general-purpose",
        model=impl_model,
        run_in_background=True,
        description=f"Implement: {issue.id} {issue.title}",
        prompt=implementer_prompt
    )
    assert result.status == "async_launched"
    pending_tasks[result.agentId] = {
        "issue_id": issue.id,
        "complexity": issue.complexity,
        "platform": "claude-code",
        "model": impl_model,
        "base_sha": wave_base_sha,
        "output_file": result.outputFile,
        "fix_round": 0  # Fix Rounds below; resumed by this agentId
    }
    agent_ids.append(result.agentId)
```

### Codex

```python
pending_tasks = {}  # agent_id -> {issue_id, complexity, base_sha, ...}
pending_reviews = {}  # review_id -> {issue_id, phase, base_sha, head_sha, ...}
agent_ids = []

wave_base_sha = run("git rev-parse HEAD")

for issue in parallelizable:
    bd update <issue.id> --status=in_progress
    impl_effort = resolve_codex_impl_effort(issue.complexity, budget_tier)
    result = spawn_agent(
        model_reasoning_effort=impl_effort,
        description=f"Implement: {issue.id} {issue.title}",
        prompt=implementer_prompt
    )
    pending_tasks[result.agent_id] = {
        "issue_id": issue.id,
        "complexity": issue.complexity,
        "platform": "codex",
        "model_policy": "inherit_active_model",
        "model_reasoning_effort": impl_effort,
        "base_sha": wave_base_sha,
        "fix_round": 0  # keep the agent open until the task closes
    }
    agent_ids.append(result.agent_id)
```

## Monitor Phase

Sub-agents persist full reports to beads comments. Only structured verdicts flow through the agent's final output.

Claude Code background agents notify automatically on completion; when notified, `Read` the agent's output file path to retrieve the verdict. Codex should continue useful orchestration work and call `wait_agent` only when no next step can proceed without that result.

```python
on_agent_complete(agent_id, output):
    issue_id = pending_tasks[agent_id]["issue_id"]
    verdict = parse_verdict(output)
    # DONE/DONE_WITH_CONCERNS: VERDICT, COMMIT, FILES, TESTS, SCOPE, INTERFACES, REPORT_PERSISTED, [CONCERNS]
    # Carry non-"none" INTERFACES into the next [WAVE-SUMMARY] (metrics-tracking.md).
    # BLOCKED/NEEDS_CONTEXT: VERDICT, BLOCKER, REPORT_PERSISTED

    if verdict.report_persisted == "NO":
        dispatch_full_report_fallback(agent_id, issue_id)

    on_implementer_complete(agent_id, verdict)

on_review_complete(review_id, output):
    issue_id = pending_reviews[review_id]["issue_id"]
    verdict = parse_verdict(output)
    if verdict.report_persisted == "NO":
        dispatch_full_report_fallback(review_id, issue_id)
    else:
        process_review(review_id, verdict)
```

## Codex Verdict Validation

The Codex SubagentStop hook blocks missing verdicts during active SDD waves,
but the orchestrator must still validate each `wait_agent` result before routing
it. Hooks are guardrails, not the source of truth for workflow state.

After `wait_agent`, parse the final output:

- Accept only a top-level line beginning `VERDICT:` with an allowed status for
  that stage.
- If the output has a missing or malformed `VERDICT`, do not infer success from
  narrative text or persisted report files.
- On the first malformed result, re-dispatch with the same prompt plus a terse
  correction: the final response must contain only the structured verdict.
- On the second malformed result, treat it as an agent failure and follow the
  implementer or reviewer failure recovery path.

Persisted beads reports support audit and fallback retrieval, but they do not
replace the final verdict. Route work only after valid verdict fields are
present.

## REPORT_PERSISTED Fallback

If a sub-agent returns `REPORT_PERSISTED: NO`, the full report was not saved to beads. The orchestrator re-dispatches a lightweight agent to retrieve it.

**Claude Code:**

```python
def dispatch_full_report_fallback(agent_id, issue_id):
    fallback = Agent(
        subagent_type="general-purpose",
        model="haiku",
        description=f"Retrieve report: {issue_id}",
        prompt=f"The previous agent for {issue_id} failed to persist its report. "
               f"Run: bd comments {issue_id} --json "
               f"If the report is missing, report MISSING. Otherwise return the report."
    )
```

**Codex:**

```python
def dispatch_full_report_fallback(agent_id, issue_id):
    fallback = spawn_agent(
        model_reasoning_effort="low",
        description=f"Retrieve report: {issue_id}",
        prompt=f"The previous agent for {issue_id} failed to persist its report. "
               f"Run: bd comments {issue_id} --json "
               f"If the report is missing, report MISSING. Otherwise return the report."
    )
```

## Review Pipeline Parallelism

Reviews for different tasks can run in parallel:

```text
Timeline (3 tasks, N=3 reviews, max parallelism):
Task A: [implement]----[spec-A]----[code-A x 3]----[agg-A]----> close
Task B:    [implement]----[spec-B]----[code-B x 3]----[agg-B]----> close
Task C:       [implement]----[spec-C]----[code-C x 3]--[agg-C]--> close
                       ^         ^               ^
                       +--parallel--+    (Claude Code may also run Codex advisory review)
```

**Rules:**
- Spec review for A and spec review for B can run in parallel.
- Code review A must wait for spec review A.
- Code review for A and code review for B can run in parallel.
- Claude Code Codex advisory review for A is dispatched in the same message as code reviews for A when enabled.

## Event-Driven Dispatch

### Shared Routing

```python
on_implementer_complete(agent_id, result):
    verdict = result

    if verdict.status in ("DONE", "DONE_WITH_CONCERNS"):
        head_sha = verdict.COMMIT
        base_sha = pending_tasks[agent_id]["base_sha"]
        pending_tasks[agent_id]["head_sha"] = head_sha

        if verdict.status == "DONE_WITH_CONCERNS":
            pending_tasks[agent_id]["concerns"] = verdict.CONCERNS

        if pending_tasks[agent_id]["fix_round"] > 0:
            on_fix_complete(agent_id, verdict)  # Fix Rounds: scoped re-review, not the full pipeline
        else:
            dispatch_spec_review(agent_id, base_sha, head_sha)

    elif verdict.status == "NEEDS_CONTEXT":
        redispatch_count = pending_tasks[agent_id].get("redispatch_count", 0) + 1
        pending_tasks[agent_id]["redispatch_count"] = redispatch_count
        if redispatch_count > 2:
            # Third NEEDS_CONTEXT: question bead blocking the task, never a pause
            # (rulings-and-escalation.md Escalation Format; failure-recovery.md)
            issue_id = pending_tasks[agent_id]["issue_id"]
            escalated_tasks[issue_id] = verdict.BLOCKER
            escalate(issue_id, question=f"Implementer asked for context 3 times: {verdict.BLOCKER}")
            # continue with independent ready issues
        else:
            redispatch_with_context(agent_id, verdict.BLOCKER, same_strength=True)

    elif verdict.status == "BLOCKED":
        handle_blocked_implementer(agent_id, verdict.BLOCKER)
```

### Claude Code Review Dispatch

```python
def dispatch_spec_review(agent_id, base_sha, head_sha):
    task_complexity = pending_tasks[agent_id]["complexity"]
    spec_model = "sonnet" if task_complexity == "complex" and budget_tier != "pro/api" else "haiku"
    spec_agent = Agent(
        subagent_type="general-purpose",
        model=spec_model,
        run_in_background=True,
        description=f"Spec review: {agent_id}",
        prompt=spec_reviewer_prompt
    )
    assert spec_agent.status == "async_launched"
    pending_spec_reviews.add(spec_agent.agentId)
    pending_reviews[spec_agent.agentId] = {
        "issue_id": pending_tasks[agent_id]["issue_id"],
        "phase": "spec",
        "base_sha": base_sha,
        "head_sha": head_sha,
        "output_file": spec_agent.outputFile
    }

def on_spec_review_pass(agent_id, result):
    issue_id = pending_tasks[agent_id]["issue_id"]
    base_sha = pending_tasks[agent_id]["base_sha"]
    head_sha = pending_tasks[agent_id]["head_sha"]
    n_reviews = tier_n_reviews

    if is_trivial_diff(base_sha, head_sha) and n_reviews > 1:
        n_reviews = 1

    reviewer_agents = []
    for i in range(n_reviews):
        code_agent = Agent(
            subagent_type="general-purpose",
            model=tier_code_model,
            run_in_background=True,
            description=f"Code review {i+1}/{n_reviews}: {agent_id}",
            prompt=code_reviewer_prompt.format(
                code_reviewer_path=code_reviewer_path,
                issue_id=issue_id,
                base_sha=base_sha,
                head_sha=head_sha,
                wave_number=wave_n
            ) + f"\nYou are Reviewer {i+1} of {n_reviews}. "
                "Review independently and do not reference other reviewers."
        )
        assert code_agent.status == "async_launched"
        reviewer_agents.append(code_agent.agentId)
        pending_reviews[code_agent.agentId] = {
            "issue_id": issue_id,
            "phase": "code",
            "base_sha": base_sha,
            "head_sha": head_sha,
            "output_file": code_agent.outputFile
        }

    if n_reviews > 1:
        pending_multi_reviews[agent_id] = reviewer_agents

    if checkpoint.platform == "claude-code" and checkpoint.codex_enabled and budget_tier != "pro/api":
        codex_agent = Agent(
            subagent_type="general-purpose",
            run_in_background=True,
            description=f"Codex cross-model review: {agent_id}",
            prompt=f"""Run a Codex adversarial review of the changes for {issue_id}.

                ```bash
                node "{checkpoint.codex_install_path}/scripts/codex-companion.mjs" adversarial-review --wait --base {base_sha}
                ```

                Persist the full output to temp/{issue_id}-codex-wave-{wave_n}.md.
                Output the full review as your final message."""
        )
        assert codex_agent.status == "async_launched"
        pending_codex_reviews[agent_id] = {
            "agent_id": codex_agent.agentId,
            "output_file": codex_agent.outputFile
        }
```

### Codex Native Review Dispatch

In native Codex sessions, Codex is the orchestrator. Use native agents for the review pipeline instead of running a separate cross-model Codex advisory review.

```python
def dispatch_spec_review(agent_id, base_sha, head_sha):
    spec_agent = spawn_agent(
        agent="spec_reviewer",
        description=f"Spec review: {agent_id}",
        prompt=spec_reviewer_prompt
    )
    pending_spec_reviews.add(spec_agent)
    pending_reviews[spec_agent.agent_id] = {
        "issue_id": pending_tasks[agent_id]["issue_id"],
        "phase": "spec",
        "base_sha": base_sha,
        "head_sha": head_sha
    }

def on_spec_review_pass(agent_id, result):
    issue_id = pending_tasks[agent_id]["issue_id"]
    base_sha = pending_tasks[agent_id]["base_sha"]
    head_sha = pending_tasks[agent_id]["head_sha"]
    n_reviews = tier_n_reviews

    if is_trivial_diff(base_sha, head_sha) and n_reviews > 1:
        n_reviews = 1

    reviewer_agents = []
    for i in range(n_reviews):
        reviewer = spawn_agent(
            agent="code_reviewer",
            description=f"Code review {i+1}/{n_reviews}: {agent_id}",
            prompt=code_reviewer_prompt.format(
                code_reviewer_path=code_reviewer_path,
                issue_id=issue_id,
                base_sha=base_sha,
                head_sha=head_sha,
                wave_number=wave_n,
                reviewer_number=i + 1,
                n_reviews=n_reviews
            ) + f"\nYou are Reviewer {i+1} of {n_reviews}. "
                "Review independently and do not reference other reviewers."
        )
        reviewer_agents.append(reviewer)
        pending_reviews[reviewer.agent_id] = {
            "issue_id": issue_id,
            "phase": "code",
            "base_sha": base_sha,
            "head_sha": head_sha
        }

    if n_reviews > 1:
        pending_multi_reviews[agent_id] = reviewer_agents
        pending_aggregators[agent_id] = "spawn review_aggregator after all reviewers finish"
```

When all Codex code reviewers for a task complete and `n_reviews > 1`, dispatch:

```python
spawn_agent(
    agent="review_aggregator",
    description=f"Aggregate reviews: {issue_id}",
    prompt="Aggregate the persisted code review reports for this issue. "
           "Preserve Critical and Important findings and produce the final verdict."
)
```

## Fix Rounds

When spec review FAILs, or code review ends with Critical or Important consensus findings (after aggregation when N > 1), the original implementer fixes them. Spec FAIL items count as Important. One cap of 3 rounds per task covers review findings and gap-closure fixes (`verification-and-evidence.md`). Minor findings never enter the loop: list them in the close reason.

```python
FIX_ROUND_CAP = 3

def on_review_findings(agent_id, findings, phase):  # phase: "spec" | "code" | "verify"
    # Call this as soon as consensus findings exist. A resumed subagent's prompt
    # cache expires after about 5 minutes idle; after that the resume pays to
    # rewrite its whole context.
    task = pending_tasks[agent_id]
    # Spec FAIL items arrive as Important, verification failures as Critical.
    findings = [f for f in findings if f.severity in ("Critical", "Important")]
    if not findings:
        return close_path(agent_id)               # verification-and-evidence.md
    if task["fix_round"] == FIX_ROUND_CAP:
        return adjudicate(task["issue_id"], findings)   # failure-recovery.md
    task["fix_round"] += 1
    task["review_phase"] = phase
    task["fix_base_sha"] = task["head_sha"]       # last reviewed commit
    task["open_findings"] = number_as_F1_to_Fn(findings)
    write_checkpoint()                            # checkpoint-recovery.md fix_loop

    message = fix_message(task)  # round R, findings F1..Fn, issue id; the
                                 # implementer follows "After Review Findings"
    if task["fix_round"] <= 2 and resume(agent_id, message):
        return                                    # completion arrives as usual
    if task["fix_round"] <= 2:
        dispatch_fresh_fix(agent_id, same_strength=True)  # fallback, same round
    else:
        dispatch_fresh_fix(agent_id, one_tier_up=True)    # round 3

def resume(agent_id, message):
    # Claude Code: SendMessage(to=agent_id, message=message). The agent resumes
    #   from its transcript and its completion is delivered like the first one.
    # Codex: followup_task(agent_id, message), or send_input(agent_id, message)
    #   on multi-agent V1.
    # Returns False when the agent can't be messaged: you stopped it, it is an
    # Explore/Plan agent, its transcript is gone, the send errors, or (Codex)
    # it was closed.
    ...

def dispatch_fresh_fix(agent_id, same_strength=False, one_tier_up=False):
    # New implementer with the shared implementer prompt plus: the issue id,
    # "read the latest [IMPL-REPORT] in bd comments <issue-id> --json", the
    # round number and F1..Fn. Round 3 moves one tier up (haiku->sonnet->opus,
    # capped by the budget tier; Codex: one model_reasoning_effort step up).
    # The fallback does not use up a round: it IS round R.
    new_id = dispatch_implementer(..., fix_round=pending_tasks[agent_id]["fix_round"])
    pending_tasks[new_id] = pending_tasks.pop(agent_id)  # later rounds resume new_id
    pending_tasks[new_id]["implementer_agent_id"] = new_id

def on_fix_complete(agent_id, verdict):
    task = pending_tasks[agent_id]
    disputed = spec_disputes(verdict.CONCERNS)    # "F2 contradicts requirement 1"
    for finding in disputed:
        # Rule at once, by the authority order in rulings-and-escalation.md.
        # A dispute does not use up a round.
        ruling = rule(task["issue_id"], finding)
        if ruling.keeps_spec:
            task["open_findings"].remove(finding)
        else:
            resume_or_fallback(agent_id, ruling)  # same round R, then continue here
            return
    dispatch_re_review(agent_id, task["fix_base_sha"], task["head_sha"],
                       task["open_findings"])     # re-review-prompt.md

def on_re_review_complete(agent_id, verdict):
    task = pending_tasks[agent_id]
    if verdict.status == "PASS" and task["review_phase"] == "spec":
        return on_spec_review_pass(agent_id, verdict)  # code review has not run yet
    if verdict.status == "PASS":
        return close_path(agent_id)               # gap closure, then bd close
    findings = verdict.not_addressed + verdict.new_breakage
    on_review_findings(agent_id, findings, task["review_phase"])  # next round, or adjudicate after R3
```

**Re-review dispatch.** One reviewer per round, using `re-review-prompt.md` (tier-default N for a security or data-loss finding; any FAIL fails the round):

- Claude Code: `Agent(subagent_type="general-purpose", model="sonnet" if complexity == "complex" and budget_tier != "pro/api" else "haiku", run_in_background=True)`.
- Codex: `spawn_agent(agent="code_reviewer")` with the re-review prompt.

Never rerun spec review, the N code reviewers, or aggregation for a fix round. The re-reviewer posts out-of-scope issues as `[DEFERRED]` comments, which never block the close.

**Codex:** do not close an implementer (`close_agent`) until its task closes or is adjudicated. A closed agent cannot take `followup_task` or `send_input`, so every later round would fall back to a fresh dispatch.

**Fallback check.** `resume` is attempted first in rounds 1 and 2. Fall back only when it fails, and record which path ran (`resume` or `fallback`) for the `[WAVE-SUMMARY]` Fix rounds line (`metrics-tracking.md`).

## Claude Code: Codex Cross-Model Review Presentation

After Claude Code code reviews complete and aggregation if N > 1, check for Codex advisory results:

1. If `pending_codex_reviews[agent_id]` exists, wait for the Codex agent to complete.
2. Read `temp/{issue_id}-codex-wave-{wave_n}.md` as primary evidence. Fall back to agent output if the file is missing.
3. Present as a separate section in the task review summary after the Claude aggregated report:

```markdown
## Cross-Model Review (Codex) - {issue_id}

[Full Codex adversarial review output]
```

4. If Codex failed or timed out: `_Codex cross-model review was unavailable for this task._`

Codex is advisory-only in Claude Code sessions. The Claude aggregated verdict remains the gate for `bd close`. In native Codex sessions, skip this subsection because Codex is already the orchestrator.
