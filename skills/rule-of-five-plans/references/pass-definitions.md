# Pass Definitions — Plans Variant

## Pass 1: Draft

**Focus:** Shape and structure. Get the outline right. Breadth over depth.

**Checklist:**
- All major sections exist (goal, architecture, tasks, verification)
- Task list is complete — every deliverable has a task
- Dependencies sketched (even if rough)
- Key Decisions section present with rationale
- Header template followed (Goal, Architecture, Tech Stack, Key Decisions)

**Exit when:** All major sections exist; task list complete.

## Pass 2: Feasibility

**Focus:** Can every step actually be executed?

**Checklist:**
- File paths verified via Glob (existing files exist, new files in correct locations)
- Commands tested or known to work (`pytest`, `npm test`, etc.)
- Dependencies available (libraries installed, APIs accessible)
- Estimates realistic (2-5 min per bite-sized step)
- No circular dependencies in task graph
- External service requirements documented

**Exit when:** No infeasible steps; all references verified.

## Pass 3: Completeness

**Focus:** Every requirement traced to a task?

**Checklist:**
- Every requirement from brainstorming/spec has a corresponding task
- Error handling tasks present where needed
- Rollback/cleanup tasks for destructive operations
- Documentation updates included
- Test tasks present for every feature task
- `Depends on:`, `Complexity:`, and `Files:` sections on every task

**Exit when:** Every requirement maps to task(s).

## Pass 4: Risk

**Focus:** What could go wrong?

**Checklist:**
- Migration risks identified (data loss, schema changes)
- Breaking changes documented (API changes, removed features)
- Parallel execution conflicts (file conflicts between tasks)
- External dependency failures (what if API is down?)
- Rollback plan exists for risky steps
- Security implications considered

**Exit when:** Risks identified and mitigated.

## Pass 5: Optimality

**Focus:** Simplest approach? YAGNI?

**Checklist:**
- Every task directly serves a stated requirement
- No over-engineering (abstractions for one use case, unnecessary configurability)
- Tasks that could be combined without losing clarity are combined
- Simplest approach chosen (not most elegant)
- No speculative tasks for "future" requirements
- You'd defend every task to a senior colleague

**Exit when:** You'd defend every task to a senior colleague.
