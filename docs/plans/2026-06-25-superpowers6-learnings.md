# Superpowers-6 Learnings — Implementation Plan

> **After approval:** convert this plan to a beads epic with plan2beads, then execute it with subagent-driven-development unless a different execution path is explicitly chosen.

**Goal:** Port 15 vetted learnings from upstream `superpowers` 6.0.x (A1–A4, B1–B11) into `superpowers-bd` without regressing fork value, keeping the Claude Code and Codex surfaces first-class on every change.

**Architecture:** Edits land in four artifact classes, each with its own propagation rule (see Global Constraints): (1) platform-neutral **skill content** — edited in `skills/` and byte-mirrored into `plugins/superpowers-bd/skills/`; (2) the **reviewer contract**, which is *duplicated* across the Claude skill, the Codex Markdown agents, and the Codex TOML fallback agents; (3) the **plan2beads parser**, which is dual-authored (Claude command + Codex flow reference); (4) **dev tooling** (a standalone shellcheck wrapper). No new runtime surface is introduced.

**Tech Stack:** Markdown skill/agent definitions, POSIX shell hooks, the `bd` CLI, Node-based Codex CLI fallback (`lib/skills-core.js`), `shellcheck`, the repo's existing test harnesses (`tests/claude-code/`, `tests/codex/`).

**Key Decisions:**
- **Single canonical source + explicit mirror sync, verified by `diff -rq`:** edit `skills/`, then mirror into `plugins/superpowers-bd/skills/`. There is **no sync script** in this fork; the mirror is maintained by hand and a drifted mirror silently degrades the Codex installed-plugin surface. Every skill-content task ends with a `diff -rq` gate rather than trusting the edit.
- **Reviewer-contract changes are multi-file by necessity:** the Claude agent `agents/code-reviewer.md` is a thin shell that reads the skill ("single source of truth — do not duplicate"), but the **Codex** agents (`plugins/superpowers-bd/agents/*.md` and `.codex/agents/*.toml`) *inline their own copy* of the review protocol. A1/B1/B3 therefore edit the skill **and** every Codex agent copy, or Codex reviewers go stale. This is the central reason the "keep both first-class" constraint is load-bearing here.
- **plan2beads is dual-authored, so B5/B6/B7 edit both parsers:** Claude's parser lives in `commands/plan2beads.md`; Codex's in `skills/plan2beads/references/codex-plan2beads-flow.md`; the `skills/plan2beads/SKILL.md` router just points each platform at its own. A one-sided edit drops the new plan sections on the other surface.
- **Behavioral guardrails get a RED baseline micro-test on every prompt surface that carries the protocol; mechanical/structural edits get deterministic checks:** A1/B1/B3 shape *reviewer* output and B2 shapes the *orchestrator's* dispatch output, so per `writing-skills` each needs a pressure-scenario baseline — and we dogfood A3 (Micro-Test-Wording) and A2 (Match-the-Form-to-the-Failure) to design those tests. Because the reviewer contract is *duplicated* across three surfaces, each reviewer-output baseline (A1/B1/B3) runs against ALL THREE — the canonical Claude skill, the Codex plugin Markdown agent (`plugins/superpowers-bd/agents/*.md`), and the Codex TOML fallback agent (`.codex/agents/*.toml` `developer_instructions`); B2 tests the orchestrator's re-dispatch prompt on the Claude and Codex dispatch paths. grep/`diff` text-parity is necessary but **not sufficient** for behavior-shaping changes (identical clause text in a different surrounding protocol can still behave differently). A4/B7/B9/B5/B6/B8/B11 verify via grep/fixture/`diff`/`shellcheck` plus the Codex semantic suite. This is why A2 and A3 land in Phase 1, before the Phase 2 guardrails they validate.
- **Plan authored on `main`; implementation runs in a worktree via plan2beads → SDD:** the plan is a document (safe on `main`), but the 15 edits should execute in a dedicated worktree through the normal SDD path. The user controls push timing; tasks commit locally only.

---

## Global Constraints

These apply to **every** task below. Do not treat them as optional.

1. **Mirror every skill-content edit.** Any change under `skills/<name>/` must be applied identically to `plugins/superpowers-bd/skills/<name>/`. Gate: `diff -rq skills plugins/superpowers-bd/skills` prints nothing before the task's commit.
2. **Reviewer-contract edits touch all copies.** A change to review behavior must land in the canonical skill *and* every Codex agent that inlines the protocol. The per-role file sets are enumerated in the File Structure table; never edit only the skill.
3. **plan2beads edits touch both parsers.** Any new plan section that must survive import is added to `commands/plan2beads.md` (Claude) **and** `skills/plan2beads/references/codex-plan2beads-flow.md` (Codex), and the new section is documented in `skills/writing-plans/SKILL.md`.
4. **Keep instruction routing intact.** Skills already encode Claude↔Codex equivalence via "Platform Routing" / the shared-intent table. New instructions must not name a Claude-only tool (`TaskCreate`, `Task`, `Skill`) without the Codex equivalent (`update_plan`, `spawn_agent`, `$skill`).
5. **No silent behavior change to hooks without parity.** If a hook's contract changes, its Codex twin (`hooks/codex-*.sh` + `plugins/superpowers-bd/hooks/codex-*.sh`) and config (`hooks/hooks.json`, `plugins/superpowers-bd/hooks.json`, `.codex/hooks.json`) are reviewed in the same task.
6. **Commit per task, local only.** Each task ends in one focused commit. Do not push, tag, or `bd dolt push` — the user controls that.
7. **No version bump in this plan.** The release (`plugin.json` + `marketplace.json` via `scripts/sync-plugin-version.sh`, `claude plugin tag`) is a separate, user-initiated step after all phases land and tests pass.

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `skills/systematic-debugging/references/rationalizations.md` | A4: hyphenate `Ultrathink`→`Ultra-think` | Modify |
| `plugins/superpowers-bd/skills/systematic-debugging/references/rationalizations.md` | A4 mirror | Modify |
| `skills/writing-skills/references/bulletproofing.md` | A2: "Match the Form to the Failure" section | Modify |
| `plugins/superpowers-bd/skills/writing-skills/references/bulletproofing.md` | A2 mirror | Modify |
| `skills/writing-skills/references/tdd-for-skills.md` | A3: "Micro-Test Wording" section | Modify |
| `plugins/superpowers-bd/skills/writing-skills/references/tdd-for-skills.md` | A3 mirror | Modify |
| `skills/using-superpowers/SKILL.md` | B10: instruction-priority hierarchy | Modify |
| `plugins/superpowers-bd/skills/using-superpowers/SKILL.md` | B10 mirror | Modify |
| `skills/writing-plans/SKILL.md` | B5/B6/B11: Global Constraints block, per-task Interfaces, right-sizing line | Modify |
| `plugins/superpowers-bd/skills/writing-plans/SKILL.md` | B5/B6/B11 mirror | Modify |
| `skills/subagent-driven-development/spec-reviewer-prompt.md` | A1 skepticism+read-only; B1 CANNOT_VERIFY | Modify |
| `plugins/superpowers-bd/skills/subagent-driven-development/spec-reviewer-prompt.md` | A1/B1 mirror | Modify |
| `skills/subagent-driven-development/SKILL.md` | B1 Review Rules; B2 no-prejudge guardrail; B4 pre-flight conflict scan | Modify |
| `plugins/superpowers-bd/skills/subagent-driven-development/SKILL.md` | B1/B2/B4 mirror | Modify |
| `skills/requesting-code-review/code-reviewer.md` | A1 skepticism+read-only; B3 plan-mandated-defect tripwire | Modify |
| `plugins/superpowers-bd/skills/requesting-code-review/code-reviewer.md` | A1/B3 mirror | Modify |
| `plugins/superpowers-bd/agents/code-reviewer.md` | Codex reviewer (inlined protocol) — A1/B3 | Modify |
| `.codex/agents/code-reviewer.toml` | Codex reviewer fallback — A1/B3 | Modify |
| `plugins/superpowers-bd/agents/spec-reviewer.md` | Codex spec reviewer (inlined protocol) — A1/B1 | Modify |
| `.codex/agents/spec-reviewer.toml` | Codex spec reviewer fallback — A1/B1 | Modify |
| `skills/rule-of-five-plans/SKILL.md` | B8: check Global Constraints/Interfaces present + propagated | Modify |
| `plugins/superpowers-bd/skills/rule-of-five-plans/SKILL.md` | B8 mirror | Modify |
| `commands/plan2beads.md` | B5/B6/B7: parse + propagate Global Constraints + Interfaces (Claude parser) | Modify |
| `skills/plan2beads/references/codex-plan2beads-flow.md` | B5/B6/B7: same parse + propagate (Codex parser) | Modify |
| `plugins/superpowers-bd/skills/plan2beads/references/codex-plan2beads-flow.md` | B5/B6/B7 mirror | Modify |
| `skills/plan2beads/SKILL.md` | B7: note new optional sections in shared rules | Modify |
| `plugins/superpowers-bd/skills/plan2beads/SKILL.md` | B7 mirror | Modify |
| `hooks/verdict-audit.sh` | B1: confirm-only (gates `NO_VERDICT`, accepts `CANNOT_VERIFY`); no change expected | Verify |
| `hooks/codex-verdict-audit.sh` | B1: same confirm-only check on Codex side | Verify |
| `plugins/superpowers-bd/hooks/codex-verdict-audit.sh` | B1: mirror of codex-verdict-audit.sh — if hook needs a CANNOT_VERIFY accept-set change, this must match (Global Constraint 5) | Verify/Modify |
| `hooks/task-completed.sh` | B9: fix both SC2034 warnings (lines 10, 24) before linting | Modify |
| `scripts/lint-shell.sh` | B9: shellcheck wrapper over all hook scripts | Create |
| `tests/shell-lint/test-lint-shell.sh` | B9: asserts lint-shell.sh runs clean | Create |
| `tests/claude-code/fixtures/plan-constraints-interfaces.md` | B7: fixture plan with Global Constraints + Interfaces | Create |
| `tests/claude-code/test-plan2beads-metadata.sh` | B5/B6/B7: asserts sections survive import to beads (Claude behavioral round-trip) | Create |
| `tests/codex/test-codex-workflow-semantics.sh` | B5/B6/B7: Codex-side assertions that `codex-plan2beads-flow.md` parses + propagates the new sections | Modify |

> Note: confirmed via `shellcheck --severity=warning` — both SC2034 warnings are in `hooks/task-completed.sh` (line 10 `PLUGIN_ROOT`, line 24 `task_id`). `link-plugin-components.sh` also has lower-severity SC2016/SC2295 *notes* (the SC2016 single-quote ones are intentional `$VAR` literals); `lint-shell.sh` gates at warning severity, so those notes are reported but do not fail the run. `shellcheck` is installed at `/opt/homebrew/bin/shellcheck`.

---

## Phase 1 — Clean adopts (independent, no fork coupling)

These are additive and mutually independent. A2 and A3 land here because Phase 2 uses their methodology.

### Task 1: A4 — Hyphenate the `Ultrathink` keyword
**Depends on:** None
**Complexity:** simple
**Files:**
- Modify: `skills/systematic-debugging/references/rationalizations.md` (the line containing `"Ultrathink this"`)
- Modify: `plugins/superpowers-bd/skills/systematic-debugging/references/rationalizations.md` (same line)

**Purpose:** The literal un-hyphenated string `Ultrathink` is the exact keyword Claude Code scans for to auto-enable extended thinking; whenever this reference loads it silently forces extended thinking. Upstream fixed the identical bug (#1283) by inserting a hyphen.

**Not In Scope:** Any other rationalization wording; the surrounding bullet's meaning is unchanged.

**Step 1 — RED (prove the bug exists):** `grep -rnE 'Ultrathink' skills plugins/superpowers-bd/skills` → expect exactly 2 hits (canonical + mirror).
**Step 2 — Fix:** In both files, change `Ultrathink this` to `Ultra-think this` (one character; semantics unchanged — it's a rationalization label, not an instruction).
**Step 3 — GREEN:** `grep -rnE 'Ultrathink' skills plugins/superpowers-bd/skills commands agents` → expect **0** hits. Then `grep -rn 'Ultra-think' skills plugins/superpowers-bd/skills` → expect 2 hits.
**Step 4 — Mirror gate:** `diff -rq skills plugins/superpowers-bd/skills` → empty.
**Step 5 — Commit:** `git commit -m "fix: hyphenate Ultrathink keyword in systematic-debugging rationalizations (A4)"`

### Task 2: A2 — "Match the Form to the Failure" in bulletproofing
**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/writing-skills/references/bulletproofing.md` (append a section)
- Modify: `plugins/superpowers-bd/skills/writing-skills/references/bulletproofing.md` (mirror)

**Purpose:** Give skill authors a classifier: prohibition lists backfire on *output-shaping* problems (upstream measured this as worse than a no-guidance control); use positive recipes there, reserve prohibitions for discrete-action failures.

**Not In Scope:** Rewriting existing bulletproofing guidance; this is additive with a scope caveat.

**Step 1 — Read current state:** Read `bulletproofing.md`; find the section ordering and the spot where failure-mode classification belongs.
**Step 2 — Add section** "Match the Form to the Failure": (a) distinguish *discrete-action* failures (skipping a step, calling the wrong tool — prohibitions work) from *output-shaping* failures (tone, verbosity, format — prohibitions backfire); (b) for output-shaping, give a positive recipe / worked example instead of a "do not" list; (c) cite the measured result (prohibition worse than no-guidance control) as the rationale; (d) cross-reference A3's micro-test as the way to tell which failure class you have.
**Step 3 — Verify content:** `grep -n "Match the Form to the Failure" skills/writing-skills/references/bulletproofing.md`.
**Step 4 — Mirror gate:** `diff -rq skills plugins/superpowers-bd/skills` → empty.
**Step 5 — Commit:** `git commit -m "docs(writing-skills): add Match the Form to the Failure to bulletproofing (A2)"`

### Task 3: A3 — "Micro-Test Wording" in tdd-for-skills
**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/writing-skills/references/tdd-for-skills.md` (append a section)
- Modify: `plugins/superpowers-bd/skills/writing-skills/references/tdd-for-skills.md` (mirror)

**Purpose:** A cheap pre-filter before full eval scenarios: a no-guidance control, 5+ reps, read every match by hand, and treat output **variance** as a metric (not just pass/fail).

**Not In Scope:** Replacing the existing RED-GREEN-REFACTOR skill-testing flow; this is a lightweight pre-step.

**Step 1 — Read current state:** Read `tdd-for-skills.md`; locate where a pre-eval "is this even the right failure?" check fits.
**Step 2 — Add section** "Micro-Test Wording": no-guidance control run; ≥5 reps; read each transcript by hand (don't grep-and-trust); record variance as a signal that wording matters; pairs with A2's classifier (high variance + output-shaping ⇒ use a positive recipe).
**Step 3 — Verify content:** `grep -n "Micro-Test Wording" skills/writing-skills/references/tdd-for-skills.md`.
**Step 4 — Mirror gate:** `diff -rq skills plugins/superpowers-bd/skills` → empty.
**Step 5 — Commit:** `git commit -m "docs(writing-skills): add Micro-Test Wording to tdd-for-skills (A3)"`

### Task 4: B10 — Instruction-priority hierarchy in using-superpowers
**Depends on:** None
**Complexity:** standard
**Files:**
- Modify: `skills/using-superpowers/SKILL.md` (extend the "User Instructions" section)
- Modify: `plugins/superpowers-bd/skills/using-superpowers/SKILL.md` (mirror)

**Purpose:** State that on a *direct conflict*, user instructions outrank skills — amplified for this fork because we inject a forceful skill-use mandate every session. Must reconcile with the existing "Instructions say WHAT, not HOW" note so the two don't appear to contradict.

**Not In Scope:** Weakening the "1% chance ⇒ invoke the skill" rule; the hierarchy governs *conflict resolution*, not whether to check for skills.

**Gotchas:** The existing "User Instructions" block says instructions are WHAT not HOW. The hierarchy must clarify: skills still own HOW *unless the user directly overrides a specific step*. List level-1 authority as the user's direct instructions plus `CLAUDE.md` (Claude) / `AGENTS.md` (Codex) — name both files so the rule reads first-class on each surface.
**Step 1 — Read current state:** Read the "User Instructions" + "Skill Types" sections of `using-superpowers/SKILL.md`.
**Step 2 — Add a short "Priority on conflict" hierarchy:** (1) direct user instruction / `CLAUDE.md` / `AGENTS.md`; (2) rigid skills (TDD, debugging discipline); (3) flexible skill guidance — with one line reconciling it against WHAT-not-HOW.
**Step 3 — Verify content + routing:** `grep -n "AGENTS.md" skills/using-superpowers/SKILL.md` (proves Codex named) and confirm no Claude-only tool is referenced without its Codex twin.
**Step 4 — Mirror gate:** `diff -rq skills plugins/superpowers-bd/skills` → empty.
**Step 5 — Commit:** `git commit -m "docs(using-superpowers): add instruction-priority hierarchy (B10)"`

### Task 5: B11 — Task right-sizing heuristic in writing-plans
**Depends on:** None
**Complexity:** simple
**Files:**
- Modify: `skills/writing-plans/SKILL.md` (one line under "Bite-Sized Task Granularity")
- Modify: `plugins/superpowers-bd/skills/writing-plans/SKILL.md` (mirror)

**Purpose:** One-line splitting heuristic — "split only where a reviewer could reject one task while approving its neighbor."

**Not In Scope:** Changing the existing bite-sized granularity guidance; this is a one-line addition.
**Step 1 — Read current state:** Read the "Bite-Sized Task Granularity" section.
**Step 2 — Add the heuristic line.**
**Step 3 — Verify:** `grep -n "approving its neighbor" skills/writing-plans/SKILL.md`.
**Step 4 — Mirror gate:** `diff -rq skills plugins/superpowers-bd/skills` → empty.
**Step 5 — Commit:** `git commit -m "docs(writing-plans): add task right-sizing heuristic (B11)"`

---

## Phase 2 — Reviewer-discipline guardrails (high coupling; validated with A2/A3 method)

These edit the **duplicated reviewer contract**. Each touches the canonical skill **and** the Codex agent copies (Markdown plugin agent + TOML fallback). They share files (`spec-reviewer-prompt.md`, `requesting-code-review/code-reviewer.md`, SDD `SKILL.md`), so run them in order to avoid conflicts. Each behavioral edit carries a RED baseline micro-test (per A3) and prefers a positive recipe over a prohibition where it shapes output (per A2). Reviewer-output edits (A1/B1/B3) run that baseline on all THREE prompt surfaces — Claude skill, Codex Markdown agent, Codex TOML fallback; B2 shapes the orchestrator's output, so it tests the generated re-dispatch prompt instead.

### Task 6: A1 — Reviewer skepticism of design rationales + explicit read-only
**Depends on:** Task 2 (A2), Task 3 (A3)
**Complexity:** complex
**Files:**
- Modify: `skills/subagent-driven-development/spec-reviewer-prompt.md` (+ mirror)
- Modify: `skills/requesting-code-review/code-reviewer.md` (+ mirror)
- Modify: `plugins/superpowers-bd/agents/code-reviewer.md` (Codex MD — inlined protocol)
- Modify: `.codex/agents/code-reviewer.toml` (Codex TOML fallback)
- Modify: `plugins/superpowers-bd/agents/spec-reviewer.md` (Codex MD — inlined protocol)
- Modify: `.codex/agents/spec-reviewer.toml` (Codex TOML fallback)

**Purpose:** Add (1) a skepticism clause — "a stated rationale ('left it per YAGNI') is the implementer grading their own work; it never downgrades a finding" — and (2) an explicit read-only clause. Load-bearing because our spec reviewers can route to cheaper models, exactly where upstream measured reviewers advocating *for* defects.

**Not In Scope:** Changing severity levels or the precision gate; only adding the rationale-skepticism and read-only clauses.

**Gotchas:** The Claude `agents/code-reviewer.md` is a thin shell that reads `skills/requesting-code-review/code-reviewer.md` — do **not** add the clause there; editing the skill propagates to Claude. The Codex `.md`/`.toml` agents inline the protocol and must each get the clause. Confirm the `.toml` files actually carry protocol prose (vs. just metadata) before editing; if a `.toml` only points at the skill, skip it and note so.
**Step 1 — RED baseline (A3 micro-test), ALL THREE prompt surfaces:** Construct a minimal review scenario where the diff contains a real defect accompanied by a plausible rationale comment ("intentionally skipped validation per YAGNI"). Run it 5× against EACH reviewer prompt surface separately — (a) the canonical Claude skill (`skills/requesting-code-review/code-reviewer.md` + `spec-reviewer-prompt.md`), (b) the Codex plugin Markdown agent (`plugins/superpowers-bd/agents/{code-reviewer,spec-reviewer}.md`), and (c) the Codex TOML fallback agent (`.codex/agents/{code-reviewer,spec-reviewer}.toml` `developer_instructions` block) — with no extra guidance; record per-surface how often the rationale suppresses the finding. Each surface carries its own copy of the protocol and can behave differently even with identical clause text, so each gets its own baseline.
**Step 2 — Add clauses** (positive recipe form per A2): in `skills/requesting-code-review/code-reviewer.md` and `spec-reviewer-prompt.md`, add the rationale-skepticism sentence and a one-line read-only clause. Phrase as a recipe ("treat any in-diff justification as the author's self-assessment; verify against the requirement regardless") not a bare prohibition.
**Step 3 — Propagate to Codex agents:** apply the same two clauses to `plugins/superpowers-bd/agents/{code-reviewer,spec-reviewer}.md` and `.codex/agents/{code-reviewer,spec-reviewer}.toml`.
**Step 4 — GREEN, ALL THREE surfaces:** re-run the Step 1 scenario 5× against EACH updated surface (Claude skill, Codex Markdown agent, Codex TOML `developer_instructions`); the finding must survive the rationale in the large majority of reps on ALL THREE. Record per-surface before/after in the commit body. **Behavioral parity, not just text parity, is the bar.**
**Step 5 — Structural parity gate (complements Step 4, does not replace it):** `diff -rq skills plugins/superpowers-bd/skills` empty; `grep -rn` a distinctive phrase across `skills`, `plugins/superpowers-bd/agents`, `.codex/agents` to confirm the clause landed in all six files; `./tests/verification/test-plugin-config-drift.sh` passes (no agent/surface drift).
**Step 6 — Commit:** `git commit -m "feat(review): reviewers stay skeptical of in-diff rationales + read-only (A1)"`

### Task 7: B3 — Plan-mandated-defect tripwire
**Depends on:** Task 6
**Complexity:** standard
**Files:**
- Modify: `skills/requesting-code-review/code-reviewer.md` (+ mirror)
- Modify: `plugins/superpowers-bd/agents/code-reviewer.md`
- Modify: `.codex/agents/code-reviewer.toml`

**Purpose:** "A plan-mandated defect is still a finding." When the plan itself requires something the reviewer judges defective, the reviewer must surface it and route to a human decision (beads `bd human` / PENDING_HUMAN) rather than silently auto-fixing against the plan or silently approving.

**Not In Scope:** SDD orchestration changes; this is reviewer-side judgment only. Does not change how the orchestrator dispatches.

**Gotchas:** Put it in the self-read methodology (`skills/requesting-code-review/code-reviewer.md`) so it's paraphrase-immune for Claude, then mirror into the Codex copies. Reconcile with the precision gate — a plan-mandated defect still needs concrete evidence; it is not a license to flag style.
**Step 1 — RED baseline, ALL THREE prompt surfaces:** review scenario where the plan explicitly mandates an approach that introduces a real defect; run it 5× against EACH surface separately — the Claude skill `code-reviewer.md`, the Codex plugin Markdown `plugins/superpowers-bd/agents/code-reviewer.md`, and the Codex TOML fallback `.codex/agents/code-reviewer.toml` `developer_instructions`; record per-surface how often it rubber-stamps "matches the plan."
**Step 2 — Add the tripwire** in `code-reviewer.md` (recipe form): flag it as a finding, cite evidence, and recommend routing to a human decision instead of auto-fixing against the plan.
**Step 3 — Propagate** to `plugins/superpowers-bd/agents/code-reviewer.md` and `.codex/agents/code-reviewer.toml`.
**Step 4 — GREEN, ALL THREE surfaces:** re-run 5× on each updated surface; the reviewer must surface the plan-mandated defect on the Claude skill, the Codex Markdown agent, AND the Codex TOML fallback.
**Step 5 — Structural parity gate (complements Step 4):** `diff -rq` empty; `grep -rn` distinctive phrase in all three files (skill + Codex `.md` + `.toml`); `./tests/verification/test-plugin-config-drift.sh` passes.
**Step 6 — Commit:** `git commit -m "feat(review): plan-mandated defect is still a finding → route to human (B3)"`

### Task 8: B1 — CANNOT_VERIFY review channel
**Depends on:** Task 6
**Complexity:** complex
**Files:**
- Modify: `skills/subagent-driven-development/spec-reviewer-prompt.md` (+ mirror)
- Modify: `skills/subagent-driven-development/SKILL.md` (Review Rules section) (+ mirror)
- Modify: `plugins/superpowers-bd/agents/spec-reviewer.md`
- Modify: `.codex/agents/spec-reviewer.toml`
- Verify: `hooks/verdict-audit.sh`, `hooks/codex-verdict-audit.sh`, `plugins/superpowers-bd/hooks/codex-verdict-audit.sh` (no change expected; if a change is needed, all three update together per Global Constraint 5)

**Purpose:** Under waves, issue N's reviewer legitimately cannot see sibling issue M's code. Add a `CANNOT_VERIFY` verdict channel so the reviewer can flag "this depends on code outside my diff" instead of guessing PASS/FAIL; the orchestrator resolves it against `wave_file_map`/receipts before close.

**Not In Scope:** Changing the existing PASS/FAIL semantics for verifiable findings; CANNOT_VERIFY is an *additional* channel, not a replacement.

**Gotchas:** `hooks/verdict-audit.sh` gates only the literal `NO_VERDICT`; a new `CANNOT_VERIFY` value passes the existing check unmodified — **confirm this by reading the hook** rather than assuming, and confirm `hooks/codex-verdict-audit.sh` and its plugin mirror `plugins/superpowers-bd/hooks/codex-verdict-audit.sh` do the same (Global Constraint 5: all three update together if any needs a change). The orchestrator-side resolution step (SDD SKILL Review Rules) is where CANNOT_VERIFY is reconciled before a task can close.
**Step 1 — Confirm hook behavior:** Read `hooks/verdict-audit.sh`, `hooks/codex-verdict-audit.sh`, and `plugins/superpowers-bd/hooks/codex-verdict-audit.sh`; verify each gates only `NO_VERDICT` and will accept `CANNOT_VERIFY`. Record evidence. If any gates more strictly, add CANNOT_VERIFY to the accept set in that hook and its mirror (Global Constraint 5 — all three update together) and note it.
**Step 2 — RED baseline, ALL THREE spec-reviewer surfaces:** Construct two scenarios. (a) POSITIVE — a spec reviewer's diff implements behavior that depends on a sibling task's symbol/file NOT in the diff (e.g., it calls a function defined in sibling issue M); the correct verdict is `CANNOT_VERIFY` naming the missing sibling. (b) NEGATIVE / guardrail — a fully self-contained diff that contains a real defect; `CANNOT_VERIFY` must NOT be used as an escape hatch (correct verdict is FAIL). Run each scenario 5× against the *current* spec-reviewer prompt on all three surfaces — Claude skill (`spec-reviewer-prompt.md`), Codex Markdown (`plugins/superpowers-bd/agents/spec-reviewer.md`), Codex TOML (`.codex/agents/spec-reviewer.toml` `developer_instructions`). Baseline: with no CANNOT_VERIFY channel today, the positive case forces a guessed PASS/FAIL — record that per surface.
**Step 3 — Add the verdict** to `spec-reviewer-prompt.md`: define when to emit `VERDICT: CANNOT_VERIFY` (finding depends on code/state outside the reviewed diff), what evidence to include (which sibling file/symbol it needs), and the explicit guardrail that it is NOT for dodging in-diff findings.
**Step 4 — Add orchestrator resolution** to SDD `SKILL.md` Review Rules: on CANNOT_VERIFY, the orchestrator checks `wave_file_map`/receipts; resolve to PASS if the dependency is satisfied by a closed sibling, else hold the task and re-review after the sibling lands. A task may not close on an unresolved CANNOT_VERIFY.
**Step 5 — Propagate** to `plugins/superpowers-bd/agents/spec-reviewer.md` and `.codex/agents/spec-reviewer.toml`.
**Step 6 — GREEN, ALL THREE surfaces:** re-run both scenarios 5× on each surface; the positive case must emit `CANNOT_VERIFY` (naming the sibling) and the negative case must still emit `FAIL` (no over-emission) on all three. Record per-surface before/after.
**Step 7 — Mirror + parity gate:** `diff -rq` empty; `./tests/verification/test-plugin-config-drift.sh` passes; CANNOT_VERIFY present in spec-reviewer (all three surfaces) and resolution present in SDD SKILL (both surfaces).
**Step 8 — Commit:** `git commit -m "feat(sdd): add CANNOT_VERIFY review channel resolved against wave_file_map (B1)"`

### Task 9: B2 — No-prejudge guardrail (orchestrator must not coach reviewers)
**Depends on:** Task 8
**Complexity:** standard
**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (Guardrails) (+ mirror)

**Purpose:** Forbid the orchestrator from injecting prejudgments into reviewer dispatch ("do not flag X", "Minor at most", "the plan already chose this"). Protects N-reviewer independence. Our real injection surface is **fix-redispatch addenda and gap-fix task descriptions**, not the initial dispatch — so the guardrail lives where those are written.

**Not In Scope:** The initial implementer dispatch (which legitimately carries scope); this targets review/re-review dispatch only.

**Gotchas:** Per A2, frame this as a *positive recipe* where possible since it shapes dispatch output: "dispatch reviewers with the diff + requirements only; route your own concerns to the resolution step, not into the reviewer's prompt." A pure prohibition list is the failure mode A2 warns about.
**Step 1 — Locate** the fix-redispatch / gap-fix description guidance in SDD `SKILL.md`.
**Step 2 — RED baseline (orchestrator-side):** Scenario — a finding was just fixed and the orchestrator must write a review re-dispatch. Run the *current* SDD re-dispatch guidance 5× and record how often the generated re-dispatch prompt leaks a prejudgment ("minor at most", "the plan already chose this", "don't flag X"). Unlike A1/B1/B3 this edit shapes the *orchestrator's* output, not a reviewer's, so the surface is SDD `SKILL.md` itself (one actor) exercised on both dispatch paths — Claude (`Task`/`TaskCreate`) and Codex (`spawn_agent`).
**Step 3 — Add the guardrail** in recipe form at that surface ("dispatch reviewers with diff + requirements only; route your concerns to the resolution step, not into the reviewer's prompt").
**Step 4 — GREEN:** re-run the scenario 5× on both dispatch paths; the generated re-dispatch must carry only diff + requirements, no prejudgment. Record before/after.
**Step 5 — Verify content + routing:** `grep -n` distinctive phrase; confirm Codex equivalence (no Claude-only tool named).
**Step 6 — Mirror gate:** `diff -rq` empty.
**Step 7 — Commit:** `git commit -m "feat(sdd): no-prejudge guardrail on review re-dispatch (B2)"`

---

## Phase 3 — Plan→beads metadata propagation (chain: B7 → B5/B6 → B8)

### Task 10: B7 — Extend the plan2beads parser contract (ENABLER)
**Depends on:** Task 5
**Complexity:** complex
**Files:**
- Modify: `commands/plan2beads.md` (Claude parser: parse-elements + parsing-rules)
- Modify: `skills/plan2beads/references/codex-plan2beads-flow.md` (Codex parser) (+ mirror)
- Modify: `skills/plan2beads/SKILL.md` (shared rules: note new optional sections) (+ mirror)
- Modify: `skills/writing-plans/SKILL.md` (header contract: declare the sections are parseable) (+ mirror)
- Create: `tests/claude-code/fixtures/plan-constraints-interfaces.md`
- Create: `tests/claude-code/test-plan2beads-metadata.sh`
- Modify: `tests/codex/test-codex-workflow-semantics.sh` (add Codex-side assertions that `codex-plan2beads-flow.md` parses + propagates the new sections — already registered in `tests/codex/run-tests.sh`)

**Purpose:** Teach the parser (both surfaces) to recognize new plan sections so they survive the markdown→beads import instead of being silently dropped. This is the enabler for B5 and B6; it ships the *parse* capability with a fixture + test, backward-compatible (sections optional).

**Not In Scope:** Actually defining the Global Constraints / Interfaces blocks in writing-plans (that's B5/B6) — B7 only makes the parser *able* to carry them. Keep the parse additive: plans without the new sections import exactly as today.

**Gotchas:** Both parsers must agree. The Claude path gets a behavioral round-trip test (`test-plan2beads-metadata.sh` actually imports to beads and checks child-task bodies); the Codex path gets **runnable** semantic assertions in `tests/codex/test-codex-workflow-semantics.sh` (already in `tests/codex/run-tests.sh`) confirming `codex-plan2beads-flow.md` documents the same parse+propagate contract — the live Codex round-trip isn't in the harness, so a static gate is the realistic Codex equivalent, matching the existing assertions at that test's lines ~152–158. Backward-compat is a hard requirement — an existing plan with neither section must produce the same beads epic as before. (The `codex-plan2beads-flow.md` mirror is *already* gated byte-identical by both `test-plugin-config-drift.sh` and `test-codex-workflow-semantics.sh` — keep it in sync or those tests fail.)
**Step 1 — RED:** Write `tests/claude-code/fixtures/plan-constraints-interfaces.md` (a tiny plan with a `## Global Constraints` block and a task carrying `**Interfaces:**`). Write `tests/claude-code/test-plan2beads-metadata.sh` asserting that after import, the constraints text appears in each child task body and the Interfaces lines appear in their task body. Run it → FAIL (parser drops them today).
**Step 2 — Extend Claude parser** (`commands/plan2beads.md`): add to "Parse elements" and "Parsing Rules" the recognition of `## Global Constraints` and per-task `**Interfaces:**` (Consumes/Produces), marked optional.
**Step 3 — Extend Codex parser** (`codex-plan2beads-flow.md` + mirror) identically.
**Step 4 — Update header contract** (`writing-plans/SKILL.md`): document that these sections, when present, are preserved through import.
**Step 5 — GREEN (both surfaces):** run `tests/claude-code/test-plan2beads-metadata.sh` → PASS (Claude behavioral round-trip). Add the Codex assertions, then `bash tests/codex/test-codex-workflow-semantics.sh` → PASS (Codex parser documents parse+propagate). Run an existing plan2beads test (or import a section-less fixture) → unchanged (backward-compat).
**Step 6 — Mirror + parity gate:** `diff -rq` empty; `./tests/verification/test-plugin-config-drift.sh` passes (codex flow mirror byte-identical).
**Step 7 — Commit:** `git commit -m "feat(plan2beads): parse optional Global Constraints + Interfaces on both surfaces (B7)"`

### Task 11: B5 — Global Constraints block, threaded into every child task
**Depends on:** Task 10
**Complexity:** standard
**Files:**
- Modify: `skills/writing-plans/SKILL.md` (define the `## Global Constraints` block) (+ mirror)
- Modify: `commands/plan2beads.md` (append constraints verbatim to each child task body)
- Modify: `skills/plan2beads/references/codex-plan2beads-flow.md` (same) (+ mirror)

**Purpose:** A constraint buried in the epic body isn't guaranteed inside an implementer's ~30-line read window. Define a `## Global Constraints` block in writing-plans and have plan2beads append it verbatim to each `temp/{epic}-task-{n}.md`. Upstream shipped this after a real `go 1.26.1` floor violation. (This plan dogfoods it.)

**Not In Scope:** Per-task interface signatures (that's B6).

**Gotchas:** "Append verbatim to each child task" must not duplicate into the epic description in a way that double-prints; define one canonical placement. Keep it short — it's injected N times.
**Step 1 — RED:** extend the B7 fixture/test (or add a case) asserting the Global Constraints text appears in *every* child task body, not just the epic.
**Step 2 — Define the block** in `writing-plans/SKILL.md` (template + guidance: short, applies to all tasks).
**Step 3 — Teach propagation** in both parsers: append the block verbatim to each child task body file.
**Step 4 — GREEN (both surfaces):** Claude test passes (constraints in every child task); extend the Codex assertion in `tests/codex/test-codex-workflow-semantics.sh` to confirm `codex-plan2beads-flow.md` documents appending the block to every child task → `bash tests/codex/test-codex-workflow-semantics.sh` PASS.
**Step 5 — Mirror gate:** `diff -rq` empty; `./tests/verification/test-plugin-config-drift.sh` passes.
**Step 6 — Commit:** `git commit -m "feat(plans): Global Constraints block threaded into every child task (B5)"`

### Task 12: B6 — Per-task Interfaces (Consumes/Produces)
**Depends on:** Task 11
**Complexity:** standard
**Files:**
- Modify: `skills/writing-plans/SKILL.md` (add `Interfaces:` to task structure) (+ mirror)
- Modify: `commands/plan2beads.md` (preserve Interfaces in task body like `Files:`)
- Modify: `skills/plan2beads/references/codex-plan2beads-flow.md` (same) (+ mirror)

**Purpose:** Give implementers exact sibling signatures (what a task Consumes / Produces) instead of re-discovering them. Preserved through plan2beads exactly as `## Files` already is.

**Not In Scope:** Auto-consumption / auto-wiring of interfaces by SDD (upstream only proposed that and retracted the cost claim) — frame purely on correctness: the signatures are *recorded* for the implementer, not auto-injected.

**Gotchas:** Frame the value on correctness (fewer mis-integrations), not the retracted "~13 tool-calls saved" number.
**Step 1 — RED:** test asserts a task's `Interfaces: Consumes/Produces` lines survive into its beads task body.
**Step 2 — Add `Interfaces:`** to the writing-plans task structure (optional, alongside Depends on/Complexity/Files).
**Step 3 — Preserve in both parsers** like the `Files:` section.
**Step 4 — GREEN (both surfaces):** Claude test passes; extend + run the Codex assertion in `tests/codex/test-codex-workflow-semantics.sh` confirming `codex-plan2beads-flow.md` preserves Interfaces → PASS.
**Step 5 — Mirror gate:** `diff -rq` empty; `./tests/verification/test-plugin-config-drift.sh` passes.
**Step 6 — Commit:** `git commit -m "feat(plans): per-task Interfaces (Consumes/Produces) preserved through import (B6)"`

### Task 13: B8 — rule-of-five-plans checks for Global Constraints / Interfaces
**Depends on:** Task 11, Task 12
**Complexity:** simple
**Files:**
- Modify: `skills/rule-of-five-plans/SKILL.md` (+ mirror)

**Purpose:** Add checks (Completeness/Feasibility lens) that Global Constraints and per-task Interfaces are present and will propagate. Gated on B5/B6 — skip if those don't land.

**Not In Scope:** New passes; this adds checklist items to existing passes.
**Step 1 — Read** the rule-of-five-plans checklist items.
**Step 2 — Add** two checklist items: Global Constraints block present (when the plan has cross-task constraints); per-task Interfaces present where a task consumes a sibling's output.
**Step 3 — Verify:** `grep -n "Global Constraints" skills/rule-of-five-plans/SKILL.md`.
**Step 4 — Mirror gate:** `diff -rq` empty.
**Step 5 — Commit:** `git commit -m "docs(rule-of-five-plans): check Global Constraints + Interfaces propagation (B8)"`

### Task 14: B4 — Pre-flight cross-issue conflict scan
**Depends on:** Task 9
**Complexity:** standard
**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (INIT/LOADING) (+ mirror)

**Purpose:** Before wave 1, scan the epic's child issues for cross-issue *requirement* contradictions (two tasks specifying incompatible behavior for shared surface); silent when clean. Distinct from — and not a duplicate of — our existing file-conflict detection (which is already ahead of upstream).

**Not In Scope:** File-level conflict detection (already handled by `wave_file_map`); this is requirement-level contradiction only.

**Gotchas:** Must be silent when clean (no noise on every epic). Operates on plan2beads output (child issue bodies), so it reads from beads, not the raw plan.
**Step 1 — Locate** the INIT/LOADING phase in SDD `SKILL.md`.
**Step 2 — Add** a pre-flight step: read child issue bodies, look for contradictory requirements on shared surfaces, surface only if found (route to human), else proceed silently.
**Step 3 — Verify content + routing:** `grep -n` distinctive phrase; confirm Codex equivalence.
**Step 4 — Mirror gate:** `diff -rq` empty.
**Step 5 — Commit:** `git commit -m "feat(sdd): pre-flight cross-issue requirement conflict scan (B4)"`

---

## Phase 4 — Dev tooling (independent)

### Task 15: B9 — Standalone shellcheck wrapper + fix existing warnings
**Depends on:** None
**Complexity:** standard
**Files:**
- Create: `scripts/lint-shell.sh`
- Create: `tests/shell-lint/test-lint-shell.sh`
- Modify: `hooks/task-completed.sh` (fix both SC2034 warnings: line 10 `PLUGIN_ROOT`, line 24 `task_id`)

**Purpose:** A standalone `shellcheck` wrapper over all hook scripts (root Claude hooks, root `codex-*.sh`, and the `plugins/superpowers-bd/hooks/` mirror), runnable manually or in CI — **never** via pre-commit.com (which destroys beads hooks, Issue #3450). Fix the two pre-existing SC2034 warnings so the lint baseline is clean.

**Not In Scope:** A pre-commit hook of any kind; wiring into a CI provider (the script is the deliverable; CI wiring is a later, separate step). No behavior change to the hooks beyond silencing SC2034.

**Gotchas:** SC2034 (unused variable) fixes must not delete a variable that's exported for a sourced context — confirm each is truly unused before removing/prefixing. The wrapper gates at `--severity=warning` so pre-existing SC2016/SC2295 *notes* in `link-plugin-components.sh` (intentional `$VAR` literals / pattern-quoting style) are reported but do not fail the run; a separate later pass can address them. The script must lint all three hook locations (`hooks/*.sh`, `hooks/codex-*.sh`, `plugins/superpowers-bd/hooks/*.sh`).
**Step 1 — Create `scripts/lint-shell.sh`:** discover `hooks/*.sh`, `hooks/codex-*.sh`, `plugins/superpowers-bd/hooks/*.sh`; run `shellcheck --severity=warning` on each; exit non-zero on any warning/error. Make it executable.
**Step 2 — RED:** run `scripts/lint-shell.sh` → expect exactly the 2 SC2034 warnings in `hooks/task-completed.sh:10,24`.
**Step 3 — Fix** both SC2034s in `task-completed.sh` (prefix with `_`, remove, or `# shellcheck disable` with justification — prefer removal/rename if genuinely unused).
**Step 4 — GREEN:** `scripts/lint-shell.sh` → clean exit 0.
**Step 5 — Add test** `tests/shell-lint/test-lint-shell.sh` asserting the wrapper exits 0 on the current tree.
**Step 6 — Commit:** `git commit -m "chore: add scripts/lint-shell.sh and fix SC2034 warnings (B9)"`

---

## Cross-cutting verification (after all phases)

1. **Mirror integrity:** `diff -rq skills plugins/superpowers-bd/skills` → empty.
2. **Keyword bug gone:** `grep -rnE 'Ultrathink' skills plugins commands agents` → 0 hits.
3. **Reviewer contract parity:** each A1/B1/B3 clause present in canonical skill **and** corresponding Codex `.md`/`.toml` agent (grep a distinctive phrase per clause).
4. **plan2beads round-trip:** `tests/claude-code/test-plan2beads-metadata.sh` passes; a section-less plan imports unchanged (backward-compat).
5. **Shell lint clean:** `scripts/lint-shell.sh` exits 0.
6. **Skill suites:** `./tests/claude-code/run-skill-tests.sh` and `./tests/codex/run-tests.sh` pass (or pre-existing failures are documented as unrelated). The Codex suite includes the new plan2beads parse+propagate assertions (B5/B6/B7) via `test-codex-workflow-semantics.sh`.
7. **Cross-agent parity gate:** `./tests/verification/test-plugin-config-drift.sh` passes — the purpose-built "both first-class" gate. It checks Claude/Codex manifest version + identity parity, Claude hook shell-form + `continueOnBlock`, Codex native local agents (`.codex/agents/*.toml`), the Codex plugin-wrapper agents/hooks surfaces, and that each Codex reference (incl. `codex-plan2beads-flow.md`) is byte-identical to its `plugins/superpowers-bd/` mirror.
8. **Manifest validity:** `claude plugin validate .` passes — frontmatter + `hooks.json` schema clean after the skill/agent edits.
9. **No version/release artifacts touched** (plugin.json/marketplace.json unchanged in these phases).

## Execution handoff

- Run in a dedicated worktree (`using-git-worktrees`), not on `main`.
- Convert with `plan2beads`, execute with `subagent-driven-development`.
- Phase 1 tasks are fully parallel-safe. Phase 4 (Task 15) is independent. Phase 2 tasks share reviewer-contract files — sequence Task 6 → {7, 8} → 9 → 14 (B4 is chained after Task 9 because both edit SDD SKILL.md). Phase 3 chain: Task 5 → Task 10 → Task 11 → Task 12 → Task 13 (Task 10 depends on Task 5 because both edit writing-plans/SKILL.md; Task 12 depends on Task 11 because both edit commands/plan2beads.md and codex-plan2beads-flow.md).
- Do not push, tag, or `bd dolt push`; the user controls release timing. A version bump + `claude plugin tag` is a separate follow-up once all suites pass.

---

## Verification Record

### Plan Verification Checklist
| Check | Status | Notes |
|-------|--------|-------|
| Complete | PASS | All 15 labels A1–A4/B1–B11 map 1:1 to 15 tasks |
| Accurate | PASS (fixed) | Live `shellcheck --severity=warning` confirmed both SC2034 in `task-completed.sh:10,24`; corrected phantom 2nd-hook claim + warning-severity gating |
| Commands valid | PASS | `grep`/`diff -rq`/`git`/`shellcheck` runnable; shellcheck at `/opt/homebrew/bin/shellcheck` |
| YAGNI | PASS | Every task serves a stated label |
| Minimal | PASS | No removable tasks; B5/B6 kept separate for clean commits but serialized |
| Not over-engineered | PASS | Edit + mirror + `diff -rq` gate; no new runtime surface |
| Key Decisions documented | PASS | 5 decisions with rationale |
| Context sections present | PASS | Purpose / Not In Scope / Gotchas on tasks |
| File Structure complete | PASS (fixed) | Removed phantom `work-state-anchor.sh` row |

### Rule-of-Five-Plans Passes
| Pass | Status | Changes | Summary |
|------|--------|---------|---------|
| Draft | CLEAN | 0 | All sections present; 15 labels mapped 1:1; verification + handoff exist |
| Feasibility | CLEAN | 0 | All 30 Modify/Verify paths exist (canonical+mirrors); `.codex/agents/*.toml` carry inline protocol; verdict-audit + codex-verdict-audit gate only `NO_VERDICT`; `agents/code-reviewer.md` is a thin shell; DAG has no cycles |
| Completeness | EDITED | 4 | Added missing `plugins/superpowers-bd/hooks/codex-verdict-audit.sh` to Task 8 + File Structure table (Global Constraint 5 hook parity) |
| Risk | EDITED | 4 | Serialized 3 parallel-execution file conflicts: B4→B2 (SDD SKILL.md), B7→B11 (writing-plans SKILL.md), B6→B5 (plan2beads parsers); updated handoff |
| Optimality | EDITED | 1 | Removed stale "B4 parallel" Phase 3 header annotation that contradicted the new B4→B2 ordering |

**Outcome:** 5/5 passes complete, none BLOCKED. Net 9 edits applied by sub-agents + 4 inline checklist fixes. Plan is verified ready.

### Post-verification review (user, 3 findings — all accepted)
| # | Finding | Resolution |
|---|---------|------------|
| 1 | Codex plan2beads coverage not first-class (metadata test was Claude-only) | Added runnable Codex assertions to `tests/codex/test-codex-workflow-semantics.sh` (already in `run-tests.sh`) for B7/B5/B6; wired into each task's GREEN step + File Structure table |
| 2 | Final verification should run the purpose-built parity gate | Added `./tests/verification/test-plugin-config-drift.sh` + `claude plugin validate .` to Cross-cutting verification (and to the reviewer/parser tasks' parity gates) |
| 3 | Reviewer RED/GREEN micro-tests phrased as one prompt run despite duplicated Codex agents | Rewrote Task 6 (A1) and Task 7 (B3) RED/GREEN to run BOTH the Claude prompt path and the Codex inlined-agent path; reframed grep/`diff` as structural-only complement; updated the testing Key Decision |

### Post-verification review round 2 (user, 2 findings — both accepted; +1 proactive)
| # | Finding | Resolution |
|---|---------|------------|
| 4 | Reviewer behavioral tests omitted the Codex TOML fallback agents (`.codex/agents/*.toml` carry their own `developer_instructions`) | Tasks 6 (A1) and 7 (B3) RED/GREEN now run all **three** prompt surfaces — Claude skill, Codex Markdown agent, Codex TOML fallback; Key Decision + Phase 2 intro updated |
| 5 | B1 (CANNOT_VERIFY) is a behavioral reviewer-output change but Task 8 had no RED/GREEN scenario | Added a positive (needs sibling code → emit `CANNOT_VERIFY`) + negative (self-contained defect → must NOT over-emit) scenario across all three spec-reviewer surfaces; restructured Task 8 to 8 steps |
| 6 | (proactive) B2 had the identical gap — behavioral but no RED/GREEN | Added an orchestrator-side re-dispatch-leakage scenario to Task 9 on both dispatch paths; clarified B2 shapes orchestrator (not reviewer) output |
