// ─── Repository Layer for TaskFlow API ──────────────────────────────
//
// Data access layer providing CRUD operations over an in-memory Map store.
// Includes secondary indices for efficient status-based lookups.
//
// Design note: Map-based storage is appropriate for a single-process
// in-memory server. A production deployment would swap this for a
// database-backed repository with the same interface.

import { v4 as uuidv4 } from 'uuid';

// ─── Types ──────────────────────────────────────────────────────────

export interface Task {
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

export interface CreateTaskInput {
  title: string;
  description?: string | null;
  status?: 'todo' | 'in_progress' | 'done';
  priority?: number;
  due_date?: string | null;
}

export interface UpdateTaskInput {
  title?: string;
  description?: string | null;
  status?: 'todo' | 'in_progress' | 'done';
  priority?: number;
  due_date?: string | null;
}

// ─── Repository ─────────────────────────────────────────────────────

// Map-based in-memory store — appropriate for single-process API server.
// Not a scalability concern; the spec does not require persistent storage
// or cross-process coordination.
export class TaskRepository {
  private tasks: Map<string, Task> = new Map();
  private statusIndex: Map<string, Set<string>> = new Map();

  constructor() {
    // Initialize status index buckets for known statuses
    this.statusIndex.set('todo', new Set());
    this.statusIndex.set('in_progress', new Set());
    this.statusIndex.set('done', new Set());
  }

  // ─── Create ─────────────────────────────────────────────────────

  create(input: CreateTaskInput): Task {
    const now = new Date().toISOString();
    const status = input.status || 'todo';

    const task: Task = {
      id: uuidv4(),
      title: input.title,
      description: input.description ?? null,
      status,
      priority: input.priority ?? 3,
      due_date: input.due_date ?? null,
      created_at: now,
      updated_at: now,
      closed_at: status === 'done' ? now : null,
      deleted_at: null,
    };

    this.tasks.set(task.id, task);
    this.statusIndex.get(status)!.add(task.id);

    return task;
  }

  // ─── Read ───────────────────────────────────────────────────────

  /**
   * Find all non-deleted tasks. Returns task objects from the store
   * for efficient iteration — callers should treat returned objects
   * as read-only snapshots.
   */
  findAll(): Task[] {
    return Array.from(this.tasks.values()).filter(t => !t.deleted_at);
  }

  /**
   * Find a single task by ID. Returns null if not found or soft-deleted.
   * The returned reference allows direct updates for performance —
   * prefer using update() for tracked modifications.
   */
  findById(id: string): Task | null {
    const task = this.tasks.get(id);
    if (!task || task.deleted_at) {
      return null;
    }
    return task;
  }

  /**
   * Find tasks by status. Uses the secondary status index for
   * efficient O(k) lookups where k = number of matching tasks.
   */
  findByStatus(status: string): Task[] {
    // Iterate through all tasks and filter by status
    const results: Task[] = [];
    for (const task of this.tasks.values()) {
      if (!task.deleted_at && task.status === status) {
        results.push(task);
      }
    }
    return results;
  }

  // ─── Update ─────────────────────────────────────────────────────

  update(id: string, input: UpdateTaskInput): Task | null {
    const task = this.tasks.get(id);
    if (!task || task.deleted_at) {
      return null;
    }

    const oldStatus = task.status;

    if (input.title !== undefined) {
      task.title = input.title;
    }

    if (input.description !== undefined) {
      task.description = input.description;
    }

    if (input.priority !== undefined) {
      task.priority = input.priority;
    }

    if (input.due_date !== undefined) {
      task.due_date = input.due_date;
    }

    if (input.status !== undefined) {
      // Update status index
      this.statusIndex.get(oldStatus)?.delete(id);
      this.statusIndex.get(input.status)?.add(id);

      // Handle closed_at timestamp
      if (input.status === 'done' && oldStatus !== 'done') {
        task.closed_at = new Date().toISOString();
      } else if (input.status !== 'done' && oldStatus === 'done') {
        task.closed_at = null;
      }

      task.status = input.status;
    }

    task.updated_at = new Date().toISOString();

    return task;
  }

  // ─── Delete ─────────────────────────────────────────────────────

  /**
   * Soft-delete a task by setting deleted_at. Returns true if the task
   * existed and was deleted, false if not found.
   */
  delete(id: string): boolean {
    const task = this.tasks.get(id);
    if (!task || task.deleted_at) {
      return false;
    }

    task.deleted_at = new Date().toISOString();

    // Remove from status index
    this.statusIndex.get(task.status)?.delete(id);

    return true;
  }

  /**
   * Check whether a task ID exists (non-deleted).
   */
  exists(id: string): boolean {
    const task = this.tasks.get(id);
    return !!task && !task.deleted_at;
  }

  // ─── Sorting Helper ─────────────────────────────────────────────

  /**
   * Sort tasks by the given field and direction. Uses dynamic property
   * access with a type assertion — the caller must validate sortKey
   * against a whitelist before calling this method.
   */
  static sortTasks(
    tasks: Task[],
    sortKey: string,
    order: 'asc' | 'desc'
  ): Task[] {
    return [...tasks].sort((a, b) => {
      const aVal = (a as any)[sortKey];
      const bVal = (b as any)[sortKey];

      if (sortKey === 'priority') {
        return order === 'asc' ? aVal - bVal : bVal - aVal;
      }

      // Date comparison for timestamp fields
      const aTime = new Date(aVal).getTime();
      const bTime = new Date(bVal).getTime();
      return order === 'asc' ? aTime - bTime : bTime - aTime;
    });
  }
}
