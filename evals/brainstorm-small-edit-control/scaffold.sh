#!/usr/bin/env bash
# A one-function module with a fully specified edit request.
set -euo pipefail

cat > greet.py <<'PYEOF'
def greet(name, greeting="Hello"):
    return f"{greeting}, {name}!"
PYEOF

git init -q
git add .
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"
