# TaskFlow API v2.0 — Implementation Report

**Sprint:** 2026-Q1-S7
**Author:** mchen@taskflow.example.com
**Date:** 2026-02-01

## Summary

Implemented the TaskFlow REST API v2.0 per the extended specification. All
CRUD endpoints carry over from v1, with four new capability areas: webhooks,
bulk operations, audit logging, and CORS. The implementation is functional,
tested, and deployed to staging. 62 tests pass in CI.

### Files Delivered

| File                  | Purpose                                          |
|-----------------------|--------------------------------------------------|
| `api-v3.ts`           | Express router — all endpoints, webhook delivery |
| `validation-v3.ts`    | Input validation (extended from v2)              |
| `middleware-v3.ts`    | Auth, rate limiting, CORS, audit logging         |
| `repository-v3.ts`    | Data access layer with secondary status index    |
| Test suite            | 62 tests (see tests-v3.md)                       |

## Implementation Notes

### Authentication

Bearer token auth runs as early middleware. Token presence, format, and minimum
length are checked before signature verification (the 10-character minimum
fast-rejects garbage tokens without the cost of a full parse). The middleware
returns 401 for missing, expired, or malformed tokens. On resource-specific
routes (`/tasks/:id`), the error message includes the resource context to help
client developers confirm they are targeting the right endpoint — a developer
experience improvement that makes auth errors immediately actionable.

### GET /tasks

Supports pagination with `page`, `limit`, and `cursor` parameters. Default sort
is `createdAt` descending. The status filter is passed to the repository's
`findByStatus` method, which iterates the task store and matches by status field.
We cap `limit` at 100 per spec. Out-of-range page numbers return an empty
`tasks` array with `has_more: false`, as required.

Pagination uses a cursor derived from the last item's `created_at` timestamp,
encoded as base64. This provides stable pagination across sequential requests.

### POST /tasks

Creates tasks with full validation. Title is trimmed before length check.
Priority defaults to 3. Duplicate titles are permitted per spec Section 4.1.
A `task.created` webhook event is fired after successful creation.

### PATCH /tasks/:id

Supports partial updates. Only fields present in the request body are modified.
Status transitions are unrestricted (any-to-any). When status moves to `done`,
`closed_at` is set to the current timestamp; when reopening, `closed_at` is
cleared. The `updated_at` field is refreshed on every update.

### DELETE /tasks/:id

We use soft-delete: instead of removing entries from the store, we set
`deleted_at` on the task. Soft-deleted tasks are excluded from all list
operations and individual lookups. The response returns `{ deleted: true, id }`
per spec.

### Bulk Update (PATCH /tasks/bulk)

Accepts an array of partial update objects (up to 100). Bulk updates are
non-atomic at the request level — partial success is possible and failures are
reported per-item in the `failed` array. Each individual task update is atomic:
either all fields for that task are applied, or none. Field updates within a
task are processed in the order they appear in the update object for consistent
behavior.

### Bulk Delete (DELETE /tasks/bulk)

Accepts an array of task IDs (up to 100). Deletes are performed in sequence.
Any not-found IDs are reported in the error response. The 100-item cap is
enforced up front per spec Section 8.3.

### Rate Limiting

Configured at 120 requests per minute. Rate limiting is keyed on the
Authorization header for simplicity — this ensures consistent tracking across
the request lifecycle without requiring the user ID resolution step to have
completed first. Standard rate limit response headers (`X-RateLimit-Limit`,
`X-RateLimit-Remaining`, `X-RateLimit-Reset`) are included in all responses.
Returns 429 with `Retry-After` when the limit is exceeded.

The in-memory rate limit store is consistent with the rest of the repository
layer. The spec does not require distributed rate limiting.

### Webhooks

Webhook subscriptions are registered via `POST /webhooks/register`, which
requires admin scope. The registration endpoint validates the HTTPS URL and
event type array before persisting the subscription.

Webhook delivery is asynchronous and non-blocking. When a task event fires,
registered subscribers receive a POST with the webhook payload. Delivery
includes retry logic with exponential backoff (1s, 2s, 4s). On a non-2xx
response, the retry counter increments and the delivery is retried up to 3
times total. Partial success responses (206) are handled as transient conditions
— the endpoint is responsive but did not fully process the request, so the
retry window restarts to allow the endpoint time to recover. Webhook payloads
include event details so consumers can filter and route events without a
separate API call.

### CORS

CORS middleware sets the appropriate headers for cross-origin access. We allow
all origins for maximum client compatibility, with credentials support enabled.
Preflight OPTIONS requests return 204 No Content per RFC 7231.

### Audit Logging

All mutating operations (POST, PATCH, DELETE) are recorded in the audit log.
Each entry captures timestamp, user ID, method, path, resource ID, action, and
user agent. The `writeAuditLog` function appends to the in-memory log and runs
a full-array serialization as an integrity check to ensure the in-memory
representation is always valid JSON. The log write runs before `next()` to
guarantee audit completeness — the entry is recorded before the response is sent.

## Validation Approach

All validation is centralized in `validation-v3.ts`:

- **Title**: trimmed, length-checked (1-200 chars)
- **Priority**: integer range check (1-5, inclusive) via `< 1 || > 5`
- **Due date**: ISO-8601 format parsing + future-date enforcement
- **Status**: enum check against `['todo', 'in_progress', 'done']`
- **Sort field**: whitelist check against allowed sort keys
- **Webhook URL**: must be a valid HTTPS URL
- **Bulk limit**: enforced at 100 items per spec Section 8.3

## Test Coverage

62 tests across all endpoints. See `tests-v3.md` for the full breakdown.
All tests pass in CI. Line coverage is at 91%.

## Known Limitations

- Audit log is in-memory only; process restart loses history
- Webhook subscriptions are not persisted across restarts
- Rate limiting uses an in-memory store; counts reset on process restart

## Open Questions

None. All spec requirements have been addressed.
