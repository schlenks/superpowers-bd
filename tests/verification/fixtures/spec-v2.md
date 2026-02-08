# TaskFlow API Specification

Version 1.0 | Last updated: 2026-01-15

## 1. Overview

TaskFlow is a lightweight task management REST API. It supports creating, reading, updating, and deleting tasks with priority levels, due dates, and status tracking.

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
      "pages": 8
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

Permanently deletes a task. The task is removed from the database and cannot be recovered.

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

| Status | Code                | When                                        |
|--------|--------------------|--------------------------------------------|
| 400    | `VALIDATION_ERROR`  | Invalid input, missing required fields      |
| 401    | `UNAUTHORIZED`      | Missing or invalid auth token               |
| 404    | `NOT_FOUND`         | Task ID does not exist                      |
| 413    | `PAYLOAD_TOO_LARGE` | Request body exceeds size limit             |
| 429    | `RATE_LIMITED`       | Too many requests                           |
| 500    | `INTERNAL_ERROR`    | Unexpected server error                     |

## 6. Rate Limiting

- 120 requests per minute per authenticated user
- Rate limit headers included in all responses:
  - `X-RateLimit-Limit: 120`
  - `X-RateLimit-Remaining: <n>`
  - `X-RateLimit-Reset: <unix-timestamp>`
- When exceeded, return `429` with `Retry-After` header
