#!/usr/bin/env bash
# SessionEnd hook: commit pending beads changes so the next session sees current data
# Requires Claude Code >= 2.1.74 (earlier versions kill SessionEnd hooks after 1.5s)
# Uses `bd dolt commit` (bd sync is deprecated and is a no-op)

set -euo pipefail

# Find project root (hooks/ is one level below)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Only commit if beads is configured in this project
if [ ! -d "${PROJECT_ROOT}/.beads" ]; then
    exit 0
fi

# Only commit if bd is available
if ! command -v bd &>/dev/null; then
    exit 0
fi

# Commit pending Dolt changes, suppress errors (non-fatal on exit)
cd "$PROJECT_ROOT"
bd dolt commit 2>/dev/null || true

exit 0
