# TaskFlow API — Test Suite Summary

**Total tests:** 47
**Pass rate:** 47/47 (100%)
**Line coverage:** 94%
**Branch coverage:** 87%

---

## Authentication Tests (6 tests)

| # | Test | Status |
|---|------|--------|
| 1 | Returns 401 when no Authorization header present | PASS |
| 2 | Returns 401 with TOKEN_INVALID for malformed token | PASS |
| 3 | Returns 401 with TOKEN_EXPIRED for expired token | PASS |
| 4 | Accepts valid bearer token and proceeds | PASS |
| 5 | Returns 401 when Authorization header uses Basic scheme | PASS |
| 6 | Returns 401 for empty bearer token value | PASS |

## GET /tasks Tests (10 tests)

| # | Test | Status |
|---|------|--------|
| 7 | Returns empty array when no tasks exist | PASS |
| 8 | Returns tasks with default pagination (page=1, limit=20) | PASS |
| 9 | Respects custom page and limit parameters | PASS |
| 10 | Caps limit at 100 | PASS |
| 11 | Filters by status=todo | PASS |
| 12 | Filters by status=in_progress | PASS |
| 13 | Filters by status=done | PASS |
| 14 | Sorts by createdAt descending (default) | PASS |
| 15 | Sorts by priority ascending | PASS |
| 16 | Does not return soft-deleted tasks | PASS |

## POST /tasks Tests (11 tests)

| # | Test | Status |
|---|------|--------|
| 17 | Creates task with required title only, defaults applied | PASS |
| 18 | Creates task with all fields provided | PASS |
| 19 | Returns 400 when title is missing | PASS |
| 20 | Returns 400 when title is empty string | PASS |
| 21 | Returns 400 when title exceeds 200 characters | PASS |
| 22 | Trims whitespace from title | PASS |
| 23 | Returns 400 for priority outside 1-5 range | PASS |
| 24 | Returns 400 for non-integer priority (e.g., 3.5) | PASS |
| 25 | Returns 400 for invalid due_date format | PASS |
| 26 | Returns 400 for invalid status value | PASS |
| 27 | Sets closed_at when task created with status=done | PASS |

## PATCH /tasks/:id Tests (12 tests)

| # | Test | Status |
|---|------|--------|
| 28 | Updates title only (partial update) | PASS |
| 29 | Updates description only | PASS |
| 30 | Updates priority only | PASS |
| 31 | Updates status from todo to in_progress | PASS |
| 32 | Updates status from in_progress to done, sets closed_at | PASS |
| 33 | Updates status from done to todo, clears closed_at | PASS |
| 34 | Updates multiple fields simultaneously | PASS |
| 35 | Returns 404 for non-existent task ID | PASS |
| 36 | Returns 400 for invalid title (empty after trim) | PASS |
| 37 | Returns 400 for priority=0 | PASS |
| 38 | Sets due_date to null to remove it | PASS |
| 39 | Refreshes updated_at on any field change | PASS |

## DELETE /tasks/:id Tests (4 tests)

| # | Test | Status |
|---|------|--------|
| 40 | Deletes existing task and returns { deleted: true } | PASS |
| 41 | Returns 404 for non-existent task ID | PASS |
| 42 | Returns 404 when deleting an already-deleted task | PASS |
| 43 | Deleted task no longer appears in GET /tasks | PASS |

## Rate Limiting Tests (2 tests)

| # | Test | Status |
|---|------|--------|
| 44 | Returns rate limit headers on normal requests | PASS |
| 45 | Returns 429 after exceeding 120 requests/minute | PASS |

## Error Envelope Tests (2 tests)

| # | Test | Status |
|---|------|--------|
| 46 | All error responses include standard envelope with error code | PASS |
| 47 | All success responses include meta.request_id and meta.timestamp | PASS |

---

## Coverage Notes

- **Not covered:** Edge cases around concurrent updates (out of scope for unit tests)
- **Not covered:** Database connection failure scenarios (mocked in unit tests)
- **Known gap:** No explicit test for `413 Payload Too Large` response (body limit handled by express middleware, verified manually)
