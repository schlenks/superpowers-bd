#!/usr/bin/env python3
"""Build E3 (reproduce-before-block reviewer rule): e3-limiter-correct, e3-limiter-buggy."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXP = HERE / "experiments"
REPO = HERE.parent.parent
METHOD = "skills/requesting-code-review/code-reviewer.md"

LIMITER = '''"""Sliding-window rate limiter (single-threaded; callers pass the clock)."""
from bisect import {bisect}
from collections import defaultdict


class SlidingWindowLimiter:
    """Allow at most `limit` requests per key in any window of `window` seconds.

    A request at time t counts against the window (t - window, t]: a request made
    exactly `window` seconds ago has expired.
    """

    def __init__(self, limit: int, window: float) -> None:
        if limit < 1:
            raise ValueError("limit must be >= 1")
        if window <= 0:
            raise ValueError("window must be > 0")
        self.limit = limit
        self.window = window
        self._hits: dict[str, list[float]] = defaultdict(list)

    def allow(self, key: str, now: float) -> bool:
        """Record and allow the request if under the limit; otherwise reject without recording."""
        hits = self._hits[key]
        if hits and now < hits[-1]:
            raise ValueError("clock went backwards")
        expired = {bisect}(hits, now - self.window)
        if expired:
            del hits[:expired]
        if len(hits) >= self.limit:
            return False
        hits.append(now)
        return True

    def remaining(self, key: str, now: float) -> int:
        """Requests still allowed for key at time now. Records nothing."""
        hits = self._hits.get(key, [])
        live = len(hits) - {bisect}(hits, now - self.window)
        return max(0, self.limit - live)

    def reset(self, key: str) -> None:
        """Forget all history for key."""
        self._hits.pop(key, None)
'''

TESTS = '''import pytest

from ratelimit.limiter import SlidingWindowLimiter


def test_allows_up_to_limit_then_rejects():
    lim = SlidingWindowLimiter(limit=2, window=10)
    assert lim.allow("a", 0)
    assert lim.allow("a", 1)
    assert not lim.allow("a", 2)


def test_keys_are_independent():
    lim = SlidingWindowLimiter(limit=1, window=10)
    assert lim.allow("a", 0)
    assert lim.allow("b", 0)


def test_window_slides():
    lim = SlidingWindowLimiter(limit=2, window=10)
    lim.allow("a", 0)
    lim.allow("a", 1)
    assert lim.allow("a", 10.5)


def test_rejected_requests_are_not_recorded():
    lim = SlidingWindowLimiter(limit=1, window=10)
    assert lim.allow("a", 0)
    assert not lim.allow("a", 5)
    assert lim.remaining("a", 5) == 0


def test_remaining_and_reset():
    lim = SlidingWindowLimiter(limit=3, window=10)
    lim.allow("a", 0)
    assert lim.remaining("a", 1) == 2
    lim.reset("a")
    assert lim.remaining("a", 1) == 3


@pytest.mark.parametrize("limit,window", [(0, 10), (1, 0), (1, -1)])
def test_invalid_config(limit, window):
    with pytest.raises(ValueError):
        SlidingWindowLimiter(limit=limit, window=window)


def test_request_exactly_window_ago_has_expired():
    lim = SlidingWindowLimiter(limit=1, window=10)
    assert lim.allow("a", 0)
    assert lim.remaining("a", 10) == 1
    assert lim.allow("a", 10)


def test_clock_backwards():
    lim = SlidingWindowLimiter(limit=5, window=10)
    lim.allow("a", 5)
    with pytest.raises(ValueError):
        lim.allow("a", 4)
'''

SHOW = '''rl-2: Sliding-window rate limiter
Status: in_progress  Priority: P1  Type: task
Parent: rl-1 (Epic: API rate limiting)

## Description
Add `SlidingWindowLimiter(limit, window)` in ratelimit/limiter.py. Single-threaded use
only: the API server runs one limiter per worker process and passes a monotonic clock
value as `now` (seconds, float).

## Acceptance Criteria
- `allow(key, now)`: allow and record the request when fewer than `limit` requests for
  `key` fall in the window (now - window, now]; otherwise return False and record nothing
- A request made exactly `window` seconds ago has expired (half-open window)
- `remaining(key, now)`: requests still allowed, never negative, records nothing
- `reset(key)`: forget history for key
- ValueError for limit < 1 or window <= 0
- `allow()` raises ValueError when `now` is earlier than the key's most recently *recorded*
  (allowed) request; rejected requests are not tracked, and `remaining()` does no clock check
- Keys are bounded by the caller (< 1,000 tenants), so key eviction is out of scope
- Tests for the above

## Files
- ratelimit/limiter.py (create)
- tests/test_limiter.py (create)
'''

GITIGNORE = "temp/\n__pycache__/\n.pytest_cache/\n"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def build(name: str, bisect: str) -> None:
    d = EXP / name
    write(d / "fixture/README.md", "# api-utils\n\nShared helpers for the API server.\n")
    write(d / "fixture/ratelimit/__init__.py", "")
    write(d / "fixture/tests/__init__.py", "")
    write(d / "fixture/.gitignore", GITIGNORE)
    # The feature lands as a second commit so the reviewer sees HEAD~1..HEAD.
    write(d / "feature/ratelimit/limiter.py", LIMITER.format(bisect=bisect))
    tests = TESTS
    if bisect != "bisect_right":  # the buggy twin must not ship the test that exposes it
        start = tests.index("def test_request_exactly_window_ago_has_expired")
        tests = tests[:start] + tests[tests.index("def test_clock_backwards"):]
    write(d / "feature/tests/test_limiter.py", tests)
    write(d / "setup.sh", f'cp -R "{d}/feature/." . && git add -A && git commit -q -m "feat: sliding-window rate limiter (rl-2)"\n')
    write(d / "bd/show-rl-2.md", SHOW)
    write(d / "bd/comments-rl-2.json", "[]")
    head_method = subprocess.run(["git", "show", f"HEAD:{METHOD}"], cwd=REPO, check=True,
                                 capture_output=True, text=True).stdout
    write(d / "methodology-A.md", head_method)
    render = {
        "source": "skills/subagent-driven-development/code-quality-reviewer-prompt.md",
        "heading": "## Shared Code Reviewer Prompt",
        "append_headings": ["**Append to the prompt:**", "**Architecture checks", "**Rule-of-five skill application"],
        "arms": {"A": "worktree", "B": "worktree"},
        "vars": {
            "base_sha": "HEAD~1", "head_sha": "HEAD", "issue_id": "rl-2", "reviewer_number": 1,
            "n_reviews": 1, "wave_number": 1,
            "rule_of_five_code_path": str(REPO / "skills/rule-of-five-code/SKILL.md"),
            "rule_of_five_tests_path": str(REPO / "skills/rule-of-five-tests/SKILL.md"),
            "rule_of_five_plans_path": str(REPO / "skills/rule-of-five-plans/SKILL.md"),
        },
        "arm_vars": {"A": {"code_reviewer_path": str(d / "methodology-A.md")},
                     "B": {"code_reviewer_path": str(REPO / METHOD)}},
    }
    write(d / "render.json", json.dumps(render, indent=2))
    write(d / "config.json", json.dumps({"model": "sonnet", "timeout": 900}, indent=2))
    kind = "correct" if bisect == "bisect_right" else "buggy"
    write(d / "grade.py", "import sys, pathlib\nsys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))\n"
                          f"from e3_grade import grade_review\n\n\ndef grade(work, run):\n"
                          f"    return grade_review(work, run, kind={kind!r})\n")


if __name__ == "__main__":
    build("e3-limiter-correct", "bisect_right")
    build("e3-limiter-buggy", "bisect_left")
    print("built")
