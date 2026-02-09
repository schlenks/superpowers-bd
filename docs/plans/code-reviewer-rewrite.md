# Plan: Code-Reviewer Agent Rewrite (v10)

## Context

The code-reviewer agent has two problems: **the prompt is weak** and **the architecture is fragmented**.

**Prompt problem:** The current prompt is a job description, not a procedure. It tells the reviewer what a good reviewer *is* but not what to *do*. It spends attention on noise (SOLID principles, documentation standards, politeness) instead of bug-finding. It lacks the adversarial framing that makes the spec-reviewer effective. Result: it produces surface-level observations while missing real bugs that a human reviewer catches.

**Architecture problem:** Three files contain reviewer instructions with different severity labels, different placeholder names, and different levels of detail. SDD dispatches `general-purpose` subagents with the template, not the agent definition — so the agent definition's hooks, memory, and maxTurns are unused during automated reviews. Named agent dispatch (`Task(subagent_type="superpowers-bd:code-reviewer")`) is treated as non-functional per project testing and policy (Improvements Archive #40, P8).

**Decision:** Consolidate to template (Option B). The canonical reviewer prompt lives in the template file. The agent definition keeps its frontmatter for interactive/manual use but its body matches the template. SDD continues dispatching `general-purpose` with the template.

---

## Tier 1 — Quick Fixes (no architecture decision needed)

### 1.1 Fix placeholder mismatch

**File:** `skills/requesting-code-review/code-reviewer.md`
- Line 18: Change `{PLAN_REFERENCE}` → `{PLAN_OR_REQUIREMENTS}`
- The skill (`skills/requesting-code-review/SKILL.md:38`) tells callers to fill `{PLAN_OR_REQUIREMENTS}`, but the template renders `{PLAN_REFERENCE}`. Unify to `{PLAN_OR_REQUIREMENTS}`.

### 1.2 Unify severity taxonomy

Adopt the aggregation system's 4 levels everywhere: **Critical > Important > Minor > Suggestion**

**Files to change:**
- `agents/code-reviewer.md` line 64: "Suggestions (nice to have)" → align with 4-level system
- `skills/requesting-code-review/code-reviewer.md`: Already uses Critical/Important/Minor. Add Suggestion tier.
- Source of truth: `skills/multi-review-aggregation/SKILL.md` line 91 (Critical > Important > Minor > Suggestion)

**Suggestion suppression rule:** Only include Suggestion-level findings if there are zero Critical, Important, or Minor findings. This prevents noise when real issues exist.

**Note:** Aggregation path (`skills/multi-review-aggregation/`) still processes Suggestions normally. This is benign (reviewers won't emit them when real issues exist), but full alignment belongs in Tier 4.

### 1.3 Add disallowedTools to agent definition

**File:** `agents/code-reviewer.md`
- Add to frontmatter: `disallowedTools: [Write, Edit, NotebookEdit]`
- Same pattern as `agents/epic-verifier.md` line 8-10

---

## Tier 2 — Prompt Rewrite (the main work)

Rewrite the template at `skills/requesting-code-review/code-reviewer.md`. This is the canonical prompt that SDD uses. The agent definition body (`agents/code-reviewer.md`) will be updated to match.

### 2.1 New prompt structure

Replace the current 7-section structure with a procedural methodology:

```
## Identity
You are a code reviewer. Your job is to find bugs, not give compliments.
Assume this code has bugs until you've proven otherwise. Report only what you can back with evidence.

## Methodology (follow in order)

### Step 1: Read the diff
- Run `git diff --stat {BASE_SHA}..{HEAD_SHA}` to see scope
- Run `git diff {BASE_SHA}..{HEAD_SHA}` to see every change
- Record the list of changed files — you will include this in your output

### Step 2: Read each changed file in full
- For EACH changed file, read the entire file (not just the diff hunks)
- Understand what the function/module does, not just what changed

### Step 3: Check requirements coverage
- Read {PLAN_OR_REQUIREMENTS}
- For each requirement, identify which code implements it
- Flag requirements with no corresponding implementation
- Flag code with no corresponding requirement (scope creep)
- Record this mapping — you will include it in your output

### Step 4: Trace data flow per changed function
- For each changed function: what are the inputs? Where do they come from?
- Where is input validated? Where could invalid input cause failure?
- What are the outputs? Who consumes them? Could a consumer break?
- Where are the trust boundaries? (user input, external APIs, file I/O)

### Step 5: Hunt for what's missing
- For each changed function: what error conditions are NOT handled?
- What inputs are NOT validated?
- What edge cases have NO test coverage?
- What happens on empty input, null, maximum size, concurrent access?

### Step 6: Check test quality
- Do tests verify behavior or just call functions?
- Are there assertions for edge cases found in Step 5?
- Do tests use real logic or just mock everything?

### Step 7: Produce findings
- Categorize by severity (see below)
- Every finding must have: file:line, what's wrong, why it matters
- If you found nothing: say what you checked and why you're confident

## Precision Gate

**No finding unless it is tied to at least one of:**
1. A violated requirement (from the plan/spec)
2. A concrete failing input or code path you can describe
3. A missing test for a specific scenario you can name

Speculative "what if" concerns without a demonstrable trigger are NOT findings — note them under Not Checked if relevant.

## Severity Levels

| Level | Meaning | Examples |
|-------|---------|---------|
| Critical | Must fix before merge | Bugs, security flaws, data loss, broken functionality |
| Important | Should fix before merge | Missing error handling, test gaps for likely scenarios, incorrect edge case behavior |
| Minor | Should consider | Missing validation for unlikely inputs, suboptimal patterns, unclear naming |
| Suggestion | Nice to have | Style improvements, minor readability tweaks |

Do NOT inflate severity. A style issue is not Important. A missing null check on internal-only code is not Critical.

Only include Suggestion-level findings if there are zero Critical, Important, or Minor findings.

## Evidence Protocol (mandatory in output)

Your output MUST include these sections. Omitting any is a review failure.

### Changed Files Manifest
List every file in the diff. For each: number of lines changed, whether you read it in full.

### Requirement Mapping
| Requirement | Implementing Code | Status |
|-------------|------------------|--------|
| [from plan] | [file:line] | Implemented / Missing / Partial |

### Uncovered Paths
List specific code paths, error conditions, or scenarios you identified as untested or unhandled.

### Not Checked
List anything you could not verify (e.g., "did not run tests", "could not trace external dependency X"). Honest gaps > false confidence.

**Verdict constraint:** If any Not Checked item covers core behavior, error handling, or security, Ready to merge CANNOT be "Yes." Use "With fixes" and note what still needs verification.

### Findings
[Grouped by severity: Critical, Important, Minor, Suggestion]

Per finding:
- **File:line**
- **What's wrong** — describe the concrete failing path or violated requirement
- **Why it matters**
- **How to fix** (if not obvious)

### Assessment
**Ready to merge?** Yes / With fixes / No
**Reasoning:** [1-2 sentences, technical]

## Rules

**DO:**
- Read every changed file in full before producing findings
- Trace data flow through changed functions
- Explicitly check for what's MISSING, not just what's wrong
- Flag your own uncertainty ("I couldn't verify X") under Not Checked
- Be precise (file:line, not vague hand-waving)
- Tie every finding to a concrete path, requirement, or scenario

**DO NOT:**
- Say "looks good" without evidence of thorough reading
- Spend output on praise — the implementer doesn't need compliments
- Report speculative concerns as findings (use Not Checked instead)
- Flag SOLID violations, scalability concerns, or documentation gaps unless they cause bugs
- Manually count cyclomatic complexity (automated linters handle this)
- Modify any code (you are a reviewer, not an implementer)
- Inflate severity to seem thorough
```

### 2.2 Key differences from current prompt

| Current | New |
|---------|-----|
| 7 aspirational sections | 7 procedural steps |
| "Review code for adherence to patterns" | "Run git diff, read each file, trace data flow" |
| "Always acknowledge strengths first" | "Don't spend output on praise" |
| SOLID principles, scalability, extensibility | Removed (architecture-astronaut noise) |
| Documentation standards, file headers | Removed (contradicts project CLAUDE.md) |
| 50-line complexity metrics section | Removed (linter hook handles this) |
| 3 severity levels | 4 levels (matches aggregation), Suggestion suppressed when real issues exist |
| No evidence requirements | Mandatory: changed files, requirement mapping, uncovered paths, not-checked |
| No adversarial framing | "Assume bugs until proven otherwise. Report only evidence-backed findings." |
| No precision gate | "No finding without violated requirement, concrete failing path, or test evidence" |
| No data flow tracing | Step 4: trace inputs/outputs per function |
| No "what's missing" pass | Step 5: explicit hunt for absences |
| Not Checked is informational only | Not Checked on core/security blocks "Yes" verdict |

---

## Tier 3 — Architecture Unification

### 3.1 Update agent definition body

**File:** `agents/code-reviewer.md`
- Replace the current body (lines 20-76) with the same content as the rewritten template
- Keep the frontmatter (name, memory, description, model, maxTurns, hooks, + new disallowedTools)
- The agent definition serves interactive/manual dispatch; the template serves SDD
- Same prompt content in both → no drift (enforced by automated test, see 3.6)

### 3.2 Update SDD prompt reference

**File:** `skills/subagent-driven-development/code-quality-reviewer-prompt.md`
- Update to reference the rewritten template
- Ensure the "paste contents of..." instruction still works with new structure

### 3.3 Update requesting-code-review skill

**File:** `skills/requesting-code-review/SKILL.md`
- Line 34: Confirm it references the correct template
- Update placeholder documentation to match unified names

### 3.4 Fix stale-copy propagation

**File:** `hooks/link-plugin-components.sh`

The current approach (skip if target exists, lines 101-103 and 129-131) means plugin updates never propagate. A naive source-vs-target hash comparison won't work because the copy process mutates the target (renames `name:` field via `update_name_field`, replaces `$CLAUDE_PLUGIN_ROOT` paths via `fix_plugin_root_paths`).

**Fix: sidecar source-hash tracking.**

For agents (lines 129-131), replace:
```bash
if [[ -f "$target" ]]; then
  continue
fi
```
With:
```bash
local source_hash
source_hash=$(md5 -q "$agent_file" 2>/dev/null || md5sum "$agent_file" | cut -d' ' -f1)
local hash_file="${target}.source-hash"
if [[ -f "$target" && -f "$hash_file" ]]; then
  local stored_hash
  stored_hash=$(cat "$hash_file")
  if [[ "$source_hash" == "$stored_hash" ]]; then
    continue  # Source unchanged, skip
  fi
  # Source changed — will re-copy below
fi
# Note: if target exists but hash_file doesn't (legacy install), fall through
# to re-copy. For agents (single files), cp overwrites safely. Hash file
# gets created after copy, completing the migration.

# ... existing copy + mutate logic ...
# After copy, store the source hash:
echo "$source_hash" > "$hash_file"
```

For skills (lines 101-103), replace:
```bash
if [[ -d "$target" ]]; then
  continue
fi
```
With:
```bash
local source_hash
if md5 -q /dev/null &>/dev/null; then
  source_hash=$(cd "$skill_dir" && LC_ALL=C find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sh -c \
    'for f; do sz=$(wc -c < "$f"); printf "%s\t%d\n" "$f" "$sz"; cat "$f"; done' _ | md5 -q)
else
  source_hash=$(cd "$skill_dir" && LC_ALL=C find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sh -c \
    'for f; do sz=$(wc -c < "$f"); printf "%s\t%d\n" "$f" "$sz"; cat "$f"; done' _ | md5sum | cut -d' ' -f1)
fi
local hash_file="$target/.source-hash"
if [[ -d "$target" && -f "$hash_file" ]]; then
  local stored_hash
  stored_hash=$(cat "$hash_file")
  if [[ "$source_hash" == "$stored_hash" ]]; then
    continue
  fi
  rm -rf "$target"  # Remove stale copy to avoid cp -r nesting
elif [[ -d "$target" ]]; then
  # Legacy target from before hash tracking — treat as stale, remove to prevent nesting
  rm -rf "$target"
fi

# ... existing copy + mutate logic ...
# After copy, store the source hash:
mkdir -p "$target"  # ensure target dir exists for hash file
echo "$source_hash" > "$hash_file"
```

Key details:
- Hash is of the SOURCE file(s), stored as a sidecar next to the mutated target
- Skill hash uses length-framed records (`path<TAB>byte_count<NL>content`) — byte count makes record boundaries unambiguous, preventing collisions from path/content boundary shifts. Assumes filenames contain no tabs or newlines (valid for plugin skill trees; enforced by `find -print0 | sort -z` pipeline which handles NUL-separated paths, not tab/newline-containing names)
- Content streams directly into hash tool via pipe — no shell variable staging, preserving NUL bytes and binary content
- For skills: `rm -rf target` before re-copy prevents directory nesting
- For skills: legacy targets (no hash file) are also removed before re-copy (migration path)
- For agents: legacy targets are safely overwritten by `cp` (single files); hash file is created after copy
- For skills: `LC_ALL=C sort -z` ensures deterministic byte-order hash across platforms and locales
- `.source-hash` files are gitignored (they're in `.claude/` which is already ignored)

### 3.5 Add stale-copy pruning

**File:** `hooks/link-plugin-components.sh`

Add a prune step at the end of `process_plugin()` that removes orphaned copies — entries in `.claude/agents/` and `.claude/skills/` prefixed with the plugin name that no longer have a corresponding source file with hooks.

```bash
# At end of process_plugin(), after processing agents and skills:

# Prune orphaned agent copies
local agents_target_dir="$project_dir/.claude/agents"
if [[ -d "$agents_target_dir" ]]; then
  for target_file in "$agents_target_dir/${plugin_name}:"*.md; do
    [[ -f "$target_file" ]] || continue
    local target_basename
    target_basename=$(basename "$target_file" .md)
    local original_name="${target_basename#${plugin_name}:}"
    local original_path="${original_name//:/\/}"
    local source_file="$agents_dir/${original_path}.md"
    if [[ ! -f "$source_file" ]] || ! has_hooks "$source_file"; then
      rm -f "$target_file" "${target_file}.source-hash"
    fi
  done
fi

# Prune orphaned skill copies
local skills_target_dir="$project_dir/.claude/skills"
if [[ -d "$skills_target_dir" ]]; then
  for target_dir in "$skills_target_dir/${plugin_name}:"*/; do
    [[ -d "$target_dir" ]] || continue
    local target_basename
    target_basename=$(basename "$target_dir")
    local original_name="${target_basename#${plugin_name}:}"
    local original_path="${original_name//:/\/}"
    local source_dir="$skills_dir/$original_path"
    local source_file="$source_dir/SKILL.md"
    if [[ ! -f "$source_file" ]] || ! has_hooks "$source_file"; then
      rm -rf "$target_dir"
    fi
  done
fi
```

### 3.6 Add automated prompt parity test

**File:** `tests/claude-code/test-reviewer-prompt-parity.sh` (new)

Test that the agent definition body and the template body contain identical prompt content. Extracts text after frontmatter from `agents/code-reviewer.md` and compares to the body of `skills/requesting-code-review/code-reviewer.md` (after the `# Code Review Agent` header line). Fails if they diverge.

**Must be wired into `tests/claude-code/run-skill-tests.sh`** so it runs automatically with the regular test suite. Otherwise drift prevention is optional and will be forgotten.

```bash
#!/usr/bin/env bash
# Verify code-reviewer agent body matches template body.
# Prevents prompt drift between the two files.
# Uses process substitution directly (no variables) to avoid
# trailing-newline normalization artifacts from command substitution.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENT="$REPO_ROOT/agents/code-reviewer.md"
TEMPLATE="$REPO_ROOT/skills/requesting-code-review/code-reviewer.md"

# Compare agent body (after frontmatter) vs template body (after header)
# Stream directly through awk into diff — no variable staging.
if diff \
  <(awk '/^---$/{c++; if(c==2){found=1; next}} found' "$AGENT") \
  <(awk 'NR>1' "$TEMPLATE") \
  > /dev/null 2>&1; then
  echo "PASS: Agent body matches template"
  exit 0
else
  echo "FAIL: Agent body and template have diverged"
  diff \
    <(awk '/^---$/{c++; if(c==2){found=1; next}} found' "$AGENT") \
    <(awk 'NR>1' "$TEMPLATE") || true
  exit 1
fi
```

### 3.7 Update link-plugin-components test

**File:** `tests/verification/test-link-plugin-components.sh`
- Update test that enforces "skip if exists" to verify:
  1. First run: copies and creates .source-hash sidecar
  2. Second run with unchanged source: skips (hash match)
  3. Third run with modified source: re-copies (hash mismatch), new hash stored
  4. Fourth run with deleted source: prunes orphaned agent copy
  5. Fifth run with deleted skill source: prunes orphaned skill copy
  6. Legacy migration: pre-existing target directory without .source-hash is treated as stale — removed and re-copied with hash file created

---

## Tier 4 — Aggregation Alignment (strongly recommended follow-up)

These items are not part of the prompt rewrite implementation. They are strongly recommended follow-up work to ensure the improvement survives the full production pipeline, but they are advisory — not enforced gates. The prompt rewrite ships when Tiers 1-3 pass verification.

- **4.1:** Stop downgrading lone findings for correctness/test-gap classes (only downgrade style/nits)
- **4.2:** Use sonnet (not haiku) for aggregation in max-5x/max-20x tiers
- **4.3:** Build regression harness from real "reviewer missed, human caught" cases
- **4.4:** Align aggregation prompt with Suggestion suppression rule. Currently aggregation can create Suggestions via downgrade (lone Minor → Suggestion). This is benign in isolation: a downgraded lone Minor means 2/3 reviewers didn't flag it at all. But for full FP-minimization consistency, aggregation should respect the suppression rule.
- **4.5:** Add aggregation-side evidence filtering: drop any finding in aggregated output that lacks file:line + concrete failing path/violated requirement/missing test scenario. This enforces the precision gate at the aggregation layer, preventing FP leakage through the pipeline. Cheap to implement (add rule to aggregator prompt).
- **4.6:** Add multi-review fixture testing (N=3 + aggregation) to verify precision gate survives the full production pipeline. Single-reviewer fixture tests (verification steps 8-9) verify the prompt works; this verifies the pipeline doesn't undermine it.
- **4.7:** Evaluate conditional N=3: run single review first, escalate to N=3 only if first review finds Critical/Important or has major Not Checked gaps. Saves tokens on clean reviews while maintaining coverage for complex changes.

---

## Files Modified (summary)

| File | Change |
|------|--------|
| `skills/requesting-code-review/code-reviewer.md` | **Full rewrite** — procedural methodology, precision gate, evidence protocol, verdict constraint, unified placeholders/severity |
| `agents/code-reviewer.md` | Add `disallowedTools`, replace body with rewritten prompt matching template |
| `skills/subagent-driven-development/code-quality-reviewer-prompt.md` | Update reference to match new template structure |
| `skills/requesting-code-review/SKILL.md` | Fix placeholder docs, confirm template reference |
| `hooks/link-plugin-components.sh` | Sidecar source-hash tracking + orphan pruning for agents and skills |
| `tests/verification/test-link-plugin-components.sh` | Update test for hash-based refresh + prune behavior |
| `tests/claude-code/test-reviewer-prompt-parity.sh` | **New** — automated test that agent body matches template body |
| `tests/claude-code/run-skill-tests.sh` | Wire in `test-reviewer-prompt-parity.sh` to regular test suite |

---

## Verification

1. **Placeholder consistency:** Grep for `PLAN_REFERENCE` in runtime prompt files (`skills/requesting-code-review/code-reviewer.md`, `agents/code-reviewer.md`, `skills/requesting-code-review/SKILL.md`) — should return 0 hits
2. **Severity consistency:** Grep for `Suggestions` (capital S, plural) in same files — should return 0 hits
3. **Legacy contract tokens:** Grep for `WHAT_WAS_IMPLEMENTED`, `DESCRIPTION`, and `Strengths` in `skills/requesting-code-review/SKILL.md` and `skills/subagent-driven-development/code-quality-reviewer-prompt.md` — should return 0 hits. Prevents doc drift from stale examples/output descriptions.
4. **disallowedTools:** Read agent definition, confirm Write/Edit/NotebookEdit are blocked
5. **Prompt parity test:** Run `tests/claude-code/test-reviewer-prompt-parity.sh` — must PASS
6. **Test runner help text:** Run `tests/claude-code/run-skill-tests.sh --help` and verify `test-reviewer-prompt-parity.sh` appears in the output. Prevents operator guidance drift.
7. **Stale-copy fix:** Modify agent source, run link-plugin-components.sh, verify target updates and .source-hash is written
8. **Stale-copy prune (agent):** In a temp fixture (copy of plugin tree), delete an agent source, run link-plugin-components.sh against the fixture, verify agent target and .source-hash are removed. Do NOT delete tracked source files in the working repo.
8b. **Stale-copy prune (skill):** Same fixture, delete a skill source directory, run link-plugin-components.sh, verify skill target directory is removed.
8c. **Legacy migration:** In a temp fixture, create a target directory without .source-hash (simulating pre-upgrade). Run link-plugin-components.sh, verify target is refreshed and .source-hash is created.
9. **Link test:** Run `tests/verification/test-link-plugin-components.sh` — should pass with hash-based refresh + prune
10. **Fixture test — known bug:** Dispatch reviewer on a code sample with a known real bug (from historical "reviewer missed, human caught"). Verify the rewritten reviewer finds it.
11. **Fixture test — known clean:** Dispatch reviewer on a clean code sample with no bugs. Verify **zero findings at any severity** (not just zero Critical/Important). Any finding on clean code = precision gate failure.
