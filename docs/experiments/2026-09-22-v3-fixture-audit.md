# V3 review fixture audit — 2026-09-22

**Decision: V3.4 failed audit and is retired from treatment selection.** An Opus
5 high-effort probe found an unkeyed retry defect in V3.3 after its earlier
audit. Two independent V3.4 audits then found more unkeyed behavior and a
scorer parser error. The calibration gate remains `failed_audit`. Earlier
V3.0–V3.3 pilots are historical and cannot be compared directly with V3.4. The key and
both scorer scripts still define 12 planted defects (B1–B12) and 16 decoys
(D1–D16).

The V3.1 audit failed because two decoys were actual bugs and several severe
spec violations were outside the key. V3.2 repairs those request paths without
removing the planted findings:

A V3.2 Sonnet pilot then found a legitimate body-size test gap in the depicted
suite and assigned it to D7. Its false-positive score is therefore not valid
for precision analysis. V3.3 adds depicted tests for body-size handling, audit
entry fields, and CORS preflight while preserving B12's zero webhook tests.
The independent follow-up audit confirmed the V3.3 test and metadata changes.

The Opus probe found that V3.3 made only three HTTP attempts after persistent
failure, although the spec requires an initial attempt and three retries with
1s, 2s, and 4s backoff. An external HTTP test failed at 3 versus 4 attempts;
V3.4 changes the loop bound and the test now passes. The probe also questioned
whether bulk mutations should emit webhooks. V3.4 states that contract
explicitly and emits events for successful bulk items, with external HTTP
checks for bulk update and delete. The depicted 66-test suite still has no
webhook tests, preserving B12. This repair passed its focused HTTP check, but
it does not make the whole fixture suitable for scoring.

The later audit found an accepted empty description converted to `null`,
unchanged PATCH fields reported as changed, and an exact-window rate-limit
boundary error. One auditor also identified that both scorers counted braces
inside JSON strings, so a valid finding summary could be marked `PARSE_FAIL`.
The shared JSON decoder now has a regression test for unmatched braces in a
summary. The HTTP check still does not measure actual retry delays or the
planted 206 failure path. The auditors differed on whether all API issues are
independent of the planted defects; the observable empty-description case
alone is enough to keep the calibration gate closed. The [Opus high-effort
design](2026-09-22-opus-high-review-design.md) moves treatment selection to a
held-out task-level fixture.

| Prior finding | V3.2 change | Evidence |
| --- | --- | --- |
| D1 short-token rejection | Removed the arbitrary 10-character guard; D1 now covers empty bearer credentials. | Signed-token middleware test and HTTP `Bearer ` request return `TOKEN_INVALID`. |
| D12 forged admin scope | Verified HMAC token claims before trusting user ID or admin scope; admin check runs before webhook body parsing. | Middleware and HTTP tests reject forged admin claims and return `403` for valid non-admin claims. |
| Cross-user task access | Repository stores an internal owner ID and scopes every task operation. | Repository and HTTP tests cover another user's list, update, and delete paths. |
| Missing mutation and webhook-failure audit data | Route handlers record real resource IDs and before/after field changes; retry exhaustion records a system audit entry. | Middleware and HTTP tests inspect audit entries, including derived `closed_at` and failed delivery. |
| Invalid input and parser responses | Description and ISO due-date validation apply to create, update, and bulk update; malformed JSON has the standard error envelope. | Validation tests and HTTP checks cover length, format, malformed and oversized bodies. |
| Missing rate headers and invalid list parameters | 401/preflight responses carry rate headers; supplied list parameters are validated. | HTTP checks cover headers and empty or malformed query values. |

The independent V3.2 source review found B1–B12 still represented and D1–D16
supported by their narrow claims at that point, but the live pilot exposed
the D7 test gap. The V3.3 follow-up review found the depicted boundary tests
consistent with the key. B1 is an explicit status-last ordering
violation, but it does not produce a different final task state with the
fixture's current fields. Treat that limitation when interpreting recall.

## Verification

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/verification/test_fixture_v3.py tests/verification/test_fixture_repository_v3.py tests/verification/test_fixture_middleware_v3.py tests/verification/test_json_blocks.py`
- `node --experimental-strip-types --test tests/verification/test_fixture_validation_v3.mjs`
- `node tests/verification/test-fixture-v3-http.mjs` after installing the three
  exact test-only dependencies listed at the top of that file. It runs the
  actual Express router with signed tokens and checks integration behavior.
- `python3 tests/verification/check_fixture_calibration.py tests/verification/fixtures/ground-truth-v3.json` — expected to reject V3.4 while `failed_audit` is set.

During preservation on 2026-10-10, the fixture checks above were rerun. The
harness contract test now calibrates an isolated copy and uses a fake CLI to
exercise complete, incomplete, malformed, and failed responses under macOS
`/bin/bash`. It verifies retained prompts, responses, and single-attempt
failure records without opening the real fixture's calibration gate. Both
runners use a portable read loop instead of `mapfile`.

The 66-test suite in `tests-v3.md` is part of the review artifact and still has
zero webhook tests; the external fixture checks above are calibration tests,
not additions to that depicted suite. Each new trial must still review
unexpected findings manually before classifying them as false positives.
