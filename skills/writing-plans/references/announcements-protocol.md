# Required Announcements Protocol

Announce each verification phase explicitly. This creates a visible audit trail.

## After Draft Plan Saved

After saving the plan file to disk, show a copy-pasteable `/compact` command with the **actual plan file path** (not a placeholder). Example output:

```
Plan written to docs/plans/2026-02-12-user-auth.md.

Context is heavy from research. Run this to free context for verification:

/compact Verification phase. Plan saved to docs/plans/2026-02-12-user-auth.md — re-read it from disk for each verification pass. Next: task 2 (Plan Verification Checklist), then tasks 3-7 (rule-of-five-plans: Draft, Feasibility, Completeness, Risk, Optimality). Drop all research findings, approach comparisons, and decision rationale. The plan speaks for itself.

After compaction finishes, type `continue` to resume verification.
```

Substitute the real path — the user should be able to copy-paste the `/compact` line directly. The last line ("type `continue`") is critical — `/compact` doesn't give the model a turn, so the user must send a follow-up message to restart work.

## Before Checklist

Mark "Plan Verification Checklist" todo in_progress, then announce:

```
Running Plan Verification Checklist...
- Complete: check/cross [explanation]
- Accurate: check/cross [files verified via Glob]
- Commands valid: check/cross [tested]
- YAGNI: check/cross [explanation]
- Minimal: check/cross [explanation]
- Not over-engineered: check/cross [explanation]
- Key Decisions documented: check/cross [count of decisions]
- Context sections present: check/cross [tasks with Purpose/Not In Scope/Gotchas]
```

## Before Each Rule-of-Five-Plans Pass

Mark corresponding todo in_progress, then announce:

```
Rule-of-five-plans pass N: [Pass Name]
Changes made: [list specific changes or "none needed"]
```
