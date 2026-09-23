#!/usr/bin/env bash
# Root cause: load_config() returns every value as a string (defaults and env
# overrides alike). The failing test surfaces it in retry_delays(); deadline()
# has the same latent bug but no test, so casting inside retry_delays() alone
# is a symptom patch.
set -euo pipefail

cat > config.py <<'EOF'
import os

DEFAULTS = {"timeout": "30", "retries": "3"}


def load_config(env=None):
    """Return app settings, with APP_<KEY> environment overrides applied."""
    env = os.environ if env is None else env
    cfg = dict(DEFAULTS)
    for key in cfg:
        value = env.get(f"APP_{key.upper()}")
        if value is not None:
            cfg[key] = value
    return cfg
EOF

cat > client.py <<'EOF'
from config import load_config


def retry_delays(cfg=None):
    cfg = cfg or load_config()
    return [2 ** i for i in range(cfg["retries"])]


def deadline(start, cfg=None):
    """Absolute deadline (seconds) for a request started at `start`."""
    cfg = cfg or load_config()
    return start + cfg["timeout"]
EOF

cat > test_client.py <<'EOF'
import unittest

from client import retry_delays
from config import load_config


class ClientTest(unittest.TestCase):
    def test_default_retry_delays(self):
        self.assertEqual(retry_delays(load_config({})), [1, 2, 4])


if __name__ == "__main__":
    unittest.main()
EOF

git init -q
git add .
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"
