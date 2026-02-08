# Superpowers-BD: Comprehensive Improvement Report

**Date:** February 8, 2026 (v5.3 — V2 experiments executed, Two-Phase DENIED, 43 active)
**Purpose:** Dramatically improve superpowers-bd by leveraging native Claude Code features + adding unique value (quality gates, persistence, file ownership)
**Philosophy:** If it's worth doing, do it. If Claude Code does it natively, use that instead. If beads already does it, don't rebuild it.

---

## How to Read This Document

1. **Section 1:** All **43 ACTIVE** improvements ranked by impact
2. **Section 2:** **PRIORITIZED** implementation order — easy wins first, code changes later
3. **Section 3:** Reference info (Opus 4.6, Claude Code 2.1.33+, Beads v0.49.4)
4. **Section 4:** Open questions — answered with research
5. **Section 5:** Additional research opportunities
6. **Section 6:** SWE-Agent research findings
7. **Section 7:** Summary: The path forward

**Key decisions already made:**
- **Dolt migration: COMPLETED** (Feb 7, 2026). Beads v0.49.4 on Dolt backend.
- **12 improvements deprecated** — now native to Claude Code 2.1.33+ (memory frontmatter, hooks, Task metrics, agent teams).
- **Agent Mail: REMOVED** — beads Rust (`br`) incompatible with Dolt backend; hook-based file ownership replaces it with zero dependencies.
- **Semaphore concurrency: ALREADY IN BEADS** — v0.49.4 has 6 layers of concurrency protection. 40 concurrent `bd create` operations succeeded with zero failures.
- **Retry with verification: NOT NEEDED** — beads uses embedded Dolt (not sql-server). Silent write failures do not occur in embedded mode.
- **Process termination (#7 v4.1): REMOVED** — Gastown tmux-specific. superpowers-bd uses Claude Code's Task tool which manages its own process lifecycle. Plugin layer cannot fix upstream orphan process bugs (Claude Code Issues #20369, #22554).
- **Pre-commit quality guard (#8 v4.1): REMOVED** — Agent identity unavailable in git hooks. pre-commit.com destroys beads' existing hook shims. Redundant if PreToolUse file ownership (#3) is implemented.
- **Task type classification (#10 v4.1): REMOVED** — Already implemented in subagent-driven-development skill (prompt routing, budget tier matrix, retry/escalation). Remaining effort-level aspect merged into #36.
- **Agent Teams: DEFERRED** — ~7x token cost makes this impractical for Max 20x subscribers (could wipe daily/weekly quota in a single session). Research preserved in Section 3.1 for when costs decrease or API users want it. Two items removed (#45 feature detection, #46 two-mode SDD). Agent teams integration (#35) moved to P8 (future).
- **Priority reordering:** Config/hooks first → stable skill modernization → prompt changes → code changes.

---

## 1. All ACTIVE Improvements Ranked by Impact (44 Remaining)

### CRITICAL IMPACT — Prevents failures, enables core capabilities

(No items — #1 moved to REMOVED after V2 experiment DENIED verdict)

### HIGH IMPACT — Significant quality or efficiency gains

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 2 | ~~**Two-phase delayed dispatch**~~ | **MERGED into #15.** The SDD skill already implements the two-phase pattern (conflict verification task blocks wave dispatch via `addBlockedBy`). The remaining value — formal `file-locks.json` generation — is exactly what #15 delivers. Keeping as separate item was redundant. | Gastown §1.4 (adapted) |
| 3 | **File ownership enforcement via hooks** | Proactive conflict prevention. `PreToolUse` hook on `Edit\|Write` checks `.claude/file-locks.json` and blocks edits to files owned by other agents. **⚠️ BLOCKED on TWO issues:** (1) `$AGENT_NAME` does not exist for regular subagents ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126)), (2) PreToolUse hooks **do not fire for subagent tool calls** ([Issue #21460](https://github.com/anthropics/claude-code/issues/21460)). Six related hook enforcement issues span Aug 2025–Jan 2026 with zero Anthropic resolution. **Primary approach is now prompt-based (#15)**, validated by Anthropic's own C compiler project at production scale. Hook enforcement is a future defense-in-depth layer. **Moved to P5 (deferred).** | Hook-based |
| 4 | **Strict SSOT: Query, Don't Track** | Prevents state drift bugs. Instead of caching task state in skills, always query beads for truth. Reality is authoritative; derived state cannot diverge. **Note:** The SDD skill already follows this pattern (queries `bd ready` at every loop iteration). This is a **design principle to codify**, not a code change. "Skills MUST NOT cache beads query results across wave boundaries." | Distributed systems SSOT principle |
| 5 | **TaskCompleted hook for quality gates** | Hard enforcement at task completion. `TaskCompleted` hook exits with code 2 to block task completion if quality criteria not met. Genuinely enforced by Claude Code (not advisory). Can use `type: "agent"` for 50-turn code analysis hooks. **The only hard enforcement mechanism that works for subagents** — PreToolUse/PostToolUse hooks do NOT fire for subagent tool calls ([Issue #21460](https://github.com/anthropics/claude-code/issues/21460)). GA since v2.1.33, pure config. **V2 Experiment A (2026-02-08):** Headless `claude -p` mode: TaskCompleted NEVER fired (0/10). **Manual verification (2026-02-08): Interactive `claude` mode: TaskCompleted FIRES.** Marker file created, hook log written. **Conclusion:** TaskCompleted works in interactive mode only. Viable for quality gate enforcement in normal Claude Code sessions. Not viable for headless automation (`claude -p`). | Native hooks |
| 6 | **Strengthen existing simplification checks + linter hooks** | Reduces code complexity. The qualitative review ("dead code? duplication? over-engineering?") is already covered by 5+ existing skills (rule-of-five Clarity pass, spec-reviewer over-engineering check, epic-verifier YAGNI, code-reviewer DRY, TDD REFACTOR phase). **Do NOT create a new skill.** Instead: (a) add quantitative checklist items to existing code-reviewer.md, (b) implement cyclomatic complexity enforcement via PostToolUse linter hooks (#25). Thresholds: flag >10, block >15 (matches McCabe/NIST). | Industry standard (SonarQube, ESLint, NIST) |

### MEDIUM IMPACT — Meaningful improvements to workflow

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 7 | **Checkpoint classification in plans** | Binary flag: `requires_human: true/false` on plan steps. Current system already batches automated work and pauses at batch boundaries. This formalizes the annotation. Original three-way taxonomy (AUTOMATED/HUMAN_DECISION/HUMAN_ACTION) is over-specified — the HUMAN_DECISION vs HUMAN_ACTION distinction rarely matters in practice. | Inspired by get-shit-done (simplified) |
| 8 | **Parallelize review pipelines** | Reviews for different tasks run concurrently. Task A and Task B reviews don't wait for each other. Only sequential: spec review before code review for same task. **Note:** This is throughput parallelism, distinct from multi-review aggregation (#46). | Original research |
| 9 | **Parallel bd queries with indexed results** | 6x speedup on multi-query operations. Goroutines with pre-allocated result slice (no mutex needed). 32s → 5s inbox load in Gastown. | Gastown §3.5 |
| 10 | **Structured agent IDs** | Validates task/bead IDs with parsing. Format: `<prefix>-<role>` or `<prefix>-<rig>-<role>-<name>`. Prevents silent failures from malformed IDs. | Gastown §2.1 |
| 11 | **--fast mode for status commands** | 60% faster status checks. Skip non-essential operations. 5s → 2s. | Gastown §3.1 |
| 12 | **Template rendering for prompts** | Consistent output formatting. Type-safe data injection. Reduces hallucination. Single source of truth for agent prompts. | Gastown §4.3 |
| 13 | **Health checks (doctor command)** | Catches misconfigurations. Check for orphaned worktrees, prefix mismatches, stale agent beads, slow operations. Auto-fix common issues. | Gastown §2.2 |
| 14 | **Completion evidence requirements** | Tasks can only close with proof. Commit hash, files changed, test results, coverage delta. `TaskCompleted` hook verifies before accepting. | Native hooks |
| 15 | **File ownership declared in task definition** | Conflicts computed at dispatch time. Each task declares owned files in description. Orchestrator writes `.claude/file-locks.json` before spawning agents. Subagent prompt includes: "check file-locks.json before editing." **Absorbs #2** (file-locks.json generation IS the formalized two-phase). Prompt-based enforcement is the proven primary mechanism — validated by [Anthropic's C compiler project](https://www.anthropic.com/engineering/building-c-compiler) at production scale. **Promoted to P2.** | Hook-based + Anthropic engineering |
| 16 | **Artifact-specific rule-of-five variants** | Better quality for non-code. Code: Draft→Correctness→Clarity→Edge Cases→Excellence. Plans: Draft→Feasibility→Completeness→Risk→Optimality. Tests: Draft→Coverage→Independence→Speed→Maintainability. | Original research |

### LOWER IMPACT — Nice to have, future consideration

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 17 | **DAG visualization** | Understand dependencies before starting. Tree view with status icons, tier view for parallel opportunities, critical path analysis. | Gastown §1.3 |
| 18 | **Complexity scoring for tasks** | Better model routing. 0-1 scale with estimated duration and confidence. Enables SLA tracking. | claude-flow |
| 19 | **Adversarial review for security code** | Try to break it. Test injection, auth bypass, privilege escalation, data leakage, DoS. Document attempted attacks and results. | loom |
| 20 | **External verification (GPT 5.2-codex)** | Second opinion on critical code. Export to external tool, triage findings as true positive / false positive / enhancement. | Original research |
| 21 | **Agent-agnostic zombie detection** | Support multiple AI backends. Read GT_AGENT env var, look up process names for Claude/Gemini/Codex/Cursor/etc. | Gastown §1.5 |
| 22 | **Memorable agent identities** | Better audit trail. Adjective+noun names (GreenCastle, BlueLake). 4,278 unique combinations. Git commits show author. | Research |
| 23 | **Git-backed context audit trail** | Every context change tracked. `.context/` directory with JSON files, git commits on each update, SQLite index for queries. | Research |
| 24 | **Pre-planning file conflict analysis** | Compute waves during planning, not runtime. List all files, identify conflicts, pre-compute optimal groupings, surface in plan header. | Gastown, original research |

### From SWE-Agent Research

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 25 | **Linter guards on all edits** | Prevents syntax errors from persisting. Run linter after edit (PostToolUse hook), surface error to Claude, prompt retry. Stops compounding errors. SWE-agent ablation: 3 percentage point improvement (15.0% → 18.0%). **✅ #42 VERIFIED (2026-02-07):** Frontmatter hooks fire for subagent tool calls. Promotes to P2.2. | SWE-agent ACI |
| 26 | **Succinct search results (max 50)** | Prevents context overflow in subagents. If >50 matches, ask to refine query. Summarize rather than dump. | SWE-agent ACI |
| 27 | **Integrated edit feedback** | Show file diff immediately after edit. Agent sees effect of action, catches mistakes faster. | SWE-agent ACI |
| 28 | **100-line file chunks** | When reading files for context, chunk to 100 lines (empirically optimal). **Mostly redundant:** Claude Code's Read tool now supports `offset`/`limit` parameters natively, defaulting to 2000 lines. At most, add a prompt instruction to SDD subagent templates to prefer 100-line chunks. **Demoted to P8.** | SWE-agent ACI |
| 29 | ~~**Specialized file viewer**~~ | **REMOVED.** Fully redundant with Claude Code's native tools: Read (offset/limit for scrolling, cat -n line numbers) + Grep (-A/-B/-C context, output_mode content with line numbers). Building a custom file viewer would duplicate native tooling with no measurable benefit. | SWE-agent |

### From Gastown Deep Dive

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 30 | **Atomic spawn (NewSessionWithCommand)** | Eliminates race conditions in subagent spawning. Command runs as pane's initial process, not sent after shell ready. Faster startup. | Gastown §15 |
| 31 | **Validation tests for hook/skill configurations** | Prevents silent failures from misconfigured skills. Test that SessionStart hooks include `--hook` flag, registry covers all roles. | Gastown §11 |
| 32 | **Batch lookups with SessionSet pattern** | O(1) repeated queries instead of N+1 subprocess calls. Single `ListSessions` → map lookup for each check. | Gastown §3.4 |

### Opus 4.6 & Native Agent Teams (Released Feb 5, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 33 | **[FUTURE] Leverage 1M context for full-codebase awareness** | ⚠️ **BETA ONLY** — not available to general users yet. When available: load entire codebase into context. Monitor for GA release. | Opus 4.6 beta |
| 34 | **Use 128K output for comprehensive deliverables** | Full implementation plans, complete code reviews, exhaustive test suites in single response. **Available now.** | Opus 4.6 release |
| 35 | **Integrate native agent teams for parallel coordination** | Replace custom parallel dispatch with native TeammateTool (13 operations) for peer-to-peer messaging. Delegate mode maps to SDD orchestrator pattern. Enables hard file ownership via `CLAUDE_CODE_AGENT_NAME`. **⚠️ DEFERRED:** ~7x token cost (official docs) makes this impractical for Max subscribers. Revisit when costs decrease or for API-only users. Enable via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. | Opus 4.6 agent teams |
| 36 | **Map task type to effort level** | VERIFICATION → low effort (cheaper). IMPLEMENTATION → high effort (better quality). Use adaptive thinking API parameters (`output_config.effort`). **Note:** Claude Code's Task tool does not currently expose the effort parameter. Task type routing (prompt templates, model selection) is already implemented in SDD skill. This improvement adds effort-level control when Claude Code exposes it. | Opus 4.6 adaptive thinking |
| 37 | **Exploit ARC AGI 2 leap for novel problem-solving** | Route complex/novel problems to Opus 4.6 (68.8% ARC vs 37.6% before). Use Sonnet for routine tasks. **Available now.** | Opus 4.6 benchmarks |

### Claude Code 2.1.33+ Features (Feb 6, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 38 | **Use `memory` frontmatter for persistent agent context** | Agents have persistent memory surviving across conversations. Scopes: `user`, `project`, `local`. Builds knowledge over time. | Claude Code v2.1.33 |
| 39 | **Hook into TeammateIdle and TaskCompleted events** | **SPLIT:** `TaskCompleted` is GA, works for subagents, and is the only hard enforcement mechanism — **promoted to P1.2**. `TeammateIdle` only relevant with agent teams (deferred due to ~7x cost) — **moved to P8**. | Claude Code v2.1.33 |
| 40 | ~~**Restrict sub-agent spawning via `Task(agent_type)` syntax**~~ | **MOVED to P8.** Per [official docs](https://code.claude.com/docs/en/sub-agents): "This restriction only applies to agents running as the main thread with `claude --agent`. Subagents cannot spawn other subagents, so `Task(agent_type)` has no effect in subagent definitions." No-op for superpowers-bd's current Task-tool-based architecture. Only relevant if architecture migrates to `--agent` mode. | Claude Code v2.1.33 |
| 41 | **Use native Task metrics for cost tracking** | Task results include token count, tool uses, duration. Native, accurate, no parsing required. | Claude Code v2.1.30 |
| 42 | **Define hooks in agent/skill frontmatter** | Hooks scoped to specific agents. Per-agent validation, cleanup on finish. **Critical finding:** the only viable path to per-agent PreToolUse/PostToolUse enforcement, bypassing [Issue #21460](https://github.com/anthropics/claude-code/issues/21460) (global hooks don't fire for subagents). **VERIFIED (2026-02-07, Claude Code 2.1.37):** Frontmatter PostToolUse hooks DO fire for subagent tool calls via `--agents`. 3/3 experiment runs confirmed with transcript proof. Foundation for #25 (linter guards) and eventually #3 (file ownership). **Promoted to P1.3.** | Claude Code v2.1.33 |
| 43 | **Use --from-pr flag for PR-linked sessions** | Sessions auto-link to PRs. Resume with `--from-pr`. Better PR workflow integration. | Claude Code v2.1.27 |
| 44 | **Leverage skill character budget scaling** | Skill content budget scales at 2% of context window. More room for comprehensive skill instructions with Opus 4.6. | Claude Code v2.1.32 |

### Stable Skill Modernization (Feb 7, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 45 | **Modernize agent frontmatter + fix writing-skills guide** | **⚠️ SCOPE CORRECTED:** `memory`, `maxTurns`, and `tools` (with `Task()` syntax) are **agent-only** fields per [official docs](https://code.claude.com/docs/en/sub-agents) — they do NOT apply to skills. Actual scope: (1) Add `memory: project` + `maxTurns` to 2 agent definitions (`code-reviewer.md`, `epic-verifier.md`), (2) Fix `plan2beads.md` missing frontmatter, (3) Update `writing-skills` guide (says "only name and description" — skills actually support 10 fields), (4) Consider `allowed-tools` on select skills for read-only enforcement. ~1.5 hours, zero risk. | Codebase audit + [official docs](https://code.claude.com/docs/en/skills) |

### New: Multi-Review Aggregation (Feb 7, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 46 | **Multi-review aggregation (N independent reviews)** | Run N independent reviews of the same code and aggregate findings. [SWR-Bench (arXiv 2509.01494)](https://arxiv.org/html/2509.01494v1) shows Self-Agg (n=10) achieves **43.67% F1 improvement** and **118.83% recall improvement** over single reviews. Distinct from #8 (which is throughput parallelism for different tasks). Self-Agg (same model N times) performs comparably to Multi-Agg (different models), so running Claude N times may be as effective as Claude + GPT. | [arXiv 2509.01494](https://arxiv.org/html/2509.01494v1) (SWR-Bench) |

**Removed from active list:**
- ~~#1~~ — **V2 DENIED (2026-02-08, p=0.000183).** Two-Phase Reflective produces 15x more false positives (0.75 vs 0.05) with identical recall (6/6). Current code-reviewer is already near-optimal. 20 paired cycles, Wilcoxon signed-rank, Bootstrap CI [-0.9, -0.5].
- ~~#2~~ — Merged into #15 (SDD already implements two-phase; remaining value = file-locks.json = #15)
- ~~#29~~ — Redundant with native Claude Code Read + Grep tools
- ~~#45 (was) SessionStart feature detection + config file~~ — Not needed without agent teams opt-in
- ~~#46 (was) Two-mode SDD: Task vs Agent Teams~~ — Agent teams impractical for Max subscribers

---

## 2. PRIORITIZED Implementation Order

**Strategy:** Work with what works today. Config/hooks first, then quality gate prompts, then file ownership via proven prompt-based patterns. Don't wait for upstream fixes with no timeline.

### Priority 1: Config & Hooks (This Week — Zero Code)

GA features in Claude Code 2.1.33+. Just configure them.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **1.1** | 38 | `memory: project` on agent definitions | Frontmatter line |
| **1.2** | 5 | TaskCompleted hook for quality gates | Hook config — **only hard enforcement for subagents. FIRES in interactive mode (manually verified). Does NOT fire in headless `claude -p`.** |
| **1.3** | 42 | Hooks in agent/skill frontmatter | Frontmatter — **✅ VERIFIED:** Frontmatter hooks fire for subagent tool calls |
| **1.4** | 41 | Native Task metrics | Already available — just use them |

**Rationale:** Zero code required. TaskCompleted (#5) is the highest-value hook — GA, genuinely blocks task completion, and critically is the **only** enforcement that works for subagents (PreToolUse/PostToolUse don't fire for subagent tool calls per [Issue #21460](https://github.com/anthropics/claude-code/issues/21460)). Frontmatter hooks (#42) verified (2026-02-07) — confirmed as the path to per-agent hook enforcement, unlocking #25 (linter guards) and eventually #3 (file ownership).

**Items removed from P1 (v4.3 → v5.0):**
- ~~#3 (P1.1 in v4.3)~~ → **P5 (deferred).** Blocked on TWO upstream issues (#16126 + #21460). Prompt-based (#15) is the proven primary mechanism.
- ~~#40 (P1.4 in v4.3)~~ → **P8.** `Task(agent_type)` is a no-op for subagent architecture.
- ~~#39 TeammateIdle~~ → **P8.** Only relevant with agent teams (deferred). TaskCompleted portion promoted to P1.2.

### Priority 1.5: Stable Skill Modernization (This Week — Zero Cost Increase)

Modernize agents with stable Claude Code 2.1.33+ features. Zero token cost increase.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **1.5.1** | 45 | Modernize agent frontmatter + fix writing-skills guide | 1.5 hours (2 agents + 1 command + writing-skills guide) |

**Rationale:** Two agent definitions lack memory/maxTurns, one command lacks frontmatter, and the writing-skills guide is factually wrong about available fields.

**Modernization checklist (scope corrected — agent-only fields):**
- [ ] Add `memory: project` to `agents/code-reviewer.md` and `agents/epic-verifier.md`
- [ ] Add `maxTurns` to both agents (test to find right values — no documented recommendations)
- [ ] Add YAML frontmatter to `commands/plan2beads.md` (only command missing it)
- [ ] Update `skills/writing-skills/SKILL.md`: expand from "only name and description" to full 10-field reference (name, description, argument-hint, disable-model-invocation, user-invocable, allowed-tools, model, context, agent, hooks)
- [ ] Consider `allowed-tools` on select skills for read-only enforcement (e.g., brainstorming, epic-verifier, verification-before-completion)
- [ ] Replace hardcoded `model: "opus"` / `model: "sonnet"` with parameterized model in SDD prompts

**⚠️ Scope correction from v4.3:** `memory`, `maxTurns`, `tools` (with `Task()` syntax) are **agent-only** frontmatter fields per [official docs](https://code.claude.com/docs/en/sub-agents). They do NOT apply to skills. Skills use `allowed-tools` (different field, no `Task()` syntax). The v4.3 claim of "17 skills + 2 agents" was incorrect — the agent-specific work is 2 files, not 19.

### Priority 2: Quality Gates & File Ownership (High ROI — Prompt/Skill Changes)

Prompt engineering, skill updates, and proven prompt-based file coordination. No infrastructure code needed.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| ~~**2.1**~~ | ~~1~~ | ~~Structured verification (Two-Phase Reflective hybrid)~~ | **REMOVED — V2 DENIED (p=0.000183).** Two-Phase is statistically worse: 15x more FP (0.75 vs 0.05), same recall (6/6). Current code-reviewer is already optimal. |
| **2.2** | 25 | Linter guards via PostToolUse hooks | Hook config — **✅ P1.3 verified** — frontmatter hooks work for subagents |
| **2.3** | 14 | Completion evidence requirements | Hook + prompt — companion to #5 |
| **2.4** | 15 | File ownership declared in task definition (absorbs #2) | Skill update — proven pattern |
| **2.5** | 6 | Strengthen simplification checks in existing skills | Prompt additions (linter hook part conditional on P1.3) |
| **2.6** | 16 | Artifact-specific rule-of-five | Skill variants |
| **2.7** | 24 | Pre-planning file conflict analysis | New analysis step in planning skills |

**Rationale:** Quality gates are superpowers-bd's unique value. ~~#1 (structured verification) is the single most impactful change~~ **#1 REMOVED — V2 experiment (2026-02-08) DENIED Two-Phase Reflective with p=0.000183.** Current code-reviewer already achieves 6/6 recall with near-zero FP (0.05). Two-Phase produces 15x more false positives (0.75). Bootstrap CI [-0.9, -0.5] firmly excludes zero. **The current review prompt is already near-optimal; improvement efforts should focus on multi-review aggregation (#46) instead.** #15 (file ownership via prompt-based coordination) is now the **primary** mechanism, not an "interim" — validated by Anthropic's own C compiler project at production scale.

**File ownership — updated status (v5.0):**
- **Prompt-based is the PRIMARY mechanism**, not an interim. Anthropic's [C compiler project](https://www.anthropic.com/engineering/building-c-compiler) used advisory file locks (text files as claims) with cooperative agents at production scale.
- **Orchestrator writes `file-locks.json` before dispatch.** Each subagent prompt includes: "Before editing any file, check `.claude/file-locks.json`. Only edit files where your task ID matches the owner."
- **Cursor's experience validates this approach:** Traditional file locking bottlenecked 20-agent runs to 2-3 effective agents. Advisory coordination scales better.
- **Hook-based enforcement is defense-in-depth (P5)**, contingent on TWO upstream fixes (#16126 + #21460).

### Priority 3: Multi-Review & Scaling (Quality at Scale)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **3.1** | 46 | Multi-review aggregation (N independent reviews) | Skill/prompt |
| **3.2** | 7 | Checkpoint classification (binary flag) | Plan format update |

**Rationale:** Multi-review aggregation (#46) delivers a 43.67% F1 improvement (SWR-Bench). Now the **primary quality improvement path** since #1 (Two-Phase Reflective) was DENIED by V2 experiments. The current single-review prompt already achieves 6/6 recall — aggregating N independent reviews will reduce the rare FP to near zero while maintaining detection. Checkpoint classification (#7) is low-effort and formalizes existing batch boundary behavior.

### Priority 4: Context & State (Beads Integration)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **4.1** | 4 | Strict SSOT (codify as design principle) | Documentation |
| **4.2** | 10 | Structured agent IDs | Code |

**Rationale:** SDD skill already follows SSOT pattern. #4 codifies it as a skill-writing rule to prevent regressions. Native memory handles context; beads handles task state.

### Priority 5: Deferred Enforcement & Performance

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **5.1** | 3 | File ownership via PreToolUse hooks | ⚠️ Blocked on [#16126](https://github.com/anthropics/claude-code/issues/16126) + [#21460](https://github.com/anthropics/claude-code/issues/21460). Defense-in-depth when upstream fixes. |
| **5.2** | 9 | Parallel bd queries | Go code |
| **5.3** | 32 | Batch lookups (SessionSet pattern) | Code |
| **5.4** | 11 | --fast mode for status | Code |
| **5.5** | 8 | Parallelize review pipelines (throughput) | Skill update |

**Rationale:** #3 moves here from P1 — blocked on 6 open upstream issues spanning 6+ months with zero Anthropic engagement. Performance items (#9, #32, #11, #8) activate after core system works.

### Priority 6: Tooling & Polish (Refinement)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **6.1** | 13 | Health checks (doctor) | Code |
| **6.2** | 12 | Template prompts | Code |
| **6.3** | 31 | Validation tests for configs | Tests |
| **6.4** | 43 | Use --from-pr flag | Config |
| **6.5** | 34 | Use 128K output | Prompt update |
| **6.6** | 44 | Leverage skill budget scaling | Config |
| **6.7** | 36 | Map task type to effort level | Blocked: Task tool lacks effort param |

### Priority 7: SWE-Agent Patterns (Agent Quality)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **7.1** | 26 | Succinct search results (max 50) | Prompt instruction |
| **7.2** | 27 | Integrated edit feedback | Prompt instruction (mostly native in IDE mode) |

**Rationale:** Reduced from 4 items to 2. #28 (100-line chunks) demoted to P8 (native Read offset/limit). #29 (file viewer) removed (redundant). Remaining items are minor prompt instructions, not feature builds.

### Priority 8: Advanced & Future (Do Last)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **8.1** | 17 | DAG visualization | Code |
| **8.2** | 19 | Adversarial security review | New skill |
| **8.3** | 20 | External verification (GPT 5.2-codex) | Integration — Self-Agg may be as effective (SWR-Bench) |
| **8.4** | 22 | Memorable agent identities | Code |
| **8.5** | 23 | Git-backed context audit trail | Code |
| **8.6** | 30 | Atomic spawn | Code |
| **8.7** | 21 | Agent-agnostic zombie detection | Code |
| **8.8** | 18 | Complexity scoring | Code |
| **8.9** | 37 | Exploit ARC AGI 2 leap | Prompt/routing |
| **8.10** | 33 | [FUTURE] 1M context | When beta exits |
| **8.11** | 35 | Integrate native agent teams | ~7x token cost impractical for Max subscribers |
| **8.12** | 40 | Restrict sub-agent spawning | No-op for current subagent architecture |
| **8.13** | 39 | TeammateIdle hooks | Only relevant with agent teams |
| **8.14** | 28 | 100-line file chunks | Mostly redundant with native Read offset/limit |

**Rationale:** These provide value but aren't critical. #40, #39 (TeammateIdle), and #28 newly added from higher tiers after research found them irrelevant or redundant for current architecture.

---

## 3. Reference: New Capabilities

### 3.1 Opus 4.6 (Released February 5, 2026)

| Capability | Opus 4.5 | Opus 4.6 | Availability |
|------------|----------|----------|--------------|
| **Context window** | 200K tokens | **1M tokens** | ⚠️ Beta only |
| **Output tokens** | 64K | **128K** | ✅ GA |
| **Terminal Bench** | 59.8% | **65.4%** | ✅ GA |
| **OSWorld (agentic)** | 66.3% | **72.7%** | ✅ GA |
| **ARC AGI 2** | 37.6% | **68.8%** | ✅ GA |

**Adaptive Thinking:** Model picks up contextual clues about how much to think. Less cost for simple tasks, automatic deep thinking for complex ones. Effort controls (`output_config.effort`: low/medium/high/max) let developers tune the intelligence/speed/cost tradeoff. **Note:** Claude Code's Task tool does not yet expose the effort parameter.

**Agent Teams (Experimental, officially supported — DEFERRED for superpowers-bd):** Multiple agents work in parallel with peer-to-peer coordination via TeammateTool (13 operations). Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (env var or `settings.json`). **~7x token cost** vs standard sessions (official docs) — impractical for Max 20x subscribers, could consume daily/weekly quota in a single session. Teammate env vars: `CLAUDE_CODE_AGENT_NAME`, `CLAUDE_CODE_AGENT_ID`, `CLAUDE_CODE_AGENT_TYPE`, `CLAUDE_CODE_TEAM_NAME`, `CLAUDE_CODE_AGENT_COLOR`. **Revisit when:** costs decrease, GA removes experimental flag, or for API-only users with high limits.

**superpowers-bd's unique value vs native agent teams (reference — agent teams deferred):**

| Capability | Native Agent Teams (~7x cost) | superpowers-bd (current) |
|------------|-------------------------------|--------------------------|
| Parallel execution | ✅ Built-in | ✅ Task tool + waves |
| Peer-to-peer messaging | ✅ TeammateTool | ❌ Hub-and-spoke |
| Session resumption | ❌ | ✅ Beads persistence |
| Quality gates | ❌ | ✅ Skills-based |
| File ownership | `AGENT_NAME` available | ⚠️ Prompt-based (blocked #16126) |
| Git-backed state | ❌ | ✅ Beads on Dolt |
| Token cost | ~7x baseline | ~1x baseline |

### 3.2 Claude Code 2.1.33+ Features (Feb 6, 2026)

| Feature | Version | What It Does |
|---------|---------|-------------|
| **`memory` frontmatter** | v2.1.33 | Persistent agent memory (`user`, `project`, `local` scopes) |
| **TeammateIdle/TaskCompleted hooks** | v2.1.33 | Event-driven multi-agent coordination |
| **Task metrics** | v2.1.30 | Token count, tool uses, duration in Task results |
| **Sub-agent restrictions** | v2.1.33 | `Task(agent_type)` in tools frontmatter |
| **Hooks in frontmatter** | v2.1.33 | Per-agent hooks (PostToolUse, PreToolUse) |
| **--from-pr flag** | v2.1.27 | PR-linked sessions |
| **Skill budget scaling** | v2.1.32 | 2% of context window for skill content |

**Agent-type hooks:** Hooks with `type: "agent"` get 50 turns with Read/Grep/Glob tools. This is a game-changer for quality gates — verification hooks can actually read and analyze code, not just run shell commands.

**Hook environment variables available:**
- `$CLAUDE_PROJECT_DIR` — project root directory
- `$CLAUDE_PLUGIN_ROOT` — plugin's root directory (for plugin hooks)
- `$CLAUDE_CODE_REMOTE` — set to "true" in remote environments
- `$CLAUDE_ENV_FILE` — path for persisting env vars (SessionStart only)
- `$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — "1" when agent teams enabled
- `$CLAUDE_CODE_TEAM_NAME` — agent team name (for team members only)
- `$CLAUDE_CODE_AGENT_NAME` — teammate name (for team members only — **KEY for file ownership**)
- `$CLAUDE_CODE_AGENT_ID` — unique agent ID (e.g., `worker-1@my-project`)
- `$CLAUDE_CODE_AGENT_TYPE` — agent type (e.g., `Explore`, `Plan`)
- ⚠️ `$AGENT_NAME` — **does NOT exist** for regular subagents ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126))

**Example patterns:**

```yaml
# memory frontmatter
---
name: code-reviewer
memory: project
description: Reviews code with accumulated project knowledge
---

# Sub-agent restrictions
---
name: lead-agent
tools:
  - Task(code-reviewer)
  - Task(implementation-agent)
---

# Per-agent hooks
---
name: code-editor
hooks:
  PostToolUse:
    - matcher: "Edit"
      command: "eslint --fix $FILE_PATH"
---
```

### 3.3 Beads v0.49.4 Concurrency Architecture (Verified Feb 7, 2026)

Beads v0.49.4 uses **embedded Dolt** (in-process via `dolthub/driver`), NOT `dolt sql-server`. Each `bd` invocation is a separate process with file-level coordination. Six layers of concurrency protection:

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| `dolt-access.lock` | Application-level file lock | Serializes Dolt access across processes |
| `.jsonl.lock` | Shared/exclusive lock | Prevents JSONL import/export races |
| Process-level semaphore | Limits concurrent Dolt access | Prevents resource exhaustion |
| Advisory flock | OS-level advisory lock | Prevents zombie bd processes |
| Lock retry + stale cleanup | Automatic retry with cleanup | Recovers from stale locks |
| Connection pool deadlock fix | Timeout on embedded Dolt close | Prevents pool deadlocks |

**Empirical results:** 40 concurrent `bd create` operations all succeeded. Zero deadlocks, zero data loss, zero errors. Performance scales linearly (3 ops = 0.66s, 10 ops = 2.08s, 40 ops = 7.67s).

**Dolt durability guarantee:** Chunk journal with `fsync()` — if a write returns success, data is on physical storage. Silent write failures are eliminated by design.

**Note:** If superpowers-bd ever migrates to `dolt sql-server` mode for true multi-agent worktree sharing (see Q2), retry-with-verification would become relevant. But for current embedded mode, it is not needed.

### 3.4 Claude Code Hooks API (Verified Feb 7, 2026 — Updated v5.0)

Key findings from research on the hooks system. **14 hook events** officially documented as of v2.1.33.

**⚠️ CRITICAL: Subagent Hook Enforcement Gap ([Issue #21460](https://github.com/anthropics/claude-code/issues/21460))**

PreToolUse and PostToolUse hooks configured in global settings **do NOT fire for subagent tool calls**. This is the most impactful finding from v5.0 research. Six related issues span Aug 2025–Jan 2026 with zero resolution:
- [#21460](https://github.com/anthropics/claude-code/issues/21460) — PreToolUse hooks not enforced on subagent tool calls (**OPEN**, security bug)
- [#16126](https://github.com/anthropics/claude-code/issues/16126) — Add agent identity to PreToolUse hook data (**OPEN**, no Anthropic engagement)
- [#6305](https://github.com/anthropics/claude-code/issues/6305) — Post/PreToolUse hooks not executing (Aug 2025)
- [#18950](https://github.com/anthropics/claude-code/issues/18950) — Subagents don't inherit user-level permissions
- [#20946](https://github.com/anthropics/claude-code/issues/20946) — PreToolUse hooks don't block in bypass mode
- [#14859](https://github.com/anthropics/claude-code/issues/14859) — Agent hierarchy in hook events

**Implications:** File ownership via PreToolUse (#3), linter guards via PostToolUse (#25), and simplification hooks (#6) all require subagent tool call hooks to be useful in SDD workflows. Global settings hooks remain broken for subagents, but **frontmatter-defined hooks (#42) provide a verified workaround** (confirmed 2026-02-07, 3/3 runs). Linter guards (#25) can proceed via frontmatter PostToolUse hooks. File ownership (#3) has a viable path via frontmatter PreToolUse hooks, though still blocked on agent identity (#16126).

**Hooks that DO work for subagents:**
- `TaskCompleted` — exit code 2 blocks task completion (GA, hard enforcement)
- `SubagentStop` — can block subagent from finishing
- `TeammateIdle` — for agent teams only

**PreToolUse hooks (main agent only):**
- Matcher is regex: `Edit|Write` correctly matches both tools
- Input via stdin as JSON: `tool_input.file_path` is correct for both Edit and Write
- `exit 2` blocks the tool call (older pattern)
- Preferred: return JSON with `permissionDecision: "deny"` and `permissionDecisionReason`
- Can also **modify tool input** via `updatedInput` (transparent sandboxing)
- ⚠️ No agent identity in hook input ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126))
- ⚠️ Subagents share `session_id` with parent ([Issue #7881](https://github.com/anthropics/claude-code/issues/7881))

**TaskCompleted hooks (works for all agents):**
- `exit 2` blocks task completion (hard enforcement)
- Receives: `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- Can use `type: "agent"` for 50-turn code analysis before allowing completion
- Can use `type: "prompt"` for lightweight single-turn LLM evaluation (Haiku default)
- Latency risk: agent-type hooks could take 60+ seconds per task
- **Latency benchmarking (2026-02-07, tested, inconclusive):** 20 sessions (5x4 types: none, command, prompt, agent) all succeeded but command hook markers never created in headless `claude -p` mode with TaskCreate/TaskUpdate workflow. Cannot determine per-type overhead — hooks may not fire for native task tool completions in headless mode. Retest needed with interactive sessions or alternative trigger method. **V2 experiments scripted (2026-02-08, PENDING):** Experiment A (trigger matrix) resolves the trigger question by testing 4 cells: {native TaskCreate+TaskUpdate, bd create+close} x {headless, interactive}, with dual-probe verification. Experiment B (latency) is gated on A — only runs for confirmed FIRES paths, with 12 measured runs per variant. Scripts: `tests/verification/test-taskcompleted-trigger-matrix-v2.sh`, `tests/verification/test-taskcompleted-latency-v2.sh`.

**Frontmatter hooks (VERIFIED):**
- Docs say hooks in skill/agent frontmatter are "scoped to the component's lifecycle and only run when that component is active"
- All hook events are supported; `Stop` hooks auto-convert to `SubagentStop` for subagents
- `once` field (boolean, skills only) makes a hook run only once per session
- **VERIFIED (2026-02-07, Claude Code 2.1.37):** Frontmatter PostToolUse hooks DO fire for subagent tool calls when defined via `--agents` flag. Experiment: 3/3 runs confirmed (positive control 3/3, all first-pass, transcript proof of Task tool invocation). This unlocks #25 (linter guards via frontmatter PostToolUse) and provides a path for #3 (file ownership via frontmatter PreToolUse).

**addBlockedBy (Task tool):**
- Soft/prompt-based enforcement only — agents *choose* to respect it
- No API-level rejection if agent marks blocked task as in_progress
- Beads dependencies (`bd ready`/`bd blocked`) provide stronger enforcement (controls query results)

---

## 4. Open Questions — Answered

### Q1: What's the fallback if Dolt crashes mid-operation?

**Answer: Dolt's embedded mode has robust crash recovery. Beads v0.49.4 adds 6 layers of protection.**

Based on [DoltHub's crash recovery testing (Jan 2026)](https://www.dolthub.com/blog/2026-01-26-dolt-crash-recovery-testing/):

- Chunk journal with fsync ensures acknowledged writes survive crashes
- DoltHub tests use VMs that can be "hard reset" mid-operation — assertions verify durability
- Beads v0.49.4 adds process-level semaphore, advisory flock, lock retry, JSONL locking, and connection pool deadlock fix on top of Dolt's own protections

**Current status:** No additional application-level retry needed for embedded mode. Beads already handles all known failure modes. Monitor for issues if workload increases significantly.

---

### Q2: How do worktrees share a single Dolt instance?

**Answer: Use `dolt sql-server` mode with multiple client connections**

Note: This would require switching from embedded mode to server mode (`dolt_mode: "server"` in metadata.json or `BEADS_DOLT_SERVER_MODE=1`). This is a future consideration — current single-process embedded mode works for one Claude Code session.

- Start `dolt sql-server` on the main repo (not in worktrees)
- Each worktree connects as a MySQL client
- Writes to same branch are serialized; different branches can write in parallel
- Configure `max_connections: 100` for concurrent sessions

```bash
# In main repo
dolt sql-server --port 3306 --max-connections 100

# In each worktree
export BEADS_DOLT_HOST=localhost
export BEADS_DOLT_PORT=3306
bd ready  # Uses shared server
```

**If switching to server mode:** Retry-with-verification would become relevant (Gastown's pattern was designed for this). Add application-level retry at that time.

---

### Q3: Can pre-commit guards work with existing hooks?

**Answer: ⚠️ REVISED — pre-commit.com is NOT compatible with beads.**

Previous recommendation to use pre-commit.com was incorrect. Research found:

1. **pre-commit.com destroys existing hooks:** `pre-commit install` moves existing hook scripts to `.legacy` files ([Issue #3450](https://github.com/pre-commit/pre-commit/issues/3450), confirmed behavior for 10+ years). This would break beads' git hook shims (pre-commit, prepare-commit-msg, post-checkout, post-merge, pre-push).

2. **Beads has its own hook chaining:** `bd hook --help` documents `chain_strategy` (before/after/replace) with configurable timeout. Use this instead.

3. **Agent identity gap in git hooks:** Git pre-commit hooks receive no information about which Claude Code agent initiated the commit. `$AGENT_NAME` is not available. Git `user.name` is shared across all agents. This makes agent-specific commit guards impossible.

**Updated recommendation:** If commit-time guards are needed, use beads' `chain_strategy: before` to add custom checks. However, this is largely redundant with PreToolUse enforcement (#3) — if agents can't edit unauthorized files, they can't commit them either.

---

### Q4: What's the right TTL for file reservations?

**Answer: 30 minutes default, with task-complexity adjustment**

- **Short (5-15 min):** Quick tasks, verification, simple changes
- **Medium (30 min):** Default — covers most implementation tasks
- **Long (1-2 hours):** Complex refactoring, multi-file changes

```
Default TTL: 30 minutes
Renewal interval: Every 10 minutes
Max extensions: 3 (total 2 hours max)
On expiry without renewal: Auto-release + escalate
```

---

### Q5: Should heartbeat failures auto-kill agents?

**Answer: NO auto-kill — NUDGE → WAKE → ESCALATE with human decision on kill**

```
10 min no heartbeat → NUDGE (send reminder)
20 min no heartbeat → WAKE (attempt to resume)
30 min no heartbeat → ESCALATE (alert human)
Human decision → KILL (only with approval)
```

Exception: If reservation TTL expires AND no heartbeat, auto-release the reservation (but don't kill the process).

---

### Q6: How aggressive should simplification review be?

**Answer: Moderate — Target cyclomatic complexity <10, flag but don't block on style**

**Metrics to enforce (via PostToolUse linter hooks, not LLM review):**
- Cyclomatic complexity: Flag >10, block >15 (matches McCabe/NIST standard)
- Function length: Flag >50 lines, block >100
- Duplication: Flag >10 lines duplicated, block >25

**What NOT to block on:** Style preferences (linter handles), naming conventions, comment density.

**Tools:** ESLint `complexity` rule, Lizard (multi-language), SonarQube (server-based).

---

### Q7: What external tool for adversarial review?

**Answer: Multiple tools based on code type**

| Code Type | Tool | Why |
|-----------|------|-----|
| General security | Claude Code Security Review (GitHub Action) | Anthropic's official tool |
| Deep audit | GPT 5.2-codex | Already in use; catching missed issues |
| Penetration testing | NeuroSploitv2 | AI-powered pentesting |
| Static analysis | Checkmarx, Semgrep | Traditional SAST tools |

**Note:** [Checkmarx research](https://checkmarx.com/zero-post/bypassing-claude-code-how-easy-is-it-to-trick-an-ai-security-reviewer/) shows AI security reviewers can be tricked — use multiple tools, not just one.

---

### Q8: How to handle Claude Desktop vs Claude Code differences?

**Answer: Use Claude Code for superpowers-bd; it has native MCP support**

| Aspect | Claude Desktop | Claude Code |
|--------|---------------|-------------|
| MCP Config | `claude_desktop_config.json`, stdio | `claude mcp add` CLI, HTTP preferred |
| Subagents | Not supported | Native Task tool |
| Performance | MCP adds overhead | MCP baked in, faster |

**Recommendation:** Use Claude Code exclusively for superpowers-bd workflows.

---

## 5. Additional Research Opportunities

### Repositories Not Yet Analyzed

| Repository | Why It Might Be Valuable | Priority |
|------------|-------------------------|----------|
| **[aider](https://github.com/paul-gauthier/aider)** | 50K+ stars. Diff handling, "architect mode" for planning, repo map for context. | **High** |
| **[mentat](https://github.com/AbanteAI/mentat)** | Context management for coding. Patterns for what context to include/exclude. | Medium |
| **[sweep](https://github.com/sweepai/sweep)** | GitHub bot for PRs. PR quality and review automation patterns. | Medium |
| **[Devon](https://github.com/entropy-research/Devon)** | Open-source Devin alternative. Multi-step task execution with planning. | Medium |
| **[continue](https://github.com/continuedev/continue)** | IDE extension with multi-file editing. Atomic changes across files. | Low |
| **[gpt-engineer](https://github.com/gpt-engineer-org/gpt-engineer)** | Full project generation. High-level planning patterns. | Low |

### Topics Needing Deeper Research

| Topic | What We Need to Learn | How to Research |
|-------|----------------------|-----------------|
| **Aider's architect mode** | How does it separate planning from execution? | Clone repo, analyze `architect.py` |
| **Dolt server mode in practice** | Connection pooling, crash recovery, multi-client patterns | DoltHub Discord, test with 5+ concurrent clients |
| **Property-based testing for AI output** | How loom does adversarial input generation | Loom source code deep dive |
| **Parallel execution at scale** | What breaks at 10+ subagents? 20+? | Testing with synthetic workloads |
| **AI security review bypasses** | Ways to trick Claude Code security review | [Checkmarx LITL research](https://checkmarx.com/zero-post/bypassing-claude-code-how-easy-is-it-to-trick-an-ai-security-reviewer/) |
| **Over-correction bias in LLM reviewers** | How to calibrate skepticism without false positives | [arXiv 2508.12358](https://arxiv.org/html/2508.12358v1) — Claude shows less susceptibility than GPT-4o |
| **Claude Code agent identity in hooks** | Track [Issue #16126](https://github.com/anthropics/claude-code/issues/16126) for `agent_name` in PreToolUse data | Monitor Claude Code releases |
| **Multi-review aggregation** | Running multiple independent reviews and aggregating (up to 43.67% F1 improvement) | [arXiv 2509.01494 (SWR-Bench)](https://arxiv.org/html/2509.01494v1) |

### Patterns Worth Investigating

| Pattern | Where Seen | What to Investigate |
|---------|-----------|---------------------|
| **Convoy batch tracking** | Gastown | How to track related work across multiple rigs/epics |
| **Race condition prevention** | Gastown §2.4 | Comprehensive list of races to prevent in parallel execution |
| **Worktree management** | Gastown §4.4 | Symlink preservation, orphan cleanup, creation verification |
| **Hook system architecture** | Gastown §11 | Guard (block), Audit (log), Inject (modify) patterns |
| **Repo maps for context** | Aider | How to build and maintain a map of the codebase |
| **LITL attacks on AI reviewers** | Checkmarx | "Lies In The Loop" — how adversaries trick AI security tools |

### Specific Research Actions

| Action | Expected Outcome | Priority |
|--------|------------------|----------|
| Clone aider, analyze architect mode | Patterns for planning/execution separation | **High** |
| Test Dolt sql-server with 5 concurrent bd processes | Confirm worktree sharing, identify edge cases | **High** |
| Review Checkmarx LITL research | Understand AI reviewer vulnerabilities | Medium |
| Analyze SWE-agent's debugging approach | Patterns for issue resolution | Medium |

---

## 6. SWE-Agent Research Findings

### Overview

[SWE-agent](https://github.com/SWE-agent/SWE-agent) is Princeton/Stanford's software engineering agent achieving state-of-the-art results on SWE-bench. Key insight: **tool quality matters as much as model quality**.

**Two versions:**
- **SWE-agent** (full): Sophisticated ACI with specialized tools — [NeurIPS 2024 paper](https://arxiv.org/pdf/2405.15793)
- **[mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent)**: 100 lines of Python, bash-only, 74%+ on SWE-bench verified

### The Agent-Computer Interface (ACI) Concept

Designing the **interface between agent and computer** as carefully as you design prompts.

> "Just like how typical language models require good prompt engineering, good ACI design leads to much better results when using agents."

**Key ACI Design Principles:**

| Principle | Implementation | Impact |
|-----------|---------------|--------|
| **Succinct output** | Search results show max 50 matches, summarized | Prevents context overflow |
| **Integrated feedback** | Edit command shows updated file immediately | Agent sees effect of actions |
| **Guardrails** | Linter blocks syntactically invalid edits | Prevents compounding errors |
| **Specialized tools** | File viewer (100 lines), search commands | ~7x better than generic bash |

### SWE-Agent Tools

| Tool | What It Does | Why It Works |
|------|--------------|--------------|
| **File Viewer** | Shows 100 lines at a time with line numbers, scroll up/down, search | Prevents context overflow, maintains orientation |
| **Integrated Editor** | Edit + automatic display + linter validation | Immediate feedback, no invalid edits persist |
| **find_file** | Search for filenames in repository | Concise results |
| **search_file** | Search string within a file | Targeted output |
| **search_dir** | Search string in directory, list matching files | Summarized (file list, not every match) |
| **Linter Guard** | Runs on every edit, blocks if syntax error | Shows before/after snippet, asks for retry |

**Result:** ~7x improvement in resolution rates vs agents with generic bash access.

### mini-swe-agent: The Counterpoint

Proves that with modern LLMs, **complex tool infrastructure isn't always necessary**:

| Design Choice | Rationale |
|--------------|-----------|
| **Bash only** | No tool-calling interface, no custom tools — just subprocess.run |
| **Stateless actions** | Every command runs independently |
| **Linear history** | Every step appends to messages — trajectory = LLM input |
| **~100 lines of code** | Radically simple, transparent, hackable |

**Performance:** 74%+ on SWE-bench verified with just bash + good prompting.

### Patterns Applicable to superpowers-bd

#### HIGH IMPACT: Adopt

| Pattern | How to Apply | Expected Benefit |
|---------|--------------|------------------|
| **Succinct search results** | Limit bd queries to top 50, summarize | Prevents subagent context overflow |
| **Integrated edit feedback** | After file edit, show diff immediately | Subagent sees effect, catches mistakes |
| **Linter guards on edits** | Run linter before accepting edit, reject + retry | Prevents syntax errors from persisting |
| **100-line file chunks** | Chunk to 100 lines when reading for context | Empirically optimal chunk size |
| **Search result limits** | If >50 matches, ask to refine query | Prevents overwhelming context |

#### MEDIUM IMPACT: Consider

| Pattern | How to Apply | Expected Benefit |
|---------|--------------|------------------|
| **Stateless action execution** | Each subagent command runs independently | Easier sandboxing, debugging |
| **Specialized file viewer** | Build file viewer skill with scroll/search | Better navigation |

#### The mini-swe-agent Insight

For superpowers-bd, this suggests:
1. **Don't over-engineer tools** — Modern Claude works with bash effectively
2. **Focus on prompting** — Self-reflection cues may matter more than tool sophistication
3. **Keep it simple** — 100 lines achieves 74% — complexity isn't always better
4. **Linear history for debugging** — Makes it easy to see what led to decisions

### Key Insight

**The ACI philosophy applies to skill design:**

> Your skills are the Agent-Computer Interface for Claude. How you design them (what tools, what output format, what guardrails) matters as much as the prompts.

**Current gap:** superpowers-bd skills may not have optimal output truncation, integrated feedback, or guardrails to prevent compounding errors.

### Sources

- [SWE-agent GitHub](https://github.com/SWE-agent/SWE-agent)
- [mini-swe-agent GitHub](https://github.com/SWE-agent/mini-swe-agent)
- [SWE-agent Paper (NeurIPS 2024)](https://arxiv.org/pdf/2405.15793)
- [Agent-Computer Interface Documentation](https://swe-agent.com/background/aci/)

---

## 7. Summary: The Path Forward

### What Success Looks Like

1. **No silent failures** — Beads v0.49.4 concurrency protections, structured IDs, health checks
2. **No missed work** — TaskCompleted hook quality gates (P1.2), completion evidence (P2.3)
3. **No conflicts** — File ownership via prompt-based coordination (#15, P2.4) — proven by Anthropic's C compiler project. Hook-based defense-in-depth when upstream fixes (P5).
4. **No state drift** — Strict SSOT principle, persistent memory, structured storage
5. **Maximum parallelism** — Task tool subagents with wave-based dispatch, cost-efficient
6. **Quality at scale** — Structured verification (Two-Phase Reflective hybrid), multi-review aggregation (#46), linter guards (#42 verified — frontmatter hooks work for subagents)
7. **Comprehensive outputs** — 128K output means complete plans in single responses
8. **Modern agents** — 2 agent definitions use current stable frontmatter fields (memory, maxTurns); writing-skills guide corrected

### The Non-Negotiables

1. **Structured verification** — Two-Phase Reflective + behavioral comparison hybrid for all reviewers (research-backed, arXiv 2508.12358)
2. **TaskCompleted hook** — The only hard enforcement mechanism that works for subagents. Promoted to P1.2.
3. **Prompt-based file ownership** — Primary mechanism, not interim. Validated at production scale. Hook-based is defense-in-depth (P5).
4. **Stable features first** — Use proven GA features only. Agent teams deferred (~7x token cost). Experimental features deferred.
5. **Verify before assuming** — Frontmatter hooks (#42) verified — ready to build linter guards (#25) and file ownership (#3) on this foundation. Don't rank improvements based on unverified assumptions.

### The Order Matters

**Config/hooks → Agent modernization → Quality gate prompts → File ownership (prompt-based) → Performance → Polish**

Don't write code when config works. Don't optimize before it works. Don't wait for upstream fixes with no timeline — use proven patterns now. Don't rebuild what beads or Claude Code already provide. Don't use experimental features that could wipe user quotas.

### What Remains Unique to superpowers-bd

Native Claude Code provides coordination. superpowers-bd ensures **quality work that persists**:

- **Beads** for git-backed task persistence (Dolt backend with 6-layer concurrency protection)
- **Structured verification** via Two-Phase Reflective hybrid (research-backed)
- **TaskCompleted hooks** for hard enforcement quality gates (the only mechanism that works for subagents)
- **Prompt-based file ownership** — proven at production scale, not dependent on upstream fixes
- **Multi-review aggregation** — 43.67% F1 improvement via N independent reviews (SWR-Bench)
- **Rule-of-five** quality gate skills
- **Modern agent frontmatter** — memory, maxTurns on agent definitions

**The playbook:** Use Claude Code's stable GA features for coordination (memory, hooks, metrics) + superpowers-bd for discipline (quality gates, persistence, file ownership). Work with what works today — don't block on upstream fixes. Don't rebuild what beads or Claude Code already provide.

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-01 | Initial comprehensive report combining all research |
| 1.1 | 2026-02-01 | Answered all 12 open questions with research |
| 1.2 | 2026-02-01 | Added SWE-agent research: ACI design, mini-swe-agent, verification patterns |
| 1.3 | 2026-02-01 | Added 3 Gastown patterns: atomic spawn, validation tests, batch lookups (48 total) |
| 1.4 | 2026-02-01 | Added native Claude Code swarm analysis (#49-50, 50 total) |
| 1.5 | 2026-02-05 | Opus 4.6 & native agent teams (#51-55, 55 total) |
| 1.6 | 2026-02-06 | Claude Code 2.1.33+ features (#56-62, 62 total). Memory, hooks, Task metrics. |
| 2.0 | 2026-02-06 | Major restructure: 12 improvements deprecated (now native). 50 active remain. |
| 2.1 | 2026-02-07 | Dolt migration (#1) marked DONE. 49 active remain. |
| 2.2 | 2026-02-07 | Accuracy review: 7 factual corrections via web research. |
| 3.0 | 2026-02-07 | Agent Mail deprioritized (beads Rust incompatible with Dolt). Hook-based file ownership replaces it. |
| 4.0 | 2026-02-07 | Streamlined: removed completed/deprecated/obsolete content. Renumbered 49 items. Reordered priorities. |
| 4.1 | 2026-02-07 | Research-verified top 4. Removed semaphore + retry (already in beads/Gastown-specific). Reframed skeptical reviewers. Downgraded two-phase dispatch. 47 items. |
| 4.2 | 2026-02-07 | **Research-verified top 10 via 5 parallel Opus agents.** Removed 3 items: process termination (Gastown tmux-specific, not applicable), pre-commit guard (agent identity gap in git hooks, pre-commit.com destroys beads hooks), task type classification (already implemented in SDD). Corrected 7 items: arXiv paper misrepresentation fixed (#1 — Claude benefits from Two-Phase Reflective, not behavioral comparison; RCRR measures false-positive avoidance only); dependency direction reversed (#2 depends on nothing, #3 depends on #2); `$AGENT_NAME` confirmed non-existent (#3 — blocked on Issue #16126); "ZFC" label dropped (#4 — fabricated, not from Gastown or math; renamed to Strict SSOT); quality gates split (#5 — TaskCompleted hard enforcement kept, addBlockedBy soft enforcement already in SDD); simplification review reframed (#6 — fold into existing skills + linter hooks, don't create new skill); checkpoint classification simplified (#7 — binary flag, lowered to P6). Added Section 3.4: Claude Code Hooks API verification. Updated Q3: pre-commit.com incompatible with beads. P3 (Foundation Code) eliminated (empty). **44 active improvements remain.** |
| 4.3 | 2026-02-07 | **Agent teams research + stable-only pivot.** Via 2 parallel Opus research agents: discovered `CLAUDE_CODE_AGENT_NAME` exists for team members (unblocks file ownership in theory), documented all 13 TeammateTool operations, corrected token cost to ~7x (official docs). **However:** ~7x token cost makes agent teams impractical for Max 20x subscribers — could wipe daily/weekly quota in a single session. **Decision: defer all experimental features, focus on stable only.** Removed 2 items (#45 feature detection, #46 two-mode SDD). Kept #45 (renumbered) as stable frontmatter modernization. P1.5 is now "Stable Skill Modernization" (~2 hours, zero token cost increase). #35 moved from P6 to P8 (future). Agent teams research preserved in Section 3.1 for future reference. **45 active improvements.** |
| 5.0 | 2026-02-07 | **Research-verified full re-ranking via 5 parallel Opus agents.** Five agents researched: (1) Claude Code hooks API, (2) AI code review/verification, (3) skill/agent frontmatter, (4) parallel execution/file ownership, (5) SWE-agent ACI patterns. **Critical discovery: [Issue #21460](https://github.com/anthropics/claude-code/issues/21460) — PreToolUse/PostToolUse hooks do NOT fire for subagent tool calls.** This fundamentally changes the file ownership strategy. Six related hook issues span Aug 2025–Jan 2026 with zero resolution. **Major priority changes:** #5 (TaskCompleted hook) promoted P2.3→P1.2 (only hard enforcement for subagents); #3 (PreToolUse file ownership) demoted P1.1→P5 (blocked on TWO issues); #15 (prompt-based file ownership) promoted P3.1→P2.4 (proven primary mechanism — Anthropic C compiler); #42 (frontmatter hooks) promoted P1.6→P1.3 (potential workaround for #21460, needs verification); #25 (linter guards) conditionally promoted to P2.2 (depends on #42 verification). **Scope corrections:** #45 corrected — `memory`, `maxTurns`, `tools` are agent-only fields, not skill fields (scope reduced from 19 files to 4); #40 moved to P8 (`Task(agent_type)` is no-op for subagent architecture). **Items changed:** #2 merged into #15; #29 removed (redundant with native tools); #46 added (multi-review aggregation, 43.67% F1 improvement from SWR-Bench). #8 promotion rejected on self-audit (SWR-Bench evidence supports new #46, not #8 which is throughput). Section 3.4 expanded with 6 open hook issues. **44 active improvements.** |
| 5.1 | 2026-02-07 | **Empirical verification of top 3 assumptions.** #42 frontmatter hooks: CONFIRMED/VERIFIED — PostToolUse hooks fire for subagent tool calls via `--agents` (3/3 runs, Claude Code 2.1.37). Promotes #25 linter guards to unconditional P2.2. #5 TaskCompleted latency: INCONCLUSIVE — 20 sessions succeeded but command hook markers never created in headless mode. No priority changes. #1 Two-Phase Reflective: PARTIAL/VERIFIED — +0.2 score improvement (5.0 vs 4.8), zero FP advantage (0.0 vs 0.2), both methods detect 5/5 bugs. Adopt for precision, not detection improvement. |
| 5.2 | 2026-02-08 | **V2 experiment scripts ready, pending execution.** Three V2 experiments scripted to resolve v1 inconclusive/ceiling-effect outcomes: (A) TaskCompleted trigger matrix — 4 cells {native TaskCreate+TaskUpdate, bd create+close} x {headless, interactive}, dual-probe verification, per-cell FIRES/DOES_NOT_FIRE/UNSTABLE verdict. Resolves v1 headless mode question for #5. (B) TaskCompleted latency — gated on A, 12 measured runs per variant + 2 warmup, cycle randomization, bootstrap CI. Only runs for confirmed FIRES paths. (C) Two-Phase Reflective v2 — harder fixture with 14 areas (6 bugs + 8 decoys, up from 5+3), 20 paired cycles (up from 5), Wilcoxon signed-rank + Bootstrap CI, CONFIRMED/PARTIAL/DENIED/INCONCLUSIVE verdicts. Designed to break v1 ceiling effect. Shared analysis via `tests/verification/analyze-v2.py`. No priority changes — results pending execution (experiments take 1-3 hours each). Updated #1 and #5 descriptions, P1.2, P2.1, and Section 3.4 TaskCompleted notes with V2 experiment references. |
| 5.3 | 2026-02-08 | **V2 experiments executed — Two-Phase DENIED, TaskCompleted headless confirmed non-functional.** Three experiments ran (16 headless + 6 interactive + 40 reflective = 62 total sessions): **(A) TaskCompleted trigger matrix: INCONCLUSIVE.** TaskCompleted hook never fired in headless `claude -p` mode (0/10 marker hits across A1xM1 and A2xM1). PostToolUse:Bash control hook fired 5/5 (proves sessions ran). All 6 M2 (expect interactive) runs timed out. Confirms V1 suspicion — TaskCompleted hooks are non-functional in headless mode. **(B) TaskCompleted latency: NOT_MEASURABLE.** Gated out — no trigger path classified as FIRES. **(C) Two-Phase Reflective: DENIED (VERIFIED, p=0.000183).** V2 overturns V1 finding with decisive evidence. Current code-reviewer: mean score 5.95, mean FP 0.05, recall 1.00. Two-Phase: mean score 5.25, mean FP 0.75, recall 1.00. Both achieve perfect 6/6 bug detection — the ONLY difference is Two-Phase produces 15x more false positives. Bootstrap CI on delta [-0.9, -0.5] firmly excludes zero. 20/20 paired cycles, 0 parse failures, 0 retries. **Priority changes:** #1 (Two-Phase Reflective) removed from CRITICAL IMPACT and P2.1 — current code-reviewer is already near-optimal. #46 (multi-review aggregation) is now the primary quality improvement path. #5 (TaskCompleted hook) updated — headless enforcement confirmed non-viable, interactive-only value. **43 active improvements (down from 44).** |

---

*This document synthesizes findings from: superpowers-bd, superpowers (original), get-shit-done, gastown (575 commits), loom, claude-flow, SWE-agent/mini-swe-agent, Dolt backend analysis, Opus 4.6 release analysis, Claude Code 2.1.33+ changelog analysis, empirical beads v0.49.4 concurrency testing, arXiv 2508.12358 (LLM verification), arXiv 2509.01494 (SWR-Bench multi-review), Claude Code hooks API verification (Issues #16126, #7881, #21460, #6305, #18950, #20946, #14859), pre-commit.com compatibility testing, Claude Code agent teams docs (code.claude.com), experimental feature detection research (paddo.dev, kieranklaassen gist, claudefa.st), Anthropic C compiler engineering blog, Cursor worktree isolation docs, official Claude Code skills/sub-agents/hooks documentation (code.claude.com), and V2 verification experiments (62 sessions: trigger matrix, latency, two-phase reflective with Wilcoxon signed-rank + Bootstrap CI).*

***Version 5.3 Summary:** 43 active improvements (down from 44). V2 experiments executed (62 sessions). **#1 (Two-Phase Reflective) REMOVED** — V2 DENIED with p=0.000183: current code-reviewer already achieves 6/6 recall with 0.05 FP; Two-Phase produces 15x more FP (0.75) with identical detection. **#5 (TaskCompleted) updated** — confirmed non-functional in headless `claude -p` mode (0/10), interactive-only value. #46 (multi-review aggregation) is now the primary quality improvement path. Priority order: config/hooks (P1) → **agent modernization (P1.5)** → quality gates + prompt-based file ownership (P2, minus #1) → **multi-review scaling (P3, promoted)** → context/state (P4) → deferred enforcement + performance (P5) → polish (P6) → SWE-agent (P7) → future (P8). Zero external runtime dependencies.*
