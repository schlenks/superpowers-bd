# V3 review fixture audit — 2026-09-22

**Decision: failed audit.** The V3.1 fixture is not suitable for automated precision or false-positive scoring. The two reviewer experiments that load it now stop before calling a model. The earlier pilot used V3.0 and remains historical evidence only.

The first repair made valid bulk payloads fit the parser, restored reachability of the bulk routes and seeded B5 lookup, and corrected B1 and B9 key explanations. Local contract checks pass, including tests that both experiment scripts stop before calling Claude and that scorer IDs match the key before a future calibrated run. A separate source-to-spec review found these remaining defects:

| Severity | Area | Evidence | Scoring effect |
| --- | --- | --- | --- |
| Critical | D12 and unkeyed authentication | `middleware-v3.ts` checks a token signature only on `/tasks/:id` and trusts client-supplied `x-auth-validated`; `/webhooks/register` infers admin scope from a token substring. | A reviewer correctly reporting admin access with a forged token can be scored as flagging a decoy. |
| Critical | Unkeyed task ownership | `spec-v3.md` promises tasks for the authenticated user, but `api-v3.ts` uses one global repository and `repository-v3.ts` stores no owner. | Cross-user task exposure is absent from the 12-bug key. |
| Important | D1 | The spec gives no minimum token length. `a.u.valid` satisfies the fixture's user and signature format, but the 10-character guard rejects it. | A concrete token-validation defect is marked as a decoy. |
| Important | D5 and webhook failure | The key says exhausted delivery is audit-logged; `api-v3.ts` only calls `console.error`, contrary to spec section 7.3. | A valid failed-delivery finding can be scored as a false positive. |
| Important | Audit contract | `auditLogger` runs before route matching, so `req.params.id` is unset; entries also lack required update before/after `changes`. | Material unkeyed findings overlap the audit area. |
| Important | Input and parser contracts | Bulk update skips due-date and description validation; create/update skip description length; the parser passes malformed JSON errors outside the required envelope. | Additional genuine defects are absent from the key. |

The independent reviewer found source support for B1–B12 as narrowly stated, with B1 representing an explicit ordering rule rather than a demonstrated wrong final state. D2–D4, D6–D11, and D13–D16 have support for their narrow claims. This was a source audit, not live HTTP execution; `tests-v3.md` describes tests but does not provide runnable application tests.

## Resume criteria

1. Repair the fixture without weakening the spec to excuse implementation bugs. Resolve D1 and D12 and audit every decoy against actual request paths.
2. Add runnable behavior checks for authentication, ownership, bulk updates, audit records, error envelopes, and each planted bug. Confirm no high-severity unkeyed defect remains.
3. Re-audit the key independently, then change `calibration_status` to `calibrated` and run repeated, matched reviewer trials. Adjudicate any new unkeyed finding manually before computing false-positive rates.

Keep the current review fanout until those trials capture model-aware tokens, cache use, wall time, tool calls, defect severity and recall, and successful task outcomes. CLI authentication and app-server startup were also unavailable at the last attempt.
