# Example Verification Output

Full annotated example of epic-verifier output showing engineering checklist, Rule-of-Five results, and verdict format.

```markdown
## Epic Verification: hub-auth

### Engineering Checklist

| Check | Status | Evidence |
|-------|--------|----------|
| YAGNI | PASS | All code traces to plan |
| Drift | PASS | JWT expiry 24h per spec |
| Tests | PASS | 47 tests cover auth flows |
| Regressions | PASS | 234 passing, 0 failing |
| Docs | PASS | README updated |
| Security | PASS | No secrets, validation present |

### Rule-of-Five: auth.service.ts (87 lines)
- Draft: PASS Clean structure
- Correctness: PASS Logic correct
- Clarity: PASS Well-named
- Edge Cases: PASS Handles failures
- Excellence: PASS Production ready

### Rule-of-Five: auth.middleware.ts (52 lines)
- Draft: PASS Standard pattern
- Correctness: FAIL Line 34: Missing null check
- Edge Cases: WARN Line 41: No malformed JWT handling

### Verdict: FAIL

Fix before re-verification:
1. auth.middleware.ts:34 - Add `if (!user?.roles)`
2. auth.middleware.ts:41 - Add try/catch for JWT.decode()
```

## Key Points

- **Checklist must have evidence column** — never just PASS/FAIL
- **Rule-of-Five runs per file** — only for files with >50 lines changed
- **Verdict is binary** — PASS or FAIL, no partial credit
- **FAIL includes fix list** — specific file:line with what to fix
