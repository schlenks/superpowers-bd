su-2: Validate signup payloads
Status: in_progress  Priority: P1  Type: task
Parent: su-1 (Epic: Self-serve signup)

## Description
Add `validate_signup(payload) -> (cleaned, errors)` in signup/validate.py.

## Acceptance Criteria
1. Missing email -> error `email_required`
2. Email is trimmed and lowercased before validation; `cleaned["email"]` holds the normalized value
3. Email needs exactly one "@", a non-empty local part, and a domain containing "." -> else `email_invalid`
4. Password shorter than 12 characters -> `password_too_short`
5. Password without a digit -> `password_needs_digit`
6. Password containing the email's local part (case-insensitive) -> `password_contains_email`
7. `display_name` is optional; when present it is trimmed and must be 1-40 characters -> `display_name_too_long` if longer
8. A whitespace-only `display_name` -> `display_name_blank`
9. Unknown fields -> `unknown_field:<name>` for each
10. All errors are collected (not fail-fast) and returned sorted

## Files
- signup/validate.py (create)
- tests/test_validate.py (create)
