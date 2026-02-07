# Superpowers-BD: Comprehensive Improvement Report

**Date:** February 7, 2026 (v4.3 — Experimental feature opt-in architecture, skill modernization P1.5, 47 active)
**Purpose:** Dramatically improve superpowers-bd by leveraging native Claude Code features + adding unique value (quality gates, persistence, file ownership)
**Philosophy:** If it's worth doing, do it. If Claude Code does it natively, use that instead. If beads already does it, don't rebuild it.

---

## How to Read This Document

1. **Section 1:** All **47 ACTIVE** improvements ranked by impact
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
- **Experimental feature opt-in:** Skills detect agent teams via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env var. User preferences stored in `.claude/superpowers-features.json`. Skills branch behavior: Task mode (default) vs Agent Teams mode (opt-in). Agent teams use ~7x tokens but unlock hard file ownership enforcement via `CLAUDE_CODE_AGENT_NAME`.
- **Priority reordering:** Config/hooks first → experimental opt-in + skill modernization → prompt changes → code changes.

---

## 1. All ACTIVE Improvements Ranked by Impact (44 Remaining)

### CRITICAL IMPACT — Prevents failures, enables core capabilities

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 1 | **Structured verification via Two-Phase Reflective + behavioral comparison** | Catches issues current reviews miss. Research ([arXiv 2508.12358](https://arxiv.org/html/2508.12358v1)) shows asking LLMs to explain-and-fix introduces over-correction bias (up to 89% false-positive rate for GPT-4o). The Two-Phase Reflective prompt outperforms behavioral comparison **for Claude specifically** (82.9% vs 78.0% RCRR on HumanEval). Hybrid approach: extract requirements → read code independently → compare point-by-point → check for unlisted behavior → THEN read implementer's report. **Note:** RCRR measures false-positive avoidance on correct code, not bug-catching ability. Spec reviewer already has strong skepticism; gaps are in `agents/code-reviewer.md` and `skills/requesting-code-review/code-reviewer.md`. | superpowers original + [arXiv 2508.12358](https://arxiv.org/html/2508.12358v1) |

### HIGH IMPACT — Significant quality or efficiency gains

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 2 | **Two-phase delayed dispatch** | Ensures ALL preparatory work (beads status, file-locks.json) completes before ANY subagent spawns in a wave. The SDD skill already conceptually does this (conflict verification tasks block dispatch via `addBlockedBy`). This formalizes it: add explicit `file-locks.json` generation between conflict detection and dispatch. **#3 depends on this** (lock file must exist before first subagent edit). ~30 min skill/prompt change. | Gastown §1.4 (adapted) |
| 3 | **File ownership enforcement via hooks** | Proactive conflict prevention. `PreToolUse` hook on `Edit\|Write` checks `.claude/file-locks.json` and blocks edits to files owned by other agents. **Two paths:** (a) **Agent Teams mode:** `CLAUDE_CODE_AGENT_NAME` env var IS available for team members — hook can compare agent name against lock file owner. **Implementable today with opt-in.** (b) **Task mode:** `$AGENT_NAME` does not exist for regular subagents ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126)). Use prompt-based enforcement as interim. Hook input JSON correctly provides `tool_input.file_path`. Use `permissionDecision: "deny"` pattern (not `exit 2`). Requires `jq`. | Hook-based |
| 4 | **Strict SSOT: Query, Don't Track** | Prevents state drift bugs. Instead of caching task state in skills, always query beads for truth. Reality is authoritative; derived state cannot diverge. **Note:** The SDD skill already follows this pattern (queries `bd ready` at every loop iteration). This is a **design principle to codify**, not a code change. "Skills MUST NOT cache beads query results across wave boundaries." | Distributed systems SSOT principle |
| 5 | **TaskCompleted hook for quality gates** | Hard enforcement at task completion. `TaskCompleted` hook exits with code 2 to block task completion if quality criteria not met. Genuinely enforced by Claude Code (not advisory). Can use `type: "agent"` for 50-turn code analysis hooks. **Note:** `addBlockedBy` for task sequencing is already in SDD skill and provides soft (prompt-based) enforcement only. | Native hooks |
| 6 | **Strengthen existing simplification checks + linter hooks** | Reduces code complexity. The qualitative review ("dead code? duplication? over-engineering?") is already covered by 5+ existing skills (rule-of-five Clarity pass, spec-reviewer over-engineering check, epic-verifier YAGNI, code-reviewer DRY, TDD REFACTOR phase). **Do NOT create a new skill.** Instead: (a) add quantitative checklist items to existing code-reviewer.md, (b) implement cyclomatic complexity enforcement via PostToolUse linter hooks (#25). Thresholds: flag >10, block >15 (matches McCabe/NIST). | Industry standard (SonarQube, ESLint, NIST) |

### MEDIUM IMPACT — Meaningful improvements to workflow

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 7 | **Checkpoint classification in plans** | Binary flag: `requires_human: true/false` on plan steps. Current system already batches automated work and pauses at batch boundaries. This formalizes the annotation. Original three-way taxonomy (AUTOMATED/HUMAN_DECISION/HUMAN_ACTION) is over-specified — the HUMAN_DECISION vs HUMAN_ACTION distinction rarely matters in practice. | Inspired by get-shit-done (simplified) |
| 8 | **Parallelize review pipelines** | Reviews for different tasks run concurrently. Task A and Task B reviews don't wait for each other. Only sequential: spec review before code review for same task. | Original research |
| 9 | **Parallel bd queries with indexed results** | 6x speedup on multi-query operations. Goroutines with pre-allocated result slice (no mutex needed). 32s → 5s inbox load in Gastown. | Gastown §3.5 |
| 10 | **Structured agent IDs** | Validates task/bead IDs with parsing. Format: `<prefix>-<role>` or `<prefix>-<rig>-<role>-<name>`. Prevents silent failures from malformed IDs. | Gastown §2.1 |
| 11 | **--fast mode for status commands** | 60% faster status checks. Skip non-essential operations. 5s → 2s. | Gastown §3.1 |
| 12 | **Template rendering for prompts** | Consistent output formatting. Type-safe data injection. Reduces hallucination. Single source of truth for agent prompts. | Gastown §4.3 |
| 13 | **Health checks (doctor command)** | Catches misconfigurations. Check for orphaned worktrees, prefix mismatches, stale agent beads, slow operations. Auto-fix common issues. | Gastown §2.2 |
| 14 | **Completion evidence requirements** | Tasks can only close with proof. Commit hash, files changed, test results, coverage delta. `TaskCompleted` hook verifies before accepting. | Native hooks |
| 15 | **File ownership declared in task definition** | Conflicts computed at dispatch time. Each task declares owned files in description. Orchestrator writes `.claude/file-locks.json` before spawning agents. | Hook-based |
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
| 25 | **Linter guards on all edits** | Prevents syntax errors from persisting. Run linter before accepting edit, reject + show error + retry if fail. Stops compounding errors. | SWE-agent ACI |
| 26 | **Succinct search results (max 50)** | Prevents context overflow in subagents. If >50 matches, ask to refine query. Summarize rather than dump. | SWE-agent ACI |
| 27 | **Integrated edit feedback** | Show file diff immediately after edit. Agent sees effect of action, catches mistakes faster. | SWE-agent ACI |
| 28 | **100-line file chunks** | When reading files for context, chunk to 100 lines (empirically optimal). Prevents context overflow while maintaining orientation. | SWE-agent ACI |
| 29 | **Specialized file viewer** | Build file viewer skill with scroll/search/line numbers. Better than raw cat for navigation. | SWE-agent |

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
| 35 | **Integrate native agent teams for parallel coordination** | Replace custom parallel dispatch with native TeammateTool (13 operations) for peer-to-peer messaging. **KEY UNLOCK:** Enables hard file ownership enforcement (#3) via `CLAUDE_CODE_AGENT_NAME`. Delegate mode maps to SDD orchestrator pattern. Shared task list with file locking. ~7x token cost vs subagents (official docs). **Available now (experimental).** Enable via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. | Opus 4.6 agent teams |
| 36 | **Map task type to effort level** | VERIFICATION → low effort (cheaper). IMPLEMENTATION → high effort (better quality). Use adaptive thinking API parameters (`output_config.effort`). **Note:** Claude Code's Task tool does not currently expose the effort parameter. Task type routing (prompt templates, model selection) is already implemented in SDD skill. This improvement adds effort-level control when Claude Code exposes it. | Opus 4.6 adaptive thinking |
| 37 | **Exploit ARC AGI 2 leap for novel problem-solving** | Route complex/novel problems to Opus 4.6 (68.8% ARC vs 37.6% before). Use Sonnet for routine tasks. **Available now.** | Opus 4.6 benchmarks |

### Claude Code 2.1.33+ Features (Feb 6, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 38 | **Use `memory` frontmatter for persistent agent context** | Agents have persistent memory surviving across conversations. Scopes: `user`, `project`, `local`. Builds knowledge over time. | Claude Code v2.1.33 |
| 39 | **Hook into TeammateIdle and TaskCompleted events** | Native hook events for multi-agent coordination. Event-driven, replaces polling-based detection. | Claude Code v2.1.33 |
| 40 | **Restrict sub-agent spawning via `Task(agent_type)` syntax** | Control which sub-agents can be spawned from `tools` frontmatter. Prevents infinite nesting. | Claude Code v2.1.33 |
| 41 | **Use native Task metrics for cost tracking** | Task results include token count, tool uses, duration. Native, accurate, no parsing required. | Claude Code v2.1.30 |
| 42 | **Define hooks in agent/skill frontmatter** | Hooks scoped to specific agents. Per-agent validation, cleanup on finish. Cleaner than global config. | Claude Code v2.1.33 |
| 43 | **Use --from-pr flag for PR-linked sessions** | Sessions auto-link to PRs. Resume with `--from-pr`. Better PR workflow integration. | Claude Code v2.1.27 |
| 44 | **Leverage skill character budget scaling** | Skill content budget scales at 2% of context window. More room for comprehensive skill instructions with Opus 4.6. | Claude Code v2.1.32 |

### Experimental Feature Opt-In Architecture (Feb 7, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 45 | **SessionStart feature detection + config file** | Detect experimental features at session start via env vars (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Store user preferences in `.claude/superpowers-features.json` (auto/enabled/disabled per feature). Inject detected capabilities as `additionalContext`. Skills read context and branch behavior accordingly. | v4.3 research |
| 46 | **Two-mode SDD: Task mode vs Agent Teams mode** | SDD skill operates in two modes based on user opt-in. **Task mode (default):** Current subagent dispatch via Task tool. **Agent Teams mode (opt-in):** TeammateTool for dispatch, Delegate mode for orchestrator, shared task list, peer-to-peer messaging, hard file ownership. User chooses at epic start alongside budget tier. ~7x token cost disclosed. | v4.3 research |
| 47 | **Modernize all skill/agent frontmatter** | Update all 17 skills + 2 agents with modern frontmatter: `memory: project` for persistent context, `max_turns` to prevent cost runaway, `tools` restrictions (e.g., `Task(code-reviewer)`), parameterized `model` instead of hardcoded strings. Update `writing-skills` guide (currently says "only name and description" — wrong since v2.1.33). Fix `plan2beads` missing frontmatter. | Codebase audit |

---

## 2. PRIORITIZED Implementation Order

**Strategy:** Easy wins first (config/hooks), then prompt changes, then code changes. Get value immediately.

### Priority 1: Use What's Already There (This Week — Config Only)

These features exist in Claude Code 2.1.33+. Just configure them.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **1.1** | 3 | File ownership via `PreToolUse` hook | ⚠️ Blocked on [Issue #16126](https://github.com/anthropics/claude-code/issues/16126); design hook now, use prompt-based interim |
| **1.2** | 39 | TeammateIdle/TaskCompleted hooks | Hook config |
| **1.3** | 38 | `memory: project` on agent definitions | Frontmatter line |
| **1.4** | 40 | Restrict sub-agent spawning | Frontmatter field |
| **1.5** | 41 | Native Task metrics | Already available — just use them |
| **1.6** | 42 | Hooks in agent frontmatter | Frontmatter field |

**Rationale:** Zero code required (except #3 which is blocked). Can be done in a single session. Immediate value.

**File ownership — current status (updated v4.3):**
- **Hook mechanism works:** `PreToolUse` on `Edit|Write` is real, `tool_input.file_path` is correct, `permissionDecision: "deny"` blocks edits
- **Agent Teams mode (NEW):** `CLAUDE_CODE_AGENT_NAME` IS available for team members. Hook can read this env var and compare against lock file owner. **Hard enforcement is possible today** if user opts into agent teams.
- **Task mode:** `$AGENT_NAME` does not exist for regular subagents ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126)). Use prompt-based enforcement as interim.
- **Interim approach:** Orchestrator writes `file-locks.json` before dispatch. Each subagent prompt includes: "Before editing any file, check `.claude/file-locks.json`. Only edit files where your name matches the owner."
- **When Issue #16126 ships:** Switch Task mode to hook-based enforcement with `permissionDecision: "deny"`

### Priority 1.5: Experimental Feature Opt-In + Skill Modernization (This Week)

Enable users to opt into experimental features (agent teams, delegate mode, TeammateIdle hooks) and modernize all skills/agents with current frontmatter fields.

**The opt-in architecture:**

```
SessionStart hook
  ├── Check env: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1?
  ├── Check config: .claude/superpowers-features.json
  ├── Inject detected capabilities as additionalContext
  └── Skills read context → branch behavior accordingly
```

**Config file schema** (`.claude/superpowers-features.json`):
```json
{
  "experimental": {
    "agent_teams": "auto",
    "delegate_mode": false
  }
}
```
Where `"auto"` = use if available, `"enabled"` = require, `"disabled"` = never use.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **1.5.1** | 45 | SessionStart feature detection + config file | 45 min (hook + config schema) |
| **1.5.2** | 47 | Modernize all skill/agent frontmatter | 2 hours (17 skills + 2 agents + writing-skills guide) |
| **1.5.3** | 46 | Two-mode SDD: Task mode vs Agent Teams mode | 2 hours (conditional logic + user opt-in flow) |
| **1.5.4** | 35 | Agent Teams integration (full) | 1.5 hours (file ownership hook + delegate mode + shared tasks) |

**Rationale:** This unlocks the most impactful improvement (#3 file ownership with hard enforcement) and brings all skills up to date with Claude Code 2.1.33+ capabilities. The opt-in approach means zero disruption for users who don't want experimental features.

**Two-mode SDD — how it works:**

| Aspect | Task Mode (default) | Agent Teams Mode (opt-in) |
|---|---|---|
| **Dispatch** | Task tool subagents | TeammateTool teammates |
| **File ownership** | Prompt-based (soft) | PreToolUse hook with `CLAUDE_CODE_AGENT_NAME` (hard) |
| **Agent identity** | None | NAME, ID, TYPE, COLOR env vars |
| **Communication** | Hub-and-spoke via Task results | Peer-to-peer write/broadcast |
| **Orchestrator** | Manual state machine in SDD skill | Delegate mode (coordination-only tools) |
| **Quality gates** | addBlockedBy (soft) | TaskCompleted hook + shared task list |
| **Token cost** | ~1x baseline | ~7x baseline |
| **Session resume** | Beads persistence | No teammate resumption |

**Cost disclosure requirement:** Any skill that triggers Agent Teams mode MUST inform the user of ~7x token cost BEFORE proceeding. Budget tier selection already exists in SDD — extend it with agent teams cost warning.

**Modernization checklist (P1.5.2):**
- [ ] Add `memory: project` to all agent definitions (`agents/code-reviewer.md`, `agents/epic-verifier.md`)
- [ ] Add `max_turns` to all subagent prompts (prevent cost runaway)
- [ ] Replace hardcoded `model: "opus"` / `model: "sonnet"` with budget tier variables in SDD prompts
- [ ] Add YAML frontmatter to `commands/plan2beads.md` (only command missing it)
- [ ] Update `skills/writing-skills/SKILL.md` line 98: expand from "only name and description" to full frontmatter field reference
- [ ] Add `tools` restrictions where appropriate (e.g., `Task(code-reviewer)` in SDD)

### Priority 2: Quality Gate Skills (High ROI — Prompt/Skill Changes)

Prompt engineering and skill updates. No infrastructure code needed.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **2.1** | 1 | Structured verification (Two-Phase Reflective hybrid) | Prompt rewrite for 3 files |
| **2.2** | 6 | Strengthen simplification checks in existing skills + linter hooks | Prompt additions + hook config |
| **2.3** | 5 | TaskCompleted hook for quality gates | Hook config |
| **2.4** | 14 | Completion evidence requirements | Hook + prompt |
| **2.5** | 16 | Artifact-specific rule-of-five | Skill variants |
| **2.6** | 25 | Linter guards via PostToolUse hooks | Hook config |
| **2.7** | 2 | Two-phase delayed dispatch | Skill update |

**Rationale:** Highest ROI improvements. Quality gates are superpowers-bd's unique value. #1 (structured verification) is the single most impactful change — research-backed, with 3 identified gaps across 3 files.

**Structured verification method (P2.1) — Two-Phase Reflective + behavioral comparison hybrid:**

```markdown
## Verification Method

Do NOT read the implementer's report first. Instead:

Step 1: Extract requirements from the spec. Create a numbered checklist.
Step 2: Read actual code independently. Audit each requirement against code (file:line evidence).
Step 3: Summarize unlisted behaviors not in the spec (scope creep check).
Step 4: THEN read the implementer's report. Note discrepancies between your analysis and their claims.
```

**Why this hybrid:** The Two-Phase Reflective prompt (extract requirements → audit code) outperforms pure behavioral comparison for Claude models (82.9% vs 78.0% RCRR on HumanEval, per arXiv 2508.12358). Adding step 3 (unlisted behaviors from behavioral comparison) and step 4 (delayed report reading) provides comprehensive coverage.

**Files requiring changes for #1:**
- `agents/code-reviewer.md` — add independent verification instructions, anti-framing warning (currently has ZERO skepticism)
- `skills/requesting-code-review/code-reviewer.md` — restructure to read code BEFORE implementer report; add requirement extraction step
- `skills/subagent-driven-development/spec-reviewer-prompt.md` — remove bias-inducing "suspiciously quickly"; restructure to delay report reading (already has strong skepticism otherwise)

### Priority 3: File Ownership (Full Implementation)

Builds on the P1 interim with full conflict prevention.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **3.1** | 15 | File ownership declared in task definition | Skill update |
| **3.2** | 24 | Pre-planning file conflict analysis | New skill |

**Rationale:** P1 gives us prompt-based enforcement. P3 makes it systematic — ownership at dispatch time, conflict detection during planning.

### Priority 4: Context & State (Beads Integration)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **4.1** | 4 | Strict SSOT (codify as design principle) | Documentation |
| **4.2** | 10 | Structured agent IDs | Code |

**Rationale:** SDD skill already follows SSOT pattern. #4 codifies it as a skill-writing rule to prevent regressions. Native memory handles context; beads handles task state.

### Priority 5: Execution Optimization (Performance)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **5.1** | 9 | Parallel bd queries | Go code |
| **5.2** | 32 | Batch lookups (SessionSet pattern) | Code |
| **5.3** | 11 | --fast mode for status | Code |
| **5.4** | 8 | Parallelize review pipelines | Skill update |

**Rationale:** After core system works, optimize for speed.

### Priority 6: Tooling & Polish (Refinement)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **6.1** | 13 | Health checks (doctor) | Code |
| **6.2** | 12 | Template prompts | Code |
| **6.3** | 31 | Validation tests for configs | Tests |
| **6.4** | 43 | Use --from-pr flag | Config |
| **6.5** | 34 | Use 128K output | Prompt update |
| **6.6** | 44 | Leverage skill budget scaling | Config |
| **6.7** | 35 | ~~Integrate native agent teams~~ | **MOVED to P1.5.4** — unlocks #3 file ownership |
| **6.8** | 36 | Map task type to effort level | Blocked: Task tool lacks effort param |
| **6.9** | 7 | Checkpoint classification (binary flag) | Plan format update |

### Priority 7: SWE-Agent Patterns (Agent Quality)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **7.1** | 26 | Succinct search results (max 50) | Skill update |
| **7.2** | 27 | Integrated edit feedback | Skill update |
| **7.3** | 28 | 100-line file chunks | Skill update |
| **7.4** | 29 | Specialized file viewer | New skill |

**Rationale:** Agent-Computer Interface improvements after core functionality works.

### Priority 8: Advanced & Future (Do Last)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **8.1** | 17 | DAG visualization | Code |
| **8.2** | 19 | Adversarial security review | New skill |
| **8.3** | 20 | External verification (GPT 5.2-codex) | Integration |
| **8.4** | 22 | Memorable agent identities | Code |
| **8.5** | 23 | Git-backed context audit trail | Code |
| **8.6** | 30 | Atomic spawn | Code |
| **8.7** | 21 | Agent-agnostic zombie detection | Code |
| **8.8** | 18 | Complexity scoring | Code |
| **8.9** | 37 | Exploit ARC AGI 2 leap | Prompt/routing |
| **8.10** | 33 | [FUTURE] 1M context | When beta exits |

**Rationale:** These provide value but aren't critical. Do after core system works reliably.

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

**Agent Teams (Experimental, officially supported):** Multiple agents work in parallel with peer-to-peer coordination via TeammateTool (13 operations). Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (env var or `settings.json`). ~7x token cost vs standard sessions (official docs). Teammate env vars: `CLAUDE_CODE_AGENT_NAME`, `CLAUDE_CODE_AGENT_ID`, `CLAUDE_CODE_AGENT_TYPE`, `CLAUDE_CODE_TEAM_NAME`, `CLAUDE_CODE_AGENT_COLOR`.

**superpowers-bd's unique value vs native agent teams:**

| Capability | Native Agent Teams | superpowers-bd (Task mode) | superpowers-bd (Teams mode) |
|------------|-------------------|---------------------------|----------------------------|
| Parallel execution | ✅ Built-in | ✅ Task tool + waves | ✅ TeammateTool + waves |
| Peer-to-peer messaging | ✅ TeammateTool | ❌ Hub-and-spoke | ✅ (via native) |
| Session resumption | ❌ | ✅ Beads persistence | ✅ Beads persistence |
| Quality gates | ❌ | ✅ Skills-based (soft) | ✅ Skills + TaskCompleted hook (hard) |
| File ownership | `AGENT_NAME` available | ⚠️ Prompt-based (blocked #16126) | ✅ PreToolUse hook + `CLAUDE_CODE_AGENT_NAME` |
| Git-backed state | ❌ | ✅ Beads on Dolt | ✅ Beads on Dolt |
| Token cost | ~7x baseline | ~1x baseline | ~7x baseline |
| Delegate mode | ✅ | ❌ | ✅ Maps to SDD orchestrator |

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

### 3.4 Claude Code Hooks API (Verified Feb 7, 2026)

Key findings from research on the hooks system:

**PreToolUse hooks:**
- Matcher is regex: `Edit|Write` correctly matches both tools
- Input via stdin as JSON: `tool_input.file_path` is correct for both Edit and Write
- `exit 2` blocks the tool call (older pattern)
- Preferred: return JSON with `permissionDecision: "deny"` and `permissionDecisionReason`
- ⚠️ No agent identity in hook input ([Issue #16126](https://github.com/anthropics/claude-code/issues/16126))
- ⚠️ Subagents share `session_id` with parent ([Issue #7881](https://github.com/anthropics/claude-code/issues/7881))

**TaskCompleted hooks:**
- `exit 2` blocks task completion (hard enforcement)
- Receives: `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- Can use `type: "agent"` for 50-turn code analysis before allowing completion
- Latency risk: agent-type hooks could take 60+ seconds per task

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
2. **No missed work** — TaskCompleted hook quality gates, completion evidence
3. **No conflicts** — File ownership: prompt-based (Task mode) OR hard enforcement via `CLAUDE_CODE_AGENT_NAME` (Agent Teams mode, opt-in)
4. **No state drift** — Strict SSOT principle, persistent memory, structured storage
5. **Maximum parallelism** — Two modes: Task tool subagents (cost-efficient) or Agent Teams (richer coordination, ~7x tokens). User chooses.
6. **Quality at scale** — Structured verification (Two-Phase Reflective hybrid), simplification via linters, multi-review aggregation
7. **Comprehensive outputs** — 128K output means complete plans in single responses
8. **Modern skills** — All 17 skills + 2 agents use current frontmatter fields (memory, tools, max_turns, hooks)

### The Non-Negotiables

1. **Structured verification** — Two-Phase Reflective + behavioral comparison hybrid for all reviewers (research-backed)
2. **File ownership** — Two-mode: prompt-based (Task mode) + hook-based (Agent Teams mode). Issue #16126 unblocked for teams.
3. **TaskCompleted hook** — Hard enforcement quality gate (the only non-advisory mechanism)
4. **Experimental feature opt-in** — Users choose stable vs experimental. Cost disclosed. Zero disruption for those who don't opt in.
5. **Opus 4.6 adoption** — 128K output, adaptive thinking, agent teams (opt-in)

### The Order Matters

**Config/hooks → Experimental opt-in + skill modernization → Prompts → Optimization → Polish**

Don't write code when config works. Don't optimize before it works. Don't parallelize before conflicts are prevented. Don't rebuild what beads or Claude Code already provide. Let users choose their own risk tolerance for experimental features.

### What Remains Unique to superpowers-bd

Native agent teams can coordinate. superpowers-bd ensures they produce **quality work that persists**:

- **Two-mode dispatch** — Task tool (cost-efficient, default) or Agent Teams (richer coordination, opt-in)
- **Beads** for git-backed task persistence (Dolt backend with 6-layer concurrency protection)
- **Structured verification** via Two-Phase Reflective hybrid (research-backed)
- **TaskCompleted hooks** for hard enforcement quality gates
- **File ownership** — prompt-based (Task mode) or hard enforcement via `CLAUDE_CODE_AGENT_NAME` (Agent Teams mode)
- **Rule-of-five** quality gate skills
- **Experimental feature opt-in** — users control their own risk/cost trade-off

**The playbook:** Use Claude Code's native features for coordination (memory, hooks, metrics, agent teams) + superpowers-bd for discipline (quality gates, persistence, file ownership). Let users opt into experimental features when they're ready. Don't rebuild what beads or Claude Code already provide.

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
| 4.3 | 2026-02-07 | **Experimental feature opt-in architecture via 2 parallel Opus research agents.** Added 3 items (#45-47): SessionStart feature detection + config file, two-mode SDD (Task vs Agent Teams), skill/agent frontmatter modernization. Added P1.5 priority tier: "Experimental Feature Opt-In + Skill Modernization." Key discovery: `CLAUDE_CODE_AGENT_NAME` IS available for agent team members — unblocks file ownership (#3) for teams mode. Updated #3 with two-mode path (Agent Teams = hard enforcement today, Task = prompt-based interim). Updated #35 with 7x cost data (corrected from earlier 3-5x estimate) and elevated from P6 to P1.5. Added 13 TeammateTool operations reference. Updated comparison table to three columns (native / Task mode / Teams mode). Updated Section 3.1 with teammate env vars. Updated Section 3.2 with experimental feature flag. Expanded hook env var reference. Updated summary with modern skills (#8) and experimental opt-in (#4 non-negotiable). **47 active improvements.** |

---

*This document synthesizes findings from: superpowers-bd, superpowers (original), get-shit-done, gastown (575 commits), loom, claude-flow, SWE-agent/mini-swe-agent, Dolt backend analysis, Opus 4.6 release analysis, Claude Code 2.1.33+ changelog analysis, empirical beads v0.49.4 concurrency testing, arXiv 2508.12358 (LLM verification), arXiv 2509.01494 (SWR-Bench multi-review), Claude Code hooks API verification (Issues #16126, #7881), pre-commit.com compatibility testing, Claude Code agent teams docs (code.claude.com), and experimental feature detection research (paddo.dev, kieranklaassen gist, claudefa.st).*

***Version 4.3 Summary:** 47 active improvements, numbered 1-47. Three new items added: feature detection (#45), two-mode SDD (#46), frontmatter modernization (#47). New P1.5 priority tier for experimental feature opt-in + skill modernization (~7 hours total). File ownership (#3) no longer fully blocked — hard enforcement available via `CLAUDE_CODE_AGENT_NAME` when user opts into agent teams. Agent teams cost ~7x tokens (official docs). Two-mode architecture: Task mode (default, cost-efficient) vs Agent Teams mode (opt-in, richer coordination). Priority order: config (P1) → **experimental opt-in + modernization (P1.5)** → quality gate prompts (P2) → file ownership (P3) → context/state (P4) → performance (P5) → polish (P6) → SWE-agent (P7) → future (P8). Zero external runtime dependencies.*
