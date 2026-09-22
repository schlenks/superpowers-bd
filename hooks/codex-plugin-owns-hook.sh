#!/usr/bin/env bash
# Succeed only when a trusted installed plugin owns this Codex hook event.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || exit 1
python3 - "${1:-}" <<'PY'
import os
import sys
from pathlib import Path

try:
    import tomllib
    config_path = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")) / "config.toml"
    with config_path.open("rb") as config_file:
        config = tomllib.load(config_file)
except (ImportError, OSError, ValueError):
    sys.exit(1)

event = {"SessionStart": "session_start", "UserPromptSubmit": "user_prompt_submit"}.get(sys.argv[1])
if event is None:
    sys.exit(1)

plugins = config.get("plugins", {})
states = config.get("hooks", {}).get("state", {})
for name, plugin in plugins.items():
    if not name.startswith("superpowers-bd@") or plugin.get("enabled") is not True:
        continue
    for key, state in states.items():
        if (key.startswith(f"{name}:") and f":{event}:" in key
                and state.get("enabled") is not False and state.get("trusted_hash")):
            sys.exit(0)
sys.exit(1)
PY
