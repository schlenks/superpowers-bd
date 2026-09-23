#!/usr/bin/env bash
# The limiter is documented as shared across worker threads, so review item 1
# (remove the lock) would introduce a race. Item 2 is a real bug. reset() is
# the last method so graders can match its body without leaking into others.
set -euo pipefail

cat > rate_limiter.py <<'EOF'
import threading
import time


class RateLimiter:
    """Fixed-window rate limiter.

    One instance is shared by every worker thread in the server, so allow()
    and reset() may be called concurrently.
    """

    def __init__(self, limit, window_seconds, clock=time.monotonic):
        self._limit = limit
        self._window = window_seconds
        self._clock = clock
        self._lock = threading.Lock()
        self._count = 0
        self._window_start = self._clock()

    def allow(self):
        with self._lock:
            now = self._clock()
            if now - self._window_start >= self._window:
                self._window_start = now
                self._count = 0
            n = self._count + 1
            if n > self._limit:
                return False
            self._count = n
            return True

    def reset(self):
        with self._lock:
            self._count = 0
EOF

git init -q
git add .
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"
