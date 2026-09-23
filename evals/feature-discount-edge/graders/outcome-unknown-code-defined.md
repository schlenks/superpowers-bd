---
type: llm
weight: 1
focus:
  source: file
  path: discounts.py
---

PASS if an unrecognized discount code has explicit, deliberate behavior: it raises a clearly named/messaged error (for example `ValueError("unknown discount code ...")` or a custom exception), or is explicitly ignored/treated as no discount. Case-insensitive matching is fine either way.

FAIL if an unknown code would surface as an incidental `KeyError`/`TypeError` from a dict lookup or similar, or if `discounts.py` is missing.
