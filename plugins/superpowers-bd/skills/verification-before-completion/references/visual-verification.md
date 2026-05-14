# Visual Verification Protocol

When frontend code is modified and browser tools are available, visual verification
is part of the gate function - not optional.

## Automatic Triggering

Visual verification runs automatically when ALL conditions are met:
- Browser tools available (`mcp__plugin_superpowers-chrome_chrome__use_browser` OR `browser_navigate`)
- Frontend files changed (see patterns below)
- Dev server is running (check common ports: 3000, 5173, 4200, 8080)

If browser tools aren't available or no frontend files changed, skip silently.
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
