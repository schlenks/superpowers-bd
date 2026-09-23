#!/usr/bin/env bash
# Empty stdlib-only Python project in a git repo. validators.py deliberately
# does not exist so the first Write to it is observable in the trace.
set -euo pipefail

cat > README.md <<'EOF'
# utils

Small stdlib-only helpers. Run tests with `python3 -m unittest`.
EOF

git init -q
git add README.md
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"
