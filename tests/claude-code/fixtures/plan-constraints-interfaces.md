# Greeting Service Implementation Plan

> **After approval:** convert this plan to a beads epic with plan2beads, then execute it with subagent-driven-development unless a different execution path is explicitly chosen.

**Goal:** Build a tiny greeting service with a formatter and a renderer.
**Architecture:** A pure `format()` helper produces a greeting string; a `render()` entry point consumes it and returns the final output.
**Tech Stack:** JavaScript (Node)
**Key Decisions:**
- **Pure formatter:** Keep `format()` side-effect-free -- simpler to test than coupling it to I/O.

---

## Global Constraints

- Every task commits locally only; do NOT push or tag.
- All new functions ship with a unit test in the same task.
- No new runtime dependencies.

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `src/format.js` | Build the greeting string | Create |
| `src/render.js` | Render the greeting to output | Create |
| `tests/format.test.js` | Tests for format.js | Create |
| `tests/render.test.js` | Tests for render.js | Create |

## Task Structure

### Task 1: Greeting Formatter
**Depends on:** None
**Complexity:** simple
**Files:**
- Create: `src/format.js`
- Test: `tests/format.test.js`

**Interfaces:**
- Consumes: a `name` string
- Produces: `format(name)` returning the greeting string `Hello, <name>!`

**Purpose:** Provide the pure greeting builder the renderer depends on.

**Step 1: Write the failing test**
Run: `node --test tests/format.test.js`
Expected: FAIL
**Step 2: Implement `format(name)`**
**Step 3: Run test to verify it passes**
Run: `node --test tests/format.test.js`
Expected: PASS

### Task 2: Greeting Renderer
**Depends on:** Task 1
**Complexity:** simple
**Files:**
- Create: `src/render.js`
- Test: `tests/render.test.js`

**Interfaces:**
- Consumes: `format(name)` from `src/format.js`
- Produces: `render(name)` returning the rendered greeting line

**Purpose:** Consume the formatter and return the final rendered output.

**Step 1: Write the failing test**
Run: `node --test tests/render.test.js`
Expected: FAIL
**Step 2: Implement `render(name)` using `format(name)`**
**Step 3: Run test to verify it passes**
Run: `node --test tests/render.test.js`
Expected: PASS
