# Upstream v6.2.0 review-fix loop: should superpowers-bd adopt it? (2026-10-14)

The parent session saved this from the subagent's hand-back, because the subagent's own write was blocked.

- **Upstream source:** obra/superpowers PR #1998 (commits 55bbb52 spec, c6fa27e plan, 28882fc templates, ebdd4ec SKILL.md), released in v6.2.0 (#2026). Later changes were reviewed through v7.0.0.
- **Spend:** about $9.45 of $15. Never more than 4 `claude` processes at once.

## Recommendation

| Sub-part | Verdict | Why |
|---|---|---|
| Resume the original implementer for fix rounds | **ADOPT** (fall back to a fresh dispatch; never pass `name:`; address by agentId) | Cheaper in every measured pair. Resumed Sonnet fixers refuse wrong findings: a spec-contradicting finding was applied 7/8 times by fresh fixers vs 0/8 by resumed ones. The user's Opus 5.5 controller already does this unprompted. |
| Rounds 4–5: fresh dispatch on a stronger model | **ADAPT** | Keep bd's 3-round cap. Rounds 1–2 resume; round 3 is a fresh dispatch one tier up; then the breaker. |
| Scoped `re-review-prompt.md` | **ADOPT** | Today a fix round implicitly reruns spec review, N=3 code reviewers and the aggregator. Use a fresh, cheap single re-reviewer: 3 of 7 real resumes of the original reviewer were cold-cache. |
| Breaker + controller adjudication | **ADAPT** | At the cap, park non-load-bearing findings with a `[RULING]` comment instead of PENDING_HUMAN. Disputes on spec grounds go straight to a ruling and don't use up a round. The load-bearing case should follow the autonomy-holds research. |

## Evidence

### E1: paired fresh vs resumed fixer (measured)

Setup (`exp/run_pairs.py`, `tests/research-2026-09` harness with a stub `bd` and `--setting-sources project`):
- **Phase 1:** a real bd implementer prompt implements a timefmt task with `claude -p`.
- **Fork:** the resulting state is copied into both arms.
- **Fresh arm:** a new `claude -p` with the full implementer prompt, a "previous implementer completed this" preamble, and the findings.
- **Resume arm:** `claude -p --resume <session>` with the same findings, the same transcript-replay mechanism SendMessage uses.
- **Grading:** hidden behavioral checks, 15 finding cases plus 23 regression cases.
- **Cost:** `total_cost_usd` is cumulative on resume, so phase 1 is subtracted from the resume arm.

| Arm | n | Fix cost (mean) | Wall | All fixed | Regressions | Wrong finding applied |
|---|---|---|---|---|---|---|
| Fresh, Sonnet 5.5, 4 correct findings | 12 | $0.101 | 18s | 12/12 | 0 | – |
| Resume, Sonnet 5.5, 4 correct findings | 12 | $0.037 (−63%; cheaper in 12/12) | 17s | 12/12 | 0 | – |
| Fresh, Sonnet 5.5, + 1 spec-contradicting finding | 8 | $0.113 | 25s | 8/8 | 7/8 | 7/8 (one flagged a concern but applied it anyway) |
| Resume, Sonnet 5.5, + the wrong finding | 8 | $0.044 (−61%) | 22s | 7/8* | 0/8 | 0/8; all 8 returned DONE_WITH_CONCERNS citing requirement 1 |
| Fresh, Opus 5.5, + the wrong finding | 5 | $0.288 | 43s | 5/5 | 0 | 0/5 |
| Resume, Opus 5.5, + the wrong finding | 5 | $0.177 (−38%) | 49s | 5/5 | 0 | 0/5 |

\* One resumed fixer read the "MM:SS" minutes as unbounded, which the spec arguably allows.

- The Sonnet wrong-finding split has Fisher p≈0.001. Opus pushed back in both arms.
- With correct findings both arms hit the ceiling, so there is no quality difference to see.
- Caveats: toy contexts were about 28k tokens, and every resume ran with a warm cache (the `-p` proxy has a 1-hour cache TTL; subagents use 5 minutes). E3 covers the real case.

### E2: real Claude Code path (n=2, Sonnet controller, CC 2.1.299)

- **Setup:** the controller dispatched a background `Agent` implementer with no `name`, waited, then sent findings with SendMessage to its agentId.
- **Result, 2/2:** the send succeeded, the result was delivered automatically as a completion notification, and all findings were fixed and committed. No teammate-mode or `idle_notification` stall.
- **Naming trap:** issue #2140 (still open) reports that naming an agent switches it to teammate mode, which then completes silently. The docs say this applies only in interactive sessions with agent teams enabled. Rule: never pass `name:`.

### E3: telemetry from the user's real bd session (acr 04010deb, 2026-10-09)

Opus 5.5 controller, 98 Agent dispatches, analyzed with `exp/real_resumes.py`.

- **Unprompted resumes:** 37 SendMessage resumes in total.
  - 30 were fixes or follow-ups sent to the original implementers.
  - 7 were "re-review fix commits X..Y" sent to the original reviewers.
  - No task exceeded 3 rounds.
- **Cache behavior by idle gap before the resume** (median gap 141s; matches the documented 5-minute subagent TTL):

| Gap | Cache | First-call cost |
|---|---|---|
| ≤223s | Hit | $0.03–0.10 |
| ≥307s (5 of 37) | Full context rewrite | $0.33–1.04, on 87k–278k-token contexts |

- **Context size:** implementer context at resume had a median of 112k tokens (range 66k–306k), so both the saving and the cold-cache penalty are larger than in the toy task.
- **Reviewer resumes:** 3 of 7 were cold, because the fix took longer than the TTL. Hence the fresh, small scoped re-reviewer.

### E4: nested-dispatch caveat

When the research subagent resumed its own background agent, that agent treated the message as coming from "a peer agent" and refused it twice. A controller in the main session is not affected. A nested controller could see its resume messages distrusted.

### Upstream evidence (as reported, not re-verified)

Campaigns: the author's (13 runs) and an independent one, PRI-2650 (93 runs, $273). They measured whether controllers follow the new mechanics, not the cost or quality of resuming vs dispatching fresh. "Resume is cheaper" was an anecdote; E1 is the first A/B.

| Mechanic | New loop | Old loop |
|---|---|---|
| Breaker parks findings | 6/6 | 0/6 |
| Scoped re-review | 2/2 | 0/2 |
| Round-4 escalation | 2/2 | 0/2 |
| Organic resume | 11 of 12 fix events | – |

- Two of upstream's severity claims did not reproduce at n=8.
- Changes in v6.3.0–v7.0.0:
  - "STOP: report BLOCKED to human" became "rule and continue; stop only if every path forward is a guess", with a "Rulings I made" list at the end.
  - Bounded waits replaced polling.
  - Codex resumes with `followup_task` (multi-agent V2, which also reloads evicted children) or `send_input` (V1).

### Platform facts (official docs)

**Claude Code:**
- SendMessage to an agentId resumes a completed background subagent with its full transcript, and the result is delivered automatically.
- Resume bugs were fixed in 2.1.290–2.1.299.
- Subagent cache TTL is 5 minutes by default. `subagentPromptCacheTtl: 1h` (2.1.242+) extends it, but 1-hour cache writes cost 2× base instead of 1.25×.
- Agents you stopped yourself, and Explore/Plan agents, cannot be resumed.
- Subagent transcripts are retained for 30 days.

**Codex 0.162.1:** the binary documents `followup_task`; upstream evals verified `send_input` live. Neither was tested live here.

## Change outline

Keep the byte-identical mirror in `plugins/superpowers-bd/skills/subagent-driven-development/` for every file below.

1. **`SKILL.md`:**
   - States: `REVIEW → FIX_ROUND(R) → RE_REVIEW → CLOSE | next round | ADJUDICATE`.
   - Rounds: R1–R2 resume the implementer (Claude Code: SendMessage to the agentId; Codex: `followup_task`, or `send_input` on V1). R3 is a fresh dispatch one tier up. Then adjudicate.
   - Fallback when the agent can't be messaged: fresh dispatch with the issue id, `[IMPL-REPORT]` and the findings.
   - Never name an implementer.
   - Minor findings never enter the loop.
2. **`background-execution.md`:**
   - add `on_review_findings` → resume;
   - track `fix_round` and `fix_base_sha` per task;
   - dispatch the fix as soon as consensus findings exist, to keep the cache warm;
   - Codex: don't close implementers early.
3. **New `re-review-prompt.md`:**
   - output, per finding: ADDRESSED or NOT ADDRESSED with file:line;
   - check only the fix diff for new breakage;
   - post out-of-scope issues as `[DEFERRED]` comments;
   - one reviewer (haiku, or sonnet for complex tasks; on Codex, `code_reviewer` with this prompt);
   - end with a `VERDICT:` line.
4. **`implementer-prompt.md` — new "After Review Findings" section:**
   - fix the findings and rerun the suite;
   - append "### Fix round R" to the report and commit as `fix:`;
   - return the same VERDICT block;
   - if a finding contradicts the spec, don't apply it — return DONE_WITH_CONCERNS naming the conflict.
5. **`failure-recovery.md`:** rewrite the rejection loop as breaker adjudication, and reconcile the conflicting caps (>2 here, >3 in SKILL.md, >=3 in verification-and-evidence.md, >2 for RE_DISPATCH).
6. **`verification-and-evidence.md`:** route gap-closure escalation to the same adjudication.
7. **`checkpoint-recovery.md`:** store `fix_rounds` and `implementer_agent_ids`.
8. **`metrics-tracking.md` / `[WAVE-SUMMARY]`:** record rounds and rulings. The epic-verifier reads `[RULING]` and `[DEFERRED]` comments.
9. **`example-workflow.md`:** add a worked fix round.
10. **Codex:** no new agent. Document the resume calls in SKILL.md's Codex section and `docs/README.codex.md`.
11. **Tests:** extend `test-workflow-contract-audit.sh`. Optionally add an eval case for wrong-finding pushback.

## Risks

- **Cold-cache resumes:** 14% in the real session, at about the cost of a fresh dispatch. Mitigation: fix promptly. A global 1-hour TTL is not recommended without measurement.
- **Anchoring:** a resumed implementer can keep missing its own blind spot, which is why round 3 is a fresh dispatch at a stronger tier. Not measured.
- **Pushback cost:** a resumed fixer could refuse a correct finding and burn rounds. With correct findings 12/12 complied; spec disputes go to a ruling either way.
- **Nested controllers and named agents** both break resume.
- **One small Python fixture:** correct-finding quality hit the ceiling, so the case for resume rests on cost (25/25 pairs) and on pushback (Sonnet only).

## Artifacts

- Results: `exp/results.jsonl`, `exp/real_resumes.json`, `exp/real_impl_contexts.json`.
- Upstream PRs and eval logs: `pr-*.md`, `evals-*.md` in this directory.
- Run directories: `/private/tmp/sbd-research-runs/resume-implementer/`.
- About 27 short leftover sessions under `~/.claude/projects/-private-tmp-sbd-research-runs-…` are safe to delete.
