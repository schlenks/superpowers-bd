---
type: llm
weight: 2
focus:
  source: file
  path: validators.py
---

The file should define `is_valid_email(address)` returning a boolean.

PASS if all three rules are enforced: (1) the address must contain an "@"; (2) at least one character must precede the "@"; (3) the part after the "@" must contain a ".". Stricter extra checks are fine.

FAIL if the file is missing, the function is missing, or any of the three rules is not enforced (for example "@example.com" or "user@localhost" would be accepted).
