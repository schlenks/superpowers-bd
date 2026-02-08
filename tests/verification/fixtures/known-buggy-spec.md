# Widget API Implementation Spec

## Requirements

1. Create a REST API endpoint `GET /api/widgets` that returns all widgets
2. Create `POST /api/widgets` that creates a new widget with `name` (required) and `color` (optional, default "blue")
3. Create `DELETE /api/widgets/:id` that deletes a widget by ID
4. All endpoints return JSON with `{ data: ..., error: null }` envelope
5. Input validation: name must be 1-100 characters, alphanumeric only
6. Rate limiting: max 100 requests per minute per IP
