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

# The epic-verifier persistence checks execute each copy's documented commands
# (mkdir, the report heredoc, the comment query and add) in a fresh git repo
# with a stub `bd` on PATH, so a broken heredoc, a path mismatch between the
# report and the add command, or a marker the query cannot find fails here.
# Idempotent mode also runs the documented retry loop (query, add only when the
# marker is absent, query again) against a stub that drops adds.
run_epic_verifier_persistence() {
  python3 - "$1" <<'PY'
from pathlib import Path
import json
import os
import re
import subprocess
import sys
import tempfile

mode = sys.argv[1]
repo_root = Path.cwd()
copies = (
    Path("skills/epic-verifier/verifier-prompt.md"),
    Path("plugins/superpowers-bd/skills/epic-verifier/verifier-prompt.md"),
    Path("agents/epic-verifier.md"),
    Path("plugins/superpowers-bd/agents/epic-verifier.md"),
    Path(".codex/agents/epic-verifier.toml"),
)
EPIC = "demo-x1"
RUN_ID = "20261014T000000Z"

STUB_BD = r'''#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BD_LOG"
if [ "$1" = comments ] && [ "$2" = add ]; then
  [ "$4" = -f ] || { echo "stub bd: expected -f <file>" >&2; exit 2; }
  [ -f "$5" ] || { echo "stub bd: no such file $5" >&2; exit 2; }
  [ -n "${BD_DROP_ADDS:-}" ] && exit 0
  cp "$5" "$BD_STATE/$3.$(ls "$BD_STATE" | wc -l | tr -d ' ')"
  exit 0
fi
if [ "$1" = comments ] && [ "$3" = --json ]; then
  python3 -c 'import glob,json,sys; print(json.dumps([{"text": open(p).read()} for p in sorted(glob.glob(sys.argv[1] + "/" + sys.argv[2] + ".*"))]))' "$BD_STATE" "$2"
  exit 0
fi
echo "stub bd: unsupported: $*" >&2
exit 2
'''

# Hermetic git: the caller's GIT_DIR, GIT_CONFIG_GLOBAL etc. must not leak in.
CLEAN_ENV = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"]

def substitute(text, head, run_id=RUN_ID):
    for old, new in (
        ("{epic_id}", EPIC), ("<epic-id>", EPIC),
        ("{head-sha}", head), ("<head-sha>", head),
        ("<verification-run-id>", run_id),
    ):
        text = text.replace(old, new)
    return text

def extract(text):
    lines = text.splitlines()
    tee = next(i for i, l in enumerate(lines) if l.startswith("tee temp/") and "EPIC_VERIFICATION_EOF" in l)
    end = next(i for i in range(tee + 1, len(lines)) if lines[i].strip() == "EPIC_VERIFICATION_EOF")
    heredoc = "\n".join(lines[tee:end + 1]) + "\n"
    after = "\n".join(lines[end + 1:])
    query = re.search(r"`(bd comments (?:\{epic_id\}|<epic-id>) --json)`", after)
    add = re.search(r"`(bd comments add (?:\{epic_id\}|<epic-id>) -f [^`]+)`", after)
    mkdir = re.search(r"`(mkdir -p temp)`", text[:text.index(lines[tee])])
    if not (query and add and mkdir):
        raise ValueError("missing mkdir, query or add command")
    if query.start() > add.start():
        raise ValueError("comment query must come before the first add")
    retries = re.search(r"up\s+to\s+(?:3|three)\s+times", after, re.IGNORECASE)
    if not retries:
        raise ValueError("missing the bounded add-retry count")
    return mkdir.group(1), heredoc, query.group(1), add.group(1), lines[tee + 1], 3

def sh(cmd, cwd, env):
    return subprocess.run(["bash", "-c", cmd], cwd=cwd, env=env, capture_output=True, text=True)

def check(path):
    text = (repo_root / path).read_text()
    mkdir, heredoc, query, add, marker_tpl, max_adds = extract(text)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        repo, bin_dir, state = tmp / "repo", tmp / "bin", tmp / "state"
        for d in (repo, bin_dir, state):
            d.mkdir()
        (bin_dir / "bd").write_text(STUB_BD)
        (bin_dir / "bd").chmod(0o755)
        env = dict(CLEAN_ENV, PATH=f"{bin_dir}:{os.environ['PATH']}",
                   BD_LOG=str(tmp / "bd.log"), BD_STATE=str(state))

        def commit(message):
            subprocess.run(GIT + ["commit", "-q", "--allow-empty", "-m", message],
                           cwd=repo, env=CLEAN_ENV, check=True)
            return subprocess.run(GIT + ["rev-parse", "HEAD"], cwd=repo, env=CLEAN_ENV,
                                  check=True, capture_output=True, text=True).stdout.strip()

        def marker_hits(marker, run_env=env):
            out = sh(substitute(query, head), repo, run_env).stdout
            return sum(marker in c["text"].splitlines() for c in json.loads(out))

        def persist(head, run_id, run_env=env):
            # The documented flow: write the report, then query before every add
            # and add only while a successful query shows the marker absent.
            for cmd in (mkdir, substitute(heredoc, head, run_id)):
                sh(cmd, repo, run_env)
            marker, adds = substitute(marker_tpl, head, run_id), 0
            while marker_hits(marker, run_env) == 0 and adds < max_adds:
                sh(substitute(add, head, run_id), repo, run_env)
                adds += 1
            return marker_hits(marker, run_env) > 0, adds

        subprocess.run(GIT + ["init", "-q"], cwd=repo, env=CLEAN_ENV, check=True)
        head = commit("init")
        marker = substitute(marker_tpl, head)
        report = repo / "temp" / f"{EPIC}-verification.md"

        if mode == "heredoc":
            for cmd in (mkdir, substitute(heredoc, head)):
                r = sh(cmd, repo, env)
                if r.returncode != 0 or r.stderr:
                    return f"command failed or warned: {cmd.splitlines()[0]}: {r.stderr.strip()}"
            body = report.read_text().splitlines()
            if body[0] != marker or "EPIC_VERIFICATION_EOF" in body:
                return "report file does not start with the marker or swallowed the terminator"
            return None

        for cmd in (mkdir, substitute(heredoc, head)):
            sh(cmd, repo, env)
        if mode == "portable":
            before = sh(substitute(query, head), repo, env)
            if before.returncode != 0 or marker in before.stdout:
                return "query before add failed or already showed the marker"
            r = sh(substitute(add, head), repo, env)
            if r.returncode != 0:
                return f"comment add failed: {r.stderr.strip()}"
            log = (tmp / "bd.log").read_text()
            if f"comments add {EPIC} -f temp/{EPIC}-verification.md" not in log:
                return "add did not reference the report file the heredoc wrote"
            after = sh(substitute(query, head), repo, env)
            texts = [c["text"] for c in json.loads(after.stdout)]
            if not any(marker in t.splitlines() for t in texts):
                return "query after add does not show the exact marker line"
            return None

        if mode == "idempotent":
            if persist(head, RUN_ID) != (True, 1):
                return "first persistence did not add exactly one confirmed comment"
            if persist(head, RUN_ID) != (True, 0):
                return "a retry added a second comment although the marker was present"
            # A new run on the same HEAD, then the first run id on a new HEAD:
            # each must persist its own comment, and no marker may match another.
            head2, run2 = commit("second"), "20261015T000000Z"
            runs = ((head, RUN_ID), (head, run2), (head2, RUN_ID))
            for h, r in runs[1:]:
                if persist(h, r) != (True, 1):
                    return f"run {r} on {h[:7]} was treated as already persisted: the marker lacks the HEAD or run id"
            for h, r in runs:
                if marker_hits(substitute(marker_tpl, h, r)) != 1:
                    return "markers from distinct runs cross-match: the marker lacks the HEAD or run id"
            dropped = dict(env, BD_DROP_ADDS="1")
            head3 = commit("third")
            if persist(head3, "20261016T000000Z", dropped) != (False, max_adds):
                return "adds that never land must stop after the bounded retries, unconfirmed"
            if "FAIL (CANNOT_VERIFY)" not in text or "Report Persistence" not in text:
                return "no fail-closed verdict for unconfirmed persistence"
            return None
    raise SystemExit(f"unknown mode {mode}")

bad = []
for path in copies:
    try:
        problem = check(path)
    except (ValueError, StopIteration, IndexError, json.JSONDecodeError) as exc:
        problem = f"cannot execute persistence commands: {exc!r}"
    if problem:
        bad.append(f"{path}: {problem}")
if bad:
    print("\n".join(bad))
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

rulings_use_canonical_prefix() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

# An example ruling starts with a placeholder or an issue id; prose mentions
# such as "every [RULING] posted" do not.
example = re.compile(r"\[RULING\] (?=[<{]|[a-z][\w-]*\.\d|[a-z]+-[a-z0-9]+:)")
canonical = re.compile(
    r"\[RULING\] (?:<[\w-]+>|\{[^}]+\}|[\w.-]+): "
    r"(?:\.\.\.|[^\n]*? — why: [^\n]*? — cost if wrong: )"
)
roots = (
    "skills", "commands", "agents", "plugins/superpowers-bd/skills",
    "plugins/superpowers-bd/agents", ".codex/agents",
)
files = [p for r in roots for p in Path(r).rglob("*") if p.suffix in (".md", ".toml")]
files += [Path("AGENTS.md"), Path("CLAUDE.md"), Path("docs/README.codex.md")]
bad = []
for path in files:
    for n, line in enumerate(path.read_text().splitlines(), 1):
        for m in example.finditer(line):
            if not canonical.match(line, m.start()):
                bad.append(f"{path}:{n}: {line.strip()[:120]}")
if bad:
    print("Rulings must use '[RULING] <issue-id>: <decision> — why: <reason> — cost if wrong: <impact>':")
    print("\n".join(bad))
    sys.exit(1)
PY
}

no_forbidden_text() {
  # no_forbidden_text <python-regex> <root>... : fail when any md/toml/yaml file matches
  python3 - "$@" <<'PY'
from pathlib import Path
import re
import sys

pattern = re.compile(sys.argv[1])
bad = []
for root in map(Path, sys.argv[2:]):
    paths = [root] if root.is_file() else root.rglob("*")
    for path in paths:
        if path.is_file() and path.suffix in (".md", ".toml", ".yaml", ".json"):
            for n, line in enumerate(path.read_text().splitlines(), 1):
                if pattern.search(line):
                    bad.append(f"{path}:{n}: {line.strip()[:120]}")
if bad:
    print("\n".join(bad))
    sys.exit(1)
PY
}

sdd_never_holds_for_a_human() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

# Only rulings-and-escalation.md may describe the hard stops that wait.
pattern = re.compile(r"PENDING_HUMAN|report_to_human|WAIT for human|pause for (?:a )?human", re.IGNORECASE)
bad = []
for root in (
    "skills/subagent-driven-development", "skills/executing-plans",
    "plugins/superpowers-bd/skills/subagent-driven-development",
    "plugins/superpowers-bd/skills/executing-plans",
):
    for path in Path(root).rglob("*"):
        if path.is_file() and path.name != "rulings-and-escalation.md" and pattern.search(path.read_text()):
            bad.append(str(path))
if bad:
    print("Synchronous human holds remain:")
    print("\n".join(bad))
    sys.exit(1)
PY
}

re_review_prompt_is_mirrored() {
  [ -f skills/subagent-driven-development/re-review-prompt.md ] &&
    cmp -s skills/subagent-driven-development/re-review-prompt.md \
      plugins/superpowers-bd/skills/subagent-driven-development/re-review-prompt.md
}

implementer_dispatch_has_no_name() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

text = Path("skills/subagent-driven-development/implementer-prompt.md").read_text()
block = re.search(r"## Claude Code Dispatch\s*```\n(.*?)```", text, re.DOTALL)
if not block or "Agent:" not in block.group(1):
    print("implementer Claude dispatch block not found")
    sys.exit(1)
if re.search(r"^\s*name:", block.group(1), re.MULTILINE):
    print("implementer dispatch passes name: (teammate mode breaks fix-round resume)")
    sys.exit(1)
PY
}

plugin_hook_commands_start_with_bash() {
  python3 - <<'PY'
from pathlib import Path
import json
import sys

bad = []
for path in (Path("plugins/superpowers-bd/hooks.json"), Path("plugins/superpowers-bd/hooks/hooks.json")):
    for groups in json.loads(path.read_text())["hooks"].values():
        for group in groups:
            for hook in group["hooks"]:
                if hook.get("type") == "command" and not hook["command"].startswith("bash "):
                    bad.append(f"{path}: {hook['command']}")
if bad:
    print("Codex hook commands must launch through bash:")
    print("\n".join(bad))
    sys.exit(1)
PY
}

review_agents_disallow_agent() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys

for path in (Path("agents/code-reviewer.md"), Path("agents/epic-verifier.md")):
    frontmatter = path.read_text().split("---", 2)[1]
    block = re.search(r"^disallowedTools:\n((?:\s+- .*\n)+)", frontmatter, re.MULTILINE)
    tools = re.findall(r"- (\S+)", block.group(1)) if block else []
    if "Agent" not in tools:
        print(f"{path}: disallowedTools lacks Agent")
        sys.exit(1)
PY
}

fix_round_loop_executes() {
  python3 - <<'PY'
from pathlib import Path
from types import SimpleNamespace as NS
import re
import sys

text = Path("skills/subagent-driven-development/background-execution.md").read_text()
block = next(b for b in re.findall(r"```python\n(.*?)```", text, re.DOTALL) if "def on_review_findings" in b)

def run(resume_ok, fix_round, findings, phase="code"):
    ns, calls = {}, []
    exec(block, ns)
    ns.update(
        pending_tasks={"a1": {"issue_id": "x.1", "fix_round": fix_round, "head_sha": "h"}},
        resume=lambda agent_id, message: resume_ok,
        fix_message=lambda task: "m",
        number_as_F1_to_Fn=lambda f: list(f),
        write_checkpoint=lambda: None,
        dispatch_implementer=lambda *a, **k: "a2",
        adjudicate=lambda issue, f: calls.append("adjudicate"),
        on_spec_review_pass=lambda a, v: calls.append("spec_pass"),
        close_path=lambda a: calls.append("close"),
    )
    ns["on_review_findings"]("a1", [NS(severity=s) for s in findings], phase)
    return ns["pending_tasks"], calls

tasks, _ = run(False, 0, ["Important"])
if "a2" not in tasks or tasks["a2"]["fix_path"] != "fallback" or tasks["a2"]["fix_round"] != 1:
    sys.exit("an unmessageable implementer must fall back to a fresh dispatch in the same round")
tasks, _ = run(True, 0, ["Critical"])
if tasks["a1"]["fix_path"] != "resume":
    sys.exit("rounds 1-2 must resume the implementer")
tasks, _ = run(True, 2, ["Critical"])
if tasks["a2"]["fix_path"] != "round3":
    sys.exit("round 3 must be a fresh dispatch")
if run(True, 3, ["Critical"])[1] != ["adjudicate"]:
    sys.exit("findings after round 3 must adjudicate, not start round 4")
if run(True, 0, ["Minor"], "spec")[1] != ["spec_pass"] or run(True, 0, ["Minor"])[1] != ["close"]:
    sys.exit("Minor-only findings must route as passed by phase")
PY
}

dispatched_roles_forbid_subagents() {
  local f
  for f in \
    skills/subagent-driven-development/implementer-prompt.md \
    skills/subagent-driven-development/spec-reviewer-prompt.md \
    skills/subagent-driven-development/re-review-prompt.md \
    skills/requesting-code-review/code-reviewer.md \
    skills/epic-verifier/verifier-prompt.md \
    plugins/superpowers-bd/agents/spec-reviewer.md \
    plugins/superpowers-bd/agents/code-reviewer.md \
    plugins/superpowers-bd/agents/epic-verifier.md \
    .codex/agents/spec-reviewer.toml \
    .codex/agents/code-reviewer.toml \
    .codex/agents/epic-verifier.toml; do
    grep -Eiq 'do not dispatch subagents' "$f" || { echo "$f: missing no-subagent clause"; return 1; }
  done
}

spec_line_flows_to_reviewers() {
  contains skills/writing-plans/SKILL.md '^\*\*Spec:\*\*' &&
    contains commands/plan2beads.md 'Spec: <value>' &&
    contains skills/plan2beads/SKILL.md 'Spec: <value>' &&
    contains skills/plan2beads/references/codex-plan2beads-flow.md 'Spec: <value>' &&
    contains skills/subagent-driven-development/context-loading.md '`Spec: <path or URL>`' &&
    contains skills/subagent-driven-development/context-loading.md '^\| `\{spec_ref\}`' &&
    contains skills/subagent-driven-development/spec-reviewer-prompt.md '\{spec_ref\}' &&
    contains skills/subagent-driven-development/implementer-prompt.md '`Spec:` line' &&
    contains .codex/agents/spec-reviewer.toml '`Spec:` line' &&
    contains plugins/superpowers-bd/agents/spec-reviewer.md '`Spec:` line'
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
  run_epic_verifier_persistence portable

check "Epic-verifier persistence is idempotent and fails closed" \
  run_epic_verifier_persistence idempotent

check "Epic-verifier report heredoc is executable and repository-compliant" \
  run_epic_verifier_persistence heredoc

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

check "Ruling examples use the canonical [RULING] <issue-id>: ... why ... cost if wrong prefix" \
  rulings_use_canonical_prefix

check "SDD and Native execution never hold synchronously for a human" \
  sdd_never_holds_for_a_human

check "No retired '[Ask budget tier' prompt remains" \
  no_forbidden_text '\[Ask budget tier' skills commands agents plugins/superpowers-bd .codex AGENTS.md CLAUDE.md docs/README.codex.md

check "Scoped re-review prompt exists and is mirrored" \
  re_review_prompt_is_mirrored

check "Implementer dispatch passes no name (resume needs a non-teammate agent)" \
  implementer_dispatch_has_no_name

check "Plan template no longer demands complete code in plan" \
  no_forbidden_text 'Complete code in plan' skills plugins/superpowers-bd/skills commands

check "Retired testing-anti-patterns reference is gone and unreferenced" \
  no_forbidden_text 'testing-anti-patterns' skills plugins/superpowers-bd agents commands .codex AGENTS.md CLAUDE.md README.md docs/README.codex.md

check "Codex plugin hook commands launch through bash" \
  plugin_hook_commands_start_with_bash

check "Claude review agents cannot dispatch subagents (Agent disallowed)" \
  review_agents_disallow_agent

check "Writing-plans keeps What a Step Contains and the Proportion check" \
  bash -c "grep -q 'What a Step Contains' skills/writing-plans/SKILL.md && grep -q 'Proportion' skills/writing-plans/SKILL.md"

check "Fix-round loop executes: resume, unmessageable fallback, round 3, adjudication" \
  fix_round_loop_executes

check "Every dispatched-role template forbids subagent spawning" \
  dispatched_roles_forbid_subagents

check "Codex spec-reviewer copies apply [RULING] comments" \
  bash -c "grep -q '\[RULING\]' .codex/agents/spec-reviewer.toml && grep -q '\[RULING\]' plugins/superpowers-bd/agents/spec-reviewer.md"

check "Plan Spec: line flows through plan2beads to SDD reviewers and implementers" \
  spec_line_flows_to_reviewers

check "Gap closure has no retry budget separate from the fix-round cap" \
  no_forbidden_text '3 attempts|max_attempts|gap_closure_attempt' skills/verification-before-completion plugins/superpowers-bd/skills/verification-before-completion

check "Execute-plan surfaces describe Native mode, not batches" \
  no_forbidden_text 'in batches|verified batches|[Bb]atch execution with checkpoints' commands/execute-plan.md skills/executing-plans plugins/superpowers-bd/skills/executing-plans README.md

check "All installable skill files stay mirrored" \
  mirrors_match

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -ne 0 ]; then
  exit 1
fi
