# Superpowers-BD: Comprehensive Improvement Report

**Date:** February 7, 2026 (v4.1 — Research-verified: removed Gastown-specific items, reframed review approach)
**Purpose:** Dramatically improve superpowers-bd by leveraging native Claude Code features + adding unique value (quality gates, persistence, file ownership)
**Philosophy:** If it's worth doing, do it. If Claude Code does it natively, use that instead. If beads already does it, don't rebuild it.

---

## How to Read This Document

1. **Section 1:** All **47 ACTIVE** improvements ranked by impact
2. **Section 2:** **PRIORITIZED** implementation order — easy wins first, code changes later
3. **Section 3:** Reference info (Opus 4.6, Claude Code 2.1.33+)
4. **Section 4:** Open questions — answered with research
5. **Section 5:** Additional research opportunities
6. **Section 6:** SWE-Agent research findings
7. **Section 7:** Summary: The path forward

**Key decisions already made:**
- **Dolt migration: COMPLETED** (Feb 7, 2026). Beads v0.49.4 on Dolt backend.
- **12 improvements deprecated** — now native to Claude Code 2.1.33+ (memory frontmatter, hooks, Task metrics, agent teams).
- **Agent Mail: REMOVED** — beads Rust (`br`) incompatible with Dolt backend; hook-based file ownership replaces it with zero dependencies.
- **Semaphore concurrency: ALREADY IN BEADS** — v0.49.4 has process-level semaphore, advisory flock, lock retry, JSONL file locking, and connection pool deadlock fix. Empirically tested: 40 concurrent `bd create` operations succeeded with zero failures.
- **Retry with verification: NOT NEEDED** — beads uses embedded Dolt (not sql-server). Dolt's chunk journal with `fsync()` guarantees durability. `getBeadInfo()` is a Gastown function for Gastown's multi-agent sql-server mode. Silent write failures do not occur in embedded mode.
- **Priority reordering:** Config/hooks first → prompt changes → code changes.

---

## 1. All ACTIVE Improvements Ranked by Impact (47 Remaining)

### CRITICAL IMPACT — Prevents failures, enables core capabilities

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 1 | **Structured verification via behavioral comparison** | Catches issues current reviews miss. Research shows unstructured "be skeptical" prompts *decrease* accuracy (52.4% → 11.0%). Instead: (1) extract requirements independently, (2) read code and summarize actual behavior, (3) compare point-by-point. This pattern reaches **85.4% accuracy**. The code quality reviewer currently has **zero** skepticism instructions and passes the implementer's self-report as fact. | superpowers original + [arXiv 2508.12358](https://arxiv.org/html/2508.12358v1) |

### HIGH IMPACT — Significant quality or efficiency gains

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 2 | **Two-phase delayed dispatch** | Ensures ALL preparatory work (beads status, file-locks.json) completes before ANY subagent spawns in a wave. The Gastown tmux race condition doesn't apply (Claude Code's Task tool passes context atomically in the prompt), but file-locks.json must be complete before the first subagent edit. This is a **skill/prompt change** (~30 min), not code. Depends on #3 to be fully meaningful. | Gastown §1.4 (adapted) |
| 3 | **File ownership enforcement via hooks** | Proactive conflict prevention. `PreToolUse` hook on `Edit\|Write` checks `.claude/file-locks.json` and blocks edits to files owned by other agents. Zero external dependencies. | Hook-based |
| 4 | **ZFC Philosophy: Query, Don't Track** | Prevents state drift bugs. Instead of caching task state in skills, always query beads for truth. Reality is authoritative; derived state cannot diverge. | Gastown §5 |
| 5 | **Blocking quality gates (task dependencies)** | Ensures nothing proceeds without review. Downstream tasks blocked via `addBlockedBy` until review task completed. `TaskCompleted` hook enforces review quality. | Native hooks |
| 6 | **Simplification review pass** | Reduces code complexity. Dedicated pass asking: dead code? duplication? over-engineering? unnecessary dependencies? Catches what correctness review misses. | Original research |
| 7 | **5-step process termination with 2s grace** | Prevents orphan processes. Process group termination → recursive descendant detection → SIGTERM → 2s wait → SIGKILL. Previous 100ms was too short for Claude shutdown. | Gastown §4.6 |
| 8 | **Pre-commit quality guard** | Enforcement at commit time. Git pre-commit hook checks `.claude/file-locks.json` — blocks commits touching files outside agent's assignment. | Git hook + file-locks.json |

### MEDIUM IMPACT — Meaningful improvements to workflow

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 9 | **Checkpoint classification in plans** | Distinguishes AUTOMATED (run without human) from HUMAN_DECISION (requires input) from HUMAN_ACTION (user must do something external). Execution system batches automated work, pauses only at true decision points. | get-shit-done |
| 10 | **Task type classification** | Different behavior for IMPLEMENTATION vs VERIFICATION tasks. Implementation can retry; verification escalates on failure. Verification can use cheaper models. | loom |
| 11 | **Parallelize review pipelines** | Reviews for different tasks run concurrently. Task A and Task B reviews don't wait for each other. Only sequential: spec review before code review for same task. | Original research |
| 12 | **Parallel bd queries with indexed results** | 6x speedup on multi-query operations. Goroutines with pre-allocated result slice (no mutex needed). 32s → 5s inbox load in Gastown. | Gastown §3.5 |
| 13 | **Structured agent IDs** | Validates task/bead IDs with parsing. Format: `<prefix>-<role>` or `<prefix>-<rig>-<role>-<name>`. Prevents silent failures from malformed IDs. | Gastown §2.1 |
| 14 | **--fast mode for status commands** | 60% faster status checks. Skip non-essential operations. 5s → 2s. | Gastown §3.1 |
| 15 | **Template rendering for prompts** | Consistent output formatting. Type-safe data injection. Reduces hallucination. Single source of truth for agent prompts. | Gastown §4.3 |
| 16 | **Health checks (doctor command)** | Catches misconfigurations. Check for orphaned worktrees, prefix mismatches, stale agent beads, slow operations. Auto-fix common issues. | Gastown §2.2 |
| 17 | **Completion evidence requirements** | Tasks can only close with proof. Commit hash, files changed, test results, coverage delta. `TaskCompleted` hook verifies before accepting. | Native hooks |
| 18 | **File ownership declared in task definition** | Conflicts computed at dispatch time. Each task declares owned files in description. Orchestrator writes `.claude/file-locks.json` before spawning agents. | Hook-based |
| 19 | **Artifact-specific rule-of-five variants** | Better quality for non-code. Code: Draft→Correctness→Clarity→Edge Cases→Excellence. Plans: Draft→Feasibility→Completeness→Risk→Optimality. Tests: Draft→Coverage→Independence→Speed→Maintainability. | Original research |

### LOWER IMPACT — Nice to have, future consideration

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 20 | **DAG visualization** | Understand dependencies before starting. Tree view with status icons, tier view for parallel opportunities, critical path analysis. | Gastown §1.3 |
| 21 | **Complexity scoring for tasks** | Better model routing. 0-1 scale with estimated duration and confidence. Enables SLA tracking. | claude-flow |
| 22 | **Adversarial review for security code** | Try to break it. Test injection, auth bypass, privilege escalation, data leakage, DoS. Document attempted attacks and results. | loom |
| 23 | **External verification (GPT 5.2-codex)** | Second opinion on critical code. Export to external tool, triage findings as true positive / false positive / enhancement. | Original research |
| 24 | **Agent-agnostic zombie detection** | Support multiple AI backends. Read GT_AGENT env var, look up process names for Claude/Gemini/Codex/Cursor/etc. | Gastown §1.5 |
| 25 | **Memorable agent identities** | Better audit trail. Adjective+noun names (GreenCastle, BlueLake). 4,278 unique combinations. Git commits show author. | Research |
| 26 | **Git-backed context audit trail** | Every context change tracked. `.context/` directory with JSON files, git commits on each update, SQLite index for queries. | Research |
| 27 | **Pre-planning file conflict analysis** | Compute waves during planning, not runtime. List all files, identify conflicts, pre-compute optimal groupings, surface in plan header. | Gastown, original research |

### From SWE-Agent Research

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 28 | **Linter guards on all edits** | Prevents syntax errors from persisting. Run linter before accepting edit, reject + show error + retry if fail. Stops compounding errors. | SWE-agent ACI |
| 29 | **Succinct search results (max 50)** | Prevents context overflow in subagents. If >50 matches, ask to refine query. Summarize rather than dump. | SWE-agent ACI |
| 30 | **Integrated edit feedback** | Show file diff immediately after edit. Agent sees effect of action, catches mistakes faster. | SWE-agent ACI |
| 31 | **100-line file chunks** | When reading files for context, chunk to 100 lines (empirically optimal). Prevents context overflow while maintaining orientation. | SWE-agent ACI |
| 32 | **Specialized file viewer** | Build file viewer skill with scroll/search/line numbers. Better than raw cat for navigation. | SWE-agent |

### From Gastown Deep Dive

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 33 | **Atomic spawn (NewSessionWithCommand)** | Eliminates race conditions in subagent spawning. Command runs as pane's initial process, not sent after shell ready. Faster startup. | Gastown §15 |
| 34 | **Validation tests for hook/skill configurations** | Prevents silent failures from misconfigured skills. Test that SessionStart hooks include `--hook` flag, registry covers all roles. | Gastown §11 |
| 35 | **Batch lookups with SessionSet pattern** | O(1) repeated queries instead of N+1 subprocess calls. Single `ListSessions` → map lookup for each check. | Gastown §3.4 |

### Opus 4.6 & Native Agent Teams (Released Feb 5, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 36 | **[FUTURE] Leverage 1M context for full-codebase awareness** | ⚠️ **BETA ONLY** — not available to general users yet. When available: load entire codebase into context. Monitor for GA release. | Opus 4.6 beta |
| 37 | **Use 128K output for comprehensive deliverables** | Full implementation plans, complete code reviews, exhaustive test suites in single response. **Available now.** | Opus 4.6 release |
| 38 | **Integrate native agent teams for parallel coordination** | Replace custom parallel dispatch with native TeammateTool for peer-to-peer messaging. Keep superpowers-bd for discipline. **Available now (research preview).** | Opus 4.6 agent teams |
| 39 | **Map task type to effort level** | VERIFICATION → low effort (cheaper). IMPLEMENTATION → high effort (better quality). Use adaptive thinking API parameters. **Available now.** | Opus 4.6 adaptive thinking |
| 40 | **Exploit ARC AGI 2 leap for novel problem-solving** | Route complex/novel problems to Opus 4.6 (68.8% ARC vs 37.6% before). Use Sonnet for routine tasks. **Available now.** | Opus 4.6 benchmarks |

### Claude Code 2.1.33+ Features (Feb 6, 2026)

| # | Improvement | What It Achieves | Source |
|---|-------------|------------------|--------|
| 41 | **Use `memory` frontmatter for persistent agent context** | Agents have persistent memory surviving across conversations. Scopes: `user`, `project`, `local`. Builds knowledge over time. | Claude Code v2.1.33 |
| 42 | **Hook into TeammateIdle and TaskCompleted events** | Native hook events for multi-agent coordination. Event-driven, replaces polling-based detection. | Claude Code v2.1.33 |
| 43 | **Restrict sub-agent spawning via `Task(agent_type)` syntax** | Control which sub-agents can be spawned from `tools` frontmatter. Prevents infinite nesting. | Claude Code v2.1.33 |
| 44 | **Use native Task metrics for cost tracking** | Task results include token count, tool uses, duration. Native, accurate, no parsing required. | Claude Code v2.1.30 |
| 45 | **Define hooks in agent/skill frontmatter** | Hooks scoped to specific agents. Per-agent validation, cleanup on finish. Cleaner than global config. | Claude Code v2.1.33 |
| 46 | **Use --from-pr flag for PR-linked sessions** | Sessions auto-link to PRs. Resume with `--from-pr`. Better PR workflow integration. | Claude Code v2.1.27 |
| 47 | **Leverage skill character budget scaling** | Skill content budget scales at 2% of context window. More room for comprehensive skill instructions with Opus 4.6. | Claude Code v2.1.32 |

---

## 2. PRIORITIZED Implementation Order

**Strategy:** Easy wins first (config/hooks), then prompt changes, then code changes. Get value immediately.

### Priority 1: Use What's Already There (This Week — Config Only)

These features exist in Claude Code 2.1.33+. Just configure them.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **1.1** | 3 | File ownership via `PreToolUse` hook | ~20 lines bash |
| **1.2** | 42 | TeammateIdle/TaskCompleted hooks | Hook config |
| **1.3** | 41 | `memory: project` on agent definitions | Frontmatter line |
| **1.4** | 43 | Restrict sub-agent spawning | Frontmatter field |
| **1.5** | 44 | Native Task metrics | Already available — just use them |
| **1.6** | 45 | Hooks in agent frontmatter | Frontmatter field |

**Rationale:** Zero code required. Can be done in a single session. Immediate value.

**File ownership hook pattern (P1.1):**
```bash
#!/bin/bash
# .claude/hooks/check-file-ownership.sh (PreToolUse on Edit|Write)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
AGENT=$(echo "$AGENT_NAME" 2>/dev/null)
OWNER=$(jq -r --arg f "$FILE_PATH" '.[$f].agent // empty' .claude/file-locks.json 2>/dev/null)
if [ -n "$OWNER" ] && [ "$OWNER" != "$AGENT" ]; then
  echo "BLOCKED: $FILE_PATH is owned by $OWNER, not $AGENT" >&2
  exit 2  # Blocks the edit and sends feedback to Claude
fi
exit 0
```

### Priority 2: Quality Gate Skills (High ROI — Prompt/Skill Changes)

Prompt engineering and skill updates. No infrastructure code needed.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **2.1** | 1 | Structured verification (behavioral comparison) | Prompt rewrite for 3 files |
| **2.2** | 6 | Simplification review pass | New skill |
| **2.3** | 5 | Blocking quality gates (task dependencies) | Task config + hook |
| **2.4** | 17 | Completion evidence requirements | Hook + prompt |
| **2.5** | 19 | Artifact-specific rule-of-five | Skill variants |
| **2.6** | 28 | Linter guards via PostToolUse hooks | Hook config |
| **2.7** | 2 | Two-phase delayed dispatch | Skill update (depends on P1.1) |

**Rationale:** Highest ROI improvements. Quality gates are superpowers-bd's unique value. #1 (structured verification) is the single most impactful change — research-backed, addresses 6 identified gaps across 5 files.

**Structured verification method (P2.1) — the behavioral comparison pattern:**

```markdown
## Verification Method

Do NOT read the implementer's report first. Instead:

Step 1: Extract requirements from the spec. Create a numbered checklist.
Step 2: Read actual code independently. Summarize what it does (not what spec says).
Step 3: Compare requirements vs actual behavior point-by-point (file:line evidence).
Step 4: Check for unlisted behavior not in the spec (scope creep).
Step 5: THEN read the implementer's report. Note discrepancies.
```

**Files requiring changes for #1:**
- `skills/subagent-driven-development/spec-reviewer-prompt.md` — add behavioral comparison; remove bias-inducing "suspiciously quickly"
- `skills/requesting-code-review/code-reviewer.md` — add independent verification section
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md` — add anti-framing warning
- `agents/code-reviewer.md` — add "verify claims, don't trust reports"
- `skills/subagent-driven-development/SKILL.md` — add meta-verification of review verdicts

### Priority 3: Foundation Code (Requires Implementation)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **3.1** | 7 | 5-step process termination | Bash code |

**Rationale:** The only remaining item requiring actual code changes. Semaphore and retry were removed (already in beads v0.49.4). Two-phase dispatch moved to P2 (it's a skill change).

### Priority 4: File Ownership (Full Implementation)

Builds on the P1 hook with full conflict prevention.

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **4.1** | 18 | File ownership declared in task definition | Skill update |
| **4.2** | 27 | Pre-planning file conflict analysis | New skill |
| **4.3** | 8 | Pre-commit quality guard | Git hook script |

**Rationale:** P1 gives us the basic hook. P4 makes it systematic — ownership at dispatch time, conflict detection during planning, enforcement at commit.

### Priority 5: Context & State (Beads Integration)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **5.1** | 4 | ZFC Philosophy | Skill update |
| **5.2** | 13 | Structured agent IDs | Code |
| **5.3** | 9 | Checkpoint classification | Skill update |
| **5.4** | 10 | Task type classification | Skill update |

**Rationale:** Native memory handles context; beads handles task state. Clear separation.

### Priority 6: Execution Optimization (Performance)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **6.1** | 12 | Parallel bd queries | Go code |
| **6.2** | 35 | Batch lookups (SessionSet pattern) | Code |
| **6.3** | 14 | --fast mode for status | Code |
| **6.4** | 11 | Parallelize review pipelines | Skill update |

**Rationale:** After core system works, optimize for speed.

### Priority 7: Tooling & Polish (Refinement)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **7.1** | 16 | Health checks (doctor) | Code |
| **7.2** | 15 | Template prompts | Code |
| **7.3** | 34 | Validation tests for configs | Tests |
| **7.4** | 46 | Use --from-pr flag | Config |
| **7.5** | 37 | Use 128K output | Prompt update |
| **7.6** | 47 | Leverage skill budget scaling | Config |
| **7.7** | 38 | Integrate native agent teams | Architecture |
| **7.8** | 39 | Map task type to effort level | Skill update |

### Priority 8: SWE-Agent Patterns (Agent Quality)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **8.1** | 29 | Succinct search results (max 50) | Skill update |
| **8.2** | 30 | Integrated edit feedback | Skill update |
| **8.3** | 31 | 100-line file chunks | Skill update |
| **8.4** | 32 | Specialized file viewer | New skill |

**Rationale:** Agent-Computer Interface improvements after core functionality works.

### Priority 9: Advanced & Future (Do Last)

| Order | # | Improvement | Effort |
|-------|---|-------------|--------|
| **9.1** | 20 | DAG visualization | Code |
| **9.2** | 22 | Adversarial security review | New skill |
| **9.3** | 23 | External verification (GPT 5.2-codex) | Integration |
| **9.4** | 25 | Memorable agent identities | Code |
| **9.5** | 26 | Git-backed context audit trail | Code |
| **9.6** | 33 | Atomic spawn | Code |
| **9.7** | 24 | Agent-agnostic zombie detection | Code |
| **9.8** | 21 | Complexity scoring | Code |
| **9.9** | 40 | Exploit ARC AGI 2 leap | Prompt/routing |
| **9.10** | 36 | [FUTURE] 1M context | When beta exits |

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

**Adaptive Thinking:** Model picks up contextual clues about how much to think. Less cost for simple tasks, automatic deep thinking for complex ones. Effort controls let developers tune the intelligence/speed/cost tradeoff.

**Agent Teams (Research Preview):** Multiple agents work in parallel with peer-to-peer coordination via TeammateTool (13 operations). Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Not yet production-ready GA.

**superpowers-bd's unique value vs native agent teams:**

| Capability | Native Agent Teams | superpowers-bd |
|------------|-------------------|----------------|
| Parallel execution | ✅ Built-in | ✅ Task tool + waves |
| Peer-to-peer messaging | ✅ TeammateTool | ✅ (via native) |
| Session resumption | ❌ | ✅ Beads persistence |
| Quality gates | ❌ | ✅ Skills-based |
| File ownership | ❌ | ✅ PreToolUse hooks |
| Pre-commit guards | ❌ | ✅ Git hook + file-locks.json |
| Git-backed state | ❌ | ✅ Beads on Dolt |
| Nested teams | ❌ | ✅ Subagent spawning |

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

**Answer: YES — Use the pre-commit framework for chaining**

Best approach: [pre-commit.com](https://pre-commit.com/) framework. Handles execution order, supports multiple hooks, any non-zero exit aborts commit.

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: file-ownership-guard
        name: File Ownership Check
        entry: .claude/hooks/check-file-ownership.sh
        language: system
        pass_filenames: false
      - id: existing-linter
        name: Your Existing Linter
        entry: npm run lint
        language: system
```

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

**Metrics to enforce:**
- Cyclomatic complexity: Flag >10, block >15
- Function length: Flag >50 lines, block >100
- Duplication: Flag >10 lines duplicated, block >25

**What NOT to block on:** Style preferences (linter handles), naming conventions, comment density.

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
| **Over-correction bias in LLM reviewers** | How to make reviewers skeptical without false positives | [arXiv 2508.12358](https://arxiv.org/html/2508.12358v1) behavioral comparison study |

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
2. **No missed work** — Blocking quality gates, completion evidence, pre-commit guards
3. **No conflicts** — File ownership via hooks, proactive detection, advisory locking
4. **No state drift** — ZFC philosophy, persistent memory, structured storage
5. **Maximum parallelism** — Native agent teams, two-phase dispatch, fan-out/gather
6. **Quality at scale** — Structured verification (behavioral comparison), simplification pass, adversarial testing
7. **Comprehensive outputs** — 128K output means complete plans in single responses

### The Non-Negotiables

1. **Hook-based file ownership** — `PreToolUse` hook enforces file ownership (zero dependencies)
2. **Structured verification** — Behavioral comparison pattern for all reviewers (85.4% accuracy vs 52.4% unstructured)
3. **Blocking quality gates** — Nothing proceeds without evidence-backed review
4. **Opus 4.6 adoption** — 128K output, adaptive thinking, native agent teams

### The Order Matters

**Config/hooks → Prompts → Code → Optimization → Polish**

Don't write code when config works. Don't optimize before it works. Don't parallelize before conflicts are prevented. Don't rebuild what beads already provides.

### What Remains Unique to superpowers-bd

Native agent teams can coordinate. superpowers-bd ensures they produce **quality work that persists**:

- **Beads** for git-backed task persistence (Dolt backend with 6-layer concurrency protection)
- **Structured verification** via behavioral comparison (research-backed, 85.4% accuracy)
- **Hook-based file ownership** (zero-dependency conflict prevention)
- **Pre-commit guards** via git hook + `.claude/file-locks.json`
- **Rule-of-five** quality gate skills

**The playbook:** Use Claude Code's native features for coordination (memory, hooks, metrics, agent teams) + superpowers-bd for discipline (quality gates, persistence, file ownership). Don't rebuild what beads or Claude Code already provide.

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
| 4.1 | 2026-02-07 | **Research-verified top 4.** Removed semaphore (#1) — already in beads v0.49.4 (6 layers of concurrency protection, 40 concurrent ops tested). Removed retry-with-verification (#2) — Gastown-specific pattern for sql-server mode, not needed in embedded mode. Reframed skeptical reviewers as "Structured verification via behavioral comparison" (85.4% accuracy per arXiv research). Downgraded two-phase dispatch from CRITICAL to HIGH (Gastown's tmux race doesn't apply to Claude Code Task tool). Added Section 3.3: Beads concurrency architecture. **47 active improvements remain.** |

---

*This document synthesizes findings from: superpowers-bd, superpowers (original), get-shit-done, gastown (575 commits), loom, claude-flow, SWE-agent/mini-swe-agent, Dolt backend analysis, Opus 4.6 release analysis, Claude Code 2.1.33+ changelog analysis, and empirical beads v0.49.4 concurrency testing.*

***Version 4.1 Summary:** 47 active improvements, renumbered 1-47. Two Gastown-specific items removed after empirical verification (semaphore already in beads, retry not needed for embedded Dolt). #1 is now "Structured verification via behavioral comparison" — the single highest-impact improvement, research-backed at 85.4% accuracy. Priority order unchanged: config/hooks (P1) → quality gate prompts (P2) → foundation code (P3) → file ownership (P4) → context/state (P5) → performance (P6) → polish (P7) → SWE-agent patterns (P8) → future (P9). Zero external runtime dependencies.*
