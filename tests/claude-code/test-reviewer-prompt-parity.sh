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
