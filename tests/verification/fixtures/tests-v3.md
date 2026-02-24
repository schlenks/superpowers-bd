# TaskFlow API v2.0 — Test Suite Summary

**Total tests:** 62
**Pass rate:** 62/62 (100%)
**Line coverage:** 91%
**Branch coverage:** 84%

---

## Authentication Tests (8 tests)

| # | Test | Status |
|---|------|--------|
| 1 | Returns 401 when no Authorization header present | PASS |
| 2 | Returns 401 with TOKEN_INVALID for malformed token | PASS |
| 3 | Returns 401 with TOKEN_EXPIRED for expired token | PASS |
| 4 | Accepts valid bearer token and proceeds | PASS |
| 5 | Returns 401 when Authorization header uses Basic scheme | PASS |
| 6 | Returns 401 for empty bearer token value | PASS |
| 7 | Returns 401 for tokens shorter than 10 characters (fast-reject guard) | PASS |
| 8 | Attaches userId to request context on valid token | PASS |

## GET /tasks Tests (12 tests)

| # | Test | Status |
|---|------|--------|
| 9 | Returns empty array when no tasks exist | PASS |
| 10 | Returns tasks with default pagination (page=1, limit=20) | PASS |
| 11 | Respects custom page and limit parameters | PASS |
| 12 | Caps limit at 100 | PASS |
| 13 | Filters by status=todo | PASS |
| 14 | Filters by status=in_progress | PASS |
| 15 | Filters by status=done | PASS |
| 16 | Returns 400 for unrecognized status value | PASS |
| 17 | Sorts by createdAt descending (default) | PASS |
| 18 | Sorts by priority ascending | PASS |
| 19 | Does not return soft-deleted tasks | PASS |
| 20 | Returns empty tasks array with has_more=false for out-of-range page | PASS |

## POST /tasks Tests (12 tests)

| # | Test | Status |
|---|------|--------|
| 21 | Creates task with required title only, defaults applied | PASS |
| 22 | Creates task with all fields provided | PASS |
| 23 | Returns 400 when title is missing | PASS |
| 24 | Returns 400 when title is empty string | PASS |
| 25 | Returns 400 when title exceeds 200 characters | PASS |
| 26 | Trims whitespace from title | PASS |
| 27 | Returns 400 for priority outside 1-5 range | PASS |
| 28 | Returns 400 for non-integer priority (e.g., 3.5) | PASS |
| 29 | Returns 400 for invalid due_date format | PASS |
| 30 | Returns 400 for past due_date | PASS |
| 31 | Returns 400 for invalid status value | PASS |
| 32 | Sets closed_at when task created with status=done | PASS |

## PATCH /tasks/:id Tests (13 tests)

| # | Test | Status |
|---|------|--------|
| 33 | Updates title only (partial update) | PASS |
| 34 | Updates description only | PASS |
| 35 | Updates priority only | PASS |
| 36 | Updates status from todo to in_progress | PASS |
| 37 | Updates status from in_progress to done, sets closed_at | PASS |
| 38 | Updates status from done to todo, clears closed_at | PASS |
| 39 | Updates multiple fields simultaneously | PASS |
| 40 | Returns 404 for non-existent task ID | PASS |
| 41 | Returns 400 for invalid title (empty after trim) | PASS |
| 42 | Returns 400 for priority=0 | PASS |
| 43 | Sets due_date to null to remove it | PASS |
| 44 | Refreshes updated_at on any field change | PASS |
| 45 | Allows duplicate titles — spec Section 4.1 explicitly permits repeats | PASS |

## DELETE /tasks/:id Tests (4 tests)

| # | Test | Status |
|---|------|--------|
| 46 | Soft-deletes existing task and returns { deleted: true, id } | PASS |
| 47 | Returns 404 for non-existent task ID | PASS |
| 48 | Returns 404 when deleting an already-deleted task | PASS |
| 49 | Deleted task no longer appears in GET /tasks | PASS |

## Bulk Update Tests (7 tests)

| # | Test | Status |
|---|------|--------|
| 50 | Updates multiple tasks in a single request | PASS |
| 51 | Reports per-item failure for not-found task IDs | PASS |
| 52 | Returns 400 for bulk operations exceeding 100 items | PASS |
| 53 | Sets closed_at when bulk update changes status to done | PASS |
| 54 | Clears closed_at when bulk update reopens a done task | PASS |
| 55 | Validates priority range in bulk update items | PASS |
| 56 | Processes updates sequentially; earlier successes not rolled back by later failures | PASS |

## Bulk Delete Tests (4 tests)

| # | Test | Status |
|---|------|--------|
| 57 | Deletes multiple tasks and returns deleted count | PASS |
| 58 | Returns 404 when any task ID is not found | PASS |
| 59 | Returns 400 for bulk delete exceeding 100 items | PASS |
| 60 | Deleted tasks no longer appear in GET /tasks | PASS |

## Rate Limiting Tests (2 tests)

| # | Test | Status |
|---|------|--------|
| 61 | Returns rate limit headers on normal requests | PASS |
| 62 | Returns 429 with Retry-After after exceeding 120 requests/minute | PASS |

---

## Coverage Notes

Test infrastructure uses a mock clock (`vi.useFakeTimers()`) for deterministic
behavior in time-dependent scenarios: due date validation, rate limit window
expiry, `closed_at` timestamp assertions, and `updated_at` refresh checks. The
mock is initialized in `beforeEach` and restored in `afterEach` to prevent test
pollution.

- **Not covered:** Concurrent update scenarios (out of scope for unit tests)
- **Not covered:** Database persistence across restarts (in-memory only)
- **Not covered:** Body size limit (413 response handled by express middleware,
  verified manually — express does not surface this through the normal handler path)
- **Not covered:** CORS preflight behavior (handled by middleware integration tests)
