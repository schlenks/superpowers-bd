---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
effort: medium
---

# Verification Before Completion

Make completion claims only from fresh evidence produced in the same response
cycle as the claim. Evidence from an earlier turn is context, not proof for a
per-message completion gate.

## Gate

1. Identify the claim being made.
2. Choose the command or inspection that directly proves that claim.
3. Run it fresh and read the complete result, including exit code and failures.
4. Decide whether the result supports the claim. If verification is incomplete
   or failed, report the actual status.
5. **ONLY THEN:** Make the claim and include the command and result in the same
   completion message.

The proof must match the claim: a linter does not prove a build, a build does not
prove runtime behavior, and an agent report does not prove its own changes.

## Proportional Verification

Scale breadth to risk while keeping evidence fresh:

- **Documentation, metadata, and formatting:** Run the relevant formatter,
  validator, link check, render check, or focused structural test.
- **Localized code changes:** Run the focused regression plus the nearest
  affected suite and static checks.
- **Cross-component, public API, security, auth, payments, migrations, or data
  integrity:** Run the full relevant test/build stack and any required runtime or
  migration checks.

Use a dedicated progress item for multi-step or high-risk verification. A
one-line documentation correction does not need a ceremonial task if its direct
validator can be run immediately.

## Visual Verification

When frontend files changed and browser automation is available, include a
visual smoke check. If frontend files changed but browser verification cannot
run, report one concise skip reason in the final verification evidence. See
`references/visual-verification.md`.

## Gap Closure

When verification fails:

1. Record the failure evidence.
2. Fix the root cause.
3. Re-run the same verification.
4. After three failed repair attempts, stop and request human direction with the
   attempted fixes and current evidence.

See `references/gap-closure-protocol.md` for native progress examples.

## Evidence Examples

| Claim | Direct evidence | Not Sufficient |
|-------|-----------------|----------------|
| Tests pass | Relevant test command exits 0 with no failures | Earlier run or “should pass” |
| Linter clean | Configured linter exits 0 | Partial check or extrapolation |
| Build succeeds | Build command exits 0 | Linter passing |
| Bug fixed | Original symptom regression passes | Code changed |
| Requirements met | Requirement-by-requirement review plus tests | Tests alone |
| UI works | Browser smoke check and clean console | Build or visual inspection of code |

## Reference Files

- `references/visual-verification.md`: Load when frontend files changed
- `references/gap-closure-protocol.md`: Load after a verification failure
- `references/key-patterns-examples.md`: Load for claim-to-evidence examples
- `references/when-to-apply.md`: Load when the required verification boundary is unclear
- `references/SKILL.test.md`: Pressure-test scenarios
