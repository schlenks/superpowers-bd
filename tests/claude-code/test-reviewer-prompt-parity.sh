#!/usr/bin/env bash
# Verify code-reviewer agent delegates to the canonical methodology file.
# Prevents re-introduction of duplicated methodology in the agent body.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENT="$REPO_ROOT/agents/code-reviewer.md"
TEMPLATE="$REPO_ROOT/skills/requesting-code-review/code-reviewer.md"

errors=0

# 1. Canonical methodology file must exist
if [[ ! -f "$TEMPLATE" ]]; then
  echo "FAIL: Canonical methodology file missing: $TEMPLATE"
  exit 1
fi

# 2. Agent body must reference the canonical file (self-read pattern)
if grep -q 'requesting-code-review/code-reviewer.md' "$AGENT"; then
  echo "PASS: Agent references canonical methodology file"
else
  echo "FAIL: Agent does not reference requesting-code-review/code-reviewer.md"
  errors=$((errors + 1))
fi

# 3. Agent body must NOT contain duplicated methodology (detect drift reintroduction)
#    The methodology has a "## Precision Gate" section — if the agent contains it,
#    someone re-duplicated the content.
agent_body=$(awk '/^---$/{c++; if(c==2){found=1; next}} found' "$AGENT")
if echo "$agent_body" | grep -q '## Precision Gate'; then
  echo "FAIL: Agent body contains duplicated methodology (found '## Precision Gate')"
  echo "      The agent should delegate to the canonical file, not duplicate it."
  errors=$((errors + 1))
else
  echo "PASS: Agent body does not contain duplicated methodology"
fi

if [[ $errors -gt 0 ]]; then
  exit 1
fi
