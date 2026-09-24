rl-2: Sliding-window rate limiter
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
