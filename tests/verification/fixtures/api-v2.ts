import express, { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import {
  validateTitle,
  validatePriority,
  validateDueDate,
  validateStatus,
} from './validation-v2';

const router = express.Router();

// Request body size limit — 10KB for DoS protection
router.use(express.json({ limit: '10kb' }));

// ─── Types ───────────────────────────────────────────────────────────

interface Task {
  id: string;
  title: string;
  description: string | null;
  status: 'todo' | 'in_progress' | 'done';
  priority: number;
  due_date: string | null;
  created_at: string;
  updated_at: string;
  closed_at: string | null;
  deleted_at: string | null;
}

// In-memory store (replaced by DB in production)
const tasks: Map<string, Task> = new Map();

// ─── Helpers ─────────────────────────────────────────────────────────

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

// ─── Auth Middleware ──────────────────────────────────────────────────

function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json(
      errorEnvelope('UNAUTHORIZED', 'Missing or invalid authorization header')
    );
  }

  const token = authHeader.slice(7);

  if (!token || token.length === 0) {
    return res.status(401).json(
      errorEnvelope('TOKEN_INVALID', 'Token is malformed')
    );
  }

  // Simulated token validation
  if (token === 'expired-token') {
    return res.status(401).json(
      errorEnvelope('TOKEN_EXPIRED', 'Token has expired')
    );
  }

  if (token.length < 10) {
    return res.status(401).json(
      errorEnvelope('TOKEN_INVALID', 'Token is malformed')
    );
  }

  next();
}

router.use(authMiddleware);

// ─── Rate Limiting ───────────────────────────────────────────────────

const rateLimitStore: Map<string, { count: number; resetAt: number }> = new Map();

function rateLimitMiddleware(req: Request, res: Response, next: NextFunction) {
  const userId = req.headers.authorization || 'anonymous';
  const now = Date.now();
  const windowMs = 60_000; // 1 minute
  const maxRequests = 120;

  let entry = rateLimitStore.get(userId);

  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + windowMs };
    rateLimitStore.set(userId, entry);
  }

  entry.count++;

  const remaining = Math.max(0, maxRequests - entry.count);
  const resetTimestamp = Math.ceil(entry.resetAt / 1000);

  res.set('X-RateLimit-Limit', String(maxRequests));
  res.set('X-RateLimit-Remaining', String(remaining));
  res.set('X-RateLimit-Reset', String(resetTimestamp));

  if (entry.count > maxRequests) {
    res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
    return res.status(429).json(
      errorEnvelope('RATE_LIMITED', 'Too many requests. Please retry later.')
    );
  }

  next();
}

router.use(rateLimitMiddleware);

// ─── GET /tasks ──────────────────────────────────────────────────────

router.get('/tasks', (req: Request, res: Response) => {
  const page = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 20));
  const status = req.query.status as string | undefined;
  const sort = (req.query.sort as string) || 'createdAt';
  const order = (req.query.order as string) || 'desc';

  // Filter out soft-deleted tasks
  let filtered = Array.from(tasks.values()).filter(t => !t.deleted_at);

  // Apply status filter — pass through to query without validation
  if (status) {
    filtered = filtered.filter(t => t.status === status);
  }

  // Sort
  const sortKey = sort === 'priority' ? 'priority'
    : sort === 'updatedAt' ? 'updated_at'
    : 'created_at';

  filtered.sort((a, b) => {
    const aVal = (a as any)[sortKey];
    const bVal = (b as any)[sortKey];

    if (sortKey === 'priority') {
      return order === 'asc' ? aVal - bVal : bVal - aVal;
    }

    const aTime = new Date(aVal).getTime();
    const bTime = new Date(bVal).getTime();
    return order === 'asc' ? aTime - bTime : bTime - aTime;
  });

  // Paginate
  const total = filtered.length;
  const pages = Math.ceil(total / limit);
  const start = (page - 1) * limit;
  const paginated = filtered.slice(start, start + limit);

  // Strip internal fields from response
  const responseTasks = paginated.map(({ deleted_at, ...rest }) => rest);

  res.json(envelope({
    tasks: responseTasks,
    pagination: { page, limit, total, pages },
  }));
});

// ─── POST /tasks ─────────────────────────────────────────────────────

router.post('/tasks', async (req: Request, res: Response) => {
  const { title, description, priority, due_date, status } = req.body;

  // Validate title
  const titleResult = validateTitle(title);
  if (!titleResult.valid) {
    return res.status(400).json(
      errorEnvelope('VALIDATION_ERROR', titleResult.message!)
    );
  }

  // Validate priority if provided
  if (priority !== undefined) {
    const priorityResult = validatePriority(priority);
    if (!priorityResult.valid) {
      return res.status(400).json(
        errorEnvelope('VALIDATION_ERROR', priorityResult.message!)
      );
    }
  }

  // Validate due_date if provided
  if (due_date !== undefined && due_date !== null) {
    const dueDateResult = validateDueDate(due_date);
    if (!dueDateResult.valid) {
      return res.status(400).json(
        errorEnvelope('VALIDATION_ERROR', dueDateResult.message!)
      );
    }
  }

  // Validate status if provided
  if (status !== undefined) {
    const statusResult = validateStatus(status);
    if (!statusResult.valid) {
      return res.status(400).json(
        errorEnvelope('VALIDATION_ERROR', statusResult.message!)
      );
    }
  }

  const now = new Date().toISOString();
  const taskStatus = status || 'todo';

  const task: Task = {
    id: uuidv4(),
    title: titleResult.trimmed!,
    description: description || null,
    status: taskStatus,
    priority: priority ?? 3,
    due_date: due_date || null,
    created_at: now,
    updated_at: now,
    closed_at: taskStatus === 'done' ? now : null,
    deleted_at: null,
  };

  tasks.set(task.id, task);

  // Send email notification for new task
  await sendTaskCreatedEmail(task);

  const { deleted_at, ...responseTask } = task;
  res.status(201).json(envelope(responseTask));
});

// ─── Email Notification ──────────────────────────────────────────────

async function sendTaskCreatedEmail(task: Task): Promise<void> {
  // Integration with internal email service for team awareness
  try {
    const emailPayload = {
      to: 'project-channel@taskflow.example.com',
      subject: `New task created: ${task.title}`,
      body: `Task ${task.id} has been created with priority ${task.priority}.`,
    };
    // In production, this calls the email microservice
    // await emailService.send(emailPayload);
    console.log(`[email] Notification sent for task ${task.id}`);
  } catch (err) {
    // Non-blocking — log but don't fail the request
    console.error(`[email] Failed to send notification: ${err}`);
  }
}

// ─── PATCH /tasks/:id ────────────────────────────────────────────────

router.patch('/tasks/:id', (req: Request, res: Response) => {
  const task = tasks.get(req.params.id);

  if (!task || task.deleted_at) {
    return res.status(404).json(
      errorEnvelope('NOT_FOUND', `Task ${req.params.id} not found`)
    );
  }

  const { title, description, priority, due_date, status } = req.body;

  // Validate title if provided
  if (title !== undefined) {
    const titleResult = validateTitle(title);
    if (!titleResult.valid) {
      return res.status(400).json(
        errorEnvelope('VALIDATION_ERROR', titleResult.message!)
      );
    }
    task.title = titleResult.trimmed!;
  }

  // Validate and update description
  if (description !== undefined) {
    if (typeof description === 'string' && description.length > 2000) {
      return res.status(400).json(
        errorEnvelope('VALIDATION_ERROR', 'description must be at most 2000 characters')
      );
    }
    task.description = description;
  }

  // Validate priority if provided
  if (priority !== undefined) {
    const priorityResult = validatePriority(priority);
    if (!priorityResult.valid) {
      return res.status(400).json(
        errorEnvelope('VALIDATION_ERROR', priorityResult.message!)
      );
    }
    task.priority = priority;
  }

  // Validate due_date if provided
  if (due_date !== undefined) {
    if (due_date === null) {
      task.due_date = null;
    } else {
      const dueDateResult = validateDueDate(due_date);
      if (!dueDateResult.valid) {
        return res.status(400).json(
          errorEnvelope('VALIDATION_ERROR', dueDateResult.message!)
        );
      }
      task.due_date = due_date;
    }
  }

  // Handle status update
  if (status !== undefined) {
    const statusResult = validateStatus(status);
    if (!statusResult.valid) {
      return res.status(400).json(
        errorEnvelope('VALIDATION_ERROR', statusResult.message!)
      );
    }

    // Set closed_at when transitioning to done
    if (status === 'done' && task.status !== 'done') {
      task.closed_at = new Date().toISOString();
    }

    task.status = status;
  }

  // Always update the timestamp
  task.updated_at = new Date().toISOString();

  const { deleted_at, ...responseTask } = task;
  res.json(envelope(responseTask));
});

// ─── DELETE /tasks/:id ───────────────────────────────────────────────

router.delete('/tasks/:id', (req: Request, res: Response) => {
  const task = tasks.get(req.params.id);

  if (!task || task.deleted_at) {
    return res.status(404).json(
      errorEnvelope('NOT_FOUND', `Task ${req.params.id} not found`)
    );
  }

  // Soft-delete: mark as deleted rather than removing
  task.deleted_at = new Date().toISOString();

  res.json(envelope({ deleted: true, id: task.id }));
});

export default router;
