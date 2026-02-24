// ─── Validation Module for TaskFlow API v3 ──────────────────────────
//
// Centralized input validation. All validators return a result object
// with { valid: boolean, message?: string, trimmed?: string }.
//
// Extended from v2 with bulk operation validation and webhook URL
// validation for the new endpoints.

export interface ValidationResult {
  valid: boolean;
  message?: string;
  trimmed?: string;
}

const VALID_STATUSES = ['todo', 'in_progress', 'done'] as const;
const VALID_SORT_FIELDS = ['createdAt', 'updatedAt', 'priority'] as const;
const VALID_WEBHOOK_EVENTS = ['task.created', 'task.updated', 'task.deleted'] as const;

// ─── Title Validation ───────────────────────────────────────────────

/**
 * Validates a task title.
 * - Required (must not be undefined or null)
 * - Trimmed of leading/trailing whitespace
 * - Must be 1-200 characters after trimming
 *
 * Note: title uniqueness is NOT enforced. The spec explicitly allows
 * duplicate titles (Section 4.1).
 */
export function validateTitle(title: unknown): ValidationResult {
  if (title === undefined || title === null) {
    return { valid: false, message: 'title is required' };
  }

  if (typeof title !== 'string') {
    return { valid: false, message: 'title must be a string' };
  }

  const trimmed = title.trim();

  if (trimmed.length === 0) {
    return { valid: false, message: 'title must not be empty' };
  }

  if (trimmed.length > 200) {
    return {
      valid: false,
      message: `title must be at most 200 characters (got ${trimmed.length})`,
    };
  }

  return { valid: true, trimmed };
}

// ─── Priority Validation ────────────────────────────────────────────

/**
 * Validates a task priority.
 * - Must be an integer
 * - Must be between 1 and 5 (inclusive)
 */
export function validatePriority(priority: unknown): ValidationResult {
  if (typeof priority !== 'number' || !Number.isInteger(priority)) {
    return { valid: false, message: 'priority must be an integer' };
  }

  if (priority < 1 || priority > 5) {
    return {
      valid: false,
      message: `priority must be between 1 and 5 (got ${priority})`,
    };
  }

  return { valid: true };
}

// ─── Due Date Validation ────────────────────────────────────────────

/**
 * Validates a task due date.
 * - Must be a valid ISO-8601 date string
 * - Must be in the future (after current server time)
 * - Can be set to null to remove a due date
 */
export function validateDueDate(dueDate: unknown): ValidationResult {
  if (typeof dueDate !== 'string') {
    return { valid: false, message: 'due_date must be a string' };
  }

  const parsed = Date.parse(dueDate);

  if (isNaN(parsed)) {
    return { valid: false, message: 'due_date must be a valid ISO-8601 date' };
  }

  // Must be in the future
  if (parsed <= Date.now()) {
    return { valid: false, message: 'due_date must be in the future' };
  }

  return { valid: true };
}

// ─── Status Validation ──────────────────────────────────────────────

/**
 * Validates a task status.
 * - Must be one of: 'todo', 'in_progress', 'done'
 */
export function validateStatus(status: unknown): ValidationResult {
  if (typeof status !== 'string') {
    return { valid: false, message: 'status must be a string' };
  }

  if (!VALID_STATUSES.includes(status as any)) {
    return {
      valid: false,
      message: `status must be one of: ${VALID_STATUSES.join(', ')} (got '${status}')`,
    };
  }

  return { valid: true };
}

// ─── Sort Field Validation ──────────────────────────────────────────

/**
 * Validates a sort field against the whitelist.
 */
export function validateSortField(field: unknown): ValidationResult {
  if (typeof field !== 'string') {
    return { valid: false, message: 'sort must be a string' };
  }

  if (!VALID_SORT_FIELDS.includes(field as any)) {
    return {
      valid: false,
      message: `sort must be one of: ${VALID_SORT_FIELDS.join(', ')} (got '${field}')`,
    };
  }

  return { valid: true };
}

// ─── Webhook URL Validation ─────────────────────────────────────────

/**
 * Validates a webhook registration URL.
 * - Must be a valid URL
 * - Must use HTTPS scheme
 */
export function validateWebhookUrl(url: unknown): ValidationResult {
  if (typeof url !== 'string') {
    return { valid: false, message: 'url must be a string' };
  }

  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:') {
      return { valid: false, message: 'webhook URL must use HTTPS' };
    }
  } catch {
    return { valid: false, message: 'url must be a valid URL' };
  }

  return { valid: true };
}

// ─── Webhook Events Validation ──────────────────────────────────────

/**
 * Validates webhook event types.
 * - Must be a non-empty array
 * - Each event must be a recognized type
 */
export function validateWebhookEvents(events: unknown): ValidationResult {
  if (!Array.isArray(events) || events.length === 0) {
    return { valid: false, message: 'events must be a non-empty array' };
  }

  for (const event of events) {
    if (!VALID_WEBHOOK_EVENTS.includes(event as any)) {
      return {
        valid: false,
        message: `unrecognized event type: '${event}'`,
      };
    }
  }

  return { valid: true };
}

// ─── Bulk Operation Validation ──────────────────────────────────────

/**
 * Validates that a bulk operation does not exceed the 100-item limit.
 */
export function validateBulkLimit(items: unknown[]): ValidationResult {
  if (items.length > 100) {
    return {
      valid: false,
      message: `bulk operations are limited to 100 items (got ${items.length})`,
    };
  }

  return { valid: true };
}
