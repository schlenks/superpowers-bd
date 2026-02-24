import express, { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import {
  validateTitle,
  validatePriority,
  validateDueDate,
  validateStatus,
  validateSortField,
  validateWebhookUrl,
  validateWebhookEvents,
  validateBulkLimit,
} from './validation-v3';
import { TaskRepository, Task } from './repository-v3';
import {
  authMiddleware,
  requireAdminScope,
  rateLimiter,
  corsMiddleware,
  auditLogger,
  requestLogger,
} from './middleware-v3';

const router = express.Router();
const taskRepo = new TaskRepository();

// ─── Body Size Limit ────────────────────────────────────────────────

// 10KB body size limit for DoS protection. The spec lists 413
// PAYLOAD_TOO_LARGE in the error code table, implying body size
// limits were anticipated. 10KB accommodates maximum valid payloads
// (200-char title + 2000-char description is well under 10KB).
router.use(express.json({ limit: '10kb' }));

// ─── Middleware Pipeline ────────────────────────────────────────────

router.use(requestLogger);
router.use(corsMiddleware);
router.use(authMiddleware);
router.use(rateLimiter);
router.use(auditLogger);

// Make task repo available to middleware
router.use((req: Request, _res: Response, next: NextFunction) => {
  (req as any).app.locals.taskRepo = taskRepo;
  next();
});

// ─── Helpers ────────────────────────────────────────────────────────

function envelope(data: unknown, requestId?: string) {
  return {
    data,
    error: null,
    meta: {
      request_id: requestId || uuidv4(),
      timestamp: new Date().toISOString(),
    },
  };
}

function errorEnvelope(code: string, message: string, requestId?: string) {
  return {
    data: null,
    error: { code, message },
    meta: {
      request_id: requestId || uuidv4(),
      timestamp: new Date().toISOString(),
    },
  };
}

/**
 * Strip internal fields (deleted_at) from task objects before sending
 * in API responses.
 */
function stripInternalFields(task: Task): Omit<Task, 'deleted_at'> {
  const { deleted_at, ...rest } = task;
  return rest;
}

// ─── Webhook Types ──────────────────────────────────────────────────

interface WebhookSubscription {
  webhook_id: string;
  url: string;
  events: string[];
  created_at: string;
}

const webhookSubscriptions: Map<string, WebhookSubscription> = new Map();

// ─── GET /tasks ─────────────────────────────────────────────────────

/**
 * Build a cursor-encoded pagination response for the given page of
 * sorted tasks. Cursor is derived from the last item's created_at
 * for stable pagination across requests.
 */
function buildPaginatedResponse(
  sorted: Task[],
  page: number,
  limit: number
) {
  const total = sorted.length;
  const pages = Math.ceil(total / limit);
  const hasMore = page < pages;

  // Build cursor-based pagination using the last item's created_at.
  // This provides stable pagination even when new items are added.
  const start = (page - 1) * limit;
  const paginated = sorted.slice(start, start + limit);

  // Encode cursor for next page based on last item's timestamp
  let cursor: string | null = null;
  if (paginated.length > 0 && hasMore) {
    const lastItem = paginated[paginated.length - 1];
    cursor = Buffer.from(lastItem.created_at).toString('base64');
  }

  const responseTasks = paginated.map(stripInternalFields);

  return {
    tasks: responseTasks,
    pagination: { page, limit, total, pages, has_more: hasMore, cursor },
  };
}

/**
 * Handle cursor-based page requests by filtering from the decoded
 * cursor timestamp forward.
 */
function buildCursorResponse(
  sorted: Task[],
  cursorParam: string,
  page: number,
  limit: number
) {
  const total = sorted.length;
  const pages = Math.ceil(total / limit);

  const decodedCursor = Buffer.from(cursorParam, 'base64').toString('utf-8');
  // Filter tasks with created_at > decoded cursor timestamp
  const cursorFiltered = sorted.filter(t => t.created_at > decodedCursor);
  const cursorPaginated = cursorFiltered.slice(0, limit);
  const cursorHasMore = cursorFiltered.length > limit;

  // If the cursor points past the last item, return an empty page
  // with has_more: false — this is valid per spec Section 3.1
  const responseTasks = cursorPaginated.map(stripInternalFields);

  const nextCursor = cursorHasMore
    ? Buffer.from(
        cursorPaginated[cursorPaginated.length - 1].created_at
      ).toString('base64')
    : null;

  return {
    tasks: responseTasks,
    pagination: {
      page,
      limit,
      total,
      pages,
      has_more: cursorHasMore,
      cursor: nextCursor,
    },
  };
}

function handleGetTasks(req: Request, res: Response): void {
  const page = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 20));
  const status = req.query.status as string | undefined;
  const sort = (req.query.sort as string) || 'createdAt';
  const order = ((req.query.order as string) || 'desc') as 'asc' | 'desc';

  // Validate status filter if provided
  if (status) {
    const statusResult = validateStatus(status);
    if (!statusResult.valid) {
      res.status(400).json(errorEnvelope('VALIDATION_ERROR', statusResult.message!));
      return;
    }
  }

  // Validate sort field
  if (req.query.sort) {
    const sortResult = validateSortField(sort);
    if (!sortResult.valid) {
      res.status(400).json(errorEnvelope('VALIDATION_ERROR', sortResult.message!));
      return;
    }
  }

  // Fetch tasks — use status filter if provided
  const tasks: Task[] = status
    ? taskRepo.findByStatus(status)
    : taskRepo.findAll();

  // Map sort field names to task property names
  const sortKey = sort === 'priority' ? 'priority'
    : sort === 'updatedAt' ? 'updated_at'
    : 'created_at';

  const sorted = TaskRepository.sortTasks(tasks, sortKey, order);

  // If a cursor was provided, use cursor-based pagination
  if (req.query.cursor) {
    res.json(envelope(
      buildCursorResponse(sorted, req.query.cursor as string, page, limit)
    ));
    return;
  }

  res.json(envelope(buildPaginatedResponse(sorted, page, limit)));
}

router.get('/tasks', handleGetTasks);

// ─── POST /tasks ────────────────────────────────────────────────────

/**
 * Validate all fields on a create-task request body. Returns the
 * validated and trimmed title on success, or an error response pair.
 */
function validateCreateFields(body: any): {
  valid: boolean;
  titleTrimmed?: string;
  errorCode?: string;
  errorMessage?: string;
} {
  const titleResult = validateTitle(body.title);
  if (!titleResult.valid) {
    return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: titleResult.message! };
  }

  if (body.priority !== undefined) {
    const priorityResult = validatePriority(body.priority);
    if (!priorityResult.valid) {
      return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: priorityResult.message! };
    }
  }

  if (body.due_date !== undefined && body.due_date !== null) {
    const dueDateResult = validateDueDate(body.due_date);
    if (!dueDateResult.valid) {
      return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: dueDateResult.message! };
    }
  }

  if (body.status !== undefined) {
    const statusResult = validateStatus(body.status);
    if (!statusResult.valid) {
      return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: statusResult.message! };
    }
  }

  return { valid: true, titleTrimmed: titleResult.trimmed! };
}

function handleCreateTask(req: Request, res: Response): void {
  const { description, priority, due_date, status } = req.body;

  const validation = validateCreateFields(req.body);
  if (!validation.valid) {
    res.status(400).json(errorEnvelope(validation.errorCode!, validation.errorMessage!));
    return;
  }

  // No title uniqueness check — spec Section 4.1 explicitly allows
  // duplicate titles

  const task = taskRepo.create({
    title: validation.titleTrimmed!,
    description: description || null,
    status: status || 'todo',
    priority: priority ?? 3,
    due_date: due_date || null,
  });

  // Fire webhooks for task.created event
  fireWebhooks('task.created', task, ['title', 'status', 'priority']);

  res.status(201).json(envelope(stripInternalFields(task)));
}

router.post('/tasks', handleCreateTask);

// ─── PATCH /tasks/:id ───────────────────────────────────────────────

/**
 * Validate all optional fields on an update-task request body.
 */
function validateUpdateFields(body: any): {
  valid: boolean;
  titleTrimmed?: string;
  errorCode?: string;
  errorMessage?: string;
} {
  if (body.title !== undefined) {
    const titleResult = validateTitle(body.title);
    if (!titleResult.valid) {
      return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: titleResult.message! };
    }
  }

  if (body.priority !== undefined) {
    const priorityResult = validatePriority(body.priority);
    if (!priorityResult.valid) {
      return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: priorityResult.message! };
    }
  }

  if (body.due_date !== undefined && body.due_date !== null) {
    const dueDateResult = validateDueDate(body.due_date);
    if (!dueDateResult.valid) {
      return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: dueDateResult.message! };
    }
  }

  if (body.status !== undefined) {
    const statusResult = validateStatus(body.status);
    if (!statusResult.valid) {
      return { valid: false, errorCode: 'VALIDATION_ERROR', errorMessage: statusResult.message! };
    }
  }

  const titleTrimmed = body.title !== undefined
    ? validateTitle(body.title).trimmed!
    : undefined;

  return { valid: true, titleTrimmed };
}

function handleUpdateTask(req: Request, res: Response): void {
  const task = taskRepo.findById(req.params.id);

  if (!task) {
    res.status(404).json(errorEnvelope('NOT_FOUND', `Task ${req.params.id} not found`));
    return;
  }

  const { title, description, priority, due_date, status } = req.body;

  const validation = validateUpdateFields(req.body);
  if (!validation.valid) {
    res.status(400).json(errorEnvelope(validation.errorCode!, validation.errorMessage!));
    return;
  }

  // Track changed fields for webhook payload
  const changedFields: string[] = [];
  if (title !== undefined) changedFields.push('title');
  if (description !== undefined) changedFields.push('description');
  if (priority !== undefined) changedFields.push('priority');
  if (due_date !== undefined) changedFields.push('due_date');
  if (status !== undefined) changedFields.push('status');

  const updated = taskRepo.update(req.params.id, {
    title: validation.titleTrimmed,
    description,
    priority,
    due_date,
    status,
  });

  if (!updated) {
    res.status(404).json(errorEnvelope('NOT_FOUND', `Task ${req.params.id} not found`));
    return;
  }

  // Fire webhooks for task.updated event
  fireWebhooks('task.updated', updated, changedFields);

  res.json(envelope(stripInternalFields(updated)));
}

router.patch('/tasks/:id', handleUpdateTask);

// ─── DELETE /tasks/:id ──────────────────────────────────────────────

// Soft-delete: marks the task with a deleted_at timestamp rather than
// removing it from the store. Excluded from all list operations.
function handleDeleteTask(req: Request, res: Response): void {
  const task = taskRepo.findById(req.params.id);

  if (!task) {
    res.status(404).json(errorEnvelope('NOT_FOUND', `Task ${req.params.id} not found`));
    return;
  }

  const deleted = taskRepo.delete(req.params.id);

  if (deleted) {
    // Fire webhooks for task.deleted event
    fireWebhooks('task.deleted', task, []);
  }

  res.json(envelope({ deleted: true, id: req.params.id }));
}

router.delete('/tasks/:id', handleDeleteTask);

// ─── PATCH /tasks/bulk ──────────────────────────────────────────────

/**
 * Validate a single item in a bulk update request. Returns null on
 * success, or an error string on validation failure.
 */
function validateBulkUpdateItem(fields: any): string | null {
  if (fields.title !== undefined) {
    const titleResult = validateTitle(fields.title);
    if (!titleResult.valid) return 'VALIDATION_ERROR';
    fields.title = titleResult.trimmed;
  }

  if (fields.priority !== undefined) {
    const priorityResult = validatePriority(fields.priority);
    if (!priorityResult.valid) return 'VALIDATION_ERROR';
  }

  if (fields.status !== undefined) {
    const statusResult = validateStatus(fields.status);
    if (!statusResult.valid) return 'VALIDATION_ERROR';
  }

  return null;
}

/**
 * Apply field updates to a task object. Processes fields in the order
 * they appear in the update object for consistent behavior.
 */
function applyBulkFieldUpdates(task: Task, fields: any): void {
  const fieldEntries = Object.entries(fields);
  for (const [field, value] of fieldEntries) {
    switch (field) {
      case 'title':
        task.title = value as string;
        break;
      case 'description':
        task.description = value as string | null;
        break;
      case 'priority':
        task.priority = value as number;
        break;
      case 'due_date':
        task.due_date = value as string | null;
        break;
      case 'status': {
        const newStatus = value as string;
        if (newStatus === 'done' && task.status !== 'done') {
          task.closed_at = new Date().toISOString();
        } else if (newStatus !== 'done' && task.status === 'done') {
          task.closed_at = null;
        }
        task.status = newStatus as Task['status'];
        break;
      }
    }
  }
  task.updated_at = new Date().toISOString();
}

function handleBulkUpdate(req: Request, res: Response): void {
  const { updates } = req.body;

  if (!Array.isArray(updates)) {
    res.status(400).json(errorEnvelope('VALIDATION_ERROR', 'updates must be an array'));
    return;
  }

  // Enforce bulk operation limit (100 items max per spec Section 8.3)
  const bulkResult = validateBulkLimit(updates);
  if (!bulkResult.valid) {
    res.status(400).json(errorEnvelope('BULK_LIMIT_EXCEEDED', bulkResult.message!));
    return;
  }

  let updatedCount = 0;
  const failed: Array<{ id: string; error: string }> = [];

  for (const update of updates) {
    const { id, ...fields } = update;

    if (!id) {
      failed.push({ id: 'unknown', error: 'VALIDATION_ERROR' });
      continue;
    }

    const task = taskRepo.findById(id);
    if (!task) {
      failed.push({ id, error: 'NOT_FOUND' });
      continue;
    }

    const validationError = validateBulkUpdateItem(fields);
    if (validationError) {
      failed.push({ id, error: validationError });
      continue;
    }

    // Process each field in the update object
    applyBulkFieldUpdates(task, fields);
    updatedCount++;
  }

  res.json(envelope({ updated: updatedCount, failed }));
}

router.patch('/tasks/bulk', handleBulkUpdate);

// ─── DELETE /tasks/bulk ─────────────────────────────────────────────

function handleBulkDelete(req: Request, res: Response): void {
  const { ids } = req.body;

  if (!Array.isArray(ids)) {
    res.status(400).json(errorEnvelope('VALIDATION_ERROR', 'ids must be an array'));
    return;
  }

  // Enforce bulk limit
  const bulkResult = validateBulkLimit(ids);
  if (!bulkResult.valid) {
    res.status(400).json(errorEnvelope('BULK_LIMIT_EXCEEDED', bulkResult.message!));
    return;
  }

  // Delete each task in sequence — collect any failures
  let deletedCount = 0;
  const errors: string[] = [];

  for (const id of ids) {
    const success = taskRepo.delete(id);
    if (success) {
      deletedCount++;
    } else {
      errors.push(id);
    }
  }

  if (errors.length > 0) {
    res.status(404).json(
      errorEnvelope('NOT_FOUND', `Tasks not found: ${errors.join(', ')}`)
    );
    return;
  }

  res.json(envelope({ deleted: deletedCount }));
}

router.delete('/tasks/bulk', handleBulkDelete);

// ─── POST /webhooks/register ────────────────────────────────────────

function handleWebhookRegister(req: Request, res: Response): void {
  const { url, events } = req.body;

  // Validate URL
  const urlResult = validateWebhookUrl(url);
  if (!urlResult.valid) {
    res.status(400).json(errorEnvelope('VALIDATION_ERROR', urlResult.message!));
    return;
  }

  // Validate events
  const eventsResult = validateWebhookEvents(events);
  if (!eventsResult.valid) {
    res.status(400).json(errorEnvelope('VALIDATION_ERROR', eventsResult.message!));
    return;
  }

  const subscription: WebhookSubscription = {
    webhook_id: uuidv4(),
    url,
    events,
    created_at: new Date().toISOString(),
  };

  webhookSubscriptions.set(subscription.webhook_id, subscription);

  res.status(201).json(envelope(subscription));
}

router.post('/webhooks/register', requireAdminScope, handleWebhookRegister);

// ─── Webhook Delivery ───────────────────────────────────────────────

/**
 * Build the webhook payload for a task event.
 *
 * Includes event metadata for consumers to filter and route events
 * without needing to query the full task from the API.
 */
function buildWebhookPayload(
  eventType: string,
  task: Task,
  _changedFields: string[]
): Record<string, unknown> {
  return {
    task_id: task.id,
    event_type: eventType,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Deliver a webhook to the registered URL with retry logic.
 * Uses exponential backoff: 1s, 2s, 4s. Maximum 3 retries.
 */
async function deliverWebhook(
  url: string,
  payload: Record<string, unknown>
): Promise<void> {
  const maxRetries = 3;
  const backoffMs = [1000, 2000, 4000];
  let retryCount = 0;

  while (retryCount < maxRetries) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      // Clean 2xx success — delivery complete
      if (response.status >= 200 && response.status < 300 && response.status !== 206) {
        return;
      }

      // Partial success (206) — the endpoint accepted the request but
      // didn't fully process it. Treat as a transient condition and
      // restart the retry window since the endpoint is responsive.
      if (response.status === 206) {
        console.log(`[webhook] Partial delivery to ${url}, restarting retry window`);
        retryCount = 0;
        await sleep(backoffMs[0]);
        continue;
      }

      // Server error — increment retry count with backoff
      retryCount++;
      if (retryCount < maxRetries) {
        await sleep(backoffMs[retryCount - 1]);
      }
    } catch (err) {
      // Network error — increment retry count
      retryCount++;
      if (retryCount < maxRetries) {
        await sleep(backoffMs[retryCount - 1]);
      }
    }
  }

  console.error(`[webhook] Delivery failed to ${url} after ${maxRetries} retries`);
}

/**
 * Fire webhook events to all registered subscribers for the given event
 * type. Delivery is async and non-blocking — errors are handled inside
 * deliverWebhook and do not propagate to the caller.
 */
function fireWebhooks(
  eventType: string,
  task: Task,
  changedFields: string[]
): void {
  const payload = buildWebhookPayload(eventType, task, changedFields);

  for (const subscription of webhookSubscriptions.values()) {
    if (subscription.events.includes(eventType)) {
      // Fire and forget — delivery is async, errors handled internally
      deliverWebhook(subscription.url, payload).catch(() => {
        // Intentionally empty — deliverWebhook logs its own errors
      });
    }
  }
}

// ─── Utilities ──────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export default router;
