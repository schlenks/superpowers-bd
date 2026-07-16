#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0

check() {
  local description="$1"
  shift
  if "$@"; then
    echo "PASS: $description"
    pass=$((pass + 1))
  else
    echo "FAIL: $description"
    fail=$((fail + 1))
  fi
}

contains() {
  grep -Eq -- "$2" "$1"
}

not_contains() {
  ! grep -Eq -- "$2" "$1"
}

scan_markdown() {
  python3 - "$@" <<'PY'
from pathlib import Path
import re
import sys

pattern = re.compile(sys.argv[1], re.MULTILINE)
roots = [Path(arg) for arg in sys.argv[2:]]
matches = []

for root in roots:
    paths = [root] if root.is_file() else root.rglob("*.md")
    for path in paths:
        if path.is_file():
            text = path.read_text()
            if pattern.search(text):
                matches.append(str(path))

if matches:
    print("\n".join(matches))
    sys.exit(1)
PY
}

no_active_task_invocations() {
  scan_markdown \
    'Task\(|^\s*Task(?: tool)?:|\bTask tool\b|\bTask calls?\b|\bboth the Task\b' \
    skills commands agents plugins/superpowers-bd/skills plugins/superpowers-bd/agents
}

implementer_examples_use_done() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

text = Path("skills/subagent-driven-development/example-workflow.md").read_text()
blocks = re.findall(
    r"Implementer \d+ verdict:\n(?P<body>(?:  .*\n)+)",
    text,
)
if not blocks or any("VERDICT: DONE" not in block for block in blocks):
    sys.exit(1)
PY
}

no_broad_wave_cleanup_globs() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

paths = (
    Path("skills/subagent-driven-development/wave-orchestration.md"),
    Path("skills/subagent-driven-development/checkpoint-recovery.md"),
    Path("skills/subagent-driven-development/metrics-tracking.md"),
)
pattern = re.compile(r"rm\s+-f\s+temp/<epic-prefix>\*", re.IGNORECASE)
bad = [str(path) for path in paths if pattern.search(path.read_text())]

if bad:
    print("Broad wave-cleanup glob remains documented:")
    print("\n".join(bad))
    sys.exit(1)
PY
}

dependency_examples_use_task_update() {
  python3 - <<'PY'
from pathlib import Path
import sys

bad = []
for root in (
    "skills",
    "commands",
    "agents",
    "plugins/superpowers-bd/skills",
    "plugins/superpowers-bd/agents",
):
    for path in Path(root).rglob("*.md"):
        lines = path.read_text().splitlines()
        for index, line in enumerate(lines):
            if "addBlockedBy:" not in line:
                continue
            context = "\n".join(lines[max(0, index - 4):index + 1])
            if "TaskUpdate:" not in context:
                bad.append(f"{path}:{index + 1}")

if bad:
    print("addBlockedBy documented outside TaskUpdate:")
    print("\n".join(bad))
    sys.exit(1)
PY
}

tdd_contract_is_coherent() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

skill = Path("skills/test-driven-development/SKILL.md").read_text()
reference = Path(
    "skills/test-driven-development/references/rationalizations-and-red-flags.md"
).read_text()

required = (
    r"NO PRODUCTION (?:BEHAVIOR )?CODE WITHOUT A FAILING TEST FIRST",
    r"(?:delete|discard).*(?:start over|restart).*test",
    r"documentation-only",
    r"declarative configuration",
    r"generated code",
    r"throwaway prototypes",
    r"verification receipt",
)
if any(not re.search(pattern, skill, re.IGNORECASE | re.DOTALL) for pattern in required):
    sys.exit(1)
if re.search(r"mechanical metadata|formatting changes", skill, re.IGNORECASE):
    sys.exit(1)
if not re.search(r"when no bounded exception applies|without a bounded exception", reference, re.IGNORECASE):
    sys.exit(1)
if not re.search(r"prototype.*discard|discard.*prototype", reference, re.IGNORECASE | re.DOTALL):
    sys.exit(1)
PY
}

epic_verifier_paths_are_read_only() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

paths = (
    Path("agents/epic-verifier.md"),
    Path("skills/epic-verifier/verifier-prompt.md"),
    Path("plugins/superpowers-bd/agents/epic-verifier.md"),
    Path(".codex/agents/epic-verifier.toml"),
)
texts = {path: path.read_text() for path in paths}
frontmatter = texts[paths[0]].split("---", 2)[1]

rule_of_five_auto_load = re.compile(
    r"^\s*-\s+rule-of-five-(?:code|tests|plans)\s*$",
    re.MULTILINE,
)
guard_fixtures = (
    "skills:\n  - rule-of-five-code\n",
    "skills:\n  - verification-before-completion\n  - rule-of-five-tests\n",
)
if any(not rule_of_five_auto_load.search(fixture) for fixture in guard_fixtures):
    print("epic-verifier auto-load guard misses a later rule-of-five skills entry")
    sys.exit(1)

if rule_of_five_auto_load.search(frontmatter):
    sys.exit(1)
for path, text in texts.items():
    if not re.search(r"read-only|do not (?:invoke|edit|modify)", text, re.IGNORECASE):
        print(f"{path}: missing read-only verifier contract")
        sys.exit(1)
    if not re.search(r"do\s+not\s+invoke.*rule-of-five|lenses.*without editing", text, re.IGNORECASE | re.DOTALL):
        print(f"{path}: missing rule-of-five no-editing guard")
        sys.exit(1)
    for line in text.splitlines():
        if re.search(r"\b(?:do not|don't|cannot|can't|without)\b", line, re.IGNORECASE):
            continue
        if re.search(r"\b(?:fix|edit|modify)\s+(?:the\s+)?(?:artifacts?|issues?|code)\b", line, re.IGNORECASE):
            print(f"{path}: contradictory editing instruction: {line.strip()}")
            sys.exit(1)

for path in paths[2:]:
    text = texts[path]
    if "bd comments add" not in text:
        print(f"{path}: missing mandatory beads report persistence")
        sys.exit(1)
    lines = text.splitlines()
    tee = next((i for i, line in enumerate(lines) if "tee temp/<epic-id>-verification.md" in line), None)
    if tee is None:
        print(f"{path}: missing executable report heredoc")
        sys.exit(1)
    terminator = next(
        (line for line in lines[tee + 1:] if line.strip() == "EPIC_VERIFICATION_EOF"),
        None,
    )
    if terminator != "EPIC_VERIFICATION_EOF":
        print(f"{path}: report heredoc terminator must be unindented")
        sys.exit(1)

for path, text in texts.items():
    if "✅" in text or "❌" in text:
        print(f"{path}: verifier status vocabulary must use PASS/FAIL")
        sys.exit(1)
PY
}

epic_verifier_persistence_is_portable() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

paths = (
    Path("skills/epic-verifier/verifier-prompt.md"),
    Path("plugins/superpowers-bd/skills/epic-verifier/verifier-prompt.md"),
    Path("agents/epic-verifier.md"),
    Path("plugins/superpowers-bd/agents/epic-verifier.md"),
    Path(".codex/agents/epic-verifier.toml"),
)

for path in paths:
    text = path.read_text()
    required = (
        r"mkdir\s+-p\s+temp",
        r"tee\s+temp/",
        r"bd comments add",
        r"retry.*(?:three|3)\s+times|up to (?:three|3) times.*retry",
    )
    for pattern in required:
        if not re.search(pattern, text, re.IGNORECASE | re.DOTALL):
            print(f"{path}: missing portable verifier persistence contract: {pattern}")
            sys.exit(1)
PY
}

epic_verifier_persistence_fails_closed() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

paths = (
    Path("skills/epic-verifier/verifier-prompt.md"),
    Path("plugins/superpowers-bd/skills/epic-verifier/verifier-prompt.md"),
    Path("agents/epic-verifier.md"),
    Path("plugins/superpowers-bd/agents/epic-verifier.md"),
    Path(".codex/agents/epic-verifier.toml"),
)

required = (
    (r"query.*comments.*before.*retry|before.*retry.*query.*comments", "query-before-retry contract"),
    (r"retry.*only.*marker.*absent|only.*retry.*marker.*absent", "absence-confirmed retry guard"),
    (r"exact marker line.*only persistence proof", "marker-only persistence proof"),
    (r"FAIL\s*\(CANNOT_VERIFY\)|CANNOT_VERIFY.*FAIL", "fail-closed persistence verdict"),
    (r"block.*epic completion|epic completion.*block", "epic completion block"),
    (r"Never emit PASS.*persistence.*unconfirmed", "no-PASS-on-persistence-failure guard"),
    (r"Report Persistence", "persistence summary status"),
)

for path in paths:
    text = path.read_text()
    if not re.search(
        r"^[^\n]*\[EPIC-VERIFICATION\][^\n]*(?:head-sha|head_sha)"
        r"[^\n]*verification-run-id[^\n]*$",
        text,
        re.IGNORECASE | re.MULTILINE,
    ):
        print(f"{path}: missing epic, HEAD, and verification-run marker line")
        sys.exit(1)

    query = re.search(
        r"bd comments (?:\{epic_id\}|<epic-id>) --json",
        text,
        re.IGNORECASE,
    )
    add = re.search(r"bd comments add", text, re.IGNORECASE)
    if query is None or add is None or query.start() > add.start():
        print(f"{path}: must query the exact marker before the first comment-add attempt")
        sys.exit(1)

    for pattern, description in required:
        if not re.search(pattern, text, re.IGNORECASE | re.DOTALL):
            print(f"{path}: missing {description}")
            sys.exit(1)
PY
}

epic_verifier_heredoc_is_valid() {
  python3 - <<'PY'
from pathlib import Path
import sys

for path in (
    Path("skills/epic-verifier/verifier-prompt.md"),
    Path("plugins/superpowers-bd/skills/epic-verifier/verifier-prompt.md"),
    Path("agents/epic-verifier.md"),
    Path("plugins/superpowers-bd/agents/epic-verifier.md"),
    Path(".codex/agents/epic-verifier.toml"),
):
    lines = path.read_text().splitlines()
    tee = next(
        (
            i
            for i, line in enumerate(lines)
            if "tee temp/" in line and "-verification.md" in line
        ),
        None,
    )
    if tee is None or "> /dev/null" not in lines[tee]:
        sys.exit(1)
    if "EPIC_VERIFICATION_EOF" not in lines[tee]:
        sys.exit(1)
    if "EPIC_VERIFICATION_EOF" not in lines[tee + 1:]:
        sys.exit(1)
    terminator = next(
        line for line in lines[tee + 1:] if line.strip() == "EPIC_VERIFICATION_EOF"
    )
    if terminator != "EPIC_VERIFICATION_EOF":
        sys.exit(1)
PY
}

writing_plan_context_routing_is_consistent() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

paths = (
    Path("skills/writing-plans/SKILL.md"),
    Path("skills/writing-plans/references/announcements-protocol.md"),
    Path("skills/writing-plans/references/execution-handoff.md"),
    Path("plugins/superpowers-bd/skills/writing-plans/SKILL.md"),
    Path("plugins/superpowers-bd/skills/writing-plans/references/announcements-protocol.md"),
    Path("plugins/superpowers-bd/skills/writing-plans/references/execution-handoff.md"),
)

for path in paths:
    text = path.read_text()
    required = (r"\[1m\]", r"sonnet-5", r"fable-5")
    if any(not re.search(pattern, text, re.IGNORECASE) for pattern in required):
        print(f"{path}: context routing must recognize the suffix and both 1M-native families")
        sys.exit(1)
PY
}

claude_agent_output_schema_is_current() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

paths = (
    Path("skills/subagent-driven-development/background-execution.md"),
    Path("skills/subagent-driven-development/metrics-tracking.md"),
    Path("skills/subagent-driven-development/simplifier-dispatch-guidance.md"),
    Path("skills/dispatching-parallel-agents/SKILL.md"),
    Path("AGENTS.md"),
    Path("CLAUDE.md"),
)
texts = {path: path.read_text() for path in paths}

forbidden = (
    r"\.task_id\b",
    r"result\.usage\.(?:total_tokens|tool_uses|duration_ms)",
    r"<usage>",
    r"\$9/M",
    r"Claude uses `Task`/`run_in_background`",
    r"subagent definitions for Task tool",
    r"`Task` with background execution",
)
for path, text in texts.items():
    for pattern in forbidden:
        if re.search(pattern, text, re.IGNORECASE):
            print(f"{path}: stale Claude Agent contract matches {pattern}")
            sys.exit(1)

background = texts[paths[0]]
metrics = texts[paths[1]]
for token in ("agentId", "outputFile"):
    if token not in background:
        print(f"{paths[0]}: missing {token}")
        sys.exit(1)
for token in (
    "totalTokens",
    "totalToolUseCount",
    "totalDurationMs",
    "input_tokens",
    "output_tokens",
):
    if token not in metrics:
        print(f"{paths[1]}: missing {token}")
        sys.exit(1)
if not re.search(r"unknown|unavailable", metrics, re.IGNORECASE):
    print(f"{paths[1]}: missing honest handling for unavailable structured metrics")
    sys.exit(1)
PY
}

integration_harness_uses_current_workflow() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

runner = Path("tests/claude-code/run-skill-tests.sh").read_text()
integration = Path(
    "tests/claude-code/test-subagent-driven-development-integration.sh"
).read_text()

runner_required = (
    r"FAST_TEST_TIMEOUT=300",
    r"INTEGRATION_TEST_TIMEOUT=1860",
    r"\*integration\*.*INTEGRATION_TEST_TIMEOUT",
    r"exit_code.*77",
)
if any(
    not re.search(pattern, runner, re.IGNORECASE | re.DOTALL)
    for pattern in runner_required
):
    print("Claude test runner lacks separate fast and integration timeout budgets")
    sys.exit(1)

integration_required = (
    r"bd init",
    r"--type=epic",
    r"--parent",
    r"execute epic",
    r'"name":"Agent"',
    r"CLAUDE_CONFIG_DIR",
    r"--plugin-dir",
    r"session-env",
    r"exit 77",
)
if any(
    not re.search(pattern, integration, re.IGNORECASE)
    for pattern in integration_required
):
    print("SDD integration fixture does not exercise the current Beads/Agent workflow")
    sys.exit(1)
if re.search(r'"name":"Task"', integration):
    print("SDD integration fixture still asserts the legacy Task tool")
    sys.exit(1)
PY
}

no_false_progress_enforcement_claims() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

patterns = (
    r"\b(?:this\s+)?task\s+(?:cannot|can't)\s+be\s+marked\s+`?completed`?",
    r"\bblocked tasks?\s+(?:cannot|can't)\s+be\s+marked\s+`?in_progress`?",
    r"\bcannot\s+(?:be\s+)?mark(?:ed)?\s+completed\b",
    r"\bcannot be skipped\b",
    r"\bnon-skippable\b",
    r"\bcannot call\s+ExitPlanMode\b",
    r"\bpending tasks?\s+block(?:s|ed|ing)?\b",
)
roots = (
    Path("skills"),
    Path("commands"),
    Path("agents"),
    Path("plugins/superpowers-bd/skills"),
    Path("plugins/superpowers-bd/agents"),
)
bad = []

for root in roots:
    for path in root.rglob("*.md"):
        text = path.read_text()
        for pattern in patterns:
            if re.search(pattern, text, re.IGNORECASE):
                bad.append(f"{path}: {pattern}")

if bad:
    print("False native-progress enforcement claims:")
    print("\n".join(bad))
    sys.exit(1)
PY
}

retired_skill_bulletproofing_doctrine_is_absent() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

checks = {
    Path("skills/writing-skills/references/tdd-for-skills.md"): (
        r"build rationalization table",
        r"re-test until bulletproof",
    ),
    Path("skills/writing-skills/references/creation-checklist.md"): (
        r"rationalization table",
        r"bulletproof",
    ),
    Path("skills/writing-skills/references/testing-skills-with-subagents.md"): (
        r"rationalization table",
        r"\bbulletproof\b",
    ),
    Path("skills/writing-skills/references/3-tier-model.md"): (
        r"rationalization tables?",
    ),
}

bad = []
for path, patterns in checks.items():
    text = path.read_text()
    for pattern in patterns:
        if re.search(pattern, text, re.IGNORECASE):
            bad.append(f"{path}: {pattern}")

if bad:
    print("Retired skill-bulletproofing doctrine remains:")
    print("\n".join(bad))
    sys.exit(1)
PY
}

fast_skill_runner_fails_closed_on_missing_tests() {
  if bash tests/claude-code/run-skill-tests.sh \
    --test test-required-file-that-does-not-exist.sh >/dev/null 2>&1; then
    echo "Fast skill runner exited 0 for a missing configured test"
    return 1
  fi
}

completion_evidence_contract_is_preserved() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

text = Path("skills/verification-before-completion/SKILL.md").read_text()
required = (
    r"same (?:message|response\s+cycle)|in this message",
    r"ONLY THEN",
    r"Not Sufficient",
)
if any(not re.search(pattern, text, re.IGNORECASE | re.DOTALL) for pattern in required):
    sys.exit(1)
PY
}

using_superpowers_parallel_ownership_is_preserved() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

text = Path("skills/using-superpowers/SKILL.md").read_text()
required = (
    r"explicit file ownership",
    r"other agents may also be editing",
    r"write\s+scopes\s+disjoint",
)
if any(not re.search(pattern, text, re.IGNORECASE | re.DOTALL) for pattern in required):
    sys.exit(1)
PY
}

using_superpowers_first_response_routing_is_preserved() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

text = Path("skills/using-superpowers/SKILL.md").read_text()
required = (
    r"before the first response",
    r"load this routing skill",
    r"load\s+relevant.*skills\s+before",
)
if any(not re.search(pattern, text, re.IGNORECASE | re.DOTALL) for pattern in required):
    sys.exit(1)
PY
}

session_start_injection_is_calibrated() {
  local hook
  for hook in hooks/session-start.sh hooks/codex-session-start.sh plugins/superpowers-bd/hooks/codex-session-start.sh; do
    grep -q "superpowers-bd:using-superpowers" "$hook" || return 1
    grep -q "superpowers-bd-session-context" "$hook" || return 1
    if grep -qi "EXTREMELY" "$hook"; then
      return 1
    fi
  done
}

aggregation_model_policy_is_executable() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

token = "{low_cost_synthesis_model}"
paths = (
    Path("skills/multi-review-aggregation/SKILL.md"),
    Path("plugins/superpowers-bd/skills/multi-review-aggregation/SKILL.md"),
    Path("skills/multi-review-aggregation/aggregator-prompt.md"),
    Path("plugins/superpowers-bd/skills/multi-review-aggregation/aggregator-prompt.md"),
    Path("commands/cr.md"),
)
texts = {path: path.read_text() for path in paths}

for path, text in texts.items():
    if re.search(r"\bhaiku model\b", text, re.IGNORECASE):
        print(f"{path}: hard-coded Haiku wording contradicts platform model policy")
        sys.exit(1)
    if "{current_low_cost_claude_synthesis_model}" in text:
        print(f"{path}: uses a second undefined synthesis-model placeholder")
        sys.exit(1)

for path in paths[2:]:
    text = texts[path]
    if token not in text:
        print(f"{path}: missing canonical synthesis-model placeholder")
        sys.exit(1)
    if not re.search(r"resolve|replace", text, re.IGNORECASE):
        print(f"{path}: does not explain how to resolve {token}")
        sys.exit(1)
    if not re.search(r"omit.*model.*inherit|inherit.*omit.*model", text, re.IGNORECASE | re.DOTALL):
        print(f"{path}: missing executable fallback when no low-cost alias exists")
        sys.exit(1)
PY
}

managed_beads_blocks_match_versioned_fixture() {
  python3 - <<'PY'
from pathlib import Path
import hashlib
import re
import sys

fixture = Path(
    "tests/verification/fixtures/beads-integration-v1-minimal.md"
).read_text().strip()

bodies = []
for name in ("AGENTS.md", "CLAUDE.md"):
    text = Path(name).read_text()
    match = re.search(
        r"<!-- BEGIN BEADS INTEGRATION v:1 profile:[^ ]+ hash:([0-9a-f]{8}) -->\n"
        r"(.*?)\n<!-- END BEADS INTEGRATION -->",
        text,
        re.DOTALL,
    )
    if not match:
        sys.exit(1)
    digest, body = match.groups()
    if hashlib.sha256(body.encode()).hexdigest()[:8] != digest:
        sys.exit(1)
    if body.strip() != fixture:
        print(f"{name}: managed beads block differs from the v1 minimal-profile fixture")
        sys.exit(1)
    prefix = text[:match.start()]
    required_override = (
        r"managed Beads block below governs durable issue tracking only"
        r".*does not\s+prohibit native workflow progress"
    )
    if not re.search(required_override, prefix, re.IGNORECASE | re.DOTALL):
        print(f"{name}: missing native-progress override before managed beads block")
        sys.exit(1)
    bodies.append(body)

if bodies[0] != bodies[1]:
    sys.exit(1)
PY
}

retired_references_absent() {
  local files=(
    "skills/writing-skills/references/persuasion-principles.md"
    "skills/verification-before-completion/references/why-this-matters.md"
    "skills/systematic-debugging/references/CREATION-LOG.md"
    "skills/systematic-debugging/references/real-world-impact.md"
    "skills/dispatching-parallel-agents/references/real-world-impact.md"
    "skills/multi-review-aggregation/references/dispatch-code.md"
    "skills/multi-review-aggregation/references/metrics-and-cost.md"
  )
  local file
  for file in "${files[@]}"; do
    [ ! -e "$file" ] || return 1
  done
}

mirrors_match() {
  python3 - <<'PY'
from pathlib import Path
import sys

plugin_root = Path("plugins/superpowers-bd/skills")
root = Path("skills")
bad = []
relative_paths = {
    path.relative_to(root)
    for path in root.rglob("*")
    if path.is_file()
} | {
    path.relative_to(plugin_root)
    for path in plugin_root.rglob("*")
    if path.is_file()
}

for relative in sorted(relative_paths):
    root_path = root / relative
    plugin_path = plugin_root / relative
    if not root_path.is_file() or not plugin_path.is_file():
        bad.append(f"{root_path} <-> {plugin_path}")
    elif root_path.read_bytes() != plugin_path.read_bytes():
        bad.append(f"{root_path} <-> {plugin_path}")

if bad:
    print("Root/plugin mirror drift:")
    print("\n".join(bad))
    sys.exit(1)
PY
}

echo "=== Workflow Contract Audit ==="

check "SDD requires loading wave orchestration before DISPATCH" \
  contains "skills/subagent-driven-development/SKILL.md" 'wave-orchestration\.md.*(required|before DISPATCH|flag lifecycle)'

check "Implementer examples use the declared DONE vocabulary" \
  implementer_examples_use_done

check "SDD cleanup guidance never sanctions broad epic-prefix globs" \
  no_broad_wave_cleanup_globs

check "Writing plans recognizes 1M-native model families" \
  contains "skills/writing-plans/SKILL.md" 'sonnet-5.*fable-5|fable-5.*sonnet-5'

check "Writing-plan routing is consistent across loaded references" \
  writing_plan_context_routing_is_consistent

check "Claude and both Codex epic-verifier paths are read-only" \
  epic_verifier_paths_are_read_only

check "Epic-verifier report persistence works in fresh consumer repositories" \
  epic_verifier_persistence_is_portable

check "Epic-verifier persistence is idempotent and fails closed" \
  epic_verifier_persistence_fails_closed

check "Epic-verifier report heredoc is executable and repository-compliant" \
  epic_verifier_heredoc_is_valid

check "Active Claude dispatch examples use Agent terminology" \
  no_active_task_invocations

check "Claude Agent bookkeeping uses the current output schema" \
  claude_agent_output_schema_is_current

check "addBlockedBy examples use TaskUpdate" \
  dependency_examples_use_task_update

check "TDD bright line, recovery, and exceptions are coherent" \
  tdd_contract_is_coherent

check "Completion evidence matches the stop-gate response boundary" \
  completion_evidence_contract_is_preserved

check "Active workflow docs avoid fictional native-progress enforcement" \
  no_false_progress_enforcement_claims

check "Writing-skills references avoid retired bulletproofing doctrine" \
  retired_skill_bulletproofing_doctrine_is_absent

check "Using-superpowers preserves Codex parallel file ownership" \
  using_superpowers_parallel_ownership_is_preserved

check "Using-superpowers routing surface matches first-response behavior" \
  using_superpowers_first_response_routing_is_preserved

check "Session-start injection uses calibrated framing on all platforms" \
  session_start_injection_is_calibrated

check "Bulletproofing preserves the measured no-guidance comparison" \
  contains "skills/writing-skills/references/bulletproofing.md" 'worse than a no-guidance control'

check "TDD-for-skills pointer names the current section" \
  not_contains "skills/writing-skills/references/tdd-for-skills.md" 'bulletproofing\.md.*\(A2\)'

check "Worked examples avoid hook-blocked truncation pipelines" \
  not_contains "skills/subagent-driven-development/example-workflow.md" 'bd show .* \| head'

check "Aggregation prompts use one executable platform model policy" \
  aggregation_model_policy_is_executable

check "Managed beads blocks match the versioned profile and preserve native progress" \
  managed_beads_blocks_match_versioned_fixture

check "Visual verification is capability-based" \
  contains "skills/verification-before-completion/references/visual-verification.md" 'capabilit'

check "Relevant visual-verification skips are reported" \
  contains "skills/verification-before-completion/references/visual-verification.md" 'frontend files changed.*skip|skip reason|verification skipped'

check "Systematic debugging has a proportional triage gate" \
  contains "skills/systematic-debugging/SKILL.md" 'Triage|triage'

check "Obsolete reference files are retired" \
  retired_references_absent

check "Workflow audit uses no undeclared ripgrep dependency" \
  not_contains "tests/verification/test-workflow-contract-audit.sh" '^[[:space:]]*rg([[:space:]]|$)'

check "Workflow audit runs in the fast Claude skill suite" \
  contains "tests/claude-code/run-skill-tests.sh" 'test-workflow-contract-audit\.sh'

check "Fast Claude skill runner fails closed for missing configured tests" \
  fast_skill_runner_fails_closed_on_missing_tests

check "Claude integration harness exercises current Beads and Agent semantics" \
  integration_harness_uses_current_workflow

check "All installable skill files stay mirrored" \
  mirrors_match

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -ne 0 ]; then
  exit 1
fi
