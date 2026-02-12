# Superpowers-BD: Improvement Roadmap

**Version:** 6.9 (February 11, 2026) | **Active items:** 9 (all DONE) | **Archive:** [docs/IMPROVEMENTS-ARCHIVE.md](docs/IMPROVEMENTS-ARCHIVE.md)

**Philosophy:** If Claude Code does it natively, use that. If beads already does it, don't rebuild it. Config before code.

**Strategy:** Config/hooks first, then quality gate prompts, then file ownership via proven prompt-based patterns. Don't wait for upstream fixes with no timeline.

*Item numbers are stable IDs from the [archive](docs/IMPROVEMENTS-ARCHIVE.md), not priority ranks.*

**Next up:** None — roadmap complete. See **Watch List** below for items to revisit periodically.

---

## Roadmap

### ~~P1.5: Agent Modernization (Zero Cost Increase)~~ DONE

| # | What | Type | Status |
|---|------|------|--------|
| 45 | Modernize 2 agents + 1 command + writing-skills guide | Frontmatter + docs | DONE |

### ~~P2: Quality Gates & File Ownership (Prompt/Skill Changes)~~ DONE

| # | What | Type | Goal |
|---|------|------|------|
| ~~46~~ | ~~Multi-review aggregation — N independent reviews~~ | ~~Skill/prompt~~ | ~~DONE~~ |
| ~~25~~ | ~~Linter guards via frontmatter PostToolUse~~ | ~~Hook config~~ | ~~DONE~~ |
| ~~14~~ | ~~Require completion evidence before closing (builds on #5)~~ | ~~Hook + prompt~~ | ~~DONE~~ |
| ~~15~~ | ~~Declare file ownership in task definitions~~ | ~~Skill update~~ | ~~DONE~~ |
| ~~6~~ | ~~Add cyclomatic complexity checks to code-reviewer~~ | ~~Prompt~~ | ~~DONE~~ |
| ~~47~~ | ~~cognitive-complexity-ts for TS/TSX linting~~ | ~~Hook enhancement~~ | ~~DONE~~ |
| ~~16~~ | ~~Create artifact-specific rule-of-five variants~~ | ~~Skill variant~~ | ~~DONE~~ |
| ~~24~~ | ~~Run file conflict analysis before planning~~ | ~~Skill update~~ | ~~OBSOLETE~~ |

### ~~P3: Formalization & State~~ DONE

### ~~P5: Deferred Enforcement & Performance~~ DONE

### ~~P6: Tooling & Polish~~ DONE

### ~~P7: SWE-Agent Patterns~~ DONE

### ~~P8: Future (Feasible)~~ DONE

### Icebox

Tracked to prevent re-raising. Revisit only when the blocking condition changes.

| # | What | Why deferred |
|---|------|-------------|
| 33 | 1M context window | Beta hasn't exited |
| 35 | Native agent teams | ~7x cost, impractical |
| 40 | Restrict sub-agent spawning | No-op for current architecture |
| 39 | TeammateIdle hooks | Agent teams only |
| 28 | 100-line file chunks | Mostly native now |
| 10 | Structured agent IDs with validation | Ephemeral subagents have no persistent identity to structure (#16126) |
| 7 | Checkpoint classification — binary flag | Conflicts with full-automation goal |
| 3 | File ownership via PreToolUse hooks | Both blockers (#16126, #21460) open 6+ months; prompt-based approach has 4 defense layers |
| 12 | Template rendering for prompts | No code execution layer; LLM interpolation works with 15 stable variables |
| 17 | DAG visualization | `bd graph` already provides tree view + tier identification; only critical path analysis missing |
| 18 | Complexity scoring (0-1 scale) | 3-level system already captures actionable value; LLM duration estimation unreliable |
| 19 | Adversarial security review skill | Covered shallowly by code-reviewer + epic-verifier + multi-review; external tools better suited |
| 20 | External verification — GPT 5.2-codex | Self-Agg (#46, DONE) matches Multi-Agg; no API integration mechanism |
| 21 | Agent-agnostic zombie detection | GT_AGENT is Gastown-specific; Task tool manages lifecycle; failure recovery covers stuck subagents |
| 22 | Memorable agent identities | Same blockers as #10; ephemeral subagents have no persistent identity |
| 23 | Git-backed context audit trail | 5 existing audit layers cover operational needs |
| 34 | Use 128K output | Claude Code caps at 32-64K (#24159, #24313); no-op when fixed |
| 43 | Use --from-pr flag for reviews | User CLI flag, not plugin config; review pipeline uses git SHAs |
| 44 | Leverage skill character budget scaling | Skills well within all budgets; 3-tier model handles overflow |
| 31 | Validation tests for hook/skill configs | All 20 skills well-formed; config changes rare; revisit if more skills added |
| 36 | Map task type to effort level | Task tool lacks effort param; model routing is functional proxy |

### Watch List

Items with specific upstream triggers. Revisit when the trigger condition changes.

| # | Item | Trigger | How to check |
|---|------|---------|--------------|
| 33 | 1M context window | Exits beta → GA | `claude --version` release notes or Anthropic blog |
| 35 | Native agent teams | Cost drops below ~3x | Anthropic pricing page or agent teams docs |
| 3 | File ownership via hooks | #16126 or #21460 resolved | `gh issue view 16126` / `gh issue view 21460` |
| 34 | 128K output | #24159 fixed | `gh issue view 24159` |
| 36 | Per-subagent effort | Task tool adds effort param | Claude Code changelog or `Task` tool schema |
| 31 | Validation tests | More skills/hooks planned | Your own roadmap — if adding new skills, do this first |

*Goal: **Q** = quality, **P** = performance, **C** = correctness, **DX** = developer experience*

---

## Design Principles

1. **Stable features first** — GA only. Agent teams deferred (~7x cost).
2. **Verify before assuming** — Frontmatter hooks verified. Build on confirmed foundations.

## Differentiators

**Shipped:**
- **Beads** — git-backed task persistence (Dolt, 6-layer concurrency)
- **Rule-of-five variants** — artifact-specific 5-pass quality gates (code, plans, tests)
- **12 workflow skills** — TDD, debugging, verification, brainstorming, etc.
- **TaskCompleted hooks** (#5) — hard enforcement quality gates (interactive mode)
- **Multi-review aggregation** (#46) — N=3 independent reviews, union+severity consensus, 43.67% F1 improvement
- **Prompt-based file ownership** (#15) — `{wave_file_map}` table serialized into each implementer prompt, showing all agents' file assignments per wave
- **Modern agent frontmatter** (#45) — memory, maxTurns, disallowedTools, command frontmatter, reference docs

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
- **#15** (file ownership in task definitions) — Done (2026-02-08). Wave file map (`{wave_file_map}`) serialized into each implementer prompt, showing all agents' file assignments. No file I/O needed — eliminates permission prompts and cleanup.
- **#25** (linter guards) — Done (2026-02-08). PostToolUse hooks run shellcheck (.sh) and jq (.json) after Write/Edit. Main thread via hooks.json, subagents via code-reviewer frontmatter. Graceful degradation if tools missing.
- **#46** (multi-review aggregation) — Done (2026-02-08). N=3 independent reviews for max-20x/max-5x tiers with union+severity consensus aggregation. New skill + SDD integration.
- **#6** (cyclomatic complexity checks) — Done (2026-02-09). Quantitative metrics section in code-reviewer (CC, function length, duplication thresholds). Lizard hook in run-linter.sh with two-pass enforcement (block CC>15/length>100, warn CC>10/length>50). Graceful degradation with install hint.
- **#47** (cognitive-complexity-ts for TS/TSX) — Done (2026-02-09). ccts-json preferred for TS/TSX cognitive complexity (warn >15, block >25), lizard fallback when ccts-json unavailable. 6 new tests.
- **#14** (completion evidence) — Done (2026-02-08). Two-layer enforcement: TaskCompleted hook Check 2 blocks implementation tasks without commit/files/tests evidence (interactive mode), structured implementer report template ensures evidence generation (all modes), `bd close --reason` persists evidence in beads audit trail.
- **#16** (artifact-specific rule-of-five variants) — Done (2026-02-11). Three variants: `rule-of-five-code` (renamed from `rule-of-five`), `rule-of-five-plans` (new), `rule-of-five-tests` (new). Each with tailored 5-pass definitions. ~25 files updated.
- **#24** (pre-planning file conflict analysis) — Obsolete (2026-02-11). Superseded by: `file-lists.md` already tells planners "shared files = no parallel", SDD's `dispatch-and-conflict.md` handles conflict deferral at runtime, #15's `{wave_file_map}` provides runtime visibility, and rule-of-five-plans Risk pass prompts for "parallel conflicts".
- **#9** (parallel bd queries) — Obsolete (2026-02-11). SQLite migration eliminated Dolt 32s bottleneck. All bd commands sub-110ms. Max 330ms sequential in hot path vs 5-30 min wave execution.
- **#32** (batch lookups) — Obsolete (2026-02-11). SQLite daemon RPC eliminates subprocess overhead. Max N=5, inherently sequential patterns can't be batched.
- **#4** (codify SSOT as design principle) — Already implemented (2026-02-11). Guard rules in SDD ("Always: check bd ready before each wave") and executing-plans ("Check bd ready before each batch") are the concrete codification. Recovery paths explicitly reference beads as SSOT. Abstract principle adds no enforcement the guard rules don't already provide.
- **#8** (parallelize review pipelines) — Already implemented (2026-02-11). `background-execution.md` specifies inter-task review parallelism with event-driven dispatch and `run_in_background=True`.
- **#11** (--fast mode for status) — Obsolete (2026-02-11). SQLite migration dropped `bd ready` from ~5s to 82ms. All status commands sub-110ms.
- **#13** (health checks — doctor command) — Already implemented (2026-02-11). `bd doctor` v0.49.6 runs 68 checks with `--fix` auto-repair.
- **#26** (cap search results at 50) — Obsolete (2026-02-11). Claude Code Grep tool has `head_limit` + auto-truncation at 30K chars.
- **#27** (integrate edit feedback) — Obsolete (2026-02-11). Edit tool returns modified content natively. PostToolUse linter hooks (#25) go further.
- **#30** (atomic spawn) — Obsolete (2026-02-11). Task tool is a single atomic primitive. Gastown tmux two-step spawn race cannot occur.
- **#37** (exploit ARC AGI 2 leap) — Already implemented (2026-02-11). Complexity-based model routing (v4.5.0) routes complex→Opus. ARC improvements inherent to model.
