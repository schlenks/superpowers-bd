# Verification Record Footer Template

Every plan MUST end with this Verification Record, assembled from sub-agent verdicts. Plans without it will be rejected.

After all 5 sub-agent verdicts are collected (plus 1 inline checklist self-review at task 2), read the plan one final time, build the tables below from the verdict strings, and append to the plan file.

```markdown
---

## Verification Record

### Plan Verification Checklist
| Check | Status | Notes |
|-------|--------|-------|
{rows from inline checklist self-review — one row per checklist item, populated from orchestrator self-review at task 2}

### Rule-of-Five-Plans Passes
| Pass | Status | Changes | Summary |
|------|--------|---------|---------|
| Draft | {STATUS} | {CHANGES} | {SUMMARY} |
| Feasibility | {STATUS} | {CHANGES} | {SUMMARY} |
| Completeness | {STATUS} | {CHANGES} | {SUMMARY} |
| Risk | {STATUS} | {CHANGES} | {SUMMARY} |
| Optimality | {STATUS} | {CHANGES} | {SUMMARY} |
```

The `{STATUS}`, `{CHANGES}`, and `{SUMMARY}` values come directly from each sub-agent's verdict. The checklist RESULTS rows come from the inline self-review announced at task 2 completion (see references/announcements-protocol.md — Plan Verification Checklist results template).

This record proves verification happened and documents what changed.
