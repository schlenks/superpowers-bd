# TaskFlow API Specification

Version 2.0 | Last updated: 2026-02-01

## 1. Overview

TaskFlow is a lightweight task management REST API. It supports creating, reading, updating, and deleting tasks with priority levels, due dates, and status tracking. Version 2.0 adds webhooks, bulk operations, audit logging, and CORS policy.

### Base URL

```
https://api.taskflow.example.com/v1
```

### Response Envelope

All responses use a standard JSON envelope:

```json
{
  "data": <payload>,
  "error": null,
  "meta": { "request_id": "uuid", "timestamp": "ISO-8601" }
}
```

Error responses set `data` to `null` and populate `error`:

```json
{
  "data": null,
  "error": { "code": "VALIDATION_ERROR", "message": "..." },
  "meta": { "request_id": "uuid", "timestamp": "ISO-8601" }
}
```

## 2. Authentication

All endpoints require a valid Bearer token in the `Authorization` header:

```
Authorization: Bearer <token>
```

Tokens are issued by the `/auth/token` endpoint (out of scope for this API). Invalid or missing tokens return `401 Unauthorized`.

Token validation rules:
- Must be a non-empty string
- Must be present on every request
- Expired tokens return `401` with error code `TOKEN_EXPIRED`
- Malformed tokens return `401` with error code `TOKEN_INVALID`

## 3. Endpoints

### 3.1 GET /tasks

Returns a paginated list of tasks for the authenticated user.

**Query Parameters:**

| Parameter  | Type    | Default | Description                              |
|-----------|---------|---------|------------------------------------------|
| `page`    | integer | 1       | Page number (1-indexed)                  |
| `limit`   | integer | 20      | Items per page (max 100)                 |
| `status`  | string  | —       | Filter by status. Must be one of: `todo`, `in_progress`, `done`. Returns `400` for unrecognized values. |
| `sort`    | string  | `createdAt` | Sort field: `createdAt`, `updatedAt`, `priority` |
| `order`   | string  | `desc`  | Sort direction: `asc` or `desc`          |

**Pagination Behavior:**
- Pagination cursor must be stable under concurrent writes. Use opaque cursor encoding task ID, not timestamp.
- If the requested page is beyond the last page, return empty tasks array with `has_more: false`.
- The `pagination` object must include `has_more` to indicate whether additional pages exist.

**Status Filtering:**
- Status filtering must use indexed lookup. Full table scans are not acceptable at scale.

**Response (200):**

```json
{
  "data": {
    "tasks": [
      {
        "id": "uuid",
        "title": "string",
        "description": "string | null",
        "status": "todo | in_progress | done",
        "priority": 1-5,
        "due_date": "ISO-8601 | null",
        "created_at": "ISO-8601",
        "updated_at": "ISO-8601",
        "closed_at": "ISO-8601 | null"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "pages": 8,
      "has_more": true
    }
  }
}
```

### 3.2 POST /tasks

Creates a new task.

**Request Body:**

```json
{
  "title": "string (required, 1-200 chars, trimmed)",
  "description": "string (optional, max 2000 chars)",
  "priority": "integer (optional, 1-5, default 3)",
  "due_date": "ISO-8601 (optional, must be in the future)",
  "status": "string (optional, default 'todo')"
}
```

**Validation Rules:**
- `title` is required and must be 1-200 characters after trimming whitespace
- `priority` must be an integer between 1 and 5 (inclusive)
- `due_date`, if provided, must be a valid ISO-8601 date in the future
- `status`, if provided, must be one of: `todo`, `in_progress`, `done`

**Response (201):**

Returns the created task object in the standard envelope.

### 3.3 PATCH /tasks/:id

Updates an existing task. Supports partial updates — only provided fields are modified.

**Request Body (all fields optional):**

```json
{
  "title": "string (1-200 chars, trimmed)",
  "description": "string (max 2000 chars)",
  "priority": "integer (1-5)",
  "due_date": "ISO-8601 (must be in the future) | null",
  "status": "string (todo | in_progress | done)"
}
```

**Status Transition Rules:**
- Any status can transition to any other status
- When status changes to `done`, set `closed_at` to current timestamp
- When reopening (status changes from `done` to `todo` or `in_progress`), clear `closed_at` to `null`
- `updated_at` is always set to current timestamp on any update

**Response (200):**

Returns the updated task object in the standard envelope.

**Errors:**
- `404` if task not found
- `400` if validation fails

### 3.4 DELETE /tasks/:id

Deletes a task. DELETE may use soft-delete with `deleted_at` timestamp. Tasks with `deleted_at` set must be excluded from all list operations and individual lookups.

**Response (200):**

```json
{
  "data": { "deleted": true, "id": "uuid" },
  "meta": { ... }
}
```

**Errors:**
- `404` if task not found

## 4. Validation

### 4.1 Title Validation
- Required on POST, optional on PATCH
- Must be 1-200 characters after trimming leading/trailing whitespace
- Empty string after trimming is invalid
- Task titles do not need to be unique. Duplicate titles are permitted.

### 4.2 Priority Validation
- Must be an integer between 1 and 5 (inclusive)
- Non-integer values return `400`
- Values outside range return `400`

### 4.3 Due Date Validation
- Must be a valid ISO-8601 date string
- Must be in the future (after current server time)
- Can be set to `null` to remove a due date
- Past dates return `400` with message "due_date must be in the future"

### 4.4 Status Validation
- Must be one of: `todo`, `in_progress`, `done`
- Unrecognized values return `400`
- Applied consistently on both GET filter and POST/PATCH body

## 5. Error Handling

All errors follow the standard envelope format.

| Status | Code                   | When                                        |
|--------|------------------------|---------------------------------------------|
| 400    | `VALIDATION_ERROR`     | Invalid input, missing required fields      |
| 400    | `BULK_LIMIT_EXCEEDED`  | Bulk operation exceeds 100-item limit       |
| 401    | `UNAUTHORIZED`         | Missing or invalid auth token               |
| 403    | `INSUFFICIENT_SCOPE`   | Token lacks required scope for operation    |
| 404    | `NOT_FOUND`            | Task ID does not exist                      |
| 413    | `PAYLOAD_TOO_LARGE`    | Request body exceeds size limit             |
| 429    | `RATE_LIMITED`         | Too many requests                           |
| 500    | `INTERNAL_ERROR`       | Unexpected server error                     |

## 6. Rate Limiting and Security

### 6.1 Authentication Error Policy

Authentication errors must not reveal resource existence. Return a generic `401` for all unauthenticated access, regardless of whether the requested resource exists. Error messages must not reference specific resource IDs or indicate whether a resource with the given ID exists.

### 6.2 Rate Limiting

- 120 requests per minute per authenticated user
- Rate limits are per-user. Key must be derived from the authenticated user identity, not the request credential. Using the raw `Authorization` header as a rate-limit key is not permitted — clients sharing a token would exhaust a single bucket.
- Rate limit headers included in all responses:
  - `X-RateLimit-Limit: 120`
  - `X-RateLimit-Remaining: <n>`
  - `X-RateLimit-Reset: <unix-timestamp>`
- When exceeded, return `429` with `Retry-After` header

## 7. Webhooks

### 7.1 Registration

Webhook subscriptions are registered via `POST /webhooks/register`.

**POST /webhooks/register requires admin scope. Returns `403 INSUFFICIENT_SCOPE` for non-admin tokens.**

**Request Body:**

```json
{
  "url": "string (required, HTTPS URL)",
  "events": ["task.created", "task.updated", "task.deleted"]
}
```

**Response (201):**

```json
{
  "data": {
    "webhook_id": "uuid",
    "url": "string",
    "events": ["string"],
    "created_at": "ISO-8601"
  }
}
```

**Errors:**
- `400` if URL is not a valid HTTPS URL
- `403` if token lacks admin scope

### 7.2 Payload Format

When an event fires, the server POSTs to the registered URL with the following payload:

```json
{
  "task_id": "uuid",
  "event_type": "task.created | task.updated | task.deleted",
  "timestamp": "ISO-8601",
  "task": { /* full task object */ },
  "changed_fields": ["field1", "field2"]
}
```

Webhook payload must include: `task_id`, `event_type`, `timestamp`, `task` (full task object), `changed_fields` (array of field names that changed). Partial payloads that omit `task` or `changed_fields` are non-compliant.

### 7.3 Delivery and Retry

- Webhook delivery is asynchronous and non-blocking
- On non-`2xx` response from the target URL, retry the delivery
- Retry count increments on every failed attempt including partial success. Maximum 3 retries total.
- Retry schedule uses exponential backoff: 1s, 2s, 4s
- After 3 failed retries, mark the delivery as failed and log to the audit log
- Only a clean `2xx` response (not `206 Partial Content`) counts as successful delivery. Partial success responses (`206`) are treated as failures and increment the retry count.

## 8. Bulk Operations

### 8.1 Bulk Update

**PATCH /tasks/bulk** accepts an array of partial update objects.

```json
{
  "updates": [
    { "id": "uuid", "status": "done", "priority": 2 },
    ...
  ]
}
```

For each task update, field application order is defined: bulk update applies status last to ensure derived fields (`closed_at`) are computed from final state. Implementations must not apply status before other fields in the same update.

Each task update is atomic — either all fields are applied or none. The entire bulk request is not atomic; partial success is possible.

**Response (200):**

```json
{
  "data": {
    "updated": 5,
    "failed": [{ "id": "uuid", "error": "NOT_FOUND" }]
  }
}
```

### 8.2 Bulk Create

**POST /tasks/bulk** accepts an array of task objects. Each task follows the same validation as `POST /tasks`. Returns 207 with per-item results.

### 8.3 Bulk Delete

**DELETE /tasks/bulk** accepts an array of task IDs.

```json
{
  "ids": ["uuid1", "uuid2", ...]
}
```

Bulk delete must validate all IDs in a single pass before deleting any. Return `404 NOT_FOUND` if any ID is not found (atomic: all-or-nothing). If all IDs are valid, delete all of them. If any ID is invalid, delete none.

**Response (200):**

```json
{
  "data": { "deleted": 3 }
}
```

**Errors:**
- `404` if any task ID does not exist (no deletions performed)

### 8.4 Bulk Limits

Bulk operations are limited to 100 items per request. Requests exceeding this limit return `400 BULK_LIMIT_EXCEEDED`. This applies to bulk create, bulk update, and bulk delete equally.

## 9. Audit Logging

### 9.1 Scope

All mutating operations (POST, PATCH, DELETE) must be recorded in the audit log. The audit log captures:
- `timestamp` (ISO-8601, UTC)
- `user_id` (authenticated user)
- `method` and `path`
- `resource_id` (task ID if applicable)
- `action` (e.g., `task.created`, `task.updated`, `task.deleted`)
- `changes` (for updates: object with before/after values for changed fields)

### 9.2 Non-Blocking Writes

Audit logging must not block request processing. Log writes must be non-blocking (async queue or fire-and-forget). Synchronous writes to audit storage that delay the HTTP response are not permitted.

### 9.3 Retention

Audit log entries are retained for 90 days. Entries older than 90 days may be purged.

### 9.4 Access

Audit logs are accessible only to admin-scoped tokens via `GET /audit` (out of scope for this API version).

## 10. CORS Policy

CORS must restrict `Access-Control-Allow-Origin` to approved origins. Credentials mode requires explicit origin allowlist.

Specifically:
- `Access-Control-Allow-Origin: *` (wildcard) is not permitted when `Access-Control-Allow-Credentials: true` is set — this combination is rejected by browsers per the Fetch Standard
- The approved origins allowlist must be maintained server-side; origins not on the allowlist receive no `Access-Control-Allow-Origin` header
- Preflight `OPTIONS` requests must return the appropriate `Access-Control-Allow-Methods` and `Access-Control-Allow-Headers` headers

## 11. Implementation Requirements

### 11.1 Idempotency

All `DELETE` operations are idempotent. Deleting an already-deleted (or never-existing) task returns `404 NOT_FOUND`. A second delete of the same task is not a server error — it returns `404`.

### 11.2 Repository Encapsulation

Repository layer must enforce encapsulation. Callers must not be able to mutate stored state without going through repository methods. Repository methods must return copies or frozen objects — not direct references to internal store entries. Direct mutation of returned task objects by callers must not affect stored state.
