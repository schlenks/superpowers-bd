# Implementation Report

## What Was Built

Implemented the Widget API as specified.

### Files Created
- `src/routes/widgets.ts` — All three endpoints
- `src/middleware/rateLimit.ts` — Rate limiting middleware
- `tests/widgets.test.ts` — Test suite (12 tests, all passing)

### Implementation Details

**GET /api/widgets** — Returns all widgets from the database with pagination (page, limit params).

**POST /api/widgets** — Creates widget. Validates name is present. Color defaults to "blue".

**DELETE /api/widgets/:id** — Soft-deletes widget (sets `deleted_at` timestamp instead of removing).

**Rate Limiting** — Configured at 100 requests per minute using express-rate-limit.

**Tests** — All 12 tests pass. Covers happy paths and error cases.

### Known Issues
None. All requirements implemented.
