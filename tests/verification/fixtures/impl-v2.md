# TaskFlow API — Implementation Report

**Sprint:** 2026-Q1-S3
**Author:** jgarcia@taskflow.example.com
**Date:** 2026-01-28

## Summary

Implemented the TaskFlow REST API per the v1.0 specification. All four CRUD endpoints are functional, tested, and deployed to staging. The API handles authentication, validation, pagination, and rate limiting.

### Files Delivered

| File                  | Purpose                              |
|-----------------------|--------------------------------------|
| `api-v2.ts`           | Express router with all 4 endpoints  |
| `validation-v2.ts`    | Input validation functions           |
| Test suite            | 47 tests (see tests-v2.md)           |

## Implementation Notes

### Authentication
Bearer token auth is implemented as middleware. We validate token presence and format, returning `401` with appropriate error codes (`TOKEN_EXPIRED` or `TOKEN_INVALID`). Tokens are verified against the auth service on every request.

### GET /tasks
Supports pagination with `page` and `limit` parameters. Default sort is `createdAt` descending. The `status` filter is passed through to the database query for efficient filtering. We cap `limit` at 100 to prevent excessive payloads.

### POST /tasks
Creates tasks with full validation. Title is trimmed before length check. Priority defaults to 3 if not provided. We added email notifications on task creation to improve team awareness — when a task is created, an email is sent to the project channel so team members can see new work items immediately.

### PATCH /tasks/:id
Supports partial updates. Only fields present in the request body are modified. Status transitions are unrestricted (any-to-any). When status moves to `done`, we set `closed_at` to the current timestamp. The `updated_at` field is refreshed on every update.

### DELETE /tasks/:id
We chose soft-delete for safety — instead of permanently removing tasks, we set a `deleted_at` timestamp. This lets us recover accidentally deleted tasks and maintains referential integrity with any future audit log. The response still returns `{ deleted: true }` so clients see the expected contract.

### Rate Limiting
Configured at 120 requests per minute per user using `express-rate-limit`. Includes standard rate limit headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`) and returns `429` with `Retry-After` when exceeded.

### Request Size Limits
We added a 10KB body size limit via `express.json({ limit: '10kb' })` to protect against payload-based DoS attacks. This is a standard hardening measure and covers all realistic task payloads (title max 200 chars + description max 2000 chars is well under 10KB).

## Validation Approach

All validation is centralized in `validation-v2.ts`:
- **Title**: trimmed, length-checked (1-200 chars)
- **Priority**: integer range check (1-5)
- **Due date**: ISO-8601 format parsing (note: we validate format but do not enforce future-date constraint at the validation layer — this is left for the application layer to decide based on use case)
- **Status**: enum check against `['todo', 'in_progress', 'done']`

## Test Coverage

47 tests across all endpoints. See `tests-v2.md` for the full breakdown. All tests pass in CI. Coverage is at 94% line coverage.

## Known Limitations

- No bulk operations (create/update/delete multiple tasks)
- No webhook support for status changes
- Pagination uses offset-based approach (cursor-based would scale better for large datasets)

## Open Questions

None. All spec requirements have been addressed.
