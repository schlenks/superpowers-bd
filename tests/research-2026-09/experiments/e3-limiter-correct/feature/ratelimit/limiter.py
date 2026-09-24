"""Sliding-window rate limiter (single-threaded; callers pass the clock)."""
from bisect import bisect_right
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
        expired = bisect_right(hits, now - self.window)
        if expired:
            del hits[:expired]
        if len(hits) >= self.limit:
            return False
        hits.append(now)
        return True

    def remaining(self, key: str, now: float) -> int:
        """Requests still allowed for key at time now. Records nothing."""
        hits = self._hits.get(key, [])
        live = len(hits) - bisect_right(hits, now - self.window)
        return max(0, self.limit - live)

    def reset(self, key: str) -> None:
        """Forget all history for key."""
        self._hits.pop(key, None)
