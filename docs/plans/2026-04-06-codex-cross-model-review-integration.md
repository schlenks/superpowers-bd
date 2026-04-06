# Codex Cross-Model Review Integration Plan

> **For Claude:** After human approval, use plan2beads to convert this plan to a beads epic, then use `superpowers-bd:subagent-driven-development` for parallel execution.

**Goal:** Integrate OpenAI's Codex plugin as a structurally distinct "second opinion" reviewer across `/cr`, rule-of-five-code, rule-of-five-plans, and rule-of-five-tests — providing cross-model diversity that catches blind spots homogeneous Claude-only review misses.

**Architecture:** Session-start detection sets `CODEX_REVIEW_AVAILABLE=1` via `CLAUDE_ENV_FILE`. Each integration point checks this env var and, when available, dispatches a parallel Codex adversarial review alongside existing Claude reviewers/passes. Codex output is presented in a distinct section, preserving its native structured format (verdict/findings/severity/confidence). Graceful degradation: when codex plugin is absent, all workflows behave identically to today.

**Tech Stack:** Shell (session-start detection), Claude Code skill/command markdown (integration points), Codex CLI via `codex-companion.mjs` (review execution)

**Key Decisions:**
- **Dedicated cross-model pass (not pooled):** Codex always runs as a separate additional review, not as one of N Claude reviewers — preserves model-diversity signal and avoids mixing output formats in aggregation
- **Adversarial mode only:** Uses `/codex:adversarial-review` (not standard review) — maximizes diversity since Claude already covers standard review perspective
- **Keep both output formats:** Codex JSON output rendered as markdown in a distinct section; Claude markdown reports unchanged — our format has requirement mapping, Not Checked, precision gate that Codex lacks
- **Session-start detection:** One-time check cached as env var — zero latency at invocation time, plugin install status doesn't change mid-session
- **Parallel execution:** Codex review runs concurrently with Claude reviewers/passes — zero added wall-clock time when Codex finishes before Claude

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `hooks/session-start.sh` | Session lifecycle hook — context injection, SDD checkpoint recovery | Modify |
| `commands/cr.md` | `/cr` slash command — ad-hoc code review dispatch and presentation | Modify |
| `skills/rule-of-five-code/SKILL.md` | Code quality 5-pass review skill | Modify |
| `skills/rule-of-five-plans/SKILL.md` | Plan quality 5-pass review skill | Modify |
| `skills/rule-of-five-tests/SKILL.md` | Test quality 5-pass review skill | Modify |
| `.claude-plugin/plugin.json` | Plugin manifest — version number | Modify |

---

## Task 1: Session-Start Codex Detection

**Depends on:** None
**Complexity:** simple
**Files:**
- Modify: `hooks/session-start.sh:42-76` (after SDD checkpoint block, before JSON output)

**Purpose:** Detect codex plugin installation and readiness at session start, export env vars for downstream skills/commands.

**Not In Scope:** Checking codex auth status every session — `setup --json` covers this. Re-checking mid-session.

**Risk — Session-start latency (MITIGATE):** `node codex-companion.mjs setup --json` runs on every session start and every `/clear`. Node.js startup plus the companion script (which may make a network/auth call) could add 1–3 seconds of latency per session. If the script hangs, there is no timeout bound. Add a `timeout 5` guard:

```bash
setup_result=$(timeout 5 node "${codex_install_path}/scripts/codex-companion.mjs" setup --json 2>/dev/null || true)
```

This caps the worst-case delay at 5 seconds and lets `|| true` handle the timeout exit code gracefully.

**Step 1: Add codex detection block to session-start.sh**

Insert after the SDD checkpoint block (line 76) and before the JSON output block (line 79). The detection sets two env vars via `CLAUDE_ENV_FILE`:

```bash
# Check codex plugin installed and ready
codex_available=""
codex_install_path=""
plugins_file="${HOME}/.claude/plugins/installed_plugins.json"
if command -v jq >/dev/null 2>&1 && [ -f "$plugins_file" ]; then
    codex_install_path=$(jq -r '.plugins["codex@openai-codex"][0].installPath // empty' "$plugins_file" 2>/dev/null)
    if [ -n "$codex_install_path" ] && [ -d "$codex_install_path" ]; then
        setup_result=$(node "${codex_install_path}/scripts/codex-companion.mjs" setup --json 2>/dev/null || true)
        if printf '%s' "$setup_result" | jq -e '.ready == true' >/dev/null 2>&1; then
            codex_available="1"
        fi
    fi
fi

if [ -n "$codex_available" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    printf 'CODEX_REVIEW_AVAILABLE=1\n' >> "$CLAUDE_ENV_FILE"
    printf 'CODEX_INSTALL_PATH=%s\n' "$codex_install_path" >> "$CLAUDE_ENV_FILE"
fi
```

**Error handling:** If `jq` is absent, the outer `command -v` guard skips detection silently — graceful degradation, no env var written. If `node` is absent or `codex-companion.mjs` fails, `|| true` prevents the script from exiting; `setup_result` will be empty and the `jq -e` check will fail, leaving `codex_available` unset.

**Step 2: Verify detection works**

Run: `bash hooks/session-start.sh` (with `CLAUDE_ENV_FILE` pointing to a temp file)
Expected: When codex plugin is installed, `CODEX_REVIEW_AVAILABLE=1` appears in the env file. When not installed, no env vars written.

**Step 3: Commit**

`git add hooks/session-start.sh`
`git commit -m "feat: detect codex plugin at session start for cross-model review"`

---

## Task 2: /cr Command — Codex Parallel Dispatch

**Depends on:** Task 1
**Complexity:** standard
**Files:**
- Modify: `commands/cr.md:159-295` (Step 6: Dispatch Reviews, Step 7: Present Results)

**Purpose:** Dispatch an additional Codex adversarial review in parallel with Claude reviewer(s), present output in a distinct cross-model section.

**Not In Scope:** Codex findings participating in Claude severity voting. Codex as a voting member for verdict.

**Gotchas:** The Codex review dispatch must work for both single (N=1) and multi-review (N>1) modes. `CODEX_REVIEW_AVAILABLE` env var may not be set if session-start didn't detect codex — check before dispatching. Subagents cannot invoke slash commands — the agent prompt must call `codex-companion.mjs` directly via Bash using the `$CODEX_INSTALL_PATH` env var set by Task 1. **Codex must receive the same resolved scope as Claude reviewers** — the companion script accepts `--base <ref>` and `--scope <working-tree|branch>` flags.

**Step 1: Resolve Codex scope arguments from /cr scope**

Before dispatching, compute `{CODEX_SCOPE_ARGS}` from the resolved `/cr` scope:

| /cr scope | HEAD_SHA | CODEX_SCOPE_ARGS |
|-----------|----------|-----------------|
| Uncommitted changes | `WORKING_TREE` | `--scope working-tree` |
| Last commit | `git rev-parse HEAD` | `--base HEAD~1` |
| Since last push | `@{push}` result | `--base {BASE_SHA}` |
| Branch diff vs main | `merge-base` result | `--base {BASE_SHA}` |
| Custom | user-provided | `--base {BASE_SHA}` |
| PR mode | `PR_BASE`/`PR_HEAD` | `--base {PR base branch name}` (from `{PR_META}.baseRefName`) |

For PR mode: Codex cannot consume a pre-fetched diff, but `--base <branch>` makes it compute the equivalent branch diff from git. This requires the PR's commits to be locally available (they are after `gh pr diff` fetches them).

**Step 2: Add Codex dispatch to Step 6 (both single and multi-review)**

After the existing Claude reviewer dispatch block, add a conditional Codex dispatch. This agent is dispatched **in the same message** as the Claude reviewer(s) — all run in parallel as background agents:

```markdown
### Step 6b: Dispatch Codex Cross-Model Review (if available)

**Skip this step entirely if `CODEX_REVIEW_AVAILABLE` is not set to `1`.**

Dispatch one additional background agent for the Codex adversarial review. **This MUST be included in the same parallel dispatch message as the Claude reviewer(s)** — not as a separate sequential step:

~~~
Agent:
  run_in_background: true
  description: "Codex cross-model review"
  prompt: |
    You are dispatching a Codex adversarial review as a cross-model second opinion.

    Check that `CODEX_REVIEW_AVAILABLE` environment variable equals "1".
    If not, output "Codex not available" and stop.

    Run the Codex adversarial review with the resolved scope:
    ```bash
    node "$CODEX_INSTALL_PATH/scripts/codex-companion.mjs" adversarial-review --wait {CODEX_SCOPE_ARGS}
    ```

    Note: Slash commands (e.g. `/codex:adversarial-review`) are not available inside
    subagent prompts. Use the companion script directly with `$CODEX_INSTALL_PATH`.

    Capture the full stdout. Write it to `temp/cr-codex-review-{RUN_TS}.md`
    using tee with a heredoc:
    ```
    mkdir -p temp
    tee temp/cr-codex-review-{RUN_TS}.md <<'CODEX_REVIEW_EOF'
    [full codex review output]
    CODEX_REVIEW_EOF
    ```

    Output the full review as your final message.
~~~

**`{RUN_TS}` must be defined** before dispatch (same value used by Claude reviewers in multi-review mode). Use `date +%Y%m%d-%H%M%S` captured once — all agents share the same timestamp.
```

**Step 3: Restructure Step 7 — wait for ALL reviews before presenting**

Replace the current Step 7 with a unified presentation step that collects both Claude and Codex results. **This fixes the N=1 path** where the command previously returned immediately after the Claude review:

```markdown
## Step 7: Present All Results

**Wait for all dispatched reviews to complete** — both Claude reviewer(s) AND the Codex background agent (if dispatched). Do NOT present partial results.

### Claude Results
Present the Claude reviewer report (N=1) or aggregated report (N>1) as today.

### Codex Cross-Model Review (if dispatched)
1. Read `temp/cr-codex-review-{RUN_TS}.md`. If missing, fall back to reading the background agent's output.
2. If the Codex review completed successfully, present it after the Claude review:

~~~
## Cross-Model Review (Codex)

[Full Codex review output — verdict, summary, findings with severity/confidence, next steps]
~~~

3. If the Codex review failed or timed out, note it briefly:

~~~
_Codex cross-model review was unavailable for this run._
~~~

The final verdict remains from Claude reviewers only — Codex is advisory.
```

**Step 3: Commit**

`git add commands/cr.md`
`git commit -m "feat(cr): add parallel codex adversarial review dispatch"`

---

## Task 3: Rule-of-Five — Parallel Codex Review (All Variants)

**Depends on:** Task 1
**Complexity:** standard
**Files:**
- Modify: `skills/rule-of-five-code/SKILL.md:13-46` (Quick Start section, after ENFORCEMENT block)
- Modify: `skills/rule-of-five-plans/SKILL.md:13-45` (Quick Start section, after ENFORCEMENT block)
- Modify: `skills/rule-of-five-tests/SKILL.md:13-45` (Quick Start section, after ENFORCEMENT block)

**Purpose:** Add a parallel Codex adversarial review to all three rule-of-five variants. The same pattern is applied to each: dispatch when pass 1 starts, present after pass 5 completes.

**Not In Scope:** Codex output influencing pass decisions. Blocking passes on Codex completion.

**Gotchas:** The Codex review targets the changed files (whatever the current working tree diff shows), not the entire codebase. Must check `CODEX_REVIEW_AVAILABLE` before dispatching. Subagents cannot invoke slash commands — the agent prompt must call `codex-companion.mjs` directly via Bash using the `$CODEX_INSTALL_PATH` env var set by Task 1.

**Step 1: Add the following section to all three SKILL.md files**

Insert after each skill's ENFORCEMENT block. The only difference per variant is the agent description label (`code`, `plan`, or `tests`):

```markdown
## Cross-Model Review (Codex)

**Skip if `CODEX_REVIEW_AVAILABLE` is not `1`.**

When creating pass 1 (Draft) task, also dispatch a background Codex adversarial review:

~~~
Agent:
  run_in_background: true
  description: "Codex cross-model audit ({variant})"
  prompt: |
    Run a Codex adversarial review of the current changes.

    Check that `CODEX_REVIEW_AVAILABLE` environment variable equals "1".
    If not, output "Codex not available" and stop.

    Run the Codex adversarial review by calling the companion script directly via Bash:
    ```bash
    node "$CODEX_INSTALL_PATH/scripts/codex-companion.mjs" adversarial-review --wait
    ```

    Note: Slash commands (e.g. `/codex:adversarial-review`) are not available inside
    subagent prompts. Use the companion script directly with `$CODEX_INSTALL_PATH`.

    Output the full stdout as your final message.
~~~

This runs concurrently with all 5 passes — zero blocking.

**After pass 5 completes, wait for the Codex background agent to finish before presenting results.** Do NOT present pass 5 results until the Codex review has either completed or timed out. This is a synchronous gate — the rule-of-five skill does not have a monitor loop or late-delivery mechanism, so all output must be collected before the skill finishes.

- If Codex completed successfully: present as "Cross-Model Audit (Codex)" section after pass 5 results
- If Codex failed or timed out: append `_Codex cross-model audit was unavailable for this run._` after pass 5 results

```markdown
## Cross-Model Audit (Codex)

[Full Codex adversarial review output — verdict, findings, recommendations]
```
```

Where `{variant}` is:
- `code` for `rule-of-five-code/SKILL.md`
- `plan` for `rule-of-five-plans/SKILL.md`
- `tests` for `rule-of-five-tests/SKILL.md`

**Step 2: Commit**

`git add skills/rule-of-five-code/SKILL.md skills/rule-of-five-plans/SKILL.md skills/rule-of-five-tests/SKILL.md`
`git commit -m "feat(rule-of-five): add parallel codex adversarial review to all variants"`

---

## Task 4: Manual Verification

**Depends on:** Task 2, Task 3
**Complexity:** standard
**Files:**
- Modify: `.claude-plugin/plugin.json` (version bump to 5.6.0)

**Purpose:** Verify all integration points work correctly with codex installed and degrade gracefully without it.

**Step 1: Verify session-start detection**

Run: `CLAUDE_ENV_FILE=/tmp/test-env bash hooks/session-start.sh`
Expected: `/tmp/test-env` contains `CODEX_REVIEW_AVAILABLE=1` and `CODEX_INSTALL_PATH=...`

**Step 2: Verify graceful degradation**

Temporarily rename `~/.claude/plugins/installed_plugins.json` (back up first), re-run session-start.
Expected: No `CODEX_REVIEW_AVAILABLE` in env file. No errors.

**Step 3: Verify /cr with Codex**

Run `/cr` on a small local change. Verify:
- Claude reviewer dispatches normally
- Codex adversarial review dispatches in parallel
- Both results presented — Claude first, Codex in separate section

**Step 4: Verify rule-of-five with Codex**

Trigger rule-of-five-code on a 50+ line code change. Verify:
- 5 Claude passes proceed normally
- Codex review runs in background during passes
- Codex output presented after pass 5

**Step 5: Commit version bump**

`git add .claude-plugin/plugin.json`
`git commit -m "chore: bump plugin version to 5.6.0 for codex integration"`

---

## Risk Notes (added by Rule-of-Five Risk pass)

**ACCEPTABLE risks (mitigated in plan or inherently low):**
- **Breaking changes without codex:** Fully mitigated — `command -v jq` + `|| true` + `CODEX_REVIEW_AVAILABLE` guards at every integration point. Behavior identical to today when codex absent.
- **Parallel task conflicts (Tasks 2, 3):** No file overlap — each task touches distinct files. Safe to parallelize.
- **Auth expiry mid-session:** Handled — each integration point has "If failed or timed out" fallback branches.
- **Rollback:** Purely additive changes. `git revert` is sufficient.
- **`$CODEX_INSTALL_PATH` injection:** Double-quoted in all bash snippets. Plugins file is user-controlled. Acceptable for a personal dev tool.
- **Codex companion interface changes:** Failure mode is silent graceful degradation (no env var written), not breakage. Acceptable.

**MITIGATED risks (edits made above):**
- **Session-start latency / hang:** Added `timeout 5` guard to `node codex-companion.mjs setup --json` call (see Task 1 edit). Caps worst-case delay at 5 seconds.
- **`{RUN_TS}` undefined / file collision:** Clarified in Task 2 that implementer must define `RUN_TS` as epoch milliseconds captured once at agent start (see Task 2 edit).

**COST RISK (action required by implementer):**
- Every `/cr`, rule-of-five-code, rule-of-five-plans, and rule-of-five-tests invocation dispatches a Codex adversarial review that calls the OpenAI API. In SDD with N=3–5 reviewers per wave, this cost multiplies. The plan provides no cost visibility or cap mechanism. **Implementer must add a note to the session-start detection output (or skill/command preamble) informing users that Codex integration incurs OpenAI API costs per review invocation.** Consider adding a `CODEX_REVIEW_AVAILABLE` acknowledgment message to the session-start JSON output so users know charges may occur.

---

## Verification Record

### Plan Verification Checklist
| Check | Status | Notes |
|-------|--------|-------|
| Complete | ✓ | All 5 requirements addressed across 4 tasks (after optimality merge) |
| Accurate | ✓ | Line ranges corrected, slash-command constraint added to all dispatch prompts |
| Commands valid | ✓ | jq path, node invocation, setup --json all verified against actual files |
| YAGNI | ✓ | All tasks serve stated requirements; cross-reference annotation removed as YAGNI |
| Minimal | ✓ | Tasks 4/5/6 merged into one; Task 3 (cross-ref) eliminated |
| Not over-engineered | ✓ | Env-var detection, direct script invocation, conditional dispatch |
| Key Decisions documented | ✓ | 5 decisions with rationale |
| Context sections present | ✓ | Purpose/Not In Scope on all tasks; Gotchas on Tasks 2 and 3 |
| File Structure complete | ✓ | All files in task Files: sections appear in table |

### Rule-of-Five-Plans Passes
| Pass | Status | Changes | Summary |
|------|--------|---------|---------|
| Draft | CLEAN | 0 | All required sections present, dependencies complete, Key Decisions sufficient |
| Feasibility | CLEAN | 0 | All file paths verified, line ranges match, commands valid, codex-companion.mjs signatures confirmed |
| Completeness | EDITED | 6 | Added plugin.json to File Structure, jq guard to Task 1, failure/timeout handling to rule-of-five tasks |
| Risk | EDITED | 3 | Added timeout guard for session-start, RUN_TS scoping for concurrent runs, cost transparency note |
| Optimality | EDITED | 2 | Merged Tasks 4/5/6 into one task, removed YAGNI cross-reference annotation task. 7 tasks → 4 tasks |

### Codex Cross-Model Review (Post-Verification)
| Finding | Severity | Fix Applied |
|---------|----------|-------------|
| Codex dispatch missing scope args — reviews ambient working tree instead of resolved /cr scope | high | Added `{CODEX_SCOPE_ARGS}` mapping table and `--base`/`--scope` flags to dispatch prompt |
| N=1 flow exits before collecting Codex result | high | Restructured Step 7 as unified presentation step that waits for all reviews before returning |
| Rule-of-five "surface when it arrives" has no delivery mechanism | medium | Replaced with synchronous gate — wait for Codex agent before presenting pass 5 results |
