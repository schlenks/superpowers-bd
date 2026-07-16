# Visual Verification Protocol

**Load this reference when:** frontend files changed and the completion claim
depends on rendered behavior.

When frontend code is modified and browser tools are available, visual verification
is part of the gate function - not optional.

## Automatic Triggering

Visual verification runs automatically when ALL conditions are met:
- A browser-automation capability is available: navigation plus at least one of
  DOM inspection, screenshots, console inspection, or interaction. Detect this
  from the current tool descriptions rather than from one provider name.
  Known examples include
  `mcp__plugin_superpowers-chrome_chrome__use_browser` and `browser_navigate`,
  but the list is not exclusive.
- Frontend files changed (see patterns below)
- Dev server is running (check common ports: 3000, 5173, 4200, 8080)

If no frontend files changed, skip silently.
If frontend files changed but no browser capability is available, include one
final evidence line: "Visual verification skipped: no browser automation
capability available."
If dev server isn't running, note: "Visual verification skipped: start dev server for browser testing"

## Frontend File Patterns

**Triggers verification:**
- Extensions: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`, `*.module.css`
- Directories: `components/`, `pages/`, `app/`, `views/`, `layouts/`, `hooks/`, `styles/`, `theme/`
- Config: `tailwind.config.*`, `postcss.config.*`

**Does not trigger:**
- Test files: `*.test.*`, `*.spec.*`, `__tests__/`
- Backend: `api/`, `server/`, `db/`

## Smoke Test Procedure

1. **Infer URL** from changed files (page routes -> direct path, components -> trace to page, fallback -> `/`)
2. **Navigate** to dev server (check ports: 3000, 5173, 4200, 8080)
3. **Check console** for uncaught exceptions or React errors (fail if found)
4. **Verify elements** render (page not blank, no error boundaries)
5. **Capture screenshot** as evidence (save to temp/ with descriptive name)

## Failure Handling

Visual verification failures trigger the same gap closure loop:
- Console errors -> fix task -> re-verify
- Missing elements -> fix task -> re-verify
- Max 3 attempts -> escalate to human
