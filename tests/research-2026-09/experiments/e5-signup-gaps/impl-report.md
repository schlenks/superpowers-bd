[IMPL-REPORT] su-2 wave-1
### Evidence
- Commit: {sha} | Files: signup/validate.py, tests/test_validate.py (2 files, 95+) | Tests: 7/7 pass, exit 0
### Summary
- Implemented validate_signup covering all 10 acceptance criteria: required/normalized/validated email,
  password length/digit/email-local-part rules, optional trimmed display_name with blank and length
  checks, unknown-field errors, and sorted non-fail-fast error collection.
- Files modified: signup/validate.py, tests/test_validate.py (matches allowed list)
- Self-review: all criteria mapped to code and tests; no scope violations.
