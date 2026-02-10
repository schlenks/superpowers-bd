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
Proactive conflict prevention. `PreToolUse` hook on `Edit|Write` checks wave file map and blocks edits to files owned by other agents. **BLOCKED on TWO issues:** (1) `$AGENT_NAME` does not exist for regular subagents ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126)), (2) PreToolUse hooks do not fire for subagent tool calls ([Issue #21460](https://github.com/anthropics/claude-code/issues/21460)). Six related hook enforcement issues span Aug 2025–Jan 2026 with zero Anthropic resolution. Primary approach is now prompt-based (#15), validated by Anthropic's C compiler project at production scale. Hook enforcement is a future defense-in-depth layer. Moved to P5. Source: Hook-based.

**#4 — Strict SSOT: Query, Don't Track**
Prevents state drift bugs. Instead of caching task state in skills, always query beads for truth. The SDD skill already follows this pattern (queries `bd ready` at every loop iteration). This is a design principle to codify, not a code change. "Skills MUST NOT cache beads query results across wave boundaries." Source: Distributed systems SSOT principle.

**#5 — TaskCompleted hook for quality gates**
Hard enforcement at task completion. `TaskCompleted` hook exits with code 2 to block task completion if quality criteria not met. Can use `type: "agent"` for 50-turn code analysis hooks. The only hard enforcement mechanism that works for subagents. GA since v2.1.33. V2 Experiment A (2026-02-08): Headless `claude -p` mode: TaskCompleted NEVER fired (0/10). Manual verification (2026-02-08): Interactive `claude` mode: TaskCompleted FIRES. Conclusion: Interactive mode only. Source: Native hooks.

**#6 — Strengthen existing simplification checks + linter hooks**
Reduces code complexity. Qualitative review already covered by 5+ existing skills. Do NOT create a new skill. Instead: (a) add quantitative checklist items to existing code-reviewer.md, (b) implement cyclomatic complexity enforcement via PostToolUse linter hooks (#25). Thresholds: flag >10, block >15 (matches McCabe/NIST). Source: Industry standard.

### MEDIUM IMPACT

**#7** — Checkpoint classification: Binary `requires_human: true/false` flag on plan steps. Simplified from three-way taxonomy. Source: Inspired by get-shit-done.

**#8** — Parallelize review pipelines: Reviews for different tasks run concurrently. Throughput parallelism, distinct from multi-review aggregation (#46). Source: Original research.

**#9** — Parallel bd queries: 6x speedup via goroutines with pre-allocated result slice. 32s → 5s inbox load in Gastown. Source: Gastown §3.5.

**#10** — Structured agent IDs: Validates task/bead IDs with parsing. Format: `<prefix>-<role>` or `<prefix>-<rig>-<role>-<name>`. Source: Gastown §2.1.

**#11** — --fast mode for status: 60% faster status checks. Skip non-essential operations. 5s → 2s. Source: Gastown §3.1.

**#12** — Template rendering for prompts: Consistent output formatting. Type-safe data injection. Source: Gastown §4.3.

**#13** — Health checks (doctor): Check for orphaned worktrees, prefix mismatches, stale agent beads, slow operations. Auto-fix common issues. Source: Gastown §2.2.

**#14** — Completion evidence requirements: Tasks can only close with proof (commit hash, files changed, test results, coverage delta). `TaskCompleted` hook verifies before accepting. Source: Native hooks.

**#15** — File ownership declared in task definition: Conflicts computed at dispatch time. Each task declares owned files in description. Orchestrator serializes `{wave_file_map}` table into each implementer prompt showing all agents' file assignments. No file I/O — eliminates permission prompts and cleanup. Absorbs #2. Prompt-based enforcement validated by [Anthropic's C compiler project](https://www.anthropic.com/engineering/building-c-compiler) at production scale. Source: Hook-based + Anthropic engineering.

**#16** — Artifact-specific rule-of-five variants: Code: Draft→Correctness→Clarity→Edge Cases→Excellence. Plans: Draft→Feasibility→Completeness→Risk→Optimality. Tests: Draft→Coverage→Independence→Speed→Maintainability. Source: Original research.

### LOWER IMPACT

**#17** — DAG visualization: Tree view with status icons, tier view for parallel opportunities, critical path analysis. Source: Gastown §1.3.

**#18** — Complexity scoring: 0-1 scale with estimated duration and confidence. Enables SLA tracking. Source: claude-flow.

**#19** — Adversarial security review: Test injection, auth bypass, privilege escalation, data leakage, DoS. Source: loom.

**#20** — External verification (GPT 5.2-codex): Second opinion on critical code. Self-Agg may be as effective (SWR-Bench). Source: Original research.

**#21** — Agent-agnostic zombie detection: Read GT_AGENT env var, look up process names for Claude/Gemini/Codex/Cursor/etc. Source: Gastown §1.5.

**#22** — Memorable agent identities: Adjective+noun names (GreenCastle, BlueLake). 4,278 unique combinations. Source: Research.

**#23** — Git-backed context audit trail: `.context/` directory with JSON files, git commits on each update, SQLite index for queries. Source: Research.

**#24** — Pre-planning file conflict analysis: Compute waves during planning, not runtime. Pre-compute optimal groupings, surface in plan header. Source: Gastown + original research.

### FROM SWE-AGENT RESEARCH

**#25** — Linter guards on all edits: Run linter after edit (PostToolUse hook), surface error to Claude, prompt retry. SWE-agent ablation: 3pp improvement (15.0% → 18.0%). Frontmatter hooks verified working for subagents (2026-02-07). **DONE (2026-02-08):** `hooks/run-linter.sh` runs shellcheck (.sh) and jq (.json) after Write/Edit. Main thread coverage via `hooks/hooks.json` PostToolUse. Subagent coverage via `agents/code-reviewer.md` frontmatter hook chain. Graceful degradation if tools not installed. 8/8 unit tests pass. Source: SWE-agent ACI.

**#26** — Succinct search results (max 50): Prevents context overflow in subagents. Source: SWE-agent ACI.

**#27** — Integrated edit feedback: Show file diff immediately after edit. Source: SWE-agent ACI.

**#28** — 100-line file chunks: Mostly redundant — Claude Code's Read tool supports `offset`/`limit` natively. Demoted to P8. Source: SWE-agent ACI.

### FROM GASTOWN

**#30** — Atomic spawn (NewSessionWithCommand): Eliminates race conditions in subagent spawning. Source: Gastown §15.

**#31** — Validation tests for hook/skill configs: Prevents silent failures from misconfigured skills. Source: Gastown §11.

**#32** — Batch lookups with SessionSet pattern: O(1) repeated queries instead of N+1 subprocess calls. Source: Gastown §3.4.

### OPUS 4.6 & CLAUDE CODE 2.1.33+

**#33** — 1M context: BETA ONLY. Monitor for GA release. Source: Opus 4.6.

**#34** — 128K output: Available now. Full plans and reviews in single response. Source: Opus 4.6.

**#35** — Native agent teams: DEFERRED. ~7x token cost impractical for Max subscribers. Enable via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Source: Opus 4.6.

**#36** — Map task type to effort level: Claude Code's Task tool doesn't expose `output_config.effort` yet. Source: Opus 4.6 adaptive thinking.

**#37** — Exploit ARC AGI 2 leap: Route complex problems to Opus 4.6 (68.8% ARC vs 37.6% before). Available now. Source: Opus 4.6 benchmarks.

**#38** — `memory` frontmatter: Persistent agent memory. Scopes: `user`, `project`, `local`. Source: Claude Code v2.1.33.

**#39** — TeammateIdle/TaskCompleted: SPLIT. TaskCompleted → P1.2 (GA, hard enforcement). TeammateIdle → P8 (agent teams only). Source: Claude Code v2.1.33.

**#40** — `Task(agent_type)` syntax: No-op for subagent architecture per [official docs](https://code.claude.com/docs/en/sub-agents). Moved to P8. Source: Claude Code v2.1.33.

**#41** — Native Task metrics: Token count, tool uses, duration in Task results. Source: Claude Code v2.1.30.

**#42** — Hooks in frontmatter: Per-agent hooks bypassing [Issue #21460](https://github.com/anthropics/claude-code/issues/21460). VERIFIED (2026-02-07, Claude Code 2.1.37): Frontmatter PostToolUse hooks DO fire for subagent tool calls via `--agents`. 3/3 runs confirmed. Foundation for #25 and #3. Source: Claude Code v2.1.33.

**#43** — --from-pr flag: Sessions auto-link to PRs. Source: Claude Code v2.1.27.

**#44** — Skill character budget scaling: 2% of context window. Source: Claude Code v2.1.32.

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

---

*This archive synthesizes findings from: superpowers-bd, superpowers (original), get-shit-done, gastown (575 commits), loom, claude-flow, SWE-agent/mini-swe-agent, Dolt backend analysis, Opus 4.6 release analysis, Claude Code 2.1.33+ changelog analysis, empirical beads v0.49.4 concurrency testing, arXiv 2508.12358 (LLM verification), arXiv 2509.01494 (SWR-Bench multi-review), Claude Code hooks API verification (Issues #16126, #7881, #21460, #6305, #18950, #20946, #14859), pre-commit.com compatibility testing, Claude Code agent teams docs, Anthropic C compiler engineering blog, Cursor worktree isolation docs, official Claude Code skills/sub-agents/hooks documentation, and V2 verification experiments (62 sessions).*
