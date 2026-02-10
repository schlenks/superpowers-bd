# Verification Record Footer Template

Every plan MUST end with this Verification Record. Plans without it will be rejected.

```markdown
---

## Verification Record

### Plan Verification Checklist
| Check | Status | Notes |
|-------|--------|-------|
| Complete | check/cross | [explanation] |
| Accurate | check/cross | [paths verified via Glob] |
| Commands valid | check/cross | [commands tested] |
| YAGNI | check/cross | [tasks removed if any] |
| Minimal | check/cross | [tasks combined if any] |
| Not over-engineered | check/cross | [simplifications made if any] |
| Key Decisions documented | check/cross | [count of decisions] |
| Context sections present | check/cross | [tasks with Purpose/Not In Scope/Gotchas] |

### Rule-of-Five Passes
| Pass | Changes Made |
|------|--------------|
| Draft | [initial structure, N tasks] |
| Correctness | [specific fixes or "none needed"] |
| Clarity | [specific improvements or "none needed"] |
| Edge Cases | [additions or "none needed"] |
| Excellence | [polish or "none needed"] |
```

This record proves verification happened and documents what changed.
