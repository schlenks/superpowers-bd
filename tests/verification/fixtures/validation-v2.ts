// ─── Validation Module for TaskFlow API ──────────────────────────────
//
// Centralized input validation. All validators return a result object
// with { valid: boolean, message?: string, trimmed?: string }.

export interface ValidationResult {
  valid: boolean;
  message?: string;
  trimmed?: string;
}

const VALID_STATUSES = ['todo', 'in_progress', 'done'] as const;

// ─── Title Validation ────────────────────────────────────────────────

/**
 * Validates a task title.
 * - Required (must not be undefined or null)
 * - Trimmed of leading/trailing whitespace
 * - Must be 1-200 characters after trimming
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

// ─── Priority Validation ─────────────────────────────────────────────

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

// ─── Due Date Validation ─────────────────────────────────────────────

/**
 * Validates a task due date.
 * - Must be a valid ISO-8601 date string
 * - Note: no future-date check here — the application layer
 *   decides whether to enforce future-only dates based on context
 *   (e.g., importing historical tasks may need past dates)
 */
export function validateDueDate(dueDate: unknown): ValidationResult {
  if (typeof dueDate !== 'string') {
    return { valid: false, message: 'due_date must be a string' };
  }

  const parsed = Date.parse(dueDate);

  if (isNaN(parsed)) {
    return { valid: false, message: 'due_date must be a valid ISO-8601 date' };
  }

  // Validate it's actually a reasonable date (not year 0 or year 99999)
  const date = new Date(parsed);
  const year = date.getFullYear();
  if (year < 2000 || year > 2100) {
    return { valid: false, message: 'due_date year must be between 2000 and 2100' };
  }

  return { valid: true };
}

// ─── Status Validation ───────────────────────────────────────────────

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
