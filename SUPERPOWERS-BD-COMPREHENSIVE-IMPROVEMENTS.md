# Superpowers-BD: Improvement Roadmap

**Version:** 6.2 (February 8, 2026) | **Active items:** 38 | **Archive:** [docs/IMPROVEMENTS-ARCHIVE.md](docs/IMPROVEMENTS-ARCHIVE.md)

**Philosophy:** If Claude Code does it natively, use that. If beads already does it, don't rebuild it. Config before code.

**Strategy:** Config/hooks first, then quality gate prompts, then file ownership via proven prompt-based patterns. Don't wait for upstream fixes with no timeline.

*Item numbers are stable IDs from the [archive](docs/IMPROVEMENTS-ARCHIVE.md), not priority ranks.*

**Next up:** #25 — linter guards via frontmatter PostToolUse

---

## Roadmap

### ~~P1.5: Agent Modernization (Zero Cost Increase)~~ DONE

| # | What | Type | Status |
|---|------|------|--------|
| 45 | Modernize 2 agents + 1 command + writing-skills guide | Frontmatter + docs | DONE |

### P2: Quality Gates & File Ownership (Prompt/Skill Changes)

| # | What | Type | Goal |
|---|------|------|------|
| ~~46~~ | ~~Multi-review aggregation — N independent reviews~~ | ~~Skill/prompt~~ | ~~DONE~~ |
| 25 | Linter guards via frontmatter PostToolUse | Hook config | C |
| 14 | Require completion evidence before closing (builds on #5) | Hook + prompt | Q |
| 15 | Declare file ownership in task definitions | Skill update | C |
| 6 | Add cyclomatic complexity checks to code-reviewer | Prompt | Q |
| 16 | Create artifact-specific rule-of-five variants | Skill variant | Q |
| 24 | Run file conflict analysis before planning | Skill update | C |

### P3: Formalization & State

| # | What | Type | Goal |
|---|------|------|------|
| 7 | Add checkpoint classification — binary flag | Plan format | DX |
| 4 | Codify SSOT as design principle | Docs | C |
| 10 | Add structured agent IDs with validation | Code | DX |

### P5: Deferred Enforcement & Performance

| # | What | Type | Goal |
|---|------|------|------|
| 3 | File ownership via PreToolUse hooks (blocked: [#16126](https://github.com/anthropics/claude-code/issues/16126) + [#21460](https://github.com/anthropics/claude-code/issues/21460)) | Code | C |
| 9 | Parallel bd queries — goroutines | Go code | P |
| 32 | Batch lookups — SessionSet pattern | Code | P |
| 11 | --fast mode for status commands | Code | P |
| 8 | Parallelize review pipelines | Skill update | P |

### P6: Tooling & Polish

| # | What | Type | Goal |
|---|------|------|------|
| 13 | Health checks — doctor command | Code | DX |
| 12 | Template rendering for prompts | Code | DX |
| 31 | Validation tests for hook/skill configs | Tests | C |
| 43 | Use --from-pr flag for reviews | Config | DX |
| 34 | Use 128K output for comprehensive deliverables | Prompt | Q |
| 44 | Leverage skill character budget scaling | Config | Q |
| 36 | Map task type to effort level (blocked: Task tool lacks effort param) | Code | DX |

### P7: SWE-Agent Patterns

| # | What | Type | Goal |
|---|------|------|------|
| 26 | Cap search results at 50 | Prompt | P |
| 27 | Integrate edit feedback into workflow | Prompt | DX |

### P8: Future (Feasible)

| # | What | Type | Goal |
|---|------|------|------|
| 17 | DAG visualization | Code | DX |
| 19 | Adversarial security review skill | Skill | Q |
| 20 | External verification — GPT 5.2-codex | Integration | Q |
| 22 | Memorable agent identities | Code | DX |
| 23 | Git-backed context audit trail | Code | C |
| 30 | Atomic spawn | Code | C |
| 21 | Agent-agnostic zombie detection | Code | DX |
| 18 | Complexity scoring | Code | Q |
| 37 | Exploit ARC AGI 2 leap | Prompt/routing | P |

### Icebox

Tracked to prevent re-raising. Revisit only when the blocking condition changes.

| # | What | Why deferred |
|---|------|-------------|
| 33 | 1M context window | Beta hasn't exited |
| 35 | Native agent teams | ~7x cost, impractical |
| 40 | Restrict sub-agent spawning | No-op for current architecture |
| 39 | TeammateIdle hooks | Agent teams only |
| 28 | 100-line file chunks | Mostly native now |

*Goal: **Q** = quality, **P** = performance, **C** = correctness, **DX** = developer experience*

---

## Design Principles

1. **Stable features first** — GA only. Agent teams deferred (~7x cost).
2. **Verify before assuming** — Frontmatter hooks verified. Build on confirmed foundations.

## Differentiators

**Shipped:**
- **Beads** — git-backed task persistence (Dolt, 6-layer concurrency)
- **Rule-of-five** — 5-pass quality gate skills
- **12 workflow skills** — TDD, debugging, verification, brainstorming, etc.
- **TaskCompleted hooks** (#5) — hard enforcement quality gates (interactive mode)
- **Multi-review aggregation** (#46) — N=3 independent reviews, union+severity consensus, 43.67% F1 improvement

**Planned (in roadmap):**
- **Prompt-based file ownership** (#15) — proven pattern, no upstream dependency
- **Modern agent frontmatter** (#45) — DONE (memory, maxTurns, disallowedTools, command frontmatter, reference docs)

**The playbook:** Claude Code stable GA for coordination + superpowers-bd for discipline.

---

## Verified Facts

Known behaviors confirmed through testing. These inform design, not block it.

| Fact | Verified |
|------|----------|
| Frontmatter hooks fire for subagent tool calls | 2026-02-07 |
| TaskCompleted hooks fire in interactive mode | 2026-02-08 |
| TaskCompleted hooks do NOT fire in headless mode | 2026-02-08 |
| Agent teams cost ~7x tokens | Official docs |
| `Task(agent_type)` is a no-op for subagents | Official docs |
| `addBlockedBy` is soft/prompt-based enforcement only | By design |

## Open Blockers

| Issue | Impact |
|-------|--------|
| [#21460](https://github.com/anthropics/claude-code/issues/21460) PreToolUse/PostToolUse don't fire for subagents | File ownership via hooks blocked |
| [#16126](https://github.com/anthropics/claude-code/issues/16126) `$AGENT_NAME` unavailable for subagents | Can't identify agent in hooks |
| [#17688](https://github.com/anthropics/claude-code/issues/17688) Plugin frontmatter hooks don't fire | Workaround: `link-plugin-components.sh` copies to `.claude/` |

## Removed Items

Rejected, merged, or made obsolete. Completed items move to the [archive](docs/IMPROVEMENTS-ARCHIVE.md) with a date.

- **#1** (two-phase reflective review) — V2 DENIED (p=0.000183). 15x more FP, same recall.
- **#2** (file-locks.json generation) — Merged into #15
- **#5** (TaskCompleted hook for quality gates) — Done (2026-02-08). Verification evidence check + audit logging.
- **#29** (chunked file reads) — Redundant with native Read + Grep tools
- **#38** (add `memory: project` to agent definitions) — Done (2026-02-08)
- **#41** (expose native Task metrics for cost tracking) — Done (2026-02-08). Per-task/wave/epic metrics in SDD skill, wave summary costs, epic completion report.
- **#42** (add hooks in agent/skill frontmatter) — Done (2026-02-08). PostToolUse audit hook on code-reviewer. Plugin hooks workaround via `link-plugin-components.sh` (#17688).
- **#46** (multi-review aggregation) — Done (2026-02-08). N=3 independent reviews for max-20x/max-5x tiers with union+severity consensus aggregation. New skill + SDD integration.
