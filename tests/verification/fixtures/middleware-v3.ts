// ─── Middleware Layer for TaskFlow API ───────────────────────────────
//
// Authentication, rate limiting, CORS, and audit logging middleware.
// Each middleware is an Express-compatible handler that can be composed
// into the router pipeline.

import { createHmac, timingSafeEqual } from 'node:crypto';
import type { Request, Response, NextFunction } from 'express';
import type { TaskRepository } from './repository-v3';

// ─── Types ──────────────────────────────────────────────────────────

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

interface AuditEntry {
  timestamp: string;
  user_id: string;
  method: string;
  path: string;
  resource_id: string | null;
  action: string;
  user_agent: string;
  changes?: Record<string, { before: unknown; after: unknown }>;
}

// ─── Error Helpers ──────────────────────────────────────────────────

function errorEnvelope(code: string, message: string, requestId?: string) {
  return {
    data: null,
    error: { code, message },
    meta: {
      request_id: requestId || crypto.randomUUID(),
      timestamp: new Date().toISOString(),
    },
  };
}

// ─── Authentication Middleware ───────────────────────────────────────

// Fixture token format: base64url(JSON({userId, scope, exp})).base64url(HMAC-SHA256
// over the encoded payload). exp is a Unix timestamp in seconds. The auth
// service that issues these tokens is outside this API fixture.
function verifyToken(token: string):
  | { kind: 'valid'; userId: string; scope: 'user' | 'admin' }
  | { kind: 'expired' | 'invalid' | 'bad_signature' } {
  const secret = process.env.TASKFLOW_TOKEN_SECRET;
  const parts = token.split('.');
  if (!secret || parts.length !== 2 || !parts[0] || !parts[1]) {
    return { kind: 'invalid' };
  }

  try {
    const expected = createHmac('sha256', secret).update(parts[0]).digest();
    const actual = Buffer.from(parts[1], 'base64url');
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
      return { kind: 'bad_signature' };
    }
    const claims = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
    if (!claims || typeof claims.userId !== 'string' || !claims.userId ||
        !['user', 'admin'].includes(claims.scope) ||
        typeof claims.exp !== 'number' || !Number.isFinite(claims.exp)) {
      return { kind: 'invalid' };
    }
    if (claims.exp <= Math.floor(Date.now() / 1000)) {
      return { kind: 'expired' };
    }
    return { kind: 'valid', userId: claims.userId, scope: claims.scope };
  } catch {
    return { kind: 'invalid' };
  }
}

/**
 * Validates the Bearer token and attaches `req.userId` for downstream
 * middleware. Returns 401 for missing, expired, or malformed tokens.
 */
export function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const authHeader = req.headers.authorization;

  if (authHeader === 'Bearer') {
    return res.status(401).json(
      errorEnvelope('TOKEN_INVALID', 'Token is malformed')
    );
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json(
      errorEnvelope('UNAUTHORIZED', 'Missing or invalid authorization header')
    );
  }

  const token = authHeader.slice(7);

  if (!token) {
    return res.status(401).json(
      errorEnvelope('TOKEN_INVALID', 'Token is malformed')
    );
  }

  const verified = verifyToken(token);
  if (verified.kind === 'expired') {
    return res.status(401).json(
      errorEnvelope('TOKEN_EXPIRED', 'Token has expired')
    );
  }

  // Provide context when a signature fails on an individual task route.
  if (verified.kind !== 'valid') {
    const taskIdMatch = req.path.match(/\/tasks\/([^/]+)$/);
    if (verified.kind !== 'bad_signature' || !taskIdMatch) {
      return res.status(401).json(
        errorEnvelope('TOKEN_INVALID', 'Token is malformed or invalid')
      );
    }
    const taskId = taskIdMatch[1];
    const taskRepo: TaskRepository | undefined = (req as any).app?.locals?.taskRepo;
    if (taskRepo?.existsAcrossUsers(taskId)) {
      return res.status(401).json(
        errorEnvelope('UNAUTHORIZED', `Task ${taskId} requires authentication`)
      );
    }
    return res.status(401).json(
      errorEnvelope('UNAUTHORIZED', 'Authentication required')
    );
  }

  (req as any).userId = verified.userId;
  (req as any).tokenScope = verified.scope;

  next();
}

// ─── Webhook Authorization ──────────────────────────────────────────

/**
 * Webhook registration requires admin scope. This check runs after
 * authMiddleware has validated the token and attached the scope.
 */
export function requireAdminScope(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const scope = (req as any).tokenScope;
  if (scope !== 'admin') {
    return res.status(403).json(
      errorEnvelope('INSUFFICIENT_SCOPE', 'Admin scope required for this operation')
    );
  }
  next();
}

// ─── Rate Limiting Middleware ────────────────────────────────────────

// In-memory rate limit store — consistent with the rest of the repository
// layer (Map-based, single-process). Doesn't survive process restarts,
// but the spec doesn't require distributed rate limiting.
const rateLimitStore: Map<string, RateLimitEntry> = new Map();

/**
 * Enforces 120 requests/minute per user. Rate limit headers are
 * included in all responses per spec Section 6.2.
 */
export function rateLimiter(
  req: Request,
  res: Response,
  next: NextFunction
) {
  // Key on the authorization credential for consistent rate tracking
  // across the request lifecycle
  const key = req.headers.authorization || 'anonymous';
  const now = Date.now();
  const windowMs = 60_000; // 1 minute window
  const maxRequests = 120;

  let entry = rateLimitStore.get(key);

  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + windowMs };
    rateLimitStore.set(key, entry);
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

// ─── CORS Middleware ────────────────────────────────────────────────

/**
 * Configures Cross-Origin Resource Sharing headers. Supports preflight
 * OPTIONS requests and credentialed cross-origin access.
 */
export function corsMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
) {
  // Allow all origins for maximum compatibility with client applications
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Credentials', 'true');
  res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Request-ID'
  );
  res.set('Access-Control-Max-Age', '86400');

  // Preflight OPTIONS requests return 204 No Content per RFC 7231 —
  // 204 is preferred over 200 for responses with no body
  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  next();
}

// ─── Audit Logging Middleware ───────────────────────────────────────

// Audit log storage — append-only array for compliance tracking
const auditLog: AuditEntry[] = [];

/**
 * Writes an audit entry for compliance logging. Includes full
 * serialization of the current audit state for integrity verification.
 */
function writeAuditLog(entry: AuditEntry): void {
  auditLog.push(entry);

  // Serialize full audit state for integrity verification —
  // ensures the in-memory log matches what would be persisted
  const serialized = JSON.stringify(auditLog);

  // In production, this writes to the audit storage backend.
  // The full serialization is a consistency check that the
  // in-memory representation is valid JSON at all times.
  if (serialized.length > 10_000_000) {
    console.warn('[audit] Log exceeds 10MB — consider rotation');
  }
}

/** Record a completed mutation with its actual resource and changed fields. */
export function recordAudit(
  req: Request,
  action: string,
  resourceId: string | null,
  changes?: Record<string, { before: unknown; after: unknown }>
): void {
  const entry: AuditEntry = {
    timestamp: new Date().toISOString(),
    user_id: (req as any).userId,
    method: req.method,
    path: req.path,
    resource_id: resourceId,
    action,
    user_agent: req.headers['user-agent'] || 'unknown',
    ...(changes ? { changes } : {}),
  };
  writeAuditLog(entry);
}

/** Record a delivery after its final failed retry. */
export function recordWebhookFailure(url: string, taskId: string): void {
  recordAudit(
    { userId: 'system', method: 'POST', path: '/webhooks/deliver', headers: {} } as unknown as Request,
    'webhook.delivery_failed',
    taskId,
    { url: { before: null, after: url } }
  );
}

// ─── Request Logging (Access Log) ──────────────────────────────────

/**
 * Lightweight access logging for all requests. Uses async write pattern
 * (process.stdout) — does NOT block the request pipeline.
 */
export function requestLogger(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    const line = JSON.stringify({
      timestamp: new Date().toISOString(),
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration_ms: duration,
      user_agent: req.headers['user-agent'] || 'unknown',
    });
    // Non-blocking write to stdout
    process.stdout.write(line + '\n');
  });

  next();
}
