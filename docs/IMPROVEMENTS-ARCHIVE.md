# Superpowers-BD: Improvement Archive

**Companion to:** [SUPERPOWERS-BD-COMPREHENSIVE-IMPROVEMENTS.md](../SUPERPOWERS-BD-COMPREHENSIVE-IMPROVEMENTS.md) (action list)

This document contains research findings, experiment results, detailed rationale, and version history supporting the improvement roadmap.

---

## 1. Detailed Item Descriptions

Each item's # matches the roadmap. Items are grouped by impact tier.

### CRITICAL IMPACT

(No items — #1 moved to REMOVED after V2 experiment DENIED verdict)

### HIGH IMPACT

**#3 — File ownership enforcement via hooks**
Proactive conflict prevention. `PreToolUse` hook on `Edit|Write` checks wave file map and blocks edits to files owned by other agents. **BLOCKED on TWO issues:** (1) `$AGENT_NAME` does not exist for regular subagents ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126)), (2) PreToolUse hooks do not fire for subagent tool calls ([Issue #21460](https://github.com/anthropics/claude-code/issues/21460)). Six related hook enforcement issues span Aug 2025–Jan 2026 with zero Anthropic resolution. Primary approach is now prompt-based (#15), validated by Anthropic's C compiler project at production scale. Hook enforcement is a future defense-in-depth layer. Moved to P5. Source: Hook-based. **Demoted P5→Icebox (2026-02-11).** Both upstream blockers (#16126, #21460) open 6+ months with zero resolution. Prompt-based approach (#15) provides 4 defense layers: ownership list, wave file map, self-review checkpoint, SCOPE verdict. Hook enforcement is marginal defense-in-depth.

**#4 — Strict SSOT: Query, Don't Track**
Prevents state drift bugs. Instead of caching task state in skills, always query beads for truth. The SDD skill already follows this pattern (queries `bd ready` at every loop iteration). This is a design principle to codify, not a code change. "Skills MUST NOT cache beads query results across wave boundaries." Source: Distributed systems SSOT principle. **Removed (2026-02-11).** Already implemented through concrete guard rules: SDD "Always: check bd ready before each wave" (SKILL.md:75), executing-plans "Check bd ready before each batch" (SKILL.md:66), recovery paths "fall back to beads as SSOT" (checkpoint-recovery.md:46, failure-recovery.md:111). Abstract principle adds no enforcement the guard rules don't already provide.

**#5 — TaskCompleted hook for quality gates**
Hard enforcement at task completion. `TaskCompleted` hook exits with code 2 to block task completion if quality criteria not met. Can use `type: "agent"` for 50-turn code analysis hooks. The only hard enforcement mechanism that works for subagents. GA since v2.1.33. V2 Experiment A (2026-02-08): Headless `claude -p` mode: TaskCompleted NEVER fired (0/10). Manual verification (2026-02-08): Interactive `claude` mode: TaskCompleted FIRES. Conclusion: Interactive mode only. Source: Native hooks.

**#6 — Strengthen existing simplification checks + linter hooks**
Reduces code complexity. Qualitative review already covered by 5+ existing skills. Do NOT create a new skill. Instead: (a) add quantitative checklist items to existing code-reviewer.md, (b) implement cyclomatic complexity enforcement via PostToolUse linter hooks (#25). Thresholds: flag >10, block >15 (matches McCabe/NIST). Source: Industry standard.

### MEDIUM IMPACT

**#7** — Checkpoint classification: Binary `requires_human: true/false` flag on plan steps. Simplified from three-way taxonomy. Source: Inspired by get-shit-done. **Demoted P3→Icebox (2026-02-11).** Conflicts with full-automation philosophy — once plan approved and epic created, execution should be fully automated. Existing 3-strike escalation handles genuine blockers. Plans are almost exclusively coding tasks with zero non-automatable steps in practice.

**#8** — Parallelize review pipelines: Reviews for different tasks run concurrently. Throughput parallelism, distinct from multi-review aggregation (#46). Source: Original research. **Removed (2026-02-11).** Already implemented in background-execution.md: inter-task review parallelism with event-driven dispatch, run_in_background=True on all reviews, polling loop handles both implementations and reviews concurrently.

**#9** — Parallel bd queries: 6x speedup via goroutines with pre-allocated result slice. 32s → 5s inbox load in Gastown. Source: Gastown §3.5. **Deprioritized P5→P8 (2026-02-11).** SQLite+daemon migration eliminated the Dolt 32s bottleneck. All bd commands are sub-110ms via RPC. Max 4 sequential calls in SDD hot path. Requires upstream Go binary changes. **Removed — obsolete (2026-02-11).** Even at P8, the 82ms savings per wave is irrelevant against 5-30 min wave execution. Close.

**#10** — Structured agent IDs: Validates task/bead IDs with parsing. Format: `<prefix>-<role>` or `<prefix>-<rig>-<role>-<name>`. Source: Gastown §2.1. **Demoted P3→Icebox (2026-02-11).** Gastown §2.1 format assumes persistent named agents; superpowers-bd uses ephemeral anonymous Task tool dispatches. 4 of 6 ID types are generated by external systems (bd CLI, Claude Code runtime). $AGENT_NAME unavailable for regular subagents (#16126). No layer where structured IDs would be validated or enforced.

**#11** — --fast mode for status: 60% faster status checks. Skip non-essential operations. 5s → 2s. Source: Gastown §3.1. **Removed — obsolete (2026-02-11).** SQLite migration dropped bd ready from ~5s (Dolt) to 82ms. All status commands sub-110ms. The performance problem no longer exists.

**#12** — Template rendering for prompts: Consistent output formatting. Type-safe data injection. Source: Gastown §4.3. **Demoted P6→Icebox (2026-02-11).** No code execution layer — prompts are LLM-interpreted, not machine-rendered. 15 stable template variables with manual registry in context-loading.md. Gastown §4.3 was for Go code templates, not applicable.

**#13** — Health checks (doctor): Check for orphaned worktrees, prefix mismatches, stale agent beads, slow operations. Auto-fix common issues. Source: Gastown §2.2. **Removed — already done (2026-02-11).** bd doctor v0.49.6 runs 68 checks covering prefix mismatches, stale molecules, test pollution, sync status, and git state. Supports --fix auto-repair. Only minor gap is git-worktree orphan detection.

**#14** — Completion evidence requirements: Tasks can only close with proof (commit hash, files changed, test results, coverage delta). `TaskCompleted` hook verifies before accepting. Source: Native hooks.

**#15** — File ownership declared in task definition: Conflicts computed at dispatch time. Each task declares owned files in description. Orchestrator serializes `{wave_file_map}` table into each implementer prompt showing all agents' file assignments. No file I/O — eliminates permission prompts and cleanup. Absorbs #2. Prompt-based enforcement validated by [Anthropic's C compiler project](https://www.anthropic.com/engineering/building-c-compiler) at production scale. Source: Hook-based + Anthropic engineering.

**#16** — Artifact-specific rule-of-five variants: Code (`rule-of-five-code`): Draft→Correctness→Clarity→Edge Cases→Excellence. Plans (`rule-of-five-plans`): Draft→Feasibility→Completeness→Risk→Optimality. Tests (`rule-of-five-tests`): Draft→Coverage→Independence→Speed→Maintainability. **DONE** (2026-02-11). Three separate skills with consistent naming, no router. Updated ~25 files (callers, docs, permissions). Source: Original research.

### LOWER IMPACT

**#17** — DAG visualization: Tree view with status icons, tier view for parallel opportunities, critical path analysis. Source: Gastown §1.3. **Demoted P8→Icebox (2026-02-11).** bd graph already provides tree view with status icons and parallel tier identification (layer system). Only critical path analysis missing — low value for typical 4-8 task graphs.

**#18** — Complexity scoring: 0-1 scale with estimated duration and confidence. Enables SLA tracking. Source: claude-flow. **Demoted P8→Icebox (2026-02-11).** 3-level complexity system (simple/standard/complex) already captures actionable value — maps to 3 model tiers. 0-1 continuous scale adds no routing decisions. LLM duration estimation unreliable. SLA tracking doesn't fit use case.

**#19** — Adversarial security review: Test injection, auth bypass, privilege escalation, data leakage, DoS. Source: loom. **Demoted P8→Icebox (2026-02-11).** Security already covered by code-reviewer (trust boundary tracing, Critical severity), epic-verifier (Section 1.6 security scan), and multi-review aggregation (security findings protected from downgrade). External tools (Semgrep, CodeQL) better suited for dedicated adversarial review.

**#20** — External verification (GPT 5.2-codex): Second opinion on critical code. Self-Agg may be as effective (SWR-Bench). Source: Original research. **Demoted P8→Icebox (2026-02-11).** Self-Agg (#46, DONE) matches Multi-Agg per SWR-Bench (arXiv 2509.01494). No integration mechanism for external model APIs from Claude Code skills (no HTTP client, no API key management).

**#21** — Agent-agnostic zombie detection: Read GT_AGENT env var, look up process names for Claude/Gemini/Codex/Cursor/etc. Source: Gastown §1.5. **Demoted P8→Icebox (2026-02-11).** GT_AGENT is Gastown/tmux-specific. Claude Code's Task tool manages subagent lifecycle. Existing SDD failure recovery covers stuck subagents (polling loop, 3-strike escalation). Process-level detection not applicable.

**#22** — Memorable agent identities: Adjective+noun names (GreenCastle, BlueLake). 4,278 unique combinations. Source: Research. **Demoted P8→Icebox (2026-02-11).** Same blockers as #10. Subagents are ephemeral Task tool dispatches with no persistent identity. $AGENT_NAME unavailable (#16126). No UI surface — agents tracked by issue_id + role.

**#23** — Git-backed context audit trail: `.context/` directory with JSON files, git commits on each update, SQLite index for queries. Source: Research. **Demoted P8→Icebox (2026-02-11).** Five existing audit layers: file-modification log, TaskCompleted gate, bd close --reason, beads comments, session transcripts (.jsonl). RELEASE-NOTES explicitly removed redundant audit logging. Narrow remaining gap (cross-session queryable design decisions) doesn't justify complexity.

**#24** — ~~Pre-planning file conflict analysis~~ **OBSOLETE** (2026-02-11): Superseded by `file-lists.md` (planners already told "shared files = no parallel"), SDD's `dispatch-and-conflict.md` (runtime conflict deferral), #15's `{wave_file_map}` (runtime visibility), and rule-of-five-plans Risk pass ("parallel conflicts"). Original proposal: Compute waves during planning, not runtime. Pre-compute optimal groupings, surface in plan header. Source: Gastown + original research.

### FROM SWE-AGENT RESEARCH

**#25** — Linter guards on all edits: Run linter after edit (PostToolUse hook), surface error to Claude, prompt retry. SWE-agent ablation: 3pp improvement (15.0% → 18.0%). Frontmatter hooks verified working for subagents (2026-02-07). **DONE (2026-02-08):** `hooks/run-linter.sh` runs shellcheck (.sh) and jq (.json) after Write/Edit. Main thread coverage via `hooks/hooks.json` PostToolUse. Subagent coverage via `agents/code-reviewer.md` frontmatter hook chain. Graceful degradation if tools not installed. 8/8 unit tests pass. Source: SWE-agent ACI.

**#26** — Succinct search results (max 50): Prevents context overflow in subagents. Source: SWE-agent ACI. **Removed — obsolete (2026-02-11).** Claude Code Grep tool has head_limit parameter + automatic truncation at 30K characters. Same reasoning as already-demoted #28.

**#27** — Integrated edit feedback: Show file diff immediately after edit. Source: SWE-agent ACI. **Removed — obsolete (2026-02-11).** Claude Code Edit tool returns modified content in tool results natively. PostToolUse linter hooks (#25, DONE) provide additional feedback beyond SWE-agent's proposal.

**#28** — 100-line file chunks: Mostly redundant — Claude Code's Read tool supports `offset`/`limit` natively. Demoted to P8. Source: SWE-agent ACI.

### FROM GASTOWN

**#30** — Atomic spawn (NewSessionWithCommand): Eliminates race conditions in subagent spawning. Source: Gastown §15. **Removed — obsolete (2026-02-11).** Task tool is a single atomic Claude Code primitive. Gastown's two-step tmux spawn race condition cannot occur. Archive already notes "Process termination: REMOVED — Gastown tmux-specific."

**#31** — Validation tests for hook/skill configs: Prevents silent failures from misconfigured skills. Source: Gastown §11. **Demoted P7→Icebox (2026-02-11).** All 20 skills currently well-formed. Config changes rare post-v4.1.2. Claude Code validates at runtime. Revisit if adding new skills or hooks.

**#32** — Batch lookups with SessionSet pattern: O(1) repeated queries instead of N+1 subprocess calls. Source: Gastown §3.4. **Deprioritized P5→P8 (2026-02-11).** Daemon RPC over Unix socket eliminates subprocess startup overhead. Max N=5 sequential calls in practice. Inherently sequential patterns (plan2beads creates with dependency chaining) cannot be batched. Requires upstream Go binary changes. **Removed — obsolete (2026-02-11).** Max N=5, inherently sequential patterns (plan2beads dependency chaining) can't be batched. Close.

### OPUS 4.6 & CLAUDE CODE 2.1.33+

**#33** — 1M context: BETA ONLY. Monitor for GA release. Source: Opus 4.6.

**#34** — 128K output: Available now. Full plans and reviews in single response. Source: Opus 4.6. **Demoted P6→Icebox (2026-02-11).** Claude Code caps output at 32-64K tokens (bugs #24159, #24313 open). No skills constrain output length. When the cap is lifted, skills benefit automatically — nothing to implement.

**#35** — Native agent teams: DEFERRED. ~7x token cost impractical for Max subscribers. Enable via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Source: Opus 4.6.

**#36** — Map task type to effort level: Claude Code's Task tool doesn't expose `output_config.effort` yet. Source: Opus 4.6 adaptive thinking. **Updated (2026-02-11).** Partially unblocked: session-level effort exists via CLAUDE_CODE_EFFORT_LEVEL (low/medium/high) and /model slider. Task tool still lacks per-subagent effort parameter. Existing model matrix (haiku/sonnet/opus by complexity) is a functional workaround. Per-Task effort dispatch remains the blocker. **Demoted P6→Icebox (2026-02-11).** Nothing to implement until Anthropic ships the feature. Model routing is the functional workaround.

**#37** — Exploit ARC AGI 2 leap: Route complex problems to Opus 4.6 (68.8% ARC vs 37.6% before). Available now. Source: Opus 4.6 benchmarks. **Removed — already done (2026-02-11).** Complexity-based model routing (v4.5.0) routes complex→Opus on max-20x/max-5x tiers via COMPLEXITY_TO_IMPL matrix. ARC AGI 2 improvements are inherent to the Opus model, not something the plugin activates.

**#38** — `memory` frontmatter: Persistent agent memory. Scopes: `user`, `project`, `local`. Source: Claude Code v2.1.33.

**#39** — TeammateIdle/TaskCompleted: SPLIT. TaskCompleted → P1.2 (GA, hard enforcement). TeammateIdle → P8 (agent teams only). Source: Claude Code v2.1.33.

**#40** — `Task(agent_type)` syntax: No-op for subagent architecture per [official docs](https://code.claude.com/docs/en/sub-agents). Moved to P8. Source: Claude Code v2.1.33.

**#41** — Native Task metrics: Token count, tool uses, duration in Task results. Source: Claude Code v2.1.30.

**#42** — Hooks in frontmatter: Per-agent hooks bypassing [Issue #21460](https://github.com/anthropics/claude-code/issues/21460). VERIFIED (2026-02-07, Claude Code 2.1.37): Frontmatter PostToolUse hooks DO fire for subagent tool calls via `--agents`. 3/3 runs confirmed. Foundation for #25 and #3. Source: Claude Code v2.1.33.

**#43** — --from-pr flag: Sessions auto-link to PRs. Source: Claude Code v2.1.27. **Demoted P6→Icebox (2026-02-11).** --from-pr is a user CLI startup flag, not a plugin config. Review pipeline uses git SHAs not PR objects. User controls push timing so PRs may not exist during reviews.

**#44** — Skill character budget scaling: 2% of context window. Source: Claude Code v2.1.32. **Demoted P6→Icebox (2026-02-11).** All 20 skills well within frontmatter (80-250 chars of 1024 max) and body (52-128 lines of 150 max) budgets. 3-tier progressive disclosure model already handles overflow. Longer descriptions would hurt discovery.

**#45** — Modernize agent frontmatter: SCOPE CORRECTED — `memory`, `maxTurns`, `tools` are agent-only fields. Actual scope: 2 agent definitions + 1 command + writing-skills guide. ~1.5 hours. Source: Codebase audit.

Checklist:
- [ ] `memory: project` on `agents/code-reviewer.md` and `agents/epic-verifier.md`
- [ ] `maxTurns` on both agents (test to find right values)
- [ ] YAML frontmatter on `commands/plan2beads.md`
- [ ] Update `skills/writing-skills/SKILL.md` to document all 10 frontmatter fields
- [ ] Consider `allowed-tools` on read-only skills (brainstorming, epic-verifier, verification-before-completion)
- [ ] Replace hardcoded model strings in SDD prompts

**#46** — Multi-review aggregation: N independent reviews aggregated. [SWR-Bench (arXiv 2509.01494)](https://arxiv.org/html/2509.01494v1): Self-Agg (n=10) achieves 43.67% F1 improvement, 118.83% recall improvement. Self-Agg performs comparably to Multi-Agg. Source: SWR-Bench.

### REMOVED ITEMS

- **#1** — Two-Phase Reflective: V2 DENIED (2026-02-08, p=0.000183). 15x more FP (0.75 vs 0.05) with identical recall (6/6). Current code-reviewer is already near-optimal. 20 paired cycles, Wilcoxon signed-rank, Bootstrap CI [-0.9, -0.5].
- **#2** — Merged into #15 (SDD already implements two-phase; remaining value = file-locks.json = #15)
- **#29** — Redundant with native Claude Code Read + Grep tools
- **#45 (original)** — SessionStart feature detection: Not needed without agent teams
- **#46 (original)** — Two-mode SDD: Agent teams impractical for Max subscribers

---

## 2. Priority Rationale

### P1 Rationale
Zero code required. TaskCompleted (#5) is the highest-value hook — GA, genuinely blocks task completion, and critically is the only enforcement that works for subagents (PreToolUse/PostToolUse don't fire for subagent tool calls per [Issue #21460](https://github.com/anthropics/claude-code/issues/21460)). Frontmatter hooks (#42) verified (2026-02-07) — confirmed as the path to per-agent hook enforcement, unlocking #25 (linter guards) and eventually #3 (file ownership).

Items removed from P1 (v4.3 → v5.0):
- #3 → P5. Blocked on #16126 + #21460. Prompt-based (#15) is the proven primary mechanism.
- #40 → P8. `Task(agent_type)` is a no-op for subagent architecture.
- #39 TeammateIdle → P8. Only relevant with agent teams. TaskCompleted portion promoted to P1.2.

### P1.5 Rationale
Two agent definitions lack memory/maxTurns, one command lacks frontmatter, and the writing-skills guide is factually wrong about available fields. Scope correction: `memory`, `maxTurns`, `tools` are agent-only fields per [official docs](https://code.claude.com/docs/en/sub-agents). The v4.3 claim of "17 skills + 2 agents" was incorrect — the agent-specific work is 2 files, not 19.

### P2 Rationale
Quality gates are superpowers-bd's unique value. #1 REMOVED — V2 experiment DENIED Two-Phase Reflective with p=0.000183. Current code-reviewer achieves 6/6 recall with 0.05 FP. Two-Phase produces 15x more false positives. #46 (multi-review aggregation) promoted to P2.1 as the primary quality improvement path — 43.67% F1 improvement (SWR-Bench). #15 (file ownership via prompt-based coordination) is the primary mechanism — validated by Anthropic's C compiler project.

**File ownership status:**
- Prompt-based is PRIMARY. Anthropic's [C compiler project](https://www.anthropic.com/engineering/building-c-compiler) used advisory file locks with cooperative agents at production scale.
- Orchestrator serializes `{wave_file_map}` table into each implementer prompt. No file I/O — agents see who owns what directly in their dispatch prompt.
- Cursor's experience: Traditional file locking bottlenecked 20-agent runs to 2-3 effective agents. Advisory coordination scales better.
- Hook-based enforcement is defense-in-depth (P5), contingent on upstream fixes.

---

## 3. Key Decisions Made

- **Dolt migration: COMPLETED** (Feb 7, 2026). Beads v0.49.4 on Dolt backend.
- **12 improvements deprecated** — now native to Claude Code 2.1.33+.
- **Agent Mail: REMOVED** — beads Rust (`br`) incompatible with Dolt backend.
- **Semaphore concurrency: ALREADY IN BEADS** — v0.49.4 has 6 layers of concurrency protection. 40 concurrent `bd create` succeeded with zero failures.
- **Retry with verification: NOT NEEDED** — embedded Dolt eliminates silent write failures.
- **Process termination: REMOVED** — Gastown tmux-specific, not applicable.
- **Pre-commit quality guard: REMOVED** — Agent identity unavailable in git hooks. pre-commit.com destroys beads hooks ([Issue #3450](https://github.com/pre-commit/pre-commit/issues/3450)).
- **Task type classification: REMOVED** — Already implemented in SDD skill.
- **Agent Teams: DEFERRED** — ~7x token cost impractical for Max 20x subscribers.

---

## 4. Reference: New Capabilities

### 4.1 Opus 4.6 (Released February 5, 2026)

| Capability | Opus 4.5 | Opus 4.6 | Availability |
|------------|----------|----------|--------------|
| Context window | 200K tokens | **1M tokens** | Beta only |
| Output tokens | 64K | **128K** | GA |
| Terminal Bench | 59.8% | **65.4%** | GA |
| OSWorld (agentic) | 66.3% | **72.7%** | GA |
| ARC AGI 2 | 37.6% | **68.8%** | GA |

**Adaptive Thinking:** Effort controls (`output_config.effort`: low/medium/high/max). Claude Code's Task tool does not yet expose the effort parameter.

**Agent Teams (DEFERRED):** ~7x token cost. TeammateTool (13 operations). Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Teammate env vars: `CLAUDE_CODE_AGENT_NAME`, `_ID`, `_TYPE`, `_TEAM_NAME`, `_COLOR`.

**superpowers-bd vs native agent teams:**

| Capability | Native Agent Teams (~7x cost) | superpowers-bd (current) |
|------------|-------------------------------|--------------------------|
| Parallel execution | Built-in | Task tool + waves |
| Peer-to-peer messaging | TeammateTool | Hub-and-spoke |
| Session resumption | No | Beads persistence |
| Quality gates | No | Skills-based |
| File ownership | `AGENT_NAME` available | Prompt-based (blocked #16126) |
| Git-backed state | No | Beads on Dolt |
| Token cost | ~7x baseline | ~1x baseline |

### 4.2 Claude Code 2.1.33+ Features (Feb 6, 2026)

| Feature | Version | What It Does |
|---------|---------|-------------|
| `memory` frontmatter | v2.1.33 | Persistent agent memory (user, project, local scopes) |
| TeammateIdle/TaskCompleted hooks | v2.1.33 | Event-driven multi-agent coordination |
| Task metrics | v2.1.30 | Token count, tool uses, duration in Task results |
| Sub-agent restrictions | v2.1.33 | `Task(agent_type)` in tools frontmatter |
| Hooks in frontmatter | v2.1.33 | Per-agent hooks (PostToolUse, PreToolUse) |
| --from-pr flag | v2.1.27 | PR-linked sessions |
| Skill budget scaling | v2.1.32 | 2% of context window for skill content |

**Agent-type hooks:** `type: "agent"` get 50 turns with Read/Grep/Glob tools.

**Hook environment variables:**
- `$CLAUDE_PROJECT_DIR` — project root
- `$CLAUDE_PLUGIN_ROOT` — plugin root (for plugin hooks)
- `$CLAUDE_CODE_REMOTE` — "true" in remote environments
- `$CLAUDE_ENV_FILE` — path for persisting env vars (SessionStart only)
- `$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — "1" when agent teams enabled
- `$CLAUDE_CODE_TEAM_NAME` — team name (team members only)
- `$CLAUDE_CODE_AGENT_NAME` — teammate name (team members only — KEY for file ownership)
- `$CLAUDE_CODE_AGENT_ID` — unique agent ID
- `$CLAUDE_CODE_AGENT_TYPE` — agent type
- `$AGENT_NAME` — does NOT exist for regular subagents ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126))

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

### 4.3 Beads v0.49.4 Concurrency Architecture (Verified Feb 7, 2026)

Embedded Dolt (in-process via `dolthub/driver`), NOT `dolt sql-server`. Six layers of concurrency protection:

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| `dolt-access.lock` | Application-level file lock | Serializes Dolt access across processes |
| `.jsonl.lock` | Shared/exclusive lock | Prevents JSONL import/export races |
| Process-level semaphore | Limits concurrent Dolt access | Prevents resource exhaustion |
| Advisory flock | OS-level advisory lock | Prevents zombie bd processes |
| Lock retry + stale cleanup | Automatic retry with cleanup | Recovers from stale locks |
| Connection pool deadlock fix | Timeout on embedded Dolt close | Prevents pool deadlocks |

**Empirical results:** 40 concurrent `bd create` — zero failures. Linear scaling (3 ops = 0.66s, 10 ops = 2.08s, 40 ops = 7.67s).

**Dolt durability:** Chunk journal with `fsync()` — if write returns success, data is on physical storage.

### 4.4 Claude Code Hooks API (Verified Feb 7, 2026)

14 hook events officially documented as of v2.1.33.

**Subagent Hook Enforcement Gap ([Issue #21460](https://github.com/anthropics/claude-code/issues/21460))**

PreToolUse/PostToolUse hooks in global settings do NOT fire for subagent tool calls. Six related issues:
- [#21460](https://github.com/anthropics/claude-code/issues/21460) — PreToolUse hooks not enforced on subagent tool calls (OPEN)
- [#16126](https://github.com/anthropics/claude-code/issues/16126) — Add agent identity to PreToolUse hook data (OPEN)
- [#6305](https://github.com/anthropics/claude-code/issues/6305) — Post/PreToolUse hooks not executing (Aug 2025)
- [#18950](https://github.com/anthropics/claude-code/issues/18950) — Subagents don't inherit user-level permissions
- [#20946](https://github.com/anthropics/claude-code/issues/20946) — PreToolUse hooks don't block in bypass mode
- [#14859](https://github.com/anthropics/claude-code/issues/14859) — Agent hierarchy in hook events

**Hooks that DO work for subagents:**
- `TaskCompleted` — exit code 2 blocks task completion (GA, hard enforcement)
- `SubagentStop` — can block subagent from finishing
- `TeammateIdle` — agent teams only

**PreToolUse hooks (main agent only):**
- Matcher is regex: `Edit|Write` matches both tools
- Input via stdin as JSON: `tool_input.file_path`
- `exit 2` blocks; preferred: JSON with `permissionDecision: "deny"` + `permissionDecisionReason`
- Can modify tool input via `updatedInput` (transparent sandboxing)
- No agent identity in hook input ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126))
- Subagents share `session_id` with parent ([Issue #7881](https://github.com/anthropics/claude-code/issues/7881))

**TaskCompleted hooks:**
- `exit 2` blocks task completion
- Receives: `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- `type: "agent"` for 50-turn code analysis; `type: "prompt"` for lightweight LLM evaluation
- Latency risk: agent-type hooks could take 60+ seconds per task
- V2 Experiment A: Does NOT fire in headless `claude -p` mode (0/10). DOES fire in interactive mode (manually verified).

**Frontmatter hooks (VERIFIED):**
- Scoped to component's lifecycle
- All hook events supported; `Stop` auto-converts to `SubagentStop` for subagents
- `once` field (boolean, skills only) makes hook run once per session
- VERIFIED (2026-02-07, Claude Code 2.1.37): Frontmatter PostToolUse hooks DO fire for subagent tool calls via `--agents`. 3/3 runs confirmed.

**addBlockedBy (Task tool):**
- Soft/prompt-based enforcement only
- Beads dependencies (`bd ready`/`bd blocked`) provide stronger enforcement

---

## 5. Open Questions — Answered

### Q1: Dolt crash recovery?
Dolt's embedded mode has robust crash recovery. Chunk journal with fsync. Beads v0.49.4 adds 6 layers of protection. No additional retry needed.

### Q2: Worktree Dolt sharing?
Use `dolt sql-server` mode with multiple client connections. Future consideration — current embedded mode works for single sessions. Would require `dolt_mode: "server"` in metadata.json.

### Q3: Pre-commit guards?
pre-commit.com is NOT compatible with beads — destroys existing hook shims ([Issue #3450](https://github.com/pre-commit/pre-commit/issues/3450)). Use beads' `chain_strategy: before` instead. Agent identity gap in git hooks makes agent-specific commit guards impossible.

### Q4: File reservation TTL?
30 minutes default. Short (5-15 min) for quick tasks, long (1-2 hours) for complex refactoring. Max extensions: 3 (2 hours total). On expiry: auto-release + escalate.

### Q5: Heartbeat failure handling?
NO auto-kill. NUDGE (10 min) → WAKE (20 min) → ESCALATE (30 min) → Human decision to KILL. Exception: auto-release reservation if TTL expires AND no heartbeat.

### Q6: Simplification aggressiveness?
Moderate. Cyclomatic complexity: flag >10, block >15 (McCabe/NIST). Function length: flag >50, block >100. Duplication: flag >10 lines, block >25. Don't block on style preferences.

### Q7: External adversarial review tool?
Multiple: Claude Code Security Review (GitHub Action), GPT 5.2-codex, NeuroSploitv2, Checkmarx/Semgrep. AI reviewers can be tricked ([Checkmarx LITL research](https://checkmarx.com/zero-post/bypassing-claude-code-how-easy-is-it-to-trick-an-ai-security-reviewer/)).

### Q8: Claude Desktop vs Claude Code?
Use Claude Code exclusively. Native MCP support, Task tool, better performance.

---

## 6. Research Opportunities

### Repositories Not Yet Analyzed

| Repository | Value | Priority |
|------------|-------|----------|
| [aider](https://github.com/paul-gauthier/aider) | Diff handling, architect mode, repo map | High |
| [mentat](https://github.com/AbanteAI/mentat) | Context management patterns | Medium |
| [sweep](https://github.com/sweepai/sweep) | PR quality/review automation | Medium |
| [Devon](https://github.com/entropy-research/Devon) | Multi-step task execution with planning | Medium |
| [continue](https://github.com/continuedev/continue) | Atomic multi-file changes | Low |
| [gpt-engineer](https://github.com/gpt-engineer-org/gpt-engineer) | High-level planning patterns | Low |

### Topics Needing Research

| Topic | How to Research |
|-------|-----------------|
| Aider's architect mode | Clone repo, analyze `architect.py` |
| Dolt server mode in practice | DoltHub Discord, test with 5+ concurrent clients |
| Property-based testing for AI output | Loom source code deep dive |
| Parallel execution at 10+ subagents | Testing with synthetic workloads |
| AI security review bypasses | [Checkmarx LITL research](https://checkmarx.com/zero-post/bypassing-claude-code-how-easy-is-it-to-trick-an-ai-security-reviewer/) |
| Over-correction bias in LLM reviewers | [arXiv 2508.12358](https://arxiv.org/html/2508.12358v1) |
| Claude Code agent identity in hooks | Track [Issue #16126](https://github.com/anthropics/claude-code/issues/16126) |

### Patterns Worth Investigating

| Pattern | Where Seen |
|---------|-----------|
| Convoy batch tracking | Gastown |
| Race condition prevention | Gastown §2.4 |
| Worktree management | Gastown §4.4 |
| Hook system architecture | Gastown §11 |
| Repo maps for context | Aider |
| LITL attacks on AI reviewers | Checkmarx |

---

## 7. SWE-Agent Research Findings

[SWE-agent](https://github.com/SWE-agent/SWE-agent) — Princeton/Stanford software engineering agent. Key insight: **tool quality matters as much as model quality**.

### Agent-Computer Interface (ACI)

> "Just like how typical language models require good prompt engineering, good ACI design leads to much better results when using agents."

| Principle | Implementation | Impact |
|-----------|---------------|--------|
| Succinct output | Max 50 matches, summarized | Prevents context overflow |
| Integrated feedback | Edit shows updated file immediately | Agent sees effect of actions |
| Guardrails | Linter blocks invalid edits | Prevents compounding errors |
| Specialized tools | File viewer (100 lines), search commands | ~7x better than generic bash |

### SWE-Agent Tools

| Tool | What It Does |
|------|--------------|
| File Viewer | 100 lines at a time, line numbers, scroll, search |
| Integrated Editor | Edit + automatic display + linter validation |
| find_file | Search filenames |
| search_file | Search within file |
| search_dir | Search directory, list matching files |
| Linter Guard | Runs on every edit, blocks on syntax error |

Result: ~7x improvement vs agents with generic bash.

### mini-swe-agent: The Counterpoint

100 lines of Python, bash-only, 74%+ on SWE-bench verified. Proves complex tool infrastructure isn't always necessary.

### Key Insight

> Your skills are the Agent-Computer Interface for Claude. How you design them matters as much as the prompts.

Sources: [SWE-agent](https://github.com/SWE-agent/SWE-agent), [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent), [NeurIPS 2024 paper](https://arxiv.org/pdf/2405.15793), [ACI docs](https://swe-agent.com/background/aci/)

---

## 8. V2 Verification Experiments (Executed 2026-02-08)

62 total sessions (16 headless + 6 interactive + 40 reflective).

### Experiment A: TaskCompleted Trigger Matrix
- **Result: INCONCLUSIVE.** TaskCompleted never fired in headless `claude -p` mode (0/10 across 2 action types x 5 runs). PostToolUse:Bash control fired 5/5 (proves sessions ran). All 6 M2 (expect interactive) runs timed out.
- **Conclusion:** TaskCompleted hooks are non-functional in headless mode. Interactive-only value.
- **Data:** `tests/verification/taskcompleted-trigger-matrix-results.csv`, `trigger-gate.json`

### Experiment B: TaskCompleted Latency
- **Result: NOT_MEASURABLE.** Gated out — no trigger path classified as FIRES from Experiment A.

### Experiment C: Two-Phase Reflective v2
- **Result: DENIED (VERIFIED, p=0.000183).** V2 overturns V1 finding (+0.2) with decisive evidence.
- Current code-reviewer: mean score 5.95, mean FP 0.05, recall 1.00 (6/6)
- Two-Phase: mean score 5.25, mean FP 0.75, recall 1.00 (6/6)
- Both achieve perfect bug detection. Two-Phase produces 15x more false positives.
- Bootstrap CI on delta [-0.9, -0.5] firmly excludes zero.
- 20/20 paired cycles, 0 parse failures, 0 retries.
- **Data:** `tests/verification/two-phase-reflective-v2-results.csv`, `two-phase-reflective-v2-summary.json`

---

## 8b. V4 Mixed-Model Review Experiment (Executed 2026-03-07)

90 total sessions (15 paired cycles x 3 reviewers x 2 conditions).

### Experiment: Mixed-Model vs Uniform Review (#46)
- **Result: INCONCLUSIVE.** Mixed-model (1xOpus + 2xSonnet) shows no measurable advantage over uniform (3xSonnet) on V3 fixture suite. Ceiling effect: both conditions achieve near-perfect scores.
- **Design:** 15 paired cycles, 3 reviewers per condition, same generalist prompt, same 12-bug + 16-decoy fixture from V3. Only variable: model selection (uniform=3xSonnet, mixed=1xOpus+2xSonnet). Score = union recall from per-area JSON.
- Uniform: mean score 11.93, recall 1.00, FP 0.07 (1 false positive in 1/15 cycles)
- Mixed: mean score 12.00, recall 1.00, FP 0.00 (zero false positives)
- Mean delta: +0.067 (mixed higher), Bootstrap 95% CI [0.0, 0.2]
- Wilcoxon: insufficient sample size (only 1 non-zero pair of 15), p=NaN
- Unique finds by Opus (bugs found by Opus but not by either Sonnet): 0 across all 15 cycles
- **Cost:** Mixed costs 133% more (7.0 vs 3.0 cost units, where 1 unit = 1 Sonnet session; Opus = 5x Sonnet)
- **Root cause:** Fixture suite ceiling effect. Both Sonnet and Opus achieve 12/12 recall on this fixture set. The V3 fixtures were designed for single-reviewer discrimination (generalist vs specialist), not multi-reviewer model discrimination. A harder fixture suite with bugs that Sonnet misses but Opus catches would be needed to detect a mixed-model advantage, if one exists.
- **Conclusion:** Do NOT adopt mixed-model review. Current uniform Sonnet review achieves perfect recall at 57% lower cost. Mixed-model remains theoretically motivated (SYMPHONY, arXiv 2601.22623) but unproven on this fixture suite. Revisit only with harder fixtures where Sonnet has recall <1.0.
- **Data:** `tests/verification/mixed-model-v4-results.csv`, `mixed-model-v4-aggregate.csv`, `mixed-model-v4-summary.json`

---

## 9. Version History

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
| 4.1 | 2026-02-07 | Research-verified top 4. Removed semaphore + retry. 47 items. |
| 4.2 | 2026-02-07 | Research-verified top 10 via 5 parallel Opus agents. Removed 3 items. Corrected 7 items. Added Section 3.4: Hooks API. 44 active. |
| 4.3 | 2026-02-07 | Agent teams research + stable-only pivot. ~7x cost discovered. 2 items removed. 45 active. |
| 5.0 | 2026-02-07 | Full re-ranking via 5 Opus agents. Critical discovery: Issue #21460 (PreToolUse/PostToolUse don't fire for subagents). Major priority reshuffling. 44 active. |
| 5.1 | 2026-02-07 | Empirical verification: #42 frontmatter hooks CONFIRMED, #5 TaskCompleted INCONCLUSIVE, #1 Two-Phase PARTIAL. |
| 5.2 | 2026-02-08 | V2 experiment scripts ready. Three experiments designed to resolve v1 inconclusive outcomes. |
| 5.3 | 2026-02-08 | V2 experiments executed (62 sessions). #1 Two-Phase DENIED (p=0.000183). #5 TaskCompleted headless confirmed non-functional. 43 active. |
| 5.4 | 2026-02-08 | Post-experiment cleanup. Fixed 3 stale Section 7 Two-Phase references. #46 promoted P3.1→P2.1. Section 1 count 44→43. |
| 5.5 | 2026-02-08 | Document split: action roadmap (153 lines) + research archive (this file). Zero content lost. Redundancy eliminated. |
| 5.6 | 2026-02-08 | Roadmap structural cleanup: removed Order column, renamed Effort→Type, split Non-Negotiables into Design Principles + Differentiators, split Key Constraints into Verified Facts + Open Blockers, split P8 into Future + Icebox, added Status column to P5/P6, added topic labels to Removed Items, moved #45 checklist to archive, verb-first What descriptions. |
| 6.3 | 2026-02-08 | #25 linter guards DONE. PostToolUse hooks for shellcheck (.sh) + jq (.json). Main thread + subagent coverage. 37 active items. |
| 5.7 | 2026-02-08 | Second structural pass: merged P3+P4 into "Formalization & State", inlined blockers (dropped Status column), added Goal column (Q/P/C/DX), added dependency notes (after #N), added "Next up" pointer, added stable-ID explanation, added Icebox purpose statement, split Differentiators into Shipped/Planned, removed non-principle from Design Principles, added Completed convention to Removed Items, restored #45 scope to What description. |
| 6.10 | 2026-03-06 | arXiv research survey: ~90 papers across 9 categories. 55 most relevant documented in Section 10. |
| 6.11 | 2026-03-06 | Deep-read 10 highest-priority papers. Major corrections: +80.8% was cherry-picked (aggregate -3.5%), "developer > LLM-generated" misattributed (source is 2602.11988 not 2601.20404), 78% iterative repair was fine-tuning not iteration, ConceptRM is training-time not runtime. Key new findings: Baseline Paradox (>45% single-agent → multi-agent hurts), agent-written tests = 0 net gain, fine-tuned models degrade with heavy iteration. 3 claims retracted, 5 downgraded, 2 confirmed. |
| 6.12 | 2026-03-06 | Deep-read 2602.11988 (ICML, ETH Zurich): confirmed source of "developer > LLM-generated" claim. 4 agents, human +4%, LLM -2%. Single runs, no stats. Retracted claim upgraded to "directionally supported but weak." Retry caps audited: already at 2-3 (optimal per research). |
| 6.13 | 2026-03-07 | V4 mixed-model experiment INCONCLUSIVE. 90 sessions, 15 paired cycles. Ceiling effect: both uniform (3xSonnet) and mixed (1xOpus+2xSonnet) achieve 12/12 recall. Mixed costs 133% more with no measurable benefit. Added Section 8b. |

---

## 10. arXiv Research Papers (Surveyed 2026-03-06)

Comprehensive survey via 5 parallel research agents. ~90 unique papers found; those most relevant to superpowers-bd workflows documented below.

### 10.1 Multi-Agent Orchestration & Parallel Execution

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2512.08296](https://arxiv.org/abs/2512.08296) | Towards a Science of Scaling Agent Systems | **DEEP-READ.** 180 configs, 4 benchmarks (non-coding), 3 LLM families. +80.8% is ONE benchmark (Finance-Agent); aggregate across all 4 is **-3.5%**. Error amplification (Independent 17.2x vs Centralized 4.4x) is real ranking but p=0.441 (not significant). **Baseline Paradox: when single-agent accuracy >45%, more agents yield NEGATIVE returns (p<0.001).** Hard scaling wall at 3-4 agents. No coding benchmarks tested. | Wave cap of 3 is empirically validated. Centralized orchestration is directionally right. But SDD should be reserved for genuinely complex tasks — simple tasks are better solved by a single agent. |
| [2602.16873](https://arxiv.org/abs/2602.16873) | AdaptOrch: Task-Adaptive Multi-Agent Orchestration | DAG-based topology selection (parallel/sequential/hierarchical/hybrid) gives 12-23% improvement over static topologies. | SDD could adapt topology per-wave rather than always using parallel. |
| [2411.03519](https://arxiv.org/abs/2411.03519) | AI Metropolis: Out-of-Order Execution | 1.3x-4.15x speedups by tracking real dependencies and eliminating false ones. | Some SDD waves may be over-serialized; false dependency elimination could unlock more parallelism. |
| [2505.19591](https://arxiv.org/abs/2505.19591) | Multi-Agent Collaboration via Evolving Orchestration | Centralized "puppeteer" dynamically directs agents based on evolving task states. | Validates lead-agent model; the "evolving" aspect could inform dynamic wave replanning. |
| [2601.10560](https://arxiv.org/abs/2601.10560) | Learning Latency-Aware Orchestration | Treats inference latency as first-class optimization objective via Critical Execution Path. | Formalizes the wave-cap tradeoff (currently 3, max 10). |
| [2602.06511](https://arxiv.org/abs/2602.06511) | EvoMAS: Evolutionary Multi-Agent Systems | 8 parallel workers achieve 63.8% on SWE-Bench-Verified. | Higher parallelism than current wave cap of 3; worth testing. |
| [2507.08944](https://arxiv.org/abs/2507.08944) | Optimizing Sequential Tasks with Parallel LLM Agents | Launch multiple solving plans in parallel, take fastest. | "Speculative execution" pattern — alternative implementations raced in parallel. |

### 10.2 Context Engineering & Skill Systems

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2602.20478](https://arxiv.org/abs/2602.20478) | Codified Context: Infrastructure for AI Agents | **DEEP-READ.** N=1 case study, single developer, 70 days, 283 sessions, 108K-line C# system. 19 agents, 660-line constitution (always loaded), 34 on-demand spec docs via MCP. No controls, no quantitative effectiveness metrics. Purely observational. Spec staleness is #1 failure mode. 24.2% infrastructure-to-code ratio. | Describes architecture similar to ours (not "validates" — no causal evidence). Useful calibration: 660-line constitution, 1-2hr/week maintenance, trigger tables for agent routing. Staleness detection is an actionable pattern we lack. |
| [2602.08004](https://arxiv.org/abs/2602.08004) | Agent Skills: Data-Driven Analysis of Claude Skills | **DEEP-READ.** 40,285 skills from skills.sh (Feb 2026). SE = 54.7% of corpus. 46.3% name-level redundancy. Median skill: 1,414 tokens. Safety: 54% L0 (safe), 30% L2 (state-changing), 9% L3 (critical). SE has highest L3 at 14%. Web Search has 5x highest demand-to-supply ratio. No quality/effectiveness metrics — measurement study only. LLM-based taxonomy (no human validation). | Our skills are in the dominant but oversaturated category — quality gates are the differentiator. Stay within token budgets (median 1,414, 95th pctile 5,077). Safety classification (L2-L3) is relevant for our file-writing/command-running workflows. |
| [2601.20404](https://arxiv.org/abs/2601.20404) | Impact of AGENTS.md Files on AI Coding Agent Efficiency | **DEEP-READ.** Tests ONE agent (Codex) on 10 repos / 124 PRs (<100 lines). With-AGENTS.md vs without: -29% wall-clock time, -17% output tokens (significant). Input tokens +3.4% (context adds to prompt). **Does NOT compare developer-provided vs LLM-generated.** No correctness evaluation (40% sanity check only). Benefits concentrated in outliers. | Context files reduce exploration overhead (~29% time savings). Our skills/CLAUDE.md serve this function. But "developer > LLM-generated" is NOT supported by this paper — that claim was wrong. |
| [2602.11988](https://arxiv.org/abs/2602.11988) | Evaluating AGENTS.md for Coding Agents | **DEEP-READ.** ICML, ETH Zurich. 4 agents (Sonnet-4.5, GPT-5.2, GPT-5.1-mini, Qwen3-30b) on AGENTbench (138 instances, 12 Python repos) + SWE-bench Lite (300 tasks). Human context: +4% resolution. LLM-generated: -2% (hurts — redundant with existing docs, adds overhead). Human vs LLM: ~+6%. **Single run per config, no statistical tests.** Python-only. LLM context helps (+2.7%) when docs are stripped, confirming redundancy mechanism. Human context provides tacit knowledge not captured in docs. | Directionally supports hand-authored skills > auto-generated. Mechanism: tacit knowledge. But weak evidence (single runs, small effects, no stats). Our skills contain workflow knowledge not in any repo docs — exactly the "tacit" category that helps. |
| [2509.14744](https://arxiv.org/abs/2509.14744) | On the Use of Agentic Coding Manifests — Claude.md | Studies CLAUDE.md as a manifest format, analyzing how developers structure instructions. | Directly studies our exact format. |
| [2511.09268](https://arxiv.org/abs/2511.09268) | Decoding Configuration of AI Coding Agents | Analysis of Claude Code project configurations in practice. | Empirical data on real-world plugin/skill configs. |
| [2510.21413](https://arxiv.org/abs/2510.21413) | Context Engineering for AI Agents in OSS | Context engineering as a distinct discipline from prompt engineering. | Skills are context engineering — structuring what the agent knows and when. |

### 10.3 Code Review & False Positive Reduction

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2602.20166](https://arxiv.org/abs/2602.20166) | ConceptRM: Mitigating Alert Fatigue | **DEEP-READ.** Trains reflection model (Qwen-30B) on 74,876 samples to filter FP from code review. 75.51% FPR reduction is best-case (GitHub out-of-domain); inner test: 62.6%. **Costs ~40% recall drop** (IR: 78%→42% on GitHub). No statistical significance tests. Single base model. NOT a multi-agent runtime system — it's a training-time data cleaning technique using model consensus. Self-reflection confirmed to fail single-turn. | Confirms external review > self-reflection (aligns with V2 Exp C). Strict consensus beats majority vote for precision. But the FP/recall tradeoff is steep. PIE metric (IR/FPR) is useful. 100 curated examples capture most calibration value. |
| [2510.01499](https://arxiv.org/abs/2510.01499) | Beyond Majority Voting: Higher-Order Aggregation | **DEEP-READ.** ISP provably dominates MV (Theorem 2). Simulated: +5.35pp at K=2. **Real-world gains are marginal: +0.54pp to +1.45pp absolute** across UltraFeedback/MMLU/ARMMAN. OW (needs ground truth) beats ISP in 73% of cases. Gains concentrate on disagreement subsets (+2.8-3.4pp). Conditional independence assumption violated by LLMs. | Getting multi-review working AT ALL matters far more than aggregation method (0.5-1.5pp difference). Binary decisions (our flag/no-flag) are the best case for these methods. Use diverse reviewers (different prompts/models), not identical replicas. |
| [2510.04048](https://arxiv.org/abs/2510.04048) | Increasing Trustworthiness Using Voting Ensembles | Variable threshold ensembles that abstain when confidence is low. | Abstain when reviewers disagree → reduces FP. Pattern for multi-review aggregation. |
| [2402.02172](https://arxiv.org/abs/2402.02172) | CodeAgent: Autonomous Communicative Agents for Code Review | Multi-agent review with QA-Checker agent. +3-7pp vulnerability detection, +30% code revision vs single-agent. | Validates multi-agent review with role specialization. |
| [2512.20845](https://arxiv.org/abs/2512.20845) | MAR: Multi-Agent Reflexion | Multiple critics generate richer reflections than single-agent self-critique. | Explains why Two-Phase Reflective (single-agent) underperformed in V2 Experiment C. |
| [2602.16741](https://arxiv.org/abs/2602.16741) | Adversarial Comments vs AI Security Reviewers | Adversarial comments have non-significant effect (p>0.21). Commercial models maintain 89-96% detection. | LLM reviewers are robust to manipulation. Reassuring for our pipeline. |
| [2601.22952](https://arxiv.org/abs/2601.22952) | Sifting the Noise: FP Filtering with LLM Agents | Reduces initial FP rate from 92% to 6%. Stronger models benefit more from agentic scaffolding. | Agent-based FP filtering works but model quality matters significantly. |
| [2601.19494](https://arxiv.org/abs/2601.19494) | AACR-Bench: Repository-Level Code Review | Multilingual benchmark; context granularity and retrieval method significantly impact performance. | Repository-level context is important for meaningful review. |
| [2602.13377](https://arxiv.org/abs/2602.13377) | Survey of Code Review Benchmarks (Pre-LLM and LLM Era) | 99 papers spanning 2015-2025. | Comprehensive reference for review evaluation methodology. |

### 10.4 Planning & Reasoning

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2601.22311](https://arxiv.org/abs/2601.22311) | Why Reasoning Fails to Plan | **DEEP-READ.** Tests LLaMA 8B/70B, GPT-4o on 3 KGQA datasets + ALFWorld. Greedy reasoning hits myopic traps 55.6% of the time, recovery only 5.4%. Their solution (Flare/MCTS-style replanning) is receding-horizon, NOT task decomposition. **Scope: deterministic, fully-observed environments only.** No coding benchmarks. No statistical significance tests. | Indirectly supports wave decomposition — receding-horizon replanning (commit to this wave, replan for next) is validated. But the paper doesn't study decomposition per se. Use directional insight, not exact numbers. |
| [2601.22623](https://arxiv.org/abs/2601.22623) | SYMPHONY: Multi-agent Planning with Heterogeneous Models | Diversity-aware search with multiple LMs outperforms single-model on code generation. | Aligns with mixed-model review experiment (v4 plan). |
| [2511.08475](https://arxiv.org/abs/2511.08475) | Designing Multi-Agent Systems for SE Tasks | Single-Path Plan Generator reduces coordination ambiguity. | Validates plan-first approach (brainstorming → writing-plans → plan2beads). |

### 10.5 TDD, Debugging & Iterative Repair

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2505.02931](https://arxiv.org/abs/2505.02931) | The Art of Repair: Optimizing Iterative Program Repair | **DEEP-READ.** Tests 3 small models (7-8B) on Java only. The 78% figure is about **fine-tuning gains, NOT iteration**. Base models gain up to 164% from iteration, but **fine-tuned/instruction-tuned models LOSE 35% with heavy iteration** (>5 rounds). Optimal: 2-3 iterations for capable models. 96% of plausible patches confirmed correct (manual review of 3,298). | Caution: our frontier models are instruction-tuned. Heavy "retry until green" loops would likely degrade quality. 2-3 iterations is the sweet spot. Single-shot implementer + external review is well-calibrated. |
| [2602.07900](https://arxiv.org/abs/2602.07900) | Rethinking Agent-Generated Tests | **DEEP-READ.** 6 frontier models on SWE-bench Verified (500 instances). GPT-5.2 writes tests on 0.6% of tasks, resolves 71.8%. Claude-opus-4.5 tests 83% of tasks, resolves 74.4%. **Causal intervention: forcing GPT-5.2 to write tests = exactly 0 net improvement** (27 gained, 27 lost). Suppressing tests in heavy-testers saves 33-49% tokens with only 1.8-2.6% resolution drop. 83.2% of tasks unchanged by intervention. Agents use prints 3-10x more than assertions. | Do NOT mandate test-writing in SDD implementers. Tests function as "learned habits" not verification. External review (code-reviewer, epic-verifier) is the right quality mechanism. Consider test suppression for token-constrained late waves. |
| [2404.17153](https://arxiv.org/abs/2404.17153) | FixAgent: Rubber Duck Debugging via Multi-Agent Synergy | LLMs explain code in NL to find logic bugs. Fixes 79/80 QuixBugs (9 never fixed before). | Could formalize "explain the code" step in systematic-debugging. |
| [2512.06749](https://arxiv.org/abs/2512.06749) | DoVer: Intervention-Driven Auto Debugging | Hypothesis-driven debugging: targeted edits + rerun + observe. | Directly implements the hypothesis-validation approach systematic-debugging should formalize. |
| [2403.16362](https://arxiv.org/abs/2403.16362) | AgentFL: Scaling Fault Localization | Comprehend-navigate-confirm phases. 157/395 bugs at Top-1 on Defects4J. | Three-phase approach maps to systematic-debugging's phased structure. |
| [2412.03905](https://arxiv.org/abs/2412.03905) | DEVLoRe: Integrating Software Artifacts for Bug Localization | Issue descriptions best for method-level; stack traces for line-level localization. | Two-stage narrowing approach for systematic-debugging context gathering. |
| [2510.23761](https://arxiv.org/abs/2510.23761) | TDFlow: Agentic Workflows for Test Driven Development | Sub-agent decomposition for TDD. Frames repo-scale SE as test-resolution. | Validates TDD skill's approach; propose/revise/debug mirrors RED-GREEN-REFACTOR. |
| [2510.18270](https://arxiv.org/abs/2510.18270) | Impact of Regression Tests on SWE Issue Resolution | Evaluates how existing test suites impact agent debugging performance. | Informs systematic-debugging's "gather context" phase. |
| [2409.13642](https://arxiv.org/abs/2409.13642) | LLM4FL: Graph-Based Fault Localization with Reflexion | Graph-based code navigation + reflexion-based re-ranking of buggy methods. | Could improve "narrow scope" phase of systematic-debugging. |

### 10.6 Benchmarks & Evaluation

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2505.20411](https://arxiv.org/abs/2505.20411) | SWE-rebench: Decontaminated Evaluation | 3x inflation on SWE-Bench-Verified vs decontaminated sets. 6x better at finding edited files. | SWE-bench scores should be treated skeptically. |
| [2512.10218](https://arxiv.org/abs/2512.10218) | Does SWE-Bench Test Ability or Memory? | Performance likely reflects training recall, not genuine skill. | Confirms contamination concerns. |
| [2602.10975](https://arxiv.org/abs/2602.10975) | FeatureBench: Benchmarking Feature Development | Claude Opus 4.5: only 11% on realistic feature tasks. | Feature development remains extremely hard — validates need for multi-agent orchestration. |
| [2509.16941](https://arxiv.org/abs/2509.16941) | SWE-Bench Pro: Long-Horizon Tasks | Best model (GPT-5): only 23.3%. Tasks require hours-to-days of engineer effort. | Long-horizon tasks are exactly what SDD's wave decomposition targets. |
| [2505.09027](https://arxiv.org/abs/2505.09027) | Tests as Prompt: TDD Benchmark | Test cases serve as both prompt and verification for code generation. | Directly relevant to TDD skill — tests as specification. |

### 10.7 Adoption & Professional Practice

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2512.14012](https://arxiv.org/abs/2512.14012) | Professional Developers Don't Vibe, They Control | Professional developers prefer controlling agent behavior, maintaining oversight and verification loops. | Skills ARE the control mechanism. Validates quality-gate approach. |
| [2601.18341](https://arxiv.org/abs/2601.18341) | Adoption of Coding Agents on GitHub | 15.85-22.60% adoption among 129,134 projects. Rapidly increasing. | Agent output quality increasingly consequential at scale. |
| [2601.16392](https://arxiv.org/abs/2601.16392) | Toward Agentic Software Project Management | Vision for AI agents managing full project lifecycle. | Aligns with beads + SDD vision of agentic project management beyond code generation. |

### 10.8 Cross-Wave Learning (New Research Direction)

| arXiv ID | Title | Key Finding | Relevance |
|-----------|-------|-------------|-----------|
| [2505.23946](https://arxiv.org/abs/2505.23946) | Lessons Learned: Multi-Agent Framework for Improvement | **DEEP-READ.** NeurIPS 2025. 3 small open-source models (7-14B) on function-level C/C++ optimization + Python generation. 3 agents + lesson bank with effectiveness tracking. Beats GPT-4o by 25% on code optimization. **BUT ablation shows "no lessons" gets 2.05x vs full LessonL 2.16x on serial tasks** — most gain is from multi-agent diversity (best-of-N), not lesson transfer. Biggest agent jump: 1→3 (1.60x→2.12x), diminishing after. Function-level only, not repo-level. | Cross-wave lesson banking is worth exploring but the mechanism may matter less than multi-agent diversity. Our wave cap of 3 captures the biggest diversity jump. Negative lessons ("don't do X") as guardrails are immediately useful. Effectiveness decay factor prevents stale advice accumulation. |
| [2512.07921](https://arxiv.org/abs/2512.07921) | DeepCode: Open Agentic Coding | Information-flow management under finite context budgets. Outperforms Cursor, Claude Code on PaperBench. | "Finite context budget" directly relevant to SDD's wave cap (context consumption constraint). |

### 10.9 Surveys (Reference)

| arXiv ID | Title | Scope |
|-----------|-------|-------|
| [2508.11126](https://arxiv.org/abs/2508.11126) | AI Agentic Programming: Survey | 152 references. Planning, tool interaction, self-correction, structured prompting. |
| [2508.00083](https://arxiv.org/abs/2508.00083) | Survey on Code Generation with LLM Agents | 5 development models: Unconstrained, Conversational, Planning-Driven, Test-Driven, Context-Enhanced. |
| [2404.04834](https://arxiv.org/abs/2404.04834) | LLM Multi-Agent Systems for SE: Literature Review | Role-Based Cooperation most common. Cross-examination improves robustness. |
| [2510.09721](https://arxiv.org/abs/2510.09721) | Benchmarks & Solutions in SE of Agentic Systems | Evolution from rule-based to autonomous. Prompt-based, fine-tuning, agent-based paradigms. |
| [2511.00872](https://arxiv.org/abs/2511.00872) | Empirical Evaluation of Agent Frameworks | 180 configs across 5 architectures (Single, Independent, Centralized, Decentralized, Hybrid). |

### Key Takeaways (Updated After Deep-Reading 10 Papers)

**Confidence tiers:** HIGH = deep-read with methodology review. MEDIUM = abstract-level only. Claims marked with caveats.

1. **Wave cap of 3 is empirically validated from two independent sources.** Scaling paper (2512.08296, HIGH): hard wall at 3-4 agents. Lessons paper (2505.23946, HIGH): biggest jump 1→3, diminishing after. Both non-coding benchmarks, but directionally strong.
2. **Baseline Paradox is the most important finding:** When single-agent accuracy >45%, adding more agents yields NEGATIVE returns (2512.08296, p<0.001). SDD should be reserved for genuinely complex, decomposable epics — not all tasks.
3. **More process ≠ better outcomes for capable models.** Agent-written tests: 0 net improvement (2602.07900, HIGH). Heavy iteration: -35% for fine-tuned models (2505.02931, HIGH, but 7-8B models only). Our single-shot implementer + external review is well-calibrated.
4. **Multi-review: just get N>1 working, don't optimize the aggregation function.** Higher-order methods add only 0.5-1.5pp over majority voting (2510.01499, HIGH). Use diverse reviewers — different prompts/models matter more than the voting algorithm.
5. **External review > self-reflection** confirmed by ConceptRM (2602.20166, HIGH) and our V2 Experiment C. Self-reflection fails single-turn. Our dedicated code-reviewer architecture is correct.
6. **Context files reduce execution time ~29%** (2601.20404, HIGH, but Codex only). Mechanism: reduced exploration overhead. Our skills/CLAUDE.md serve this function.
7. **Wave decomposition is indirectly supported** by planning research (2601.22311, HIGH, but non-coding scope). Greedy reasoning traps at 55.6%, recovery 5.4%. Receding-horizon replanning (our wave pattern) is the validated alternative.
8. **Cross-wave learning has modest potential.** Lesson transfer adds ~0.11x on top of multi-agent diversity (2505.23946, HIGH). Most gain comes from best-of-N selection. Negative lessons as guardrails are the highest-value application.
9. **Codified context architecture is described (not validated) at scale** (2602.20478, N=1 case study). Spec staleness is the #1 failure mode. 660-line constitution is a useful calibration point.
10. **SWE-bench contamination is severe** (3x-6x inflation, MEDIUM — not deep-read). Feature-level benchmarks show 11-23% solve rates for realistic tasks.

**Retracted claims:**
- ~~"Developer-provided > LLM-generated for all 4 agents"~~ — Misattributed to 2601.20404 (tests 1 agent, doesn't compare). Actual source: 2602.11988 (ICML, 4 agents). Human +4%, LLM -2%. Directionally correct but single runs, no statistical tests.
- ~~"+80.8% centralized orchestration"~~ — cherry-picked from 1 of 4 benchmarks. Aggregate is -3.5%.
- ~~"78% more patches from iterative repair"~~ — that's fine-tuning gains, not iteration. Fine-tuned models lose 35% with heavy iteration.

---

*This archive synthesizes findings from: superpowers-bd, superpowers (original), get-shit-done, gastown (575 commits), loom, claude-flow, SWE-agent/mini-swe-agent, Dolt backend analysis, Opus 4.6 release analysis, Claude Code 2.1.33+ changelog analysis, empirical beads v0.49.4 concurrency testing, Claude Code hooks API verification (Issues #16126, #7881, #21460, #6305, #18950, #20946, #14859), pre-commit.com compatibility testing, Claude Code agent teams docs, Anthropic C compiler engineering blog, Cursor worktree isolation docs, official Claude Code skills/sub-agents/hooks documentation, V2 verification experiments (62 sessions), and arXiv research survey (2026-03-06, ~90 papers across multi-agent orchestration, code review, TDD/debugging, context engineering, planning/reasoning, benchmarks, and adoption).*
