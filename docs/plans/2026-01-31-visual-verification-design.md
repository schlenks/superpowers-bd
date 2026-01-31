# Visual Verification for Frontend Code

**Date:** 2026-01-31
**Status:** Approved
**Target:** `verification-before-completion` skill

## Summary

Add automatic visual verification to the verification-before-completion skill when:
1. Browser tools are available (superpowers-chrome or Playwright MCP)
2. Frontend files have been modified
3. Dev server is running

No prompts - fully automatic. If conditions aren't met, skip silently.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Trigger | Any frontend file changed | Conservative - can't predict what breaks UI |
| Detection | Runtime tool check | More reliable than config parsing |
| Verification | Smoke test | Good signal, low cost |
| URL inference | Tiered with fallback | Handles most cases gracefully |
| User prompts | None | Humans make mistakes, just verify |

## Tool Detection

```
superpowers-chrome available IF:
  → tool "mcp__plugin_superpowers-chrome_chrome__use_browser" exists

Playwright MCP available IF:
  → tool "browser_navigate" exists

No browser tools:
  → skip visual verification silently
```

## Frontend File Patterns

**Triggers verification:**
- Extensions: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`, `*.module.css`
- Directories: `components/`, `pages/`, `app/`, `views/`, `layouts/`, `hooks/`, `styles/`, `theme/`
- Config: `tailwind.config.*`, `postcss.config.*`

**Does not trigger:**
- Test files: `*.test.*`, `*.spec.*`, `__tests__/`
- Backend: `api/`, `server/`, `db/`

## URL Inference

```
1. Page/Route file changed?
   src/pages/products/index.tsx  → /products
   src/app/dashboard/page.tsx    → /dashboard

2. Dynamic route?
   src/pages/products/[id].tsx   → /products/1

3. Component file?
   → trace imports to find a page

4. Utility/hook?
   → check root page /

5. Multiple pages affected?
   → check each (max 3)

6. Can't determine?
   → / (root)
```

**Dev server URL detection:**
Check ports in order: 3000, 5173, 4200, 8080
Or parse "dev" script from package.json

## Smoke Test Procedure

```
1. NAVIGATE to inferred URL
   - Fail if: connection refused, 404, 500

2. WAIT for page load (max 5 seconds)
   - Fail if: timeout

3. CHECK console for errors
   - Fail if: uncaught exceptions, React errors
   - Warn if: deprecation warnings (don't fail)

4. VERIFY key elements exist
   - Check: page has content (not blank)
   - Check: no "error boundary" or crash messages
   - If specific component changed: verify element exists

5. CAPTURE screenshot as evidence

PASS: Page loads, no critical errors, elements render
FAIL: Any critical check fails → trigger gap closure loop
```

## Integration Point

Visual verification integrates into the existing Gate Function:

```
BEFORE claiming any status:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command
3. READ: Full output, check exit code
4. VERIFY: Does output confirm the claim?

   4a. VISUAL VERIFY (if applicable):
       - IF browser tools available
       - AND frontend files changed
       - THEN run visual smoke test
       - Evidence: screenshot + console check

5. ONLY THEN: Make the claim
```

## Failure Handling

Visual verification failures trigger the existing gap closure loop:
- Console errors → fix task → re-verify
- Missing elements → fix task → re-verify
- Max 3 attempts → escalate to human

## Skill Text Addition

Add new section to `verification-before-completion/SKILL.md` after "The Gate Function":

```markdown
## Visual Verification (Frontend)

When frontend code is modified and browser tools are available, visual verification
is part of the gate function - not optional.

### Automatic Triggering

Visual verification runs automatically when ALL conditions are met:
- Browser tools available (`mcp__plugin_superpowers-chrome_chrome__use_browser` OR `browser_navigate`)
- Frontend files changed (see patterns below)
- Dev server is running

If browser tools aren't available or no frontend files changed, skip silently.
If dev server isn't running, note: "Visual verification skipped: start dev server for browser testing"

### Frontend File Patterns

**Triggers verification:**
- Extensions: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`, `*.module.css`
- Directories: `components/`, `pages/`, `app/`, `views/`, `layouts/`, `hooks/`, `styles/`, `theme/`
- Config: `tailwind.config.*`, `postcss.config.*`

**Does not trigger:**
- Test files: `*.test.*`, `*.spec.*`, `__tests__/`
- Backend: `api/`, `server/`, `db/`

### Smoke Test Procedure

1. **Infer URL** from changed files (page routes → direct path, components → trace to page, fallback → `/`)
2. **Navigate** to dev server (check ports: 3000, 5173, 4200, 8080)
3. **Check console** for uncaught exceptions or React errors (fail if found)
4. **Verify elements** render (page not blank, no error boundaries)
5. **Capture screenshot** as evidence

### Failure Handling

Visual verification failures trigger the same gap closure loop:
- Console errors → fix task → re-verify
- Missing elements → fix task → re-verify
- Max 3 attempts → escalate to human
```

## Sources

- [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp)
- [Simon Willison's TIL on Playwright MCP](https://til.simonwillison.net/claude-code/playwright-mcp-claude-code)
- superpowers-chrome plugin documentation
