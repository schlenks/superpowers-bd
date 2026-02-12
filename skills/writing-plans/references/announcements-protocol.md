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

## Before Each Verification Sub-Agent Dispatch

Mark the corresponding native task in_progress, then announce:

```
Dispatching verification sub-agent: {pass_name}...
```

## After Each Verdict Collected

Announce the verdict immediately:

```
{pass_name} verdict: {STATUS} — {SUMMARY}
```

For the checklist pass, include the per-item results:

```
Plan Verification Checklist verdict: {STATUS}
- Complete: {check/cross} {explanation}
- Accurate: {check/cross} {explanation}
- Commands valid: {check/cross} {explanation}
- YAGNI: {check/cross} {explanation}
- Minimal: {check/cross} {explanation}
- Not over-engineered: {check/cross} {explanation}
- Key Decisions documented: {check/cross} {explanation}
- Context sections present: {check/cross} {explanation}
{CHANGES} changes — {SUMMARY}
```

## After All Verdicts Collected

After appending the Verification Record to the plan file, display the populated tables to the user before calling ExitPlanMode:

```
Verification complete. Record appended to plan.

### Plan Verification Checklist
| Check | Status | Notes |
|-------|--------|-------|
| Complete | {check/cross} | {explanation} |
| Accurate | {check/cross} | {explanation} |
...

### Rule-of-Five-Plans Passes
| Pass | Status | Changes | Summary |
|------|--------|---------|---------|
| Draft | {STATUS} | {CHANGES} | {SUMMARY} |
| Feasibility | {STATUS} | {CHANGES} | {SUMMARY} |
| Completeness | {STATUS} | {CHANGES} | {SUMMARY} |
| Risk | {STATUS} | {CHANGES} | {SUMMARY} |
| Optimality | {STATUS} | {CHANGES} | {SUMMARY} |
```

Use the **actual values** from the collected verdicts — never show template placeholders to the user.

## On BLOCKED/FAIL Verdict

Stop the dispatch loop and announce:

```
Verification BLOCKED at {pass_name}: {SUMMARY}
Please resolve the issue before verification can continue.
```
